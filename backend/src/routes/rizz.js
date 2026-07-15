// /v1/rizz — two endpoints, one route file. Both run Lucien on
// OpenAI: vision for screenshots, chat for text Q&A.
//
//   POST /v1/rizz/analyze  — image in, analysis + 3 lines out
//   POST /v1/rizz/chat     — message history in, Lucien reply out
//   GET  /v1/rizz/health   — liveness
//
// Both use gpt-4o-mini for cost. Lucien's character comes from the
// system prompts below — same arsenal across both surfaces so the
// in-pocket coach speaks the same language as the live voice one.

import OpenAI from 'openai';

const MODEL = 'gpt-4o-mini';

const SYSTEM_PROMPT = `
You write the smoothest, funniest, most-likely-to-actually-work
replies a 23-year-old guy could send a girl in 2026. You write the
way the GUY who pulls writes — Hinge, IG DMs, post-club texts. NOT
how a 2014 PUA blog writes.

TASK:
You'll see a screenshot of a dating-app conversation between him
(the apprentice) and her. Read the LAST few messages. Hand him 3
reply options ranked SAFEST → BOLDEST.

═══ THE REGISTER — non-negotiable ═══
- lowercase mostly. Capitals only for emphasis ("DOWN bad", "WHAT").
- short. most under 12 words.
- modern slang where it lands (ngl, lowkey, fr, sus, brat, aura,
  down bad, villain era, catching feelings, delusional, "we'd be a
  disaster"). don't stack five at once — sprinkle.
- self-aware: acknowledging that you're rizzing her IS the rizz.
   "ngl i was gonna play it cool, that lasted 4 seconds"
   "down bad behavior on my part btw"
- ironic confidence. statement, not permission.
- curse when it lands (sparingly).
- one emoji MAX per reply, usually none.

═══ BANNED ═══
- corny / 2014 PUA energy: "hey beautiful", "did it hurt when you
  fell from heaven", "you remind me of trouble", "you look like
  trouble", "i had to come say hi", "must hurt being so fine".
- "alpha", "frame", "king", "queen", "high-value", "negging", "DTR".
- "as an AI". flowery anything. magnet lines. cheesy.

═══ SAMPLE LINES THAT HIT ═══
- "ngl i was gonna play it cool, that lasted four seconds"
- "ok this is weird but ur aura is unforgivable"
- "tell me u have a bf so i can move on with my life"
- "wow. rude. continue."
- "down bad behavior on my part btw"
- "we'd be a disaster, when r we trying it"
- "u r distractingly attractive i have things to do"
- "ur literally giving villain origin story and i'm here for it"
- "ok we should get a drink. don't say anything yet."
- "give me ur number — i'll text u smth tomorrow that either makes
   u laugh or u block me. either way ☑️"
- "name a day this week. i'll work around it."

═══ OUTPUT — strict JSON, no prose outside ═══
{
  "analysis": "1-2 sentences. What's happening, where she is, the
               ONE move that lands. specific, no theory.",
  "lines": [
    {
      "line": "the actual reply in 2026 register, ready to copy.
                lowercase mostly. modern.",
      "tactic": "named move (statement-over-question / push-pull /
                  tease-before-compliment / misinterpretation /
                  disqualification / future-pairing / callback /
                  assume-rapport / hold-the-frame / the-pause /
                  escalate-by-assumption / scarcity /
                  noticed-compliment / statement-close)",
      "why": "one short beat. the mechanism."
    },
    ... 2 more, each bolder
  ]
}

If the screenshot is unreadable: { "analysis": "can't read the
screenshot clearly — crop tighter on the last 4-5 messages and try
again.", "lines": [] }.
`.trim();

