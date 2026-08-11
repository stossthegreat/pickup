// ═════════════════════════════════════════════════════════════════════
//  score-chat — the TEXT ladder's only writer.
//
//  Grades a text transcript on the chat rubric (_shared/grade-chat.ts —
//  its own axes, because voice's confidence/flow/recovery aren't visible
//  in writing), records the attempt, and rolls the user's standing.
//
//  It deliberately does NOT touch rizz_elo. Voice ELO moves on voice
//  only; grinding text to a voice rank you never earned would make the
//  competitive board a lie.
//
//  POST (user JWT) { surface?, scenario?, transcript }
//  → { score, rubric, best, attempts, average, isBest }
//
//  Deploy:  supabase functions deploy score-chat
//  Secrets: supabase secrets set OPENAI_API_KEY=sk-...
// ═════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { gradeChat } from "../_shared/grade-chat.ts";

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

  // ── 2 · Read the request ───────────────────────────────────────────
  let body: { surface?: string; scenario?: string; transcript?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "bad json" }, { status: 400 });
  }
  const transcript = (body.transcript ?? "").trim();
  // Too short to grade honestly — refuse rather than hand out a number
  // that would sit on a public board.
  if (transcript.length < 20) {
    return Response.json({ error: "transcript too short" }, { status: 400 });
  }
  const surface = body.surface ?? "roleplay";
  const scenario = body.scenario ?? null;

  // ── 3 · Grade ──────────────────────────────────────────────────────
  const graded = await gradeChat(transcript);
  if (!graded) {
    // A grader outage must never be recorded as a zero — that would
    // permanently dent an average the user can't recover.
    return Response.json({ error: "grader unavailable" }, { status: 503 });
  }

  // ── 4 · Persist under the service role ─────────────────────────────
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  await admin.from("chat_attempts").insert({
    user_id: uid,
    surface,
    scenario,
    score: graded.score,
    rubric: graded.rubric,
  });

  // Roll the standing from the attempts themselves rather than
  // incrementing a counter — idempotent, and self-heals if a write was
  // ever lost.
  const { data: rows } = await admin
    .from("chat_attempts")
    .select("score")
    .eq("user_id", uid);

  const scores: number[] = (rows ?? []).map((r) => r.score as number);
  const attempts = scores.length;
  const best = attempts ? Math.max(...scores) : graded.score;
  const average = attempts
    ? Math.round(scores.reduce((a, b) => a + b, 0) / attempts)
    : graded.score;

  await admin.from("chat_score").upsert({
    user_id: uid,
    best,
    attempts,
    average,
    updated_at: new Date().toISOString(),
  });

  return Response.json({
    score: graded.score,
    rubric: graded.rubric,
    best,
    attempts,
    average,
    isBest: graded.score >= best,
  });
});
