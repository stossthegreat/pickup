// ═════════════════════════════════════════════════════════════════════
//  battle-action — RIZZ BATTLES.
//
//  Two men. The same AI woman. Both run the scenario blind; the shared
//  rubric (same one as solo sessions) grades both; higher score takes
//  the duel and ELO changes hands. All lifecycle writes happen here via
//  the service role — clients can only read their own battles.
//
//  POST (user JWT) { action, ... }:
//    create      {scenario}        → mint a code duel, caller = player A
//    join        {code}            → claim the open duel as player B
//    queue       {}                → pair with a waiting stranger, or wait
//    leave_queue {}                → withdraw from matchmaking
//    submit      {battle_id, transcript} → grade caller's attempt; when
//                both sides are in, settle the duel + exchange ELO
//
//  Deploy:  supabase functions deploy battle-action
//  (OPENAI_API_KEY shared with score-voice.)
// ═════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { gradeTranscript, tierFor } from "../_shared/grade.ts";
import { addLeaguePoints } from "../_shared/league.ts";

// Scenario keys mirror the app's vibe keys — both players are forced
// into the SAME AI personality, which is what makes it a duel.
const SCENARIOS = [
  "cold",
  "into_you",
  "chaos",
  "testing",
  "ice_then_fire",
  "sweet",
];

const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const mintCode = () =>
  Array.from(
    { length: 6 },
    () => CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)],
  ).join("");

