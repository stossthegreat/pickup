// ═════════════════════════════════════════════════════════════════════
//  daily-game — THE DAILY + LEAGUE state. The Duolingo engine.
//
//  THE DAILY: one scenario per UTC day, deterministic and identical for
//  the whole world. ONE attempt each (DB-enforced). Scores feed the
//  weekly league; the league promotes 10 / relegates 5 every Sunday
//  21:00 UTC, settled lazily on next contact — no cron required.
//
//  POST (user JWT) { action: 'status' }
//    → { scenarioKey, ymd, attempted, myScore, board[], worldAvg,
//        league: { division, divisionName, rank, points, size,
//                  locksAt, zone }, ceremony? }
//  POST { action: 'submit', transcript }
//    → { score, rubric, rankToday, worldAvg }
//
//  Deploy: supabase functions deploy daily-game
// ═════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { gradeTranscript } from "../_shared/grade.ts";
import {
  addLeaguePoints,
  DIVISIONS,
  ensureLeague,
  lockTime,
  PROMOTE_TOP,
  RELEGATE_BOTTOM,
  settleLastWeek,
  weekStart,
} from "../_shared/league.ts";

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

  // Lazy week-end verdict — fires once, the client shows the ceremony.
  const ceremony = await settleLastWeek(admin, uid);

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
        .select("user_id, points").eq("league_id", leagueId)
        .order("points", { ascending: false });
      const rank =
        (standings ?? []).findIndex((r) => r.user_id === uid) + 1;
      const size = standings?.length ?? 1;
      const zone = rank <= PROMOTE_TOP
        ? "promotion"
        : rank > size - RELEGATE_BOTTOM
        ? "drop"
        : "safe";

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
        },
        ceremony,
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
