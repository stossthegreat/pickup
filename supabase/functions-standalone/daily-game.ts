// ═══════════════════════════════════════════════════════════════════
//  daily-game — SELF-CONTAINED copy-paste version.
//
//  Paste this ENTIRE file into:
//    Supabase -> Edge Functions -> Deploy a new function -> via Editor
//    The function name MUST be exactly:  daily-game
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

// Shared fixtures core — weekly head-to-head between squadmates.
// The score IS the weekly league points, so every rep in the app moves
// the fixture without any extra tracking.

// deno-lint-ignore-file no-explicit-any

/// This week's league points for a user (0 when not enrolled yet).
async function weekPoints(
  admin: any,
  uid: string,
  week: string,
): Promise<number> {
  const { data } = await admin
    .from("league_members")
    .select("points, leagues!inner(week_start)")
    .eq("user_id", uid)
    .eq("leagues.week_start", week);
  return data?.[0]?.points ?? 0;
}

/// Settle LAST week's fixture for this user if it's unsettled: compare
/// final points, stamp the winner, bump career records. Returns
/// 'won' | 'lost' | 'draw' | null.
async function settleLastFixture(
  admin: any,
  uid: string,
): Promise<string | null> {
  const lastWeek = weekStart(new Date(Date.now() - 7 * 24 * 3600_000));
  const { data: rows } = await admin
    .from("fixtures")
    .select()
    .eq("week_start", lastWeek)
    .eq("settled", false)
    .or(`player_a.eq.${uid},player_b.eq.${uid}`);
  const f = rows?.[0];
  if (!f) return null;

  const [pa, pb] = await Promise.all([
    weekPoints(admin, f.player_a, lastWeek),
    weekPoints(admin, f.player_b, lastWeek),
  ]);
  const winner = pa === pb ? null : pa > pb ? f.player_a : f.player_b;

  await admin.from("fixtures")
    .update({ winner, settled: true }).eq("id", f.id);

  if (winner) {
    const loser = winner === f.player_a ? f.player_b : f.player_a;
    const [{ data: w }, { data: l }] = await Promise.all([
      admin.from("profiles").select("fixture_wins").eq("id", winner).single(),
      admin.from("profiles").select("fixture_losses").eq("id", loser).single(),
    ]);
    await Promise.all([
      admin.from("profiles")
        .update({ fixture_wins: (w?.fixture_wins ?? 0) + 1 }).eq("id", winner),
      admin.from("profiles")
        .update({ fixture_losses: (l?.fixture_losses ?? 0) + 1 }).eq("id", loser),
    ]);
  }
  return winner == null ? "draw" : winner === uid ? "won" : "lost";
}

/// Ensure this user has a fixture THIS week: find it, or pair the
/// squad's unpaired members deterministically (sorted ids, adjacent
/// pairs). The odd man out gets a bye (no fixture). Returns the
/// fixture row or null (no squad / bye week).
async function ensureFixture(
  admin: any,
  uid: string,
): Promise<any | null> {
  const week = weekStart();

  // Squad?
  const { data: membership } = await admin
    .from("squad_members")
    .select("squad_id")
    .eq("user_id", uid)
    .eq("status", "active")
    .limit(1);
  const squadId = membership?.[0]?.squad_id;
  if (!squadId) return null;

  // Existing fixture this week?
  const { data: existing } = await admin
    .from("fixtures")
    .select()
    .eq("week_start", week)
    .eq("squad_id", squadId)
    .or(`player_a.eq.${uid},player_b.eq.${uid}`);
  if (existing && existing.length > 0) return existing[0];

  // Pair the unpaired.
  const [{ data: roster }, { data: paired }] = await Promise.all([
    admin.from("squad_members").select("user_id")
      .eq("squad_id", squadId).eq("status", "active"),
    admin.from("fixtures").select("player_a, player_b")
      .eq("week_start", week).eq("squad_id", squadId),
  ]);
  const taken = new Set<string>();
  for (const f of paired ?? []) {
    taken.add(f.player_a);
    taken.add(f.player_b);
  }
  const free = (roster ?? [])
    .map((r: any) => r.user_id as string)
    .filter((id: string) => !taken.has(id))
    .sort(); // deterministic
  const myIdx = free.indexOf(uid);
  if (myIdx < 0) return null;
  // Partner: the neighbour in the sorted free list.
  const partner = free[myIdx % 2 === 0 ? myIdx + 1 : myIdx - 1];
  if (!partner) return null; // odd man out — bye week

  const { data: fixture } = await admin.from("fixtures").insert({
    week_start: week,
    squad_id: squadId,
    player_a: uid < partner ? uid : partner,
    player_b: uid < partner ? partner : uid,
  }).select().single();
  return fixture;
}

// ── function ───────────────────────────────────────────────────────

// Rotation matches the app's vibe keys — the client renders the full
// persona (portrait, setting, voice) from the key.
const SCENARIOS = [
  "cold",
  "into_you",
  "chaos",
  "testing",
  "ice_then_fire",
  "sweet",
];

const utcYmd = (d = new Date()) =>
  d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();

