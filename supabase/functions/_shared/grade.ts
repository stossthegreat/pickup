// Shared grading core — the ONE rubric every score in the system comes
// from. score-voice (solo sessions) and battle-action (duels) both
// import this, so a solo 8,200 and a battle 8,200 mean the same thing.
// Folders starting with _ are not deployed as functions.

export const RUBRIC_AXES = [
  "confidence",
  "flow",
  "wit",
  "recovery",
  "close",
] as const;

export const WEIGHTS: Record<(typeof RUBRIC_AXES)[number], number> = {
  confidence: 0.26,
  flow: 0.24,
  wit: 0.18,
  recovery: 0.18,
  close: 0.14,
};

export const TIERS: Array<[string, number]> = [
  ["HIM", 1900],
  ["DANGEROUS", 1600],
  ["CONTENDER", 1300],
  ["INITIATE", 1100],
  ["OBSERVER", 0],
];

export const tierFor = (r: number) => TIERS.find(([, min]) => r >= min)![0];

const GRADER_PROMPT = `You are the scoring engine for a social-confidence
training app. Grade the user's half of this practice roleplay transcript
on five axes, each 0-100:

confidence — certainty, directness, owning statements, no approval-seeking
flow       — natural rhythm, listening, building on what she says
wit        — humour, playfulness, spark (calibrated, never mean)
recovery   — how they handle pushback, rejection, curveballs, silence
close      — momentum toward a respectful, concrete next step

The conversation may be in ANY language. Grade it in its own language
on the same standard — never mark down for not being English, and never
mistake a language you read less fluently for a lack of personality.

Grade HONESTLY on a real-world standard. 50 = average nervous attempt,
70 = genuinely good, 85+ = exceptional and rare, 95+ = almost never.
A short or low-effort transcript caps every axis at 40.

Return ONLY JSON: {"confidence":n,"flow":n,"wit":n,"recovery":n,"close":n}`;

export interface GradeResult {
  rubric: Record<string, number>;
  weighted: number; // 0..100
  score: number; // 0..9999
}

/// Grade a transcript with the fixed rubric at temperature 0.
/// Returns null when the grader is unreachable or returns junk.
export async function gradeTranscript(
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
