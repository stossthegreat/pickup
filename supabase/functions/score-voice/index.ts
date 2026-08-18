// ═════════════════════════════════════════════════════════════════════
//  score-voice — solo-session scoring. THE KEYSTONE.
//
//  Grades a roleplay transcript with the shared rubric (_shared/grade.ts
//  — identical to battles, so every number in the system is comparable),
//  drifts the user's ELO toward the rating the performance implies, and
//  persists via the service role. The only solo-score writer.
//
//  POST (user JWT) { scenario, transcript }
//  → { score, rubric, eloDelta, newRating, tier }
//
//  Deploy:  supabase functions deploy score-voice
//  Secrets: supabase secrets set OPENAI_API_KEY=sk-...
// ═════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { gradeTranscript, tierFor } from "../_shared/grade.ts";
import { addLeaguePoints } from "../_shared/league.ts";

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
    .from("rizz_elo").select("rating, peak, voice_points")
    .eq("user_id", uid).maybeSingle();
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
  // VOICE POINTS — the board's sort key since 0017. Cumulative 0-100
  // session scores: the higher you score the higher you climb, and
  // volume catches up — the one property an ELO can never give a
  // leaderboard. `rating` continues below, for divisions and stakes.
  const aiScore = Math.round(score / 99.99);
  const eloPatch = {
    user_id: uid,
    rating: newRating,
    tier,
    peak: Math.max(eloRow?.peak ?? 1000, newRating),
    updated_at: new Date().toISOString(),
  };
  // Same migration-order guard as battle-action: if 0017 hasn't run
  // yet the column doesn't exist, and scoring must not start failing
  // because a deploy landed first.
  const { error: eloErr } = await admin.from("rizz_elo").upsert({
    ...eloPatch,
    voice_points: (eloRow?.voice_points ?? 0) + aiScore,
  });
  if (eloErr) await admin.from("rizz_elo").upsert(eloPatch);

  // Every session quietly fuels the weekly league (auto-enrol) — the
  // casual roleplayer IS in the game without ever opting in. Half the
  // daily's rate so THE DAILY stays the big score of the day.
  await addLeaguePoints(admin, uid, Math.round(score / 200));

  return Response.json({ score, rubric, eloDelta, newRating, tier });
});

// Deploy trigger: 2026-08-10T21:32Z
