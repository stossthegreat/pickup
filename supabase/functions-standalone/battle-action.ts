// ═══════════════════════════════════════════════════════════════════
//  battle-action — SELF-CONTAINED copy-paste version.
//
//  Paste this ENTIRE file into:
//    Supabase -> Edge Functions -> Deploy a new function -> via Editor
//    The function name MUST be exactly:  battle-action
//
//  No CLI, no access token, no GitHub. The shared helpers are inlined
//  below instead of imported, which is what makes the browser editor
//  work.
//
//  (The clean DRY versions live in supabase/functions/ and are what a
//  CLI/CI deploy uses. Keep the logic in sync if you edit one.)
// ═══════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";

// ── inlined shared helpers ─────────────────────────────────────────

// Shared grading core — the ONE rubric every score in the system comes
// from. score-voice (solo sessions) and battle-action (duels) both
// import this, so a solo 8,200 and a battle 8,200 mean the same thing.
// Folders starting with _ are not deployed as functions.

const RUBRIC_AXES = [
  "confidence",
  "flow",
  "wit",
  "recovery",
  "close",
] as const;

const WEIGHTS: Record<(typeof RUBRIC_AXES)[number], number> = {
  confidence: 0.26,
  flow: 0.24,
  wit: 0.18,
  recovery: 0.18,
  close: 0.14,
};

const TIERS: Array<[string, number]> = [
  ["HIM", 1900],
  ["DANGEROUS", 1600],
  ["CONTENDER", 1300],
  ["INITIATE", 1100],
  ["OBSERVER", 0],
];

const tierFor = (r: number) => TIERS.find(([, min]) => r >= min)![0];

const GRADER_PROMPT = `You are the scoring engine for a social-confidence
training app. Grade the user's half of this practice roleplay transcript
on five axes, each 0-100:

confidence — certainty, directness, owning statements, no approval-seeking
flow       — natural rhythm, listening, building on what she says
wit        — humour, playfulness, spark (calibrated, never mean)
recovery   — how they handle pushback, rejection, curveballs, silence
close      — momentum toward a respectful, concrete next step

Grade HONESTLY on a real-world standard. 50 = average nervous attempt,
70 = genuinely good, 85+ = exceptional and rare, 95+ = almost never.
A short or low-effort transcript caps every axis at 40.

Return ONLY JSON: {"confidence":n,"flow":n,"wit":n,"recovery":n,"close":n}`;

interface GradeResult {
  rubric: Record<string, number>;
  weighted: number; // 0..100
  score: number; // 0..9999
}

/// Grade a transcript with the fixed rubric at temperature 0.
/// Returns null when the grader is unreachable or returns junk.
async function gradeTranscript(
  transcript: string,
): Promise<GradeResult | null> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: GRADER_PROMPT },
        { role: "user", content: transcript.slice(0, 24_000) },
      ],
    }),
  });
  if (!res.ok) return null;

  let rubric: Record<string, number>;
  try {
    rubric = JSON.parse((await res.json()).choices[0].message.content);
  } catch {
    return null;
  }
  for (const axis of RUBRIC_AXES) {
    const v = Number(rubric[axis]);
    rubric[axis] = Number.isFinite(v)
      ? Math.max(0, Math.min(100, Math.round(v)))
      : 0;
  }
  const weighted = RUBRIC_AXES.reduce(
    (sum, axis) => sum + rubric[axis] * WEIGHTS[axis],
    0,
  );
  return { rubric, weighted, score: Math.round(weighted * 99.99) };
}

// Shared league core — enrolment, points, lazy week-end settlement.
// Used by daily-game (the main door) and score-voice (casual roleplay
// sessions passively feed the league — Duolingo's auto-enrol trick, so
// normal-mode players appear in the game without opting in).

// deno-lint-ignore-file no-explicit-any

const DIVISIONS = [
  "ROOKIE LEAGUE",
  "PLAYER LEAGUE",
  "SAVAGE LEAGUE",
  "ELITE LEAGUE",
  "HIM LEAGUE",
];
const MAX_DIVISION = DIVISIONS.length;
const LEAGUE_SIZE = 30;
const PROMOTE_TOP = 10;
const RELEGATE_BOTTOM = 5;

