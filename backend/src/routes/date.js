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
import { rizzChat } from '../rizz_brain.js';

// Text roleplay runs on gpt-4o-mini: cheap, fast, and — because the turn
// prompt is heavily directive (explicit reward/punish persona, JSON
// response_format) — it holds character fine for text. A turn returns HER
// reply + the score delta; coaching is on-demand via /help (Lucien).
const MODEL = 'gpt-4o-mini';

const VALID_FOCUS = ['confidence', 'presence', 'humor', 'listening', 'game'];

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
    const userProfile = normaliseProfile(body.userProfile);

    if (!DATE_WOMEN[characterId]) {
      return reply.code(400).send({
        error: 'unknown characterId',
        valid: Object.keys(DATE_WOMEN),
      });
    }
    if (!text) return reply.code(400).send({ error: 'text required' });

    const system = buildDateTurnPrompt({ woman: characterId, focus, creator, userProfile });

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
        // High temp + penalties push it off the bland "assistant" default
        // into short, varied, real texting. Low max_tokens keeps her from
        // monologuing — real girls fire off fragments, not paragraphs.
        temperature: 1.05,
        top_p: 0.92,
        frequency_penalty: 0.6,
        presence_penalty: 0.4,
        max_tokens: 180,
        response_format: { type: 'json_object' },
        messages: msgs,
      });

      const parsed = safeParse(res.choices?.[0]?.message?.content);
      // Clamp + sanitise so the client never gets junk.
      const delta = clamp(Number(parsed.delta ?? 0), -8, 14);
      return {
        her: String(parsed.her || '…').slice(0, 400),
        delta,
        strong: parsed.strong === true || delta >= 6,
      };
    } catch (err) {
      req.log.error({ err }, 'date/turn failed');
      // Never kill the scene — degrade gracefully.
      return reply.code(200).send({
        her: '…',
        delta: 0,
        strong: false,
        error: 'ai_unavailable',
      });
    }
  });

  // ─── /help — Lucien steps in on demand ──────────────────────────────────
  // The "Get Help" button. Lucien reads the live convo and hands over the
  // exact line to send next, in the SAME brilliant-rizz voice as the Texts
  // tab (rizz_brain CHAT_SYSTEM). Quoted lines render as tap-to-copy cards.
  //
  // Body: { characterId, history:[{who,text}], creator, userProfile }
  // Returns: { help: string }  (rizz prose + one or more "quoted" lines)
  app.post('/help', async (req, reply) => {
    const body = req.body || {};
    const w = DATE_WOMEN[body.characterId];
    const creator = body.creator === true || body.creator === 'true';
    const history = Array.isArray(body.history) ? body.history.slice(-14) : [];
    const profile = normaliseProfile(body.userProfile);

    const convo = history
      .filter((h) => h && h.text)
      .map((h) => `${h.who === 'you' ? 'ME' : 'HER'}: ${h.text}`)
      .join('\n');
    const archetype = w ? w.archetype : 'a girl i just matched with';
    const who = profile.name ? ` my name's ${profile.name}.` : '';
    const ask =
      `i'm texting a girl — the ${archetype} type.${who} here's the convo so far:\n\n` +
      `${convo || '(i haven\'t said anything yet)'}\n\n` +
      `what do i send back right now? give me the exact line.`;

    try {
      const out = await rizzChat({
        messages: [{ role: 'user', content: creator ? `${ask}\n\n(no filter, be savage)` : ask }],
      });
      const help = (out && typeof out.reply === 'string') ? out.reply.trim() : '';
      if (!help) return reply.code(200).send({ help: '', error: 'ai_unavailable' });
      return { help };
    } catch (err) {
      req.log.error({ err }, 'date/help failed');
      return reply.code(200).send({ help: '', error: 'ai_unavailable' });
    }
  });
}

// Sanitise the optional user profile → { name, ageGroup } (strings only,
// bounded). Anything malformed collapses to empty and is simply omitted.
function normaliseProfile(p) {
  if (!p || typeof p !== 'object') return {};
  const name = typeof p.name === 'string' ? p.name.trim().slice(0, 40) : '';
  const ageGroup = typeof p.ageGroup === 'string' ? p.ageGroup.trim().slice(0, 20) : '';
  return { name, ageGroup };
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

function clamp(n, lo, hi) {
  if (Number.isNaN(n)) return 0;
  return Math.max(lo, Math.min(hi, n));
}
