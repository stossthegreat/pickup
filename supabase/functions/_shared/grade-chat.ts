// ═════════════════════════════════════════════════════════════════════
//  The TEXT rubric. Deliberately NOT the voice one.
//
//  Voice is graded on confidence, flow, wit, recovery and close — half
//  of which are about delivery, timing and holding your nerve out loud.
//  None of that exists in a text thread. Reusing the voice rubric would
//  have scored people on qualities the medium can't express, so text
//  gets axes that are actually visible in writing.
//
//  Same shape as _shared/grade.ts so every number in the system is
//  built the same way: five axes 0..100, weighted, one honest total.
// ═════════════════════════════════════════════════════════════════════

export const CHAT_AXES = [
  "opening",
  "relevance",
  "personality",
  "momentum",
  "restraint",
] as const;

const WEIGHTS: Record<string, number> = {
  opening: 0.22, // does the first line earn a reply
  relevance: 0.22, // is it about HER, not a script
  personality: 0.24, // is there a person behind it
  momentum: 0.20, // does the thread move forward
  restraint: 0.12, // length, neediness, double-texting
};

const GRADER_PROMPT =
  `You are the scoring engine for a social-confidence trainer. You grade
TEXT conversations — dating-app threads and DMs. Grade only what writing
can show; never guess at tone of voice.

opening     — does the first message earn a reply on its own merit
relevance   — engages with what SHE actually said or posted, not a script
personality — a specific human is visible; opinions, humour, a point of view
momentum    — the thread moves somewhere; questions land, hooks are picked up
restraint   — calibrated length, no neediness, no double-texting, no pleading

Grade HONESTLY on a real-world standard. 50 = average forgettable
message, 70 = genuinely good, 85+ = exceptional and rare, 95+ = almost
never. A one-word or copy-paste message caps every axis at 30.

Return ONLY JSON: {"opening":n,"relevance":n,"personality":n,"momentum":n,"restraint":n}`;

export interface ChatGrade {
  rubric: Record<string, number>;
  score: number; // 0..100 — the number a human reads
}

/// Grade a text transcript at temperature 0. Null when the grader is
/// unreachable or returns junk — callers must treat that as "no score
/// recorded", never as a zero, or a network blip would tank a ladder.
export async function gradeChat(transcript: string): Promise<ChatGrade | null> {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) return null;

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${key}`,
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

  for (const axis of CHAT_AXES) {
    const v = Number(rubric[axis]);
    rubric[axis] = Number.isFinite(v)
      ? Math.max(0, Math.min(100, Math.round(v)))
      : 0;
  }
  const weighted = CHAT_AXES.reduce(
    (sum, axis) => sum + rubric[axis] * WEIGHTS[axis],
    0,
  );
  return { rubric, score: Math.round(weighted) };
}