/// Monday (UTC) of the week containing `now`, as YYYY-MM-DD.
function weekStart(now = new Date()): string {
  const d = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
  ));
  const dow = (d.getUTCDay() + 6) % 7; // Mon=0..Sun=6
  d.setUTCDate(d.getUTCDate() - dow);
  return d.toISOString().slice(0, 10);
}

/// Sunday 21:00 UTC of the given week — when the league locks.
function lockTime(week: string): string {
  const d = new Date(`${week}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 6);
  d.setUTCHours(21, 0, 0, 0);
  return d.toISOString();
}

/// Settle LAST week for this user if unsettled (lazy — no cron needed):
/// top 10 of their old league promote, bottom 5 relegate. Returns the
/// ceremony ('promoted' | 'relegated' | 'held') or null when nothing to
/// settle.
async function settleLastWeek(
  admin: any,
  uid: string,
): Promise<string | null> {
  const lastWeek = weekStart(
    new Date(Date.now() - 7 * 24 * 3600_000),
  );
  const { data: memberships } = await admin
    .from("league_members")
    .select("league_id, points, settled, leagues!inner(week_start, division)")
    .eq("user_id", uid)
    .eq("settled", false)
    .eq("leagues.week_start", lastWeek);
  const m = memberships?.[0];
  if (!m) return null;

  const { data: standings } = await admin
    .from("league_members")
    .select("user_id, points")
    .eq("league_id", m.league_id)
    .order("points", { ascending: false });
  const rank =
    (standings ?? []).findIndex((r: any) => r.user_id === uid) + 1;
  const division = m.leagues.division as number;

  let ceremony = "held";
  let newDivision = division;
  if (rank > 0 && rank <= PROMOTE_TOP && division < MAX_DIVISION) {
    newDivision = division + 1;
    ceremony = "promoted";
  } else if (
    rank > (standings?.length ?? 0) - RELEGATE_BOTTOM &&
    division > 1
  ) {
    newDivision = division - 1;
    ceremony = "relegated";
  }

  await admin.from("profiles").update({ division: newDivision })
    .eq("id", uid);
  await admin.from("league_members").update({ settled: true })
    .eq("league_id", m.league_id).eq("user_id", uid);
  return ceremony;
}

/// Ensure the user is in a league THIS week (auto-enrol, Duolingo
/// style): join the emptiest open league in their division or found a
/// new one. Returns the league id.
async function ensureLeague(
  admin: any,
  uid: string,
): Promise<string> {
  const week = weekStart();
  // Already in?
  const { data: mine } = await admin
    .from("league_members")
    .select("league_id, leagues!inner(week_start)")
    .eq("user_id", uid)
    .eq("leagues.week_start", week);
  if (mine && mine.length > 0) return mine[0].league_id as string;

  const { data: prof } = await admin.from("profiles")
    .select("division").eq("id", uid).single();
  const division = prof?.division ?? 1;

  // Emptiest league in this division/week with room.
  const { data: leagues } = await admin
    .from("leagues")
    .select("id, league_members(count)")
    .eq("week_start", week)
    .eq("division", division);
  let target = (leagues ?? [])
    .map((l: any) => ({
      id: l.id as string,
      count: l.league_members?.[0]?.count ?? 0,
    }))
    .filter((l: any) => l.count < LEAGUE_SIZE)
    .sort((a: any, b: any) => a.count - b.count)[0]?.id;

  if (!target) {
    const { data: created } = await admin.from("leagues")
      .insert({ week_start: week, division }).select().single();
    target = created!.id as string;
  }
  await admin.from("league_members")
    .upsert({ league_id: target, user_id: uid });
  return target;
}

/// Add points to this week's league row (auto-enrolling first).
async function addLeaguePoints(
  admin: any,
  uid: string,
  points: number,
): Promise<void> {
  const leagueId = await ensureLeague(admin, uid);
  const { data: row } = await admin.from("league_members")
    .select("points").eq("league_id", leagueId).eq("user_id", uid)
    .single();
  await admin.from("league_members")
    .update({ points: (row?.points ?? 0) + points })
    .eq("league_id", leagueId).eq("user_id", uid);
}

// ── function ───────────────────────────────────────────────────────

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
      const medium = body.medium === "voice" ? "voice" : "chat";
      const row = {
        scenario,
        mode: "code",
        invite_code: mintCode(),
        player_a: uid,
        state: "open",
      };
      // MIGRATION ORDER MUST NOT BREAK MINTING. This function and
      // migration 0016 ship separately, and whichever lands second wins
      // a window where they disagree. The first cut of this insert set
      // `medium` unconditionally, so a redeploy ahead of the migration
      // made EVERY create fail — "couldn't mint a challenge" on a
      // button that worked the day before. Try with the column, and if
      // the schema doesn't know it yet, mint without: a chat-default
      // battle beats no battle every time.
      let { data, error } = await admin.from("battles")
        .insert({ ...row, medium }).select().single();
      if (error) {
        ({ data, error } = await admin.from("battles")
          .insert(row).select().single());
      }
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
      // ── FIRST: AM I ALREADY IN A FIGHT? ─────────────────────────
      //
      // THE BUG THIS FIXES, and it was the worst one in the feature.
      //
      // Pairing is one-sided. The man who arrives SECOND finds the
      // waiting stranger, creates the battle and gets it back in his
      // response — instant. The man who was waiting is simply deleted
      // from the queue and told nothing. His client polls this action
      // again three seconds later, finds nobody waiting, and RE-QUEUES
      // HIM — so he never learned the fight exists, and worse, he was
      // now in line for a second one while already committed to a
      // first. He only discovered it by backing out to the Battles
      // screen and waiting for its slow poll, which is where the
      // "five minutes to see my own match" came from.
      //
      // So the queue action answers the right question first: not
      // "who is waiting" but "do I already have a fight". His very
      // next poll now returns it, which makes the pairing feel
      // simultaneous on both phones.
      const { data: existing } = await admin.from("battles").select()
        .or(`player_a.eq.${uid},player_b.eq.${uid}`)
        .eq("state", "active")
        .order("created_at", { ascending: false })
        .limit(1);
      const live = existing?.[0];
      if (live) {
        // Only surface one he hasn't answered yet — a duel he has
        // already submitted to is waiting on the OTHER man, and
        // handing it back here would drop him into a fight he has
        // finished.
        const mineIsA = live.player_a === uid;
        const myScore = mineIsA ? live.a_score : live.b_score;
        if (myScore === null || myScore === undefined) {
          await admin.from("battle_queue").delete().eq("user_id", uid);
          return Response.json({ battle: live });
        }
      }

      // LIKE FOR LIKE. A voice man and a text man are not opponents —
      // there is no honest way to score a spoken attempt against a
      // typed one. The medium is part of the matchmaking key.
      const wantMedium = body.medium === "voice" ? "voice" : "chat";

      // Oldest waiting stranger, else join the line ourselves.
      //
      // Same migration-order guard as create: before 0016 the medium
      // column doesn't exist, the filtered select errors, and — because
      // the error was never checked — the queue silently no-opped:
      // nobody ever entered the line and nobody was ever paired. If the
      // schema doesn't know the column, fall back to one unfiltered
      // line (everything in it is chat by definition).
      let { data: waiting, error: qerr } = await admin.from("battle_queue")
        .select()
        .neq("user_id", uid).eq("medium", wantMedium)
        .order("enqueued_at", { ascending: true })
        .limit(1);
      if (qerr) {
        ({ data: waiting } = await admin.from("battle_queue").select()
          .neq("user_id", uid)
          .order("enqueued_at", { ascending: true })
          .limit(1));
      }
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
          const paired = {
            scenario,
            mode: "random",
            player_a: opponent.user_id,
            player_b: uid,
            state: "active",
          };
          let { data: battle, error: berr } = await admin.from("battles")
            .insert({ ...paired, medium: wantMedium }).select().single();
          if (berr) {
            ({ data: battle } = await admin.from("battles")
              .insert(paired).select().single());
          }
          return Response.json({ battle });
        }
      }
      const seat = {
        user_id: uid,
        enqueued_at: new Date().toISOString(),
      };
      const { error: uerr } = await admin.from("battle_queue")
        .upsert({ ...seat, medium: wantMedium });
      if (uerr) await admin.from("battle_queue").upsert(seat);
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
        .select("id, player_a, player_b, state, a_score, b_score")
        .eq("id", bid).maybeSingle();
      if (!row) return Response.json({ error: "not found" }, { status: 404 });

      // EITHER player, not just the creator. This used to be
      // creator-only and open-only, which meant a duel someone joined
      // and then abandoned sat on both screens permanently with no way
      // to shift it. Any man in a fight can walk away from it.
      const mineIsA = row.player_a === uid;
      if (!mineIsA && row.player_b !== uid) {
        return Response.json({ error: "not yours" }, { status: 403 });
      }
      if (row.state === "scored") {
        return Response.json({ error: "already settled" }, { status: 409 });
      }

      const myScore = mineIsA ? row.a_score : row.b_score;
      const theirScore = mineIsA ? row.b_score : row.a_score;
      const them = mineIsA ? row.player_b : row.player_a;

      // ── HE ALREADY PLAYED. WALKING AWAY IS A FORFEIT, NOT A DELETE.
      //
      // The obvious implementation — delete whatever you're allowed to
      // touch — quietly destroys the other man's graded attempt, and
      // does it in the exact situation where he is most invested:
      // he has recorded his run and is waiting on you. Deleting there
      // would make quitting the optimal move whenever you think you're
      // losing, which kills the ladder outright.
      //
      // So the row survives and settles against you. He wins, the RR
      // moves, and it lands on his screen as a result rather than as a
      // duel that vanished.
      if (theirScore !== null && theirScore !== undefined && them) {
        await admin.from("battles").update({
          state: "scored",
          winner: them,
          [mineIsA ? "a_score" : "b_score"]: 0,
        }).eq("id", bid);

        const { data: elos } = await admin.from("rizz_elo")
          .select("user_id, battle_rating, battle_peak, battles_won, battles_lost")
          .in("user_id", [uid, them]);
        const mine = elos?.find((e) => e.user_id === uid);
        const theirs = elos?.find((e) => e.user_id === them);
        const { newA, newB } = eloExchange(
          mine?.battle_rating ?? 1000,
          theirs?.battle_rating ?? 1000,
          false, // "A" (the quitter) did not win
        );
        await admin.from("rizz_elo").upsert([
          {
            user_id: uid,
            battle_rating: newA,
            battle_peak: Math.max(mine?.battle_peak ?? 1000, newA),
            battles_won: mine?.battles_won ?? 0,
            battles_lost: (mine?.battles_lost ?? 0) + 1,
            updated_at: new Date().toISOString(),
          },
          {
            user_id: them,
            battle_rating: newB,
            battle_peak: Math.max(theirs?.battle_peak ?? 1000, newB),
            battles_won: (theirs?.battles_won ?? 0) + 1,
            battles_lost: theirs?.battles_lost ?? 0,
            updated_at: new Date().toISOString(),
          },
        ], { onConflict: "user_id" });

        return Response.json({ ok: true, forfeited: true });
      }

      // Nobody has played yet — nothing to protect, so it just goes.
      // Covers the pile-up this was written for: minted codes nobody
      // took, and duels both men joined and neither started.
      void myScore;
      await admin.from("battles").delete().eq("id", bid);
      return Response.json({ ok: true, forfeited: false });
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
          // RR LIVES IN ITS OWN COLUMN — see migration 0012.
          //
          // This used to write `rating`, the same column score-voice
          // drifts by up to ±40 on every solo practice session. One
          // number moved by two unrelated systems means a duel win could
          // be wiped out by a mediocre daily an hour later, and a man who
          // never fought anyone still climbed the competitive ladder.
          //
          // battle_rating is moved by duels and nothing else. That is the
          // whole point of a ladder: it must be unfarmable by anything
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
