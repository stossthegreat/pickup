// ═══════════════════════════════════════════════════════════════════
//  score-voice — SELF-CONTAINED copy-paste version.
//
//  Paste this ENTIRE file into:
//    Supabase -> Edge Functions -> Deploy a new function -> via Editor
//    The function name MUST be exactly:  score-voice
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

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  // ── 1 · Identify the caller from their JWT ─────────────────────────
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

  const { scenario = "Practice", transcript = "" } = await req.json()
    .catch(() => ({}));
  if (typeof transcript !== "string" || transcript.trim().length < 20) {
    return Response.json({ error: "transcript too short" }, { status: 400 });
  }

  // ── 2 · Grade with the shared rubric ───────────────────────────────
  const graded = await gradeTranscript(transcript);
  if (!graded) {
    return Response.json({ error: "grader unavailable" }, { status: 502 });
  }
  const { rubric, weighted, score } = graded;

  // ── 3 · ELO drift toward the rating this performance implies ───────
  //  implied = 800 (all-zeros) .. ~2200 (perfect). Rating moves 1/8 of
  //  the gap per session, capped ±40 — converges in ~10 sessions, can't
  //  be farmed with volume once you're rated correctly.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: eloRow } = await admin
    .from("rizz_elo").select("rating, peak").eq("user_id", uid).single();
  const rating = eloRow?.rating ?? 1000;
  const implied = 800 + weighted * 14;
  const eloDelta = Math.max(-40, Math.min(40, Math.round((implied - rating) / 8)));
  const newRating = Math.max(0, rating + eloDelta);
  const tier = tierFor(newRating);

  // ── 4 · Persist (service role — the only writer) ───────────────────
  await admin.from("voice_sessions").insert({
    user_id: uid,
    scenario,
    score,
    rubric,
  });
  await admin.from("rizz_elo").upsert({
    user_id: uid,
    rating: newRating,
    tier,
    peak: Math.max(eloRow?.peak ?? 1000, newRating),
    updated_at: new Date().toISOString(),
  });

  // Every session quietly fuels the weekly league (auto-enrol) — the
  // casual roleplayer IS in the game without ever opting in. Half the
  // daily's rate so THE DAILY stays the big score of the day.
  await addLeaguePoints(admin, uid, Math.round(score / 200));

  return Response.json({ score, rubric, eloDelta, newRating, tier });
});