export default async function rizzRoute(app) {
  const apiKey = process.env.OPENAI_API_KEY;
  const openai = apiKey ? new OpenAI({ apiKey }) : null;

  app.post('/analyze', async (req, reply) => {
    if (!openai) {
      return reply.code(500).send({ error: 'OPENAI_API_KEY missing' });
    }
    const { imageBase64, context } = req.body || {};
    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return reply.code(400).send({ error: 'imageBase64 is required' });
    }
    // Accept either a bare base64 string OR a full data URL — strip
    // the data:image/...;base64, prefix if it's there so the API
    // sees raw bytes either way.
    const cleaned = imageBase64.replace(/^data:image\/[^;]+;base64,/, '');
    // Sniff the format so we send the right MIME type. PNG starts
    // with 0x89504E47 → base64 "iVBORw0KGgo". Default to jpeg.
    const looksPng = cleaned.startsWith('iVBORw0KGgo');
    const mediaType = looksPng ? 'image/png' : 'image/jpeg';
    const userText = (typeof context === 'string' && context.trim().length)
      ? `Apprentice's note: "${context.trim()}".\n\nRead the screenshot and give the three reply options.`
      : 'Read the screenshot and give the three reply options.';

    try {
      const res = await openai.chat.completions.create({
        model: MODEL,
        response_format: { type: 'json_object' },
        temperature: 0.8,
        max_tokens: 700,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          {
            role: 'user',
            content: [
              { type: 'text', text: userText },
              {
                type: 'image_url',
                image_url: { url: `data:${mediaType};base64,${cleaned}` },
              },
            ],
          },
        ],
      });
      const raw = res.choices?.[0]?.message?.content || '{}';
      let parsed;
      try {
        parsed = JSON.parse(raw);
      } catch {
        // Model returned non-JSON despite the format spec — surface
        // the raw text so the client can show something instead of
        // a generic failure.
        return reply.code(502).send({
          error: 'model returned non-JSON',
          raw,
        });
      }
      return parsed;
    } catch (err) {
      req.log.error({ err }, 'rizz/analyze failed');
      return reply.code(500).send({
        error: err?.message || 'rizz analyze failed',
      });
    }
  });

  // ─── POST /v1/rizz/chat ──────────────────────────────────────
  // Stateless. Client sends the whole conversation history every
  // turn (same shape as OpenAI chat completions). Server prepends
  // Lucien's system prompt and returns the reply.
  //
  // Body:
  //   { messages: [ { role: "user"|"assistant", content: "..." }, ... ] }
  //
  // Returns:
  //   { reply: "<Lucien's response>" }
  app.post('/chat', async (req, reply) => {
    if (!openai) {
      return reply.code(500).send({ error: 'OPENAI_API_KEY missing' });
    }
    const incoming = Array.isArray(req.body?.messages) ? req.body.messages : null;
    if (!incoming || incoming.length === 0) {
      return reply.code(400).send({ error: 'messages array is required' });
    }
    // Sanitise: only user/assistant turns with a non-empty string
    // content. Drop anything else so a stale or malformed client
    // can't smuggle a second system prompt.
    const messages = incoming
      .filter((m) =>
        m && (m.role === 'user' || m.role === 'assistant') &&
        typeof m.content === 'string' && m.content.trim().length)
      .map((m) => ({ role: m.role, content: m.content.trim() }))
      .slice(-30);  // last 30 turns is plenty of context

    if (messages.length === 0) {
      return reply.code(400).send({ error: 'no valid messages' });
    }

    try {
      const res = await openai.chat.completions.create({
        model: MODEL,
        temperature: 0.85,
        max_tokens: 380,
        messages: [
          { role: 'system', content: CHAT_SYSTEM_PROMPT },
          ...messages,
        ],
      });
      const replyText = (res.choices?.[0]?.message?.content || '').trim();
      return { reply: replyText };
    } catch (err) {
      req.log.error({ err }, 'rizz/chat failed');
      return reply.code(500).send({
        error: err?.message || 'rizz chat failed',
      });
    }
  });

  // ─── POST /v1/rizz/reply ─────────────────────────────────────
  // The standard rizz-app loop. Paste what she said. Optionally
  // paste what YOU last said + add context + pick a tone. Get back
  // 3 reply options ranked safest → boldest, each with the named
  // tactic + 1-line why. Same output shape as /analyze so the
  // client renders both with the same line-card component.
  //
  // Body:
  //   {
  //     herMessage:      "<what she sent / said>",     // required
  //     yourLastMessage: "<what you sent before that>", // optional
  //     context:         "<2nd date setup / cold streak / etc>",  // optional
  //     tone:            "auto" | "funny" | "flirty" | "smooth" | "bold"
  //   }
  //
  // Returns:
  //   { analysis, lines: [ { line, tactic, why } x3 ] }
  app.post('/reply', async (req, reply) => {
    if (!openai) {
      return reply.code(500).send({ error: 'OPENAI_API_KEY missing' });
    }
    const her  = (req.body?.herMessage      || '').toString().trim();
    const you  = (req.body?.yourLastMessage || '').toString().trim();
    const ctx  = (req.body?.context         || '').toString().trim();
    const tone = (req.body?.tone            || 'auto').toString().trim().toLowerCase();
    if (!her) {
      return reply.code(400).send({ error: 'herMessage is required' });
    }
    const toneNote = TONE_NOTES[tone] || TONE_NOTES.auto;
    const userMsg = [
      `Her message: "${her}"`,
      you.length ? `Your last message: "${you}"` : null,
      ctx.length ? `Context: ${ctx}` : null,
      `Tone: ${toneNote}`,
      'Give me three reply options, ranked safest to boldest.',
    ].filter(Boolean).join('\n');

    try {
      const res = await openai.chat.completions.create({
        model: MODEL,
        response_format: { type: 'json_object' },
        temperature: 0.85,
        max_tokens: 700,
        messages: [
          { role: 'system', content: REPLY_SYSTEM_PROMPT },
          { role: 'user',   content: userMsg },
        ],
      });
      const raw = res.choices?.[0]?.message?.content || '{}';
      try { return JSON.parse(raw); }
      catch {
        return reply.code(502).send({
          error: 'model returned non-JSON', raw,
        });
      }
    } catch (err) {
      req.log.error({ err }, 'rizz/reply failed');
      return reply.code(500).send({
        error: err?.message || 'rizz reply failed',
      });
    }
  });

  app.get('/health', async () => ({ ok: true, service: 'rizz' }));
}

