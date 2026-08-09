// ═════════════════════════════════════════════════════════════════════
//  score-voice — THE KEYSTONE.
//
//  Every competition surface (board, tiers, battles, cups) stands on one
//  thing: a fair, consistent score for a roleplay session. This function
//  is the only writer of scores and ELO in the entire system — clients
//  can read the board but can never touch a number.
//
//  POST (authenticated user JWT) {
//    scenario:   string   — scenario title shown on the reveal
//    transcript: string   — the session transcript to grade
//  }
//  → { score, rubric{confidence,flow,wit,recovery,close}, eloDelta,
//      newRating, tier }
//
//  Deploy:  supabase functions deploy score-voice
//  Secrets: supabase secrets set OPENAI_API_KEY=sk-...
//  (SUPABASE_URL / SERVICE_ROLE / ANON keys are injected automatically.)
// ═════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";

const RUBRIC_AXES = ["confidence", "flow", "wit", "recovery", "close"] as const;

// Axis weights → headline score on a 0–9999 scale. Confidence and flow
// carry the most because they're what the programme actually trains.
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

  // ── 2 · Grade with the rubric (temperature 0 → consistency) ────────
  const oaRes = await fetch("https://api.openai.com/v1/chat/completions", {
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
  if (!oaRes.ok) {
    return Response.json({ error: "grader unavailable" }, { status: 502 });
  }
  const oa = await oaRes.json();
  let rubric: Record<string, number>;
  try {
    rubric = JSON.parse(oa.choices[0].message.content);
  } catch {
    return Response.json({ error: "grader returned junk" }, { status: 502 });
  }
  for (const axis of RUBRIC_AXES) {
    const v = Number(rubric[axis]);
    rubric[axis] = Number.isFinite(v) ? Math.max(0, Math.min(100, Math.round(v))) : 0;
  }

  // ── 3 · Headline score (0–9999) ────────────────────────────────────
  const weighted = RUBRIC_AXES.reduce(
    (sum, axis) => sum + rubric[axis] * WEIGHTS[axis],
    0,
  ); // 0..100
  const score = Math.round(weighted * 99.99);

  // ── 4 · ELO drift toward the rating this performance implies ───────
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

  // ── 5 · Persist (service role — the only writer) ───────────────────
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

  return Response.json({ score, rubric, eloDelta, newRating, tier });
});