// Deterministic scenario of the day — same for every user on earth.
function scenarioOfDay(d = new Date()): string {
  const epochDay = Math.floor(d.getTime() / 86_400_000);
  return SCENARIOS[epochDay % SCENARIOS.length];
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
  const ymd = utcYmd();
  const scenarioKey = scenarioOfDay();

  // Lazy week-end verdicts — each fires once; the client shows the
  // ceremonies (league promotion/relegation + fixture result).
  const ceremony = await settleLastWeek(admin, uid);
  const fixtureCeremony = await settleLastFixture(admin, uid);

  switch (body.action) {
    case "status": {
      const [{ data: mine }, { data: top }] = await Promise.all([
        admin.from("daily_attempts").select("score")
          .eq("user_id", uid).eq("ymd", ymd).maybeSingle(),
        admin.from("daily_attempts")
          .select("user_id, score, profiles(handle, avatar_url)")
          .eq("ymd", ymd).order("score", { ascending: false }).limit(10),
      ]);
      const { data: all } = await admin.from("daily_attempts")
        .select("score").eq("ymd", ymd);
      const scores = (all ?? []).map((r) => r.score as number);
      const worldAvg = scores.length === 0
        ? null
        : Math.round(scores.reduce((a, b) => a + b, 0) / scores.length);

      // League snapshot (auto-enrol so the game is never invisible).
      const leagueId = await ensureLeague(admin, uid);
      const { data: league } = await admin.from("leagues")
        .select("division, week_start").eq("id", leagueId).single();
      const { data: standings } = await admin.from("league_members")
        .select("user_id, points, profiles(handle, avatar_url)")
        .eq("league_id", leagueId)
        .order("points", { ascending: false });
      const rank =
        (standings ?? []).findIndex((r) => r.user_id === uid) + 1;
      const size = standings?.length ?? 1;
      const zone = rank <= PROMOTE_TOP
        ? "promotion"
        : rank > size - RELEGATE_BOTTOM
        ? "drop"
        : "safe";

      // ── FIXTURE — this week's head-to-head vs one squadmate ──────
      const fixture = await ensureFixture(admin, uid);
      let fixtureOut = null;
      if (fixture) {
        const oppId =
          fixture.player_a === uid ? fixture.player_b : fixture.player_a;
        const week = weekStart();
        const [myPts, theirPts, { data: opp }] = await Promise.all([
          weekPoints(admin, uid, week),
          weekPoints(admin, oppId, week),
          admin.from("profiles")
            .select("handle, fixture_wins, fixture_losses")
            .eq("id", oppId).single(),
        ]);
        fixtureOut = {
          opponentId: oppId,
          opponentHandle: opp?.handle ?? null,
          opponentRecord:
            `${opp?.fixture_wins ?? 0}W-${opp?.fixture_losses ?? 0}L`,
          myPoints: myPts,
          theirPoints: theirPts,
          locksAt: lockTime(week),
        };
      }

      return Response.json({
        scenarioKey,
        ymd,
        attempted: !!mine,
        myScore: mine?.score ?? null,
        board: (top ?? []).map((r) => ({
          userId: r.user_id,
          score: r.score,
          handle: (r.profiles as { handle?: string } | null)?.handle ?? null,
        })),
        worldAvg,
        league: {
          division: league!.division,
          divisionName: DIVISIONS[(league!.division as number) - 1],
          rank,
          points: standings?.find((r) => r.user_id === uid)?.points ?? 0,
          size,
          locksAt: lockTime(league!.week_start as string),
          zone,
          promoteTop: PROMOTE_TOP,
          relegateBottom: RELEGATE_BOTTOM,
          // The full table — the client renders the zone bands.
          standings: (standings ?? []).map((r) => ({
            userId: r.user_id,
            points: r.points,
            handle:
              (r.profiles as { handle?: string } | null)?.handle ?? null,
            avatarUrl:
              (r.profiles as { avatar_url?: string } | null)?.avatar_url ??
                null,
          })),
        },
        fixture: fixtureOut,
        ceremony,
        fixtureCeremony,
      });
    }

    case "submit": {
      const transcript = String(body.transcript ?? "");
      if (transcript.trim().length < 20) {
        return Response.json({ error: "transcript too short" }, { status: 400 });
      }
      const { data: existing } = await admin.from("daily_attempts")
        .select("id").eq("user_id", uid).eq("ymd", ymd).maybeSingle();
      if (existing) {
        return Response.json({ error: "one attempt per day" }, { status: 409 });
      }
      const graded = await gradeTranscript(transcript);
      if (!graded) {
        return Response.json({ error: "grader unavailable" }, { status: 502 });
      }
      const { error: insErr } = await admin.from("daily_attempts").insert({
        user_id: uid,
        ymd,
        scenario: scenarioKey,
        score: graded.score,
        rubric: graded.rubric,
      });
      if (insErr) {
        // unique-violation race → someone double-fired the submit
        return Response.json({ error: "one attempt per day" }, { status: 409 });
      }

      // League fuel: 1 point per 100 score for the daily.
      await addLeaguePoints(admin, uid, Math.round(graded.score / 100));

      const { data: better } = await admin.from("daily_attempts")
        .select("id").eq("ymd", ymd).gt("score", graded.score);
      const { data: all } = await admin.from("daily_attempts")
        .select("score").eq("ymd", ymd);
      const scores = (all ?? []).map((r) => r.score as number);
      const worldAvg =
        Math.round(scores.reduce((a, b) => a + b, 0) / scores.length);

      return Response.json({
        score: graded.score,
        rubric: graded.rubric,
        rankToday: (better?.length ?? 0) + 1,
        worldAvg,
      });
    }

    default:
      return Response.json({ error: "unknown action" }, { status: 400 });
  }
});
