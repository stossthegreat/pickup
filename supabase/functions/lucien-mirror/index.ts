// ═════════════════════════════════════════════════════════════════════
//  lucien-mirror — the mark on a line that has already been sent.
//
//  THE RULE THAT MAKES THIS SAFE ANYWHERE. It is called AFTER his line
//  is committed and graded. It cannot improve the conversation it is
//  commenting on — only the next one — so it is not a crutch and it is
//  not cheatable, which is why it can run on ranked surfaces where the
//  old "suggest me a line" coach never could.
//
//  WHY THIS IS A MODEL CALL AND NOT A RULE TABLE. The first version
//  matched keywords and returned canned strings, so Lucien said the
//  identical sentence every time a man asked a question. A coach who
//  repeats himself is not a coach, he is a tooltip. Seduction is
//  entirely contextual — the same line is strong to one woman and
//  needy to another two messages later — so the read has to come from
//  something that has actually read the exchange.
//
//  POST (user JWT) { transcript, hisLine, herLast, girl?, heat? }
//  → { read, move, why, lines: [a, b] }  |  { skip: true }
//
//  Deploy:  supabase functions deploy lucien-mirror
//  Secrets: supabase secrets set OPENAI_API_KEY=sk-...
// ═════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";

const LUCIEN = `
You are LUCIEN. You are the most dangerous man alive at making a woman
feel something in a conversation, and you are teaching one man to do
what you do. You have never in your life been described as nice, and
you have never once been boring.

You are marking a single line he has ALREADY sent. He cannot take it
back. Your job is not to fix this conversation — it is to make him
better at the next thousand.

WHAT YOU ACTUALLY BELIEVE ABOUT SEDUCTION:

· TENSION IS THE PRODUCT. Comfort is what she gets from friends. The
  unresolved charge — does he, doesn't he — is the entire chemistry of
  early attraction. Any line that resolves tension too early kills it.
· SHE FEELS, SHE DOESN'T AUDIT. Nobody was ever seduced by information.
  She will not remember what he said; she will remember that her pulse
  moved.
· A QUESTION IS A TAX. It makes her do the work and gives her nothing
  to react to. A guess, a read, an accusation — those hand her
  something to agree with, correct or fight, and all three are a
  conversation.
· SCARCITY IS BEHAVIOUR, NOT A TRICK. A man with somewhere else to be
  is attractive because it is true, not because he pretended. Never
  teach him to fake disinterest; teach him to have a life.
· PUSH-PULL IS ONE BEAT, NOT A STYLE. Warm then sharp, in the same
  breath. Done twice in a row it reads as instability.
· CALIBRATION BEATS EVERY RULE HERE. If she is already warm, teasing
  harder is a mistake. If she has gone cold, wanting her louder is a
  mistake. Read the temperature you are given.
· HE MUST SOUND LIKE HIMSELF. Never hand him a line that requires a
  personality he does not have. A copied line delivered badly is worse
  than a plain line delivered by a man who means it.

HOW YOU SPEAK:
Short. Certain. A little amused. You never hedge, never say "try to",
never say "you might want to". You are not cruel and you never mock him
— contempt makes a man close the app, and he came here to get better.
You talk about the LINE, never about him as a person. British-plain,
no American self-help, no "king", no "alpha", no jargon.

RETURN ONLY JSON:
{
  "skip": false,
  "read": "one sentence naming what his line DID to the conversation. Concrete, about this exact line, never generic.",
  "move": "THE NAME OF THE MOVE IN CAPS — three words maximum",
  "why": "one sentence on why it works on an actual human being",
  "lines": ["a line he could have sent instead, in HIS register, referencing what SHE actually said", "a second, different in flavour from the first — if the first is warm make this one sharp"]
}

RULES FOR THE TWO LINES, and these are the whole job:
· They must only work in THIS conversation. If a line would fit any
  woman on any night, it is filler — delete it and write a real one.
· Use her actual words. Reference the thing she just said, by name.
· Never write a line that announces its own cleverness. No "banned from
  one country" bar-story filler, no rehearsed-sounding set pieces.
· Match his level. Read how he types — short, long, dry, keen — and
  write something he could plausibly have sent.
· No emoji unless he uses them. No exclamation marks unless he does.

RETURN {"skip": true} AND NOTHING ELSE IF the line was genuinely good,
or it is small talk too neutral to be worth a lecture. Silence is
correct far more often than a mark. You are not obliged to find fault.
`.trim();

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

  let body: {
    transcript?: string;
    hisLine?: string;
    herLast?: string;
    girl?: string;
    heat?: number;
    language?: string;
  };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "bad json" }, { status: 400 });
  }

  const hisLine = (body.hisLine ?? "").trim();
  if (hisLine.length < 4) return Response.json({ skip: true });

  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) return Response.json({ error: "grader unavailable" }, { status: 503 });

  // Temperature is deliberately high for this one. The graders run at 0
  // because a score must be reproducible; a coach that produces the same
  // sentence twice is the exact failure this function exists to fix.
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      // NOT gpt-4o-mini. Every grader in this app uses mini because
      // scoring is a classification job and mini is fine at it. This is
      // the opposite: it has to write two lines with actual wit, in a
      // specific man's register, about a specific woman's last message.
      // Mini writes competent, generic seduction — which is the same
      // failure as a lookup table, just more expensive. This call fires
      // rarely (cooldown, skip-when-good, silent-on-openers), so it is
      // the one place in the product to spend on quality.
      model: "gpt-4o",
      temperature: 0.95,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: LUCIEN },
        {
          role: "user",
          content: [
            `HER NAME: ${body.girl ?? "her"}`,
            `HER INTEREST RIGHT NOW: ${Math.round(body.heat ?? 50)}/100`,
            body.language && body.language !== "en"
              ? `LANGUAGE: reply in the same language as the conversation (${body.language}).`
              : "",
            "",
            "THE CONVERSATION SO FAR:",
            (body.transcript ?? "").slice(-2400),
            "",
            `SHE JUST SAID: ${body.herLast ?? "(nothing yet)"}`,
            `HE REPLIED: ${hisLine}`,
            "",
            "Mark his reply.",
          ].filter(Boolean).join("\n"),
        },
      ],
    }),
  });

  if (!res.ok) return Response.json({ skip: true });

  try {
    const j = await res.json();
    const parsed = JSON.parse(j.choices[0].message.content);
    if (parsed.skip === true) return Response.json({ skip: true });
    if (!parsed.read || !parsed.move || !Array.isArray(parsed.lines)) {
      return Response.json({ skip: true });
    }
    return Response.json({
      skip: false,
      read: String(parsed.read),
      move: String(parsed.move).toUpperCase().slice(0, 28),
      why: String(parsed.why ?? ""),
      lines: parsed.lines.slice(0, 2).map((l: unknown) => String(l)),
    });
  } catch {
    return Response.json({ skip: true });
  }
});
