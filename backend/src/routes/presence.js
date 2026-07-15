// POST /v1/presence/score
//
// The voice-side scorer for the PRESENCE curriculum.
//
// Body (multipart/form-data):
//   - audio:           m4a/wav of the apprentice delivering the line
//   - lessonId:        string — pinned scene metadata is server-side
//   - targetLine:      the verbatim line he was supposed to deliver
//   - deliveryCue:     the one delivery cue for the line
//   - targetWpmLow:    pace band low bound
//   - targetWpmHigh:   pace band high bound
//   - warmthExpected:  "true" / "false"
//
// Returns (application/json):
//   {
//     transcript: "...",
//     wpm: 102,
//     scores: {
//       voiceAuthority: 0.74,   // 0..1
//       pace:           0.81,
//       confidence:     0.65,
//       warmth:         0.40,
//     },
//     fatalFlaw: "One sentence in Lucien's voice."
//   }
//
// The handler does three things:
//   1. Whisper transcribes the audio. The transcript is what we ask
//      GPT to judge against the target line.
//   2. We compute words-per-minute deterministically — backend-side
//      math, not an LLM hallucination. Pace score is then computed
//      from the WPM band defined by the lesson.
//   3. GPT scores voiceAuthority + confidence + warmth against the
//      target + delivery cue, returning strict JSON.

import { openai, MODELS } from '../openai.js';

export default async function presenceRoute(app) {
  app.post('/score', async (req, reply) => {
    let lessonId       = '';
    let targetLine     = '';
    let deliveryCue    = '';
    let targetWpmLow   = 90;
    let targetWpmHigh  = 150;
    let warmthExpected = false;
    let audioBuffer    = null;
    let audioMs        = 0;        // recording duration the frontend
                                   // passes so we can compute WPM
                                   // without re-decoding the file

    for await (const part of req.parts()) {
      if (part.type === 'file' && part.fieldname === 'audio') {
        audioBuffer = await part.toBuffer();
      } else if (part.type === 'field') {
        const v = String(part.value);
        switch (part.fieldname) {
          case 'lessonId':       lessonId       = v;            break;
          case 'targetLine':     targetLine     = v;            break;
          case 'deliveryCue':    deliveryCue    = v;            break;
          case 'targetWpmLow':   targetWpmLow   = parseInt(v) || targetWpmLow;  break;
          case 'targetWpmHigh':  targetWpmHigh  = parseInt(v) || targetWpmHigh; break;
          case 'warmthExpected': warmthExpected = v === 'true'; break;
          case 'audioMs':        audioMs        = parseInt(v) || 0; break;
        }
      }
    }

    if (!audioBuffer) {
      return reply.code(400).send({ error: 'audio required' });
    }

    // ── 1. Whisper transcribe ───────────────────────────────────────
    let transcript = '';
    try {
      const file = new File([audioBuffer], 'presence.m4a',
          { type: 'audio/m4a' });
      const tr = await openai.audio.transcriptions.create({
        file,
        model: MODELS.whisper,
      });
      transcript = (tr.text || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'presence whisper failed');
      return reply.code(500).send({
        error: 'transcription_failed',
        detail: String(e.message || e),
      });
    }

    // ── 2. WPM + pace score (deterministic, no LLM) ────────────────
    const wordCount = transcript.split(/\s+/).filter(Boolean).length;
    const durationSec = audioMs > 0 ? audioMs / 1000 : 0;
    const wpm = durationSec > 0
      ? Math.round((wordCount / durationSec) * 60)
      : 0;

    // Pace score: 1.0 inside the band, falling off linearly outside.
    const targetCenter = (targetWpmLow + targetWpmHigh) / 2;
    const bandHalf     = (targetWpmHigh - targetWpmLow) / 2;
    let pace;
    if (wpm === 0) {
      pace = 0;
    } else if (wpm >= targetWpmLow && wpm <= targetWpmHigh) {
      pace = 1.0;
    } else {
      // Each WPM outside the band costs 1/60 of the score; ±60 wpm
      // away from the band edge collapses the score to 0.
      const distance = Math.min(
        Math.abs(wpm - targetWpmLow),
        Math.abs(wpm - targetWpmHigh)
      );
      pace = Math.max(0, 1 - distance / 60);
    }

    // ── 3. GPT scores voiceAuthority + confidence + warmth ────────
    const judgePrompt = `
You are Lucien, the worldly strategist. You are scoring one delivery
attempt by an apprentice. You have the verbatim transcript, the
target line he was supposed to say, and the delivery cue.

You will return STRICT JSON ONLY with these keys:
  voiceAuthority  (0..1) — did he sound grounded, weighted, decisive?
                           a high-pitched, light, throat-voiced
                           delivery scores low; a grave, low-pitched,
                           measured one scores high.
  confidence      (0..1) — did he avoid hedges ("um", "I think",
                           "kind of", "maybe"), filler words, and
                           upward inflection at the ends of
                           declarations? Each hedge costs heavily.
  warmth          (0..1) — was there appropriate warmth in his tone?
                           Lessons either EXPECT warmth (curiosity,
                           playfulness — score high if present) or
                           DO NOT (most others — score high for
                           neutral, low for forced cheer).
  fatalFlaw       (string) — ONE sentence in Lucien's voice naming the
                            single biggest weakness in this attempt.
                            Short. Disappointed amusement, never
                            anger. Never "as an AI". Never pickup
                            vocabulary. Examples:
                            "You hedged on the word that mattered."
                            "You filled the silence I left for you."
                            "The pitch lifted on the last word — it
                             always does, with you."

Apprentice's transcript:
"${transcript || '(silence)'}"

Target line:
"${targetLine}"

Delivery cue (the ONE thing that mattered for this line):
${deliveryCue}

Warmth expected on this lesson: ${warmthExpected ? 'YES' : 'NO'}

Output JSON only. No prose, no markdown.
`.trim();

    let scoresJson = null;
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.judge || MODELS.chat,
        messages: [
          { role: 'system', content:
              'You return strict JSON only. No prose. No code fences.' },
          { role: 'user',   content: judgePrompt },
        ],
        temperature: 0.4,
        response_format: { type: 'json_object' },
        max_tokens: 240,
      });
      const raw = chat.choices?.[0]?.message?.content || '{}';
      scoresJson = JSON.parse(raw);
    } catch (e) {
      req.log.error({ err: e }, 'presence judge failed');
      return reply.code(500).send({
        error: 'judge_failed',
        detail: String(e.message || e),
      });
    }

    const clamp = (v) => Math.max(0, Math.min(1, Number(v) || 0));
    const out = {
      transcript,
      wpm,
      scores: {
        voiceAuthority: clamp(scoresJson.voiceAuthority),
        pace,
        confidence:     clamp(scoresJson.confidence),
        warmth:         clamp(scoresJson.warmth),
      },
      fatalFlaw: typeof scoresJson.fatalFlaw === 'string'
        ? scoresJson.fatalFlaw.trim()
        : '',
    };

    req.log.info({
      msg: 'presence score',
      lessonId, wpm,
      voiceAuthority: out.scores.voiceAuthority,
      confidence:     out.scores.confidence,
      warmth:         out.scores.warmth,
      pace:           out.scores.pace,
    });

    return reply.send(out);
  });
}
