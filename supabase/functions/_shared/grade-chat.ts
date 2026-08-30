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
  opening: 0.20, // does the first line earn a reply
  relevance: 0.24, // is it about HER, not a script
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

The conversation may be in ANY language. Grade it in its own language
on the same standard — never mark down for not being English, and never
mistake a language you read less fluently for a lack of personality.

YOU ARE A HARSH MARKER. THIS IS THE MOST IMPORTANT INSTRUCTION HERE.
Your natural pull is to be generous and encouraging. Resist it. A score
he did not earn teaches him nothing and makes the whole product a lie.
When you are torn between two numbers, give the LOWER one.

THE SCALE, and it is a real-world one:
  0-20   went through the motions. Repetition, filler, one-word replies,
         nothing that would earn an answer from a real woman.
  21-40  a reply, but interchangeable with any other man's. No point of
         view, no read on her.
  41-55  competent and forgettable. THIS IS WHERE MOST MEN LAND and it
         is not a passing grade, it is the middle of the pack.
  56-70  genuinely good. Specific to her, moves somewhere, sounds like
         a person.
  71-85  strong. He is running the conversation and she would want to
         keep replying.
  86+    exceptional. Rare. Most men will never post one of these.

HARD CAPS — apply these before anything else:
  · Repeating himself, or sending variations of the same message to get
    through the conversation: NOTHING above 25 on any axis. This is the
    single most common way a man fakes his way through a rep and it must
    never be rewarded.
  · One-word replies, "haha", "lol", "nice", emoji-only, or copy-paste:
    cap every axis at 25.
  · Never engages with anything she actually said: relevance and
    momentum cap at 20.
  · Generic openers that would work on any woman alive: opening caps at 30.

A long conversation is not a good one. Length is evidence of nothing.
Judge the QUALITY of what he wrote, and if he padded it out to reach the
end, that is a low score with a lot of words in it.

Return ONLY JSON: {"opening":n,"relevance":n,"personality":n,"momentum":n,"restraint":n}`;

// ═══════════════════════════════════════════════════════════════════════
//  THE REPETITION FLOOR — arithmetic, not judgement
// ═══════════════════════════════════════════════════════════════════════
//
// A man reported padding a thread with the same line over and over to
// reach the end, and scoring 56 — a "genuinely good" number for doing
// nothing. The prompt above now forbids it, but a language model told to
// be harsh is still a language model: it drifts generous, and it drifts
// most on exactly the low-effort input we most need it to punish.
//
// So repetition is measured in code, where it cannot be talked out of.
// His own lines are normalised and compared; near-duplicates count. The
// resulting cap is applied AFTER the model has spoken, so the model
// cannot lift him back over it.
//
// This is deliberately blunt. A man who repeats himself half the time
// has not had a conversation, whatever a grader thinks of the prose.
function normalise(line: string): string {
  return line
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}

function similar(a: string, b: string): boolean {
  if (a === b) return true;
  const A = new Set(a.split(" ").filter(Boolean));
  const B = new Set(b.split(" ").filter(Boolean));
  if (A.size === 0 || B.size === 0) return false;
  let shared = 0;
  for (const w of A) if (B.has(w)) shared++;
  // Jaccard: shared words over the union. 0.8 catches "hey what you up
  // to" against "hey what are you up to" without catching two different
  // sentences that happen to share a few common words.
  const union = new Set([...A, ...B]).size;
  return shared / union >= 0.8;
}

/// The highest total this transcript may score, given how much of it is
/// the same thing said again. 100 = no cap.
export function repetitionCap(transcript: string): number {
  const mine = transcript
    .split("\n")
    .filter((l) => l.startsWith("YOU:"))
    .map((l) => normalise(l.slice(4)))
    .filter((l) => l.length > 0);

  if (mine.length < 3) return 100;

  // How many of his lines repeat something he already said?
  let repeats = 0;
  for (let i = 1; i < mine.length; i++) {
    for (let j = 0; j < i; j++) {
      if (similar(mine[i], mine[j])) {
        repeats++;
        break;
      }
    }
  }
  const ratio = repeats / mine.length;

  // Effort floor: a thread of three-word replies is not a conversation
  // either, however varied those three words are.
  const avgWords =
    mine.reduce((n, l) => n + l.split(" ").length, 0) / mine.length;

  let cap = 100;
  if (ratio >= 0.5) cap = Math.min(cap, 20);
  else if (ratio >= 0.3) cap = Math.min(cap, 35);
  else if (ratio >= 0.15) cap = Math.min(cap, 55);
  if (avgWords < 3) cap = Math.min(cap, 30);
  else if (avgWords < 5) cap = Math.min(cap, 50);
  return cap;
}

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

  // The floor is applied LAST, so a generous grader cannot lift him back
  // over it. The axes are pulled down with the total — a scorecard that
  // showed five healthy bars above a capped number would just look
  // broken.
  const cap = repetitionCap(transcript);
  let score = Math.round(weighted);
  if (score > cap) {
    const factor = cap / score;
    for (const axis of CHAT_AXES) {
      rubric[axis] = Math.round(rubric[axis] * factor);
    }
    score = cap;
  }
  return { rubric, score };
}