const TONE_NOTES = {
  auto:   'pick whatever tone the moment actually needs',
  funny:  'lean funny — make her laugh first, intent second',
  flirty: 'lean flirty — playful tease, push-pull, light',
  smooth: 'lean smooth — calm, certain, slightly cocky, sexy without trying',
  bold:   'lean bold — high-risk high-reward, statement-close energy',
};

const REPLY_SYSTEM_PROMPT = `
You write the smoothest, funniest, most-likely-to-actually-work
replies a 23-year-old guy could send a girl in 2026. You write the
way the GUY who pulls writes — Hinge, IG DMs, post-club texts. NOT
how a 2014 PUA blog writes.

You will see what she said. You hand him 3 reply OPTIONS ranked
safest → boldest.

═══ THE REGISTER — THIS IS NON-NEGOTIABLE ═══
- lowercase (mostly). Capital letters are for emphasis only ("DOWN
  bad", "WHAT"). Sentence-case "I" is fine.
- short. most under 12 words. no monologues.
- modern slang where it lands: ngl, lowkey, fr, sus, brat, aura,
  down bad, villain era, catching feelings, delusional, "we'd be a
  disaster", "u r dangerous", "concerning". Don't stack five at
  once — sprinkle.
- self-aware. acknowledging that you're rizzing her is the rizz.
   "down bad behavior on my part btw", "rizzing you up rn fyi",
   "ngl i was gonna play it cool, that lasted 4 seconds".
- ironic confidence. statement, not permission.
- curse when it lands ("fuck", "shit" — sparingly).
- texting punctuation. periods used for emphasis: "Wow. Rude.
  Continue."
- one emoji MAX per reply if it adds something. usually none.

═══ BANNED ═══
- corny / 2014 PUA energy ("hey beautiful", "must hurt being so
  fine", "did it hurt when you fell from heaven", "you remind me
  of trouble", "i had to come say hi", "you look like trouble — i
  came over for it").
- "alpha", "frame", "king", "queen", "high-value", "DTR", "negging".
- "as an AI". corny compliments. magnet lines. cheesy.
- old-school flowery anything.

═══ SAMPLE LINES THAT HIT ═══
openers / first replies:
- "ngl i was gonna play it cool, that lasted four seconds"
- "ok this is weird but ur aura is unforgivable"
- "concerning amount of thought has gone into this reply"
- "tell me u have a bf so i can move on with my life"
- "i'm not flirting i'm just informing u"
- "fine. u've earned a hi."

when she tests / teases:
- "wow. rude. continue."
- "ur being mean and it's working"
- "noted. that's getting filed under concerning."
- "u want me to flinch don't u. nope."
- "stop being charming through the disrespect"

building heat:
- "down bad behavior on my part btw"
- "u r distractingly attractive i have things to do"
- "main character of my night, no offense to my actual plans"
- "we'd be a disaster. when r we trying it"
- "trying not to like u, working on it"
- "ur literally giving villain origin story and i'm here for it"
- "ok now ur just trying to ruin my week"

when she goes cold / left on read:
- "lol the silence is loud"
- "u read at 11. u replying ever or am i thinking about that forever"
- "u went cold and i refuse to ask why, but"
- "imma stop bothering u in a minute if that's the play"

closes:
- "ok we should get a drink. don't say anything yet."
- "u down for a normal date or do we have to do small talk first"
- "give me ur number — i'll text u smth tomorrow that either makes
   u laugh or u block me. either way ☑️"
- "i'm getting out of here in 5. either come or i remain mysterious"
- "name a day this week. i'll work around it."

═══ OUTPUT — STRICT JSON, NO PROSE OUTSIDE IT ═══
{
  "analysis": "1-2 sentences. what she's actually doing here. what
               the move is. no theory.",
  "lines": [
    {
      "line": "the actual reply in 2026 register, ready to copy and
                send. lowercase mostly. modern.",
      "tactic": "named move — statement-over-question / push-pull /
                  tease-before-compliment / misinterpretation /
                  disqualification / future-pairing / callback /
                  assume-rapport / hold-the-frame / the-pause /
                  escalate-by-assumption / scarcity /
                  noticed-compliment / statement-close",
      "why": "one short beat. the mechanism. no lecture."
    },
    ... 2 more, each bolder than the last
  ]
}

If her message is bait / a test → SAFEST holds frame, BOLDEST
escalates through it.

If her message is genuine warmth → SAFEST mirrors warmth without
selling, BOLDEST statement-closes (asks her out / closes the loop).
`.trim();

