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
import { gradeTranscript } from "../_shared/grade.ts";
import { addLeaguePoints } from "../_shared/league.ts";
import { rollChatStanding } from "../_shared/roll-chat.ts";

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

    // CANCEL — bin an open challenge you minted and nobody took.
    //
    // A code duel used to be permanent: mint one, and the card sat on
    // the Battles screen forever with no way to get rid of it. Codes
    // pile up, the screen turns into a graveyard, and the one button
    // that matters gets pushed further down every time.
    //
    // Only the man who created it, only while it is still OPEN, and
    // only if nobody has joined — once a rival is in, it is his fight
    // too and one player does not get to delete it.
    case "cancel": {
      const bid = body.battle_id as string | undefined;
      if (!bid) return Response.json({ error: "battle_id required" }, { status: 400 });
      const { data: row } = await admin.from("battles")
        .select("id, player_a, player_b, state").eq("id", bid).single();
      if (!row) return Response.json({ error: "not found" }, { status: 404 });
      if (row.player_a !== uid) {
        return Response.json({ error: "not yours" }, { status: 403 });
      }
      if (row.state !== "open" || row.player_b) {
        return Response.json({ error: "already claimed" }, { status: 409 });
      }
      await admin.from("battles").delete().eq("id", bid);
      return Response.json({ ok: true });
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

      // ── RIZZ POINTS — battles are the main feed into the text ladder.
      // A duel IS a graded text conversation, so it records a chat_attempt
      // like any other and the cumulative board picks it up. The grader
      // here is the shared 0..9999 rubric (battles predate the chat one
      // and re-grading would mean a second model call per submission), so
      // the score is rescaled by the app's standard 99.99 factor into the
      // 0..100 the text ladder speaks.
      await admin.from("chat_attempts").insert({
        user_id: uid,
        surface: "battle",
        scenario: b.scenario ?? null,
        score: Math.max(0, Math.min(100, Math.round(graded.score / 99.99))),
        rubric: graded.rubric,
      });

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
          // RR LIVES IN ITS OWN COLUMN — see migration 0012.
          //
          // This used to write `rating`, the same column score-voice
          // drifts by up to ±40 on every solo practice session. One
          // number moved by two unrelated systems means a duel win could
          // be wiped out by a mediocre daily an hour later, and a man who
          // never fought anyone still climbed the competitive ladder.
          //
          // battle_rating is moved by duels and nothing else. That is the
          // whole point of a ladder: it has to be unfarmable by anything
          // except the thing it claims to measure.
          const { data: elos } = await admin.from("rizz_elo")
            .select(
              "user_id, battle_rating, battle_peak, battles_won, battles_lost",
            )
            .in("user_id", [b.player_a, b.player_b]);
          const ea = elos?.find((e) => e.user_id === b.player_a);
          const eb = elos?.find((e) => e.user_id === b.player_b);
          const { newA, newB } = eloExchange(
            ea?.battle_rating ?? 1000,
            eb?.battle_rating ?? 1000,
            aWon,
          );
          await admin.from("rizz_elo").upsert([
            {
              user_id: b.player_a,
              battle_rating: newA,
              battle_peak: Math.max(ea?.battle_peak ?? 1000, newA),
              battles_won: (ea?.battles_won ?? 0) + (aWon ? 1 : 0),
              battles_lost: (ea?.battles_lost ?? 0) + (aWon ? 0 : 1),
              updated_at: new Date().toISOString(),
            },
            {
              user_id: b.player_b,
              battle_rating: newB,
              battle_peak: Math.max(eb?.battle_peak ?? 1000, newB),
              battles_won: (eb?.battles_won ?? 0) + (aWon ? 0 : 1),
              battles_lost: (eb?.battles_lost ?? 0) + (aWon ? 1 : 0),
              updated_at: new Date().toISOString(),
            },
          ]);
        }
        // Tie → state scored, winner stays null, no ELO movement.
        // Duel winner banks a league bonus on top of the session fuel.
        if (patch.winner) {
          await addLeaguePoints(admin, patch.winner as string, 15);
        }

        // Settle the RIZZ POINTS side too. Both men get their battle
        // counted; the winner also banks the flat win bonus. Rolled from
        // the attempts each time, so a retry can't inflate anyone.
        const winnerId = patch.winner as string | undefined;
        await Promise.all([
          rollChatStanding(admin, b.player_a as string, {
            addBattle: true,
            addWin: winnerId === b.player_a,
          }),
          rollChatStanding(admin, b.player_b as string, {
            addBattle: true,
            addWin: winnerId === b.player_b,
          }),
        ]);
      } else {
        // First man in. His attempt already counts toward the ladder —
        // the battle tally waits until the duel actually settles, so a
        // challenge nobody answers can't pad his record.
        await rollChatStanding(admin, uid);
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
