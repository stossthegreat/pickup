// POST /v1/diablo/turn   — full conversational turn (audio in → reply + audio out)
// POST /v1/diablo/speak  — pure TTS  (text in → audio out, Diablo's performance)
//
// /turn body (multipart/form-data):
//   - audio:      m4a/wav file (the user's spoken line)
//   - mode:       "charm" | "heat" | "thirst" | "diablo"
//   - context:    JSON string {kind: "rhetoric"|"rizz", lessonId, scene?, character?}
//   - history:    JSON string [{role:"user"|"diablo", text:"…"}, …]
//
// /turn response (application/json):
//   { "transcript", "reply", "audio" (b64 mp3), "mode" }
//
// /speak body (application/json):
//   { "text": "what to say", "mode": "charm|heat|thirst|diablo" }
//
// /speak response (application/json):
//   { "audio": "<base64 mp3>", "mode": "<echoed>" }
//
// Audio is returned base64 in v1 so the Flutter side can play with
// audioplayers.BytesSource without dealing with HTTP streaming yet.

import { openai, MODELS } from '../openai.js';
import { personaFor } from '../personas.js';

export default async function diabloRoute(app) {

  // ─── /speak — TTS only. The frontend uses this to make Diablo voice
  //              lesson intros, verdicts, model answers, and the opening
  //              line of a scene WITHOUT needing a user recording first.
  app.post('/speak', async (req, reply) => {
    const { text, mode = 'charm' } = req.body || {};
    if (!text || typeof text !== 'string') {
      return reply.code(400).send({ error: 'text required' });
    }
    const persona = personaFor(mode);
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: persona.voice,
        input: text.trim(),
        instructions: persona.instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      return reply.send({
        audio: buf.toString('base64'),
        mode,
      });
    } catch (e) {
      req.log.error({ err: e }, 'speak failed');
      return reply.code(500).send({
        error: 'speak_failed',
        detail: String(e.message || e),
      });
    }
  });

  app.post('/turn', async (req, reply) => {
    let mode = 'charm';
    let history = [];
    let context = {};
    let audioBuffer = null;

    for await (const part of req.parts()) {
      if (part.type === 'file' && part.fieldname === 'audio') {
        audioBuffer = await part.toBuffer();
      } else if (part.type === 'field') {
        if (part.fieldname === 'mode')    mode = String(part.value);
        if (part.fieldname === 'context') {
          try { context = JSON.parse(String(part.value)); } catch {}
        }
        if (part.fieldname === 'history') {
          try { history = JSON.parse(String(part.value)); } catch {}
        }
      }
    }

    if (!audioBuffer) {
      return reply.code(400).send({ error: 'audio field required' });
    }

    const persona = personaFor(mode);

    // 1) Whisper transcribe.
    let transcript = '';
    try {
      const file = await OpenAIFile(audioBuffer, 'turn.m4a');
      const tr = await openai.audio.transcriptions.create({
        file,
        model: MODELS.whisper,
      });
      transcript = (tr.text || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'whisper failed');
      return reply.code(500).send({ error: 'transcription_failed', detail: String(e.message || e) });
    }

    // 2) Chat — Diablo's reply in-persona.
    const messages = [
      { role: 'system', content: persona.chat },
      { role: 'system', content: buildContextMessage(context) },
      ...history.map(h => ({
        role: h.role === 'diablo' ? 'assistant' : 'user',
        content: h.text,
      })),
      { role: 'user', content: transcript || '(silence)' },
    ];

    let replyText = '';
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages,
        temperature: mode === 'diablo' ? 1.0 : (mode === 'thirst' ? 0.95 : 0.85),
        max_tokens: mode === 'diablo' ? 500 : (mode === 'thirst' ? 280 : 180),
      });
      replyText = (chat.choices?.[0]?.message?.content || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'chat failed');
      return reply.code(500).send({ error: 'chat_failed', detail: String(e.message || e) });
    }

    // 3) TTS — Diablo's voice carrying the line.
    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: persona.voice,
        input: replyText,
        instructions: persona.instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      // Audio is best-effort; still return the text so the UI doesn't go dark.
      req.log.warn({ err: e }, 'tts failed — returning text only');
    }

    return reply.send({
      transcript,
      reply: replyText,
      audio: audioB64,
      mode,
    });
  });
}

// Wraps the Whisper input. openai-node accepts a Web File object.
async function OpenAIFile(buffer, name) {
  // Node 20+ has global File from undici.
  return new File([buffer], name, { type: 'audio/m4a' });
}

function buildContextMessage(ctx) {
  if (!ctx || !ctx.kind) {
    return 'Context: general charisma conversation.';
  }
  if (ctx.kind === 'rhetoric') {
    return `Context: rhetoric drill, lesson "${ctx.lessonId || 'unknown'}".
The user just attempted a 30-second spoken response. Grade his attempt
and reply IN CHARACTER. Do not mention that you are a coach or AI.`;
  }
  if (ctx.kind === 'rizz') {
    return `Context: rizz scenario.
Scene: ${ctx.scene || 'unspecified'}
Character you play: ${ctx.character || 'sharp, slightly bored woman'}
You ARE this character. Respond as her. Stay in scene at all times.`;
  }
  return `Context: ${JSON.stringify(ctx)}`;
}