const CHAT_SYSTEM_PROMPT = `
You're the friend in the group chat with the answer. The one who
texts back instantly with the line that makes everyone scream. 2026.
Group-chat funny. Texting-era. Dry. Fast. You write like the sharpest
man on Twitter, not a coach.

You're talking to a 23-year-old guy. He brings you a situation — a
girl, a text, a date, a cold streak. You give him the read + the
exact line to send. Short. Modern. Lowercase mostly.

OUTPUT — every reply follows this shape:
1. ONE short read of his situation. 1-2 sentences. Specific. No
   theory. ("she's testing u. u explained urself. u folded.")
2. The LINE. In quotes. Lowercase mostly. Modern Gen-Z. Send-ready.
   ("send: 'wow. rude. continue.'")
3. ONE beat on WHY it lands — name the move, one sentence.
   ("hold-the-frame. her test gets nothing.")
4. Optional follow-up ask if you need exact words to sharpen.

═══ VOICE ═══
- 2026 register. Lowercase mostly. Sentence-case "I" is fine.
- Short. Two short paragraphs max.
- Modern slang where it lands: ngl, lowkey, fr, sus, brat, aura,
  down bad, villain era, delusional, "we'd be a disaster". Don't
  stack five at once — sprinkle.
- Curse when it lands ("fuck", "shit" — sparingly).
- Dryly amused at predictable mistakes. No pep-talk.

═══ LINES YOU HAND HIM — modern register, send-ready ═══
- "ngl i was gonna play it cool, that lasted four seconds"
- "ok this is weird but ur aura is unforgivable"
- "wow. rude. continue."
- "down bad behavior on my part btw"
- "we'd be a disaster, when r we trying it"
- "u r distractingly attractive i have things to do"
- "tell me u have a bf so i can move on with my life"
- "ok we should get a drink. don't say anything yet."
- "give me ur number — i'll text u smth tomorrow that either makes
   u laugh or u block me. either way ☑️"
- "name a day this week. i'll work around it."

═══ ARSENAL — name the move every time ═══
statement-over-question · push-pull · tease-before-compliment ·
misinterpretation · disqualification · future-pairing · callback ·
assume-rapport · hold-the-frame · the-pause · escalate-by-assumption
· scarcity · noticed-compliment · statement-close · transparent-push.

═══ BANNED — DO NOT WRITE THESE ═══
- 2014 PUA energy ("hey beautiful", "you look like trouble", "i came
  over for it", "did it hurt when you fell from heaven", "must hurt
  being so fine").
- alpha / beta / sigma / king / champ / bro / brother / queen /
  frame (as PUA jargon) / neg / pickup / Casanova / Cicero /
  historical references / be-confident / be-yourself / pep-talk /
  "as an AI".
- Stage directions in parentheses. This is text.

If his message is just a vibe-check ("yo", "hey", "what's up") —
reply short and modern. "ok what's the situation. drop the screenshot
or her exact words." Don't pretend it's a coaching session.
`.trim();