// Classic ELO exchange for a settled duel. K=32.
function eloExchange(ra: number, rb: number, aWon: boolean) {
  const expectedA = 1 / (1 + Math.pow(10, (rb - ra) / 400));
  const delta = Math.round(32 * ((aWon ? 1 : 0) - expectedA));
  return { newA: Math.max(0, ra + delta), newB: Math.max(0, rb - delta) };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return Response.json({ error: "not signed in" }, { status: 401 });
  }
  const uid = userData.user.id;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const body = await req.json().catch(() => ({}));
  const action = body.action as string;

  switch (action) {
    // ── CHALLENGE A FRIEND ─────────────────────────────────────────
    case "create": {
      const scenario = SCENARIOS.includes(body.scenario)
        ? body.scenario
        : SCENARIOS[Math.floor(Math.random() * SCENARIOS.length)];
      const { data, error } = await admin.from("battles").insert({
        scenario,
        mode: "code",
        invite_code: mintCode(),
        player_a: uid,
        state: "open",
      }).select().single();
      if (error) return Response.json({ error: "could not create" }, { status: 500 });
      return Response.json({ battle: data });
    }

    // ── ENTER WITH CODE ────────────────────────────────────────────
    case "join": {
      const code = String(body.code ?? "").trim().toUpperCase();
      const { data: b } = await admin.from("battles").select()
        .eq("invite_code", code).eq("state", "open").maybeSingle();
      if (!b) return Response.json({ error: "invalid code" }, { status: 404 });
      if (b.player_a === uid) {
        return Response.json({ error: "that is your own battle" }, { status: 400 });
      }
      const { data, error } = await admin.from("battles")
        .update({ player_b: uid, state: "active" })
        .eq("id", b.id).eq("state", "open").is("player_b", null)
        .select().single();
      if (error || !data) {
        return Response.json({ error: "battle already claimed" }, { status: 409 });
      }
      return Response.json({ battle: data });
    }

    // ── LINE UP (random matchmaking) ───────────────────────────────
    case "queue": {
      // Oldest waiting stranger, else join the line ourselves.
      const { data: waiting } = await admin.from("battle_queue").select()
        .neq("user_id", uid).order("enqueued_at", { ascending: true })
        .limit(1);
      const opponent = waiting?.[0];
      if (opponent) {
        // Claim them — the delete's row count is the lock, so two
        // concurrent pairers can't both take the same opponent.
        const { data: claimed } = await admin.from("battle_queue").delete()
          .eq("user_id", opponent.user_id).select();
        if (claimed && claimed.length > 0) {
          await admin.from("battle_queue").delete().eq("user_id", uid);
          const scenario =
            SCENARIOS[Math.floor(Math.random() * SCENARIOS.length)];
          const { data: battle } = await admin.from("battles").insert({
            scenario,
            mode: "random",
            player_a: opponent.user_id,
            player_b: uid,
            state: "active",
          }).select().single();
          return Response.json({ battle });
        }
      }
      await admin.from("battle_queue").upsert({ user_id: uid });
      return Response.json({ queued: true });
    }

    case "leave_queue": {
      await admin.from("battle_queue").delete().eq("user_id", uid);
      return Response.json({ left: true });
    }

    // ── SUBMIT AN ATTEMPT ──────────────────────────────────────────
    case "submit": {
      const battleId = String(body.battle_id ?? "");
      const transcript = String(body.transcript ?? "");
      if (transcript.trim().length < 20) {
        return Response.json({ error: "transcript too short" }, { status: 400 });
      }
      const { data: b } = await admin.from("battles").select()
        .eq("id", battleId).maybeSingle();
      if (!b) return Response.json({ error: "no such battle" }, { status: 404 });
      if (b.state === "scored") {
        return Response.json({ error: "battle already settled" }, { status: 409 });
      }
      const isA = b.player_a === uid;
      const isB = b.player_b === uid;
      if (!isA && !isB) {
        return Response.json({ error: "not your battle" }, { status: 403 });
      }
      if ((isA && b.a_score != null) || (isB && b.b_score != null)) {
        return Response.json({ error: "attempt already submitted" }, { status: 409 });
      }

      const graded = await gradeTranscript(transcript);
      if (!graded) {
        return Response.json({ error: "grader unavailable" }, { status: 502 });
      }

      // Battles fuel the weekly league/fixture engine like any session.
      await addLeaguePoints(admin, uid, Math.round(graded.score / 200));

      const patch: Record<string, unknown> = isA
        ? { a_score: graded.score }
        : { b_score: graded.score };

      const aScore = isA ? graded.score : b.a_score;
      const bScore = isB ? graded.score : b.b_score;
      let settled = false;

      // Both attempts in → settle the duel + exchange ELO.
      if (aScore != null && bScore != null && b.player_a && b.player_b) {
        settled = true;
        patch.state = "scored";
        if (aScore !== bScore) {
          const aWon = aScore > bScore;
          patch.winner = aWon ? b.player_a : b.player_b;
          const { data: elos } = await admin.from("rizz_elo")
            .select("user_id, rating, peak")
            .in("user_id", [b.player_a, b.player_b]);
          const ea = elos?.find((e) => e.user_id === b.player_a);
          const eb = elos?.find((e) => e.user_id === b.player_b);
          const { newA, newB } = eloExchange(
            ea?.rating ?? 1000,
            eb?.rating ?? 1000,
            aWon,
          );
          await admin.from("rizz_elo").upsert([
            {
              user_id: b.player_a,
              rating: newA,
              tier: tierFor(newA),
              peak: Math.max(ea?.peak ?? 1000, newA),
              updated_at: new Date().toISOString(),
            },
            {
              user_id: b.player_b,
              rating: newB,
              tier: tierFor(newB),
              peak: Math.max(eb?.peak ?? 1000, newB),
              updated_at: new Date().toISOString(),
            },
          ]);
        }
        // Tie → state scored, winner stays null, no ELO movement.
        // Duel winner banks a league bonus on top of the session fuel.
        if (patch.winner) {
          await addLeaguePoints(admin, patch.winner as string, 15);
        }
      }

      const { data: updated } = await admin.from("battles").update(patch)
        .eq("id", battleId).select().single();

      return Response.json({
        battle: updated,
        yourScore: graded.score,
        rubric: graded.rubric,
        settled,
      });
    }

    default:
      return Response.json({ error: "unknown action" }, { status: 400 });
  }
});
