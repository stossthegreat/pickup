// /v1/coach — the teach/game layer. Wraps the ported im-him RIZZ brain
// (the elite line-writer: 12-word cap, move labels, no AI tells). This is
// what makes Bro good at game/rizz in teach mode.
//
//   POST /v1/coach/lines — { her?, vibe?, ctx?, scenario?, previous?, imageBase64? }
//                          → { replies: [{ text, tag }] }   (3 ranked lines)
//   POST /v1/coach/qa    — { messages[], imageBase64? } → { reply }
//   GET  /v1/coach/health

import { rizzReply, rizzChat } from '../rizz_brain.js';

export default async function coachRoute(app) {
  app.get('/health', async () => ({ ok: true, brain: 'rizz-v297' }));

  // Screenshot or text → three lines he can send, ranked safest→boldest.
  app.post('/lines', async (req, reply) => {
    const b = req.body || {};
    try {
      const out = await rizzReply({
        her: b.her,
        vibe: b.vibe,
        ctx: b.ctx,
        scenario: b.scenario,
        previous: b.previous,
        imageBase64: b.imageBase64,
        mySide: b.mySide,
      });
      return out; // { replies: [...] }
    } catch (err) {
      req.log.error({ err }, 'coach/lines failed');
      return reply.code(200).send({ replies: [], error: 'ai_unavailable' });
    }
  });

  // Free-form coaching Q&A (Bro answers game questions).
  app.post('/qa', async (req, reply) => {
    const b = req.body || {};
    try {
      const out = await rizzChat({ messages: b.messages, imageBase64: b.imageBase64 });
      return out;
    } catch (err) {
      req.log.error({ err }, 'coach/qa failed');
      return reply.code(200).send({ reply: '', error: 'ai_unavailable' });
    }
  });
}
