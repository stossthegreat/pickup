// POST /v1/rhetoric/score   — text-only judge (transcript → scores + verdict)
// POST /v1/rhetoric/drill   — full audio drill (audio → transcribe + score + TTS verdict)
//
// /score body:
//   { "lessonId", "transcript" }
// /score response:
//   { "dimensions", "verdict", "total" }
//
// /drill body (multipart):
//   - audio:    m4a/wav file
//   - lessonId: string
// /drill response:
//   {
//     "transcript", "dimensions", "verdict", "total",
//     "audio": "<base64 mp3 of the verdict in Diablo's voice>"
//   }
//
// /drill is the LOW-LATENCY path. Saves an extra round trip vs.
// calling /v1/diablo/turn + /v1/rhetoric/score back-to-back.

import { openai, MODELS } from '../openai.js';
import { JUDGE_PROMPT, personaFor } from '../personas.js';

export default async function rhetoricRoute(app) {

  // ─── /score — text-only judge ─────────────────────────────────────────
  app.post('/score', async (req, reply) => {
    const { lessonId, transcript } = req.body || {};
    if (!transcript || typeof transcript !== 'string') {
      return reply.code(400).send({ error: 'transcript required' });
    }
    try {
      const result = await judge(transcript, lessonId);
      return reply.send(result);
    } catch (e) {
      req.log.error({ err: e }, 'score failed');
      return reply.code(500).send({
        error: 'score_failed',
        detail: String(e.message || e),
      });
    }
  });

  // ─── /drill — full audio path with TTS in one round trip ──────────────
  app.post('/drill', async (req, reply) => {
    let lessonId = '';
    let audioBuffer = null;

    for await (const part of req.parts()) {
      if (part.type === 'file' && part.fieldname === 'audio') {
        audioBuffer = await part.toBuffer();
      } else if (part.type === 'field' && part.fieldname === 'lessonId') {
        lessonId = String(part.value);
      }
    }

    if (!audioBuffer) {
      return reply.code(400).send({ error: 'audio field required' });
    }

    // 1) Transcribe.
    let transcript = '';
    try {
      const file = new File([audioBuffer], 'drill.m4a', { type: 'audio/m4a' });
      const tr = await openai.audio.transcriptions.create({
        file,
        model: MODELS.whisper,
      });
      transcript = (tr.text || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'whisper failed');
      return reply.code(500).send({
        error: 'transcription_failed',
        detail: String(e.message || e),
      });
    }

    // 2) Judge in one chat call (scores + verdict line).
    let judged;
    try {
      judged = await judge(transcript, lessonId);
    } catch (e) {
      req.log.error({ err: e }, 'judge failed');
      return reply.code(500).send({
        error: 'judge_failed',
        detail: String(e.message || e),
      });
    }

    // 3) TTS — Diablo voicing the verdict in HEAT.
    let audioB64 = '';
    if (judged.verdict && judged.verdict.trim().length > 0) {
      const persona = personaFor('heat');
      try {
        const speech = await openai.audio.speech.create({
          model: MODELS.tts,
          voice: persona.voice,
          input: judged.verdict.trim(),
          instructions: persona.instructions,
          response_format: 'mp3',
        });
        const buf = Buffer.from(await speech.arrayBuffer());
        audioB64 = buf.toString('base64');
      } catch (e) {
        req.log.warn({ err: e }, 'tts failed — returning text only');
      }
    }

    return reply.send({
      transcript,
      dimensions: judged.dimensions,
      verdict: judged.verdict,
      total: judged.total,
      audio: audioB64,
    });
  });
}

// Shared judge — one chat call returns scores + Diablo's verdict.
async function judge(transcript, lessonId) {
  const chat = await openai.chat.completions.create({
    model: MODELS.judge,
    messages: [
      { role: 'system', content: JUDGE_PROMPT },
      {
        role: 'user',
        content:
          `Lesson: ${lessonId || 'general'}\n` +
          `Transcript:\n"""${transcript}"""\n\n` +
          `Return STRICT JSON only.`,
      },
    ],
    temperature: 0.4,
    response_format: { type: 'json_object' },
  });
  const raw = chat.choices?.[0]?.message?.content || '{}';
  const parsed = JSON.parse(raw);
  const dims = parsed.dimensions || {};
  const total = Object.values(dims).reduce(
    (a, b) => a + (typeof b === 'number' ? b : 0),
    0,
  );
  return {
    dimensions: dims,
    verdict: parsed.verdict || '',
    total,
  };
}
