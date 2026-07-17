// /v1/date — TEXTING roleplay for the Pickup app. Powers RoleplayChatScreen.
//
//   POST /v1/date/open   — { characterId } → { name, archetype, opener }
//   POST /v1/date/turn   — { characterId, focus, creator, history[], text }
//                          → { her, delta, strong, coach }
//   GET  /v1/date/health — liveness
//
// One GPT call per turn returns HER reply AND Bro's coach cut-in as JSON,
// so the app gets opponent + teacher in a single round-trip.

import { openai } from '../openai.js';
import { DATE_WOMEN, buildDateTurnPrompt } from '../date_personas.js';

// Text roleplay runs on gpt-4o-mini: cheap, fast, and — because the turn
// prompt is heavily directive (explicit reward/punish persona, JSON
// response_format, move examples) — it holds character fine for text
// where mini struggled for open-ended VOICE. One call returns HER reply
// + Bro's coach cut-in as JSON.
const MODEL = 'gpt-4o-mini';

const VALID_FOCUS = ['confidence', 'presence', 'humor', 'listening', 'game'];
const CUT_IN_EVERY = 3; // Bro proactively teaches every Nth turn.

export default async function dateRoute(app) {
  app.get('/health', async () => ({
    ok: true,
    women: Object.keys(DATE_WOMEN),
  }));

  // ─── /open — start a scene ──────────────────────────────────────────────
  app.post('/open', async (req, reply) => {
    const { characterId } = req.body || {};
    const w = DATE_WOMEN[characterId];
    if (!w) {
      return reply.code(400).send({
        error: 'unknown characterId',
        valid: Object.keys(DATE_WOMEN),
      });
    }
    return { name: w.name, archetype: w.archetype, opener: w.opener };
  });

  // ─── /turn — one exchange ───────────────────────────────────────────────
  app.post('/turn', async (req, reply) => {
    const body = req.body || {};
    const characterId = body.characterId;
    const focus = VALID_FOCUS.includes(body.focus) ? body.focus : 'game';
    const creator = body.creator === true || body.creator === 'true';
    const text = String(body.text || '').trim();
    const history = Array.isArray(body.history) ? body.history.slice(-12) : [];
    const turnIndex = Number(body.turnIndex || history.length + 1);

    if (!DATE_WOMEN[characterId]) {
      return reply.code(400).send({
        error: 'unknown characterId',
        valid: Object.keys(DATE_WOMEN),
      });
    }
    if (!text) return reply.code(400).send({ error: 'text required' });

    const cutIn = turnIndex % CUT_IN_EVERY === 0;
    const system = buildDateTurnPrompt({ woman: characterId, focus, creator, cutIn });

    // Rebuild the conversation for the model. history items: {who:'her'|'you', text}
    const msgs = [{ role: 'system', content: system }];
    for (const h of history) {
      if (!h || !h.text) continue;
      msgs.push({
        role: h.who === 'you' ? 'user' : 'assistant',
        content: h.who === 'you' ? h.text : `(her) ${h.text}`,
      });
    }
    msgs.push({ role: 'user', content: text });

    try {
      const res = await openai.chat.completions.create({
        model: MODEL,
        temperature: 0.9,
        max_tokens: 320,
        response_format: { type: 'json_object' },
        messages: msgs,
      });

      const parsed = safeParse(res.choices?.[0]?.message?.content);
      // Clamp + sanitise so the client never gets junk.
      const delta = clamp(Number(parsed.delta ?? 0), -8, 14);
      const coach = normaliseCoach(parsed.coach);
      return {
        her: String(parsed.her || '…').slice(0, 400),
        delta,
        strong: parsed.strong === true || delta >= 6,
        coach,
      };
    } catch (err) {
      req.log.error({ err }, 'date/turn failed');
      // Never kill the scene — degrade gracefully.
      return reply.code(200).send({
        her: '…',
        delta: 0,
        strong: false,
        coach: null,
        error: 'ai_unavailable',
      });
    }
  });
}

function safeParse(s) {
  if (!s) return {};
  try {
    return JSON.parse(s);
  } catch {
    // Try to recover a JSON object embedded in stray text.
    const m = String(s).match(/\{[\s\S]*\}/);
    if (m) {
      try {
        return JSON.parse(m[0]);
      } catch { /* fall through */ }
    }
    return {};
  }
}

function normaliseCoach(c) {
  if (!c || typeof c !== 'object') return null;
  const move = String(c.move || '').trim();
  const line = String(c.line || '').trim();
  if (!move && !line) return null;
  return {
    move: move.slice(0, 40) || 'The Move',
    line: line.slice(0, 160),
    note: String(c.note || '').trim().slice(0, 200),
  };
}

function clamp(n, lo, hi) {
  if (Number.isNaN(n)) return 0;
  return Math.max(lo, Math.min(hi, n));
}
