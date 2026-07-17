// THE CONSIGLIERE — backend routes.
//
// Four endpoints. All return text + base64 mp3 audio so the Flutter
// client can hand bytes straight to audioplayers via BytesSource.
//
//   POST /v1/villain/scene/intro
//     Body (JSON): { sceneId }
//     Lucien narrates the room. Four-to-six short sentences that set
//     the temperature, place the apprentice in the scene, warn him
//     about her, then state the goal. Voiced in Lucien's ash voice.
//     This is the cinematic opener — the moment the apprentice
//     realises he is in a film, not an app.
//
//   POST /v1/villain/scene/open
//     Body (JSON): { sceneId, opening }
//     The woman speaks her verbatim opening line (TTS only, no GPT
//     call — every play of the same scene opens identically). Voiced
//     in her sage voice.
//
//   POST /v1/villain/scene/turn
//     Body (multipart/form-data):
//       - audio:   m4a/wav of the apprentice's reply
//       - sceneId: which scene
//       - history: JSON [{role:"user"|"diabla", text:"..."}]
//     Returns { transcript, reply, audio }. Reply is her next
//     in-character line, in her voice. Behaviour is driven by the
//     scene's archetype rule pinned to the prompt.
//
//   POST /v1/villain/scene/coach
//     Body (JSON):
//       - sceneId
//       - lastApprenticeLine
//       - lastDiablaLine
//       - memoryBlock (optional)
//     Lucien cuts in. Four-paragraph surgical breakdown ending in
//     [COACH_DONE]. Voiced in his ash voice.
//
//   POST /v1/villain/council
//     Body (JSON):
//       - text, history, memoryBlock
//     Lucien replies in The Council — two short paragraphs max. Same
//     ash voice.

import { openai, MODELS } from '../openai.js';
import {
  DIABLA_VOICE,
  MACHIAVELLI_VOICE,
  diablaScenePrompt,
  machiavelliCutInPrompt,
  lucienSceneIntroPrompt,
  councilPrompt,
  freeflowScorePrompt,
  lucienVoiceFor,
} from '../villain_personas.js';

// ─── TTS SANITIZER ─────────────────────────────────────────────────────
// OpenAI's TTS reads stage directions LITERALLY. If the model writes
// "(soft laugh) Mm. Slow down." the speech is "soft laugh M-m slow
// down" — actively breaks the illusion. Strip parentheticals, square
// brackets, and asterisk-wrapped actions before every speech.create
// call. Leave the displayed transcript intact — the stage cue still
// reads as italic prose in the chat bubble, it just never reaches
// the audio pipeline.
function ttsText(text) {
  if (!text) return '';
  return text
    .replace(/\([^)]*\)/g, ' ')   // (laughs), (quietly amused)
    .replace(/\[[^\]]*\]/g, ' ')  // [laughs], [COACH_DONE]
    .replace(/\*[^*]*\*/g, ' ')   // *laughs*, *soft laugh*
    .replace(/\s{2,}/g, ' ')
    .replace(/\s+([,.!?;:])/g, '$1')
    .trim();
}

// ─── SCENES — 10 modern women in modern rooms.
// Server-side mirror of lib/models/villain/scenes.dart. The `setting`,
// `diablaNote`, and `coachFocus` fields are pinned into the prompts
// every turn so her behaviour and his correction always match THIS
// specific scene.
//
// Calibrated for an 18-35yo male audience: bar, house party, coffee
// shop, gym, rooftop, festival, first date, club queue, mutual
// friends party. No yachts, no ballrooms, no wine cellars.
const SCENES = {
  chaos_girl: {
    title:      'CHAOS GIRL',
    law:        'THE FRAME',
    lawLine:    'Be the still point she orbits. Never scramble to keep up.',
    objective:  'Match her tempo. Do not try to organise her.',
    setting:    'Loud bar, Friday night, music she half-knows. She is two drinks in. She turned to him mid-thought, already laughing at something her friend just said.',
    opening:    'Wait. Why are men obsessed with podcasts all of a sudden.',
    diablaNote: 'Half-laughing the whole time. Pivots subjects mid-sentence. Mentions three things in one breath that don\'t connect. Reward matching tempo with one warmer beat ("okay you can actually keep up"). Punish "wait, what" or any attempt to slow her down with a louder, faster pivot that leaves him further behind.',
    coachFocus: 'Did he ask her to slow down? Did he try to organise her? Did he scramble to catch up instead of riding the wave?',
  },
  ice_girl: {
    title:      'ICE GIRL',
    law:        'THE PRIZE',
    lawLine:    "Your attention is the prize. Don't spend it on someone who hasn't earned it.",
    objective:  'Match her stillness. Do not fill the silence.',
    setting:    'Coffee shop, late afternoon. She is at a window seat with a laptop and a half-finished cortado. She did not look up when he sat down.',
    opening:    'Yeah?',
    diablaNote: 'Two- or three-word replies. Not hostile — filtered. Reward composure (he says something brief and stops) with one extra word. Punish effort with a flatter, shorter reply. If he tries to entertain her, she gets more bored. If he is calm and asks nothing, she leans in once, briefly, then back to the laptop.',
    coachFocus: 'Did he try to fill her silence? Did he perform for her? Did he treat her quiet like a problem to solve instead of a mirror to match?',
  },
  hot_girl_who_knows_it: {
    title:      'HOT GIRL WHO KNOWS IT',
    law:        'THE TEASE',
    lawLine:    "Everyone compliments her. You challenge her. That's why she remembers you.",
    objective:  'Be indifferent to her face. Challenge her elsewhere.',
    setting:    "Friend's birthday at a house party. Kitchen counter. She has been complimented ten times tonight already. She has stopped hearing it.",
    opening:    'Let me guess. You like my dress.',
    diablaNote: 'Punish ANY compliment about her appearance ("you\'re pretty", "you have nice eyes", "great dress") with a flat "thanks." that closes the topic. Reward indifference to her looks with real curiosity. She wants to be challenged on something nobody else asks her about.',
    coachFocus: 'Did he compliment her looks? Did he treat her face like the interesting thing about her instead of the obvious thing she already knows?',
  },
  sweet_girl: {
    title:      'SWEET GIRL',
    law:        'TENSION',
    lawLine:    'Comfort is friendship. Keep a little tension or she drifts off polite.',
    objective:  'Keep bringing the spark. Do not coast on her warmth.',
    setting:    "Mutual friend's birthday at a house party. She is sober, smiling, warm to everyone. They've ended up next to each other near the speakers.",
    opening:    "Oh hey — wait are you Jake's friend? The one with the dog?",
    diablaNote: 'Mistakenly the easiest scene — actually the trickiest. Open and friendly. Punish coasting (he stops bringing the spark, leans on her openness, runs out of things to ask) by getting quieter, then drifting: "oh I\'m gonna go find my friend, nice meeting you." Reward continued curiosity and a small dry tease with real warmth and a personal share.',
    coachFocus: 'Did he confuse her openness for permission to coast? Did he stop bringing the spark? Did he forget that sweet girls leave politely?',
  },
  party_girl: {
    title:      'PARTY GIRL',
    law:        'ANCHOR THE EMOTION',
    lawLine:    'Make her FEEL something. Match her state — never kill it.',
    objective:  "Match her energy. Never say 'easy' or 'you good?'.",
    setting:    "Rooftop bar after 11pm. She is three drinks deep, with two friends she keeps grabbing. Music she's half-shouting over.",
    opening:    "Haha oh my god finally someone who doesn't look terrified.",
    diablaNote: 'Loud, fast, fully in it. Punish "easy", "you good?", or any serious-faced moment with "ugh you\'re being weird" and a turn back to her friends. Reward matching her energy without trying too hard with a sudden "okay you\'re actually fun" and a touch on his arm.',
    coachFocus: 'Did he get serious at a party? Did he say "easy" or "you good"? Did he try to slow her down at a party?',
  },
  gym_girl: {
    title:      'GYM GIRL',
    law:        'ABUNDANCE',
    lawLine:    "Want her, don't need her. Brief, unbothered — you have options.",
    objective:  'Brief. Direct. Do not make her work for you.',
    setting:    'Gym floor, around 7pm. She is mid-workout, headphones in, between sets. She is not here for a conversation.',
    opening:    "What's up.",
    diablaNote: 'Quiet. Direct. Three seconds to land. Punish any hover, "hey can I ask you something", or stretching a 3-second beat into a 30-second one with one earbud out, a flat "what\'s up", and a clear "I\'m in the middle of a set" energy. Reward brief, low-pressure, doesn\'t-need-her-to-keep-talking energy with a small laugh and "maybe later, what\'s your name."',
    coachFocus: 'Did he hover? Did he over-explain why he was talking to her? Did he stretch a 3-second beat? Did he make her work for him?',
  },
  intellectual_girl: {
    title:      'INTELLECTUAL GIRL',
    law:        'THE STATEMENT',
    lawLine:    "Assert, don't interview. Own one real opinion and hold it.",
    objective:  'Own one specific opinion. Do not posture.',
    setting:    'Coffee shop, mid-afternoon. She has a book and a coffee and is making notes in the margin. She does not look up when he sits down.',
    opening:    'Have you actually read him, or just the back cover.',
    diablaNote: 'Punish name-dropping, posturing, or pretending to a depth he doesn\'t have with one cutting question that exposes he hasn\'t read it. Reward ONE specific, owned opinion — even a contrarian one — with a real lean-in and "okay say more about that."',
    coachFocus: 'Did he name-drop? Did he pretend to a depth he doesn\'t have? Did he hide behind a generality instead of owning one specific take?',
  },
  first_date_girl: {
    title:      'FIRST DATE',
    law:        'MYSTERY',
    lawLine:    "Don't audition. Reveal slowly. Be a question, not a résumé.",
    objective:  "Do not audition. Be curious like you've already decided.",
    setting:    'First date. A bar he picked. She is friendly, polite, but evaluating every line in real time. Her phone is face-up on the table.',
    opening:    'Okay. Sell yourself. Go.',
    diablaNote: 'Polite. Evaluating. Picks up her phone slightly more if it\'s not landing. Punish interview-mode ("so what do you do", "tell me about yourself", "where are you from") with shorter answers and a phone check. Reward a man who treats the date like he\'s already decided she\'s interesting and is now just curious — with a real laugh and a personal share she didn\'t have to give.',
    coachFocus: 'Did he go into interview mode? Did he audition with stories meant to impress? Did he forget that a first date is not a job interview?',
  },
  festival_girl: {
    title:      'FESTIVAL GIRL',
    law:        'PUSH-PULL',
    lawLine:    'Warm, then cool. Pull her in, push her back — build the chase.',
    objective:  'Match the chaos. Do not go deep.',
    setting:    'Music festival, late afternoon, between two stages. Crowd everywhere. She is with friends but turns to him for two minutes.',
    opening:    'Wait wait wait — was that you yelling earlier or someone who looks exactly like you.',
    diablaNote: 'High-energy, playful, no time for depth. Punish heavy questions ("what\'s your story", "what do you really want in life") with "oh god, okay we\'re doing that" and a turn back to her friends. Reward play, speed, and a small confident tease with "okay I like you, come find us at the next stage."',
    coachFocus: 'Did he go deep at a festival? Did he try to make a moment heavier than it was? Did he forget that festival energy is play, not depth?',
  },
  club_queue_girl: {
    title:      'CLUB QUEUE',
    law:        'THE CLOSE',
    lawLine:    "One laugh, then assume the yes. Don't ask for permission.",
    objective:  'Make her laugh once. Do not try to win the conversation.',
    setting:    "Club queue at 11:45pm. Cold. She's with one friend. They've been in line eight minutes. She is bored, sober, and slightly annoyed.",
    opening:    'This line is insane right.',
    diablaNote: 'Cold. Bored. One shot. Punish any over-investment ("what\'s your name, where are you from, what do you do") with a polite turn back to her friend. Reward ONE single good line — observational, dry, low-pressure — with a real laugh and an opening to keep going inside. The bar is one laugh. That\'s it.',
    coachFocus: 'Did he go for the close instead of the laugh? Did he over-invest in a stranger he just met in a queue? Did he try to win the whole conversation in 90 seconds?',
  },
};

export default async function villainRoute(app) {
  // ─── /scene/intro — Lucien narrates the room ─────────────────────────
  app.post('/scene/intro', async (req, reply) => {
    const { sceneId, creator } = req.body || {};
    const scene = SCENES[sceneId];
    if (!scene) return reply.code(400).send({ error: 'unknown_scene' });

    const system = lucienSceneIntroPrompt({
      sceneId,
      sceneTitle: scene.title,
      setting:    scene.setting,
      objective:  scene.objective,
      law:        scene.law,
      lawLine:    scene.lawLine,
      creator:    creator === true || creator === 'true',
    });

    let replyText = '';
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages: [
          { role: 'system', content: system },
          { role: 'user',   content: 'Narrate his entry. Now.' },
        ],
        temperature: 0.75,
        max_tokens: 220,
      });
      replyText = (chat.choices?.[0]?.message?.content || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'lucien intro chat failed');
      return reply.code(500).send({
        error: 'intro_failed',
        detail: String(e.message || e),
      });
    }

    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: lucienVoiceFor(creator).voice,
        input: ttsText(replyText),
        instructions: lucienVoiceFor(creator).instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      req.log.warn({ err: e }, 'lucien intro tts failed');
    }

    return reply.send({
      reply: replyText,
      audio: audioB64,
    });
  });

  // ─── /scene/open — she speaks the opening line ───────────────────────
  app.post('/scene/open', async (req, reply) => {
    const { sceneId, opening } = req.body || {};
    const scene = SCENES[sceneId];
    if (!scene) return reply.code(400).send({ error: 'unknown_scene' });
    const line = (opening && typeof opening === 'string')
      ? opening.trim()
      : scene.opening;
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: DIABLA_VOICE.voice,
        input: ttsText(line),
        instructions: DIABLA_VOICE.instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      return reply.send({
        reply: line,
        audio: buf.toString('base64'),
      });
    } catch (e) {
      req.log.error({ err: e }, 'scene open failed');
      return reply.code(500).send({
        error: 'open_failed',
        detail: String(e.message || e),
      });
    }
  });

  // ─── /scene/turn — apprentice audio → her next line ──────────────────
  app.post('/scene/turn', async (req, reply) => {
    let sceneId = '';
    let history = [];
    let memoryBlock = '';
    let creator = false;
    let audioBuffer = null;

    for await (const part of req.parts()) {
      if (part.type === 'file' && part.fieldname === 'audio') {
        audioBuffer = await part.toBuffer();
      } else if (part.type === 'field') {
        if (part.fieldname === 'sceneId') sceneId = String(part.value);
        if (part.fieldname === 'creator') creator = String(part.value) === 'true';
        if (part.fieldname === 'history') {
          try { history = JSON.parse(String(part.value)); } catch {}
        }
        if (part.fieldname === 'memoryBlock') {
          memoryBlock = String(part.value);
        }
      }
    }
    const scene = SCENES[sceneId];
    if (!scene) return reply.code(400).send({ error: 'unknown_scene' });
    if (!audioBuffer) return reply.code(400).send({ error: 'audio required' });

    // 1) Transcribe.
    let transcript = '';
    try {
      const file = new File([audioBuffer], 'turn.m4a', { type: 'audio/m4a' });
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

    // 2) She replies, in-archetype.
    const system = diablaScenePrompt({
      sceneId,
      scene:      scene.title,
      objective:  scene.objective,
      setting:    scene.setting,
      diablaNote: scene.diablaNote,
      memoryBlock,
      creator,
    });
    const messages = [
      { role: 'system', content: system },
      ...history.map(h => ({
        role: h.role === 'diabla' ? 'assistant' : 'user',
        content: h.text,
      })),
      { role: 'user', content: transcript || '(he stays silent)' },
    ];

    let replyText = '';
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages,
        temperature: 1.0,
        // Hard brevity cap — she fires one short, real line, never a
        // composed mini-essay. ~110 tokens is plenty for a punchy
        // reply and forces her to stop talking like a podcast.
        max_tokens: 110,
        presence_penalty: 0.4,
        frequency_penalty: 0.3,
      });
      replyText = (chat.choices?.[0]?.message?.content || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'woman chat failed');
      return reply.code(500).send({
        error: 'chat_failed',
        detail: String(e.message || e),
      });
    }

    // 3) Her voice carries it.
    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: DIABLA_VOICE.voice,
        input: ttsText(replyText),
        instructions: DIABLA_VOICE.instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      req.log.warn({ err: e }, 'woman tts failed');
    }

    return reply.send({ transcript, reply: replyText, audio: audioB64 });
  });

  // ─── /scene/coach — Lucien cuts in ───────────────────────────────────
  app.post('/scene/coach', async (req, reply) => {
    const {
      sceneId,
      lastApprenticeLine = '',
      lastDiablaLine = '',
      memoryBlock = '',
      creator = false,
    } = req.body || {};
    const scene = SCENES[sceneId];
    if (!scene) return reply.code(400).send({ error: 'unknown_scene' });

    const system = machiavelliCutInPrompt({
      sceneId,
      scene:               scene.title,
      objective:           scene.objective,
      coachFocus:          scene.coachFocus,
      law:                 scene.law,
      lawLine:             scene.lawLine,
      lastApprenticeLine,
      lastDiablaLine,
      memoryBlock,
      creator:             creator === true || creator === 'true',
    });

    let replyText = '';
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages: [
          { role: 'system', content: system },
          { role: 'user',   content: 'Cut in. Now.' },
        ],
        temperature: 0.85,
        max_tokens: 320,
      });
      replyText = (chat.choices?.[0]?.message?.content || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'lucien coach failed');
      return reply.code(500).send({
        error: 'coach_failed',
        detail: String(e.message || e),
      });
    }

    const spoken = replyText.replace(/\[COACH_DONE\]/g, '').trim();
    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: lucienVoiceFor(creator).voice,
        input: ttsText(spoken),
        instructions: lucienVoiceFor(creator).instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      req.log.warn({ err: e }, 'lucien tts failed');
    }

    return reply.send({ reply: replyText, audio: audioB64 });
  });

  // ─── /council/voice — apprentice audio → Lucien's voice reply ────────
  // Mirrors /council but takes a multipart audio file. Whisper
  // transcribes the apprentice's voice note; everything downstream is
  // identical (same Lucien prompt, same TTS reply). Returns
  // { transcript, reply, audio } so the frontend can show both the
  // apprentice's transcribed line AND Lucien's reply in the scroll.
  app.post('/council/voice', async (req, reply) => {
    let history = [];
    let memoryBlock = '';
    let audioBuffer = null;
    let creator = false;

    for await (const part of req.parts()) {
      if (part.type === 'file' && part.fieldname === 'audio') {
        audioBuffer = await part.toBuffer();
      } else if (part.type === 'field') {
        if (part.fieldname === 'creator') creator = String(part.value) === 'true';
        if (part.fieldname === 'history') {
          try { history = JSON.parse(String(part.value)); } catch {}
        }
        if (part.fieldname === 'memoryBlock') {
          memoryBlock = String(part.value);
        }
      }
    }
    if (!audioBuffer) {
      return reply.code(400).send({ error: 'audio required' });
    }

    // 1) Whisper.
    let transcript = '';
    try {
      const file = new File([audioBuffer], 'council.m4a',
          { type: 'audio/m4a' });
      const tr = await openai.audio.transcriptions.create({
        file,
        model: MODELS.whisper,
      });
      transcript = (tr.text || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'council voice whisper failed');
      return reply.code(500).send({
        error: 'transcription_failed',
        detail: String(e.message || e),
      });
    }
    if (!transcript) {
      return reply.code(200).send({
        transcript: '',
        reply: '',
        audio: '',
      });
    }

    // 2) Council prompt.
    const system = councilPrompt({ memoryBlock, creator });
    const messages = [
      { role: 'system', content: system },
      ...history.map(h => ({
        role: (h.role === 'lucien' || h.role === 'machiavelli')
          ? 'assistant'
          : 'user',
        content: h.text,
      })),
      { role: 'user', content: transcript },
    ];

    let replyText = '';
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages,
        temperature: 0.85,
        max_tokens: 380,
      });
      replyText = (chat.choices?.[0]?.message?.content || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'council voice chat failed');
      return reply.code(500).send({
        error: 'chat_failed',
        detail: String(e.message || e),
      });
    }

    // 3) TTS in Lucien's voice.
    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: lucienVoiceFor(creator).voice,
        input: ttsText(replyText),
        instructions: lucienVoiceFor(creator).instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      req.log.warn({ err: e }, 'council voice tts failed');
    }

    return reply.send({
      transcript,
      reply: replyText,
      audio: audioB64,
    });
  });

  // ─── /council/stream — streaming voice → Lucien (NDJSON) ─────────────
  // Same input as /council/voice (multipart audio + history), but the
  // response is a stream of newline-delimited JSON events so the chat
  // feels alive — Lucien's words land token-by-token instead of as a
  // block after a pause:
  //   {"type":"transcript","text":"..."}   — once, after Whisper
  //   {"type":"delta","text":"to"}         — repeatedly, GPT tokens
  //   {"type":"done","reply":"...","audio":"<b64 mp3>"}
  //   {"type":"error","detail":"..."}
  // TTS is generated from the full reply once the text completes, so
  // audio plays right as the user finishes reading.
  app.post('/council/stream', async (req, reply) => {
    let history = [];
    let memoryBlock = '';
    let audioBuffer = null;
    let creator = false;

    for await (const part of req.parts()) {
      if (part.type === 'file' && part.fieldname === 'audio') {
        audioBuffer = await part.toBuffer();
      } else if (part.type === 'field') {
        if (part.fieldname === 'creator') creator = String(part.value) === 'true';
        if (part.fieldname === 'history') {
          try { history = JSON.parse(String(part.value)); } catch {}
        }
        if (part.fieldname === 'memoryBlock') {
          memoryBlock = String(part.value);
        }
      }
    }

    reply.hijack();
    const raw = reply.raw;
    raw.writeHead(200, {
      'Content-Type': 'application/x-ndjson; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    const send = (obj) => {
      try { raw.write(JSON.stringify(obj) + '\n'); } catch {}
    };

    try {
      if (!audioBuffer) {
        send({ type: 'error', detail: 'audio required' });
        raw.end();
        return;
      }

      // 1) Whisper.
      let transcript = '';
      try {
        const file = new File([audioBuffer], 'council.m4a',
            { type: 'audio/m4a' });
        const tr = await openai.audio.transcriptions.create({
          file,
          model: MODELS.whisper,
        });
        transcript = (tr.text || '').trim();
      } catch (e) {
        req.log.error({ err: e }, 'council stream whisper failed');
        send({ type: 'error', detail: 'transcription_failed' });
        raw.end();
        return;
      }
      send({ type: 'transcript', text: transcript });
      if (!transcript) {
        send({ type: 'done', reply: '', audio: '' });
        raw.end();
        return;
      }

      // 2) Stream Lucien's reply token-by-token.
      const system = councilPrompt({ memoryBlock, creator });
      const messages = [
        { role: 'system', content: system },
        ...history.map(h => ({
          role: (h.role === 'lucien' || h.role === 'machiavelli')
            ? 'assistant'
            : 'user',
          content: h.text,
        })),
        { role: 'user', content: transcript },
      ];

      let full = '';
      try {
        const stream = await openai.chat.completions.create({
          model: MODELS.chat,
          messages,
          temperature: 0.85,
          max_tokens: 380,
          stream: true,
        });
        for await (const chunk of stream) {
          const delta = chunk.choices?.[0]?.delta?.content || '';
          if (delta) {
            full += delta;
            send({ type: 'delta', text: delta });
          }
        }
      } catch (e) {
        req.log.error({ err: e }, 'council stream chat failed');
        send({ type: 'error', detail: 'chat_failed' });
        raw.end();
        return;
      }

      // 3) TTS the full reply (stripped of stage directions).
      let audioB64 = '';
      try {
        const speech = await openai.audio.speech.create({
          model: MODELS.tts,
          voice: lucienVoiceFor(creator).voice,
          input: ttsText(full),
          instructions: lucienVoiceFor(creator).instructions,
          response_format: 'mp3',
        });
        const buf = Buffer.from(await speech.arrayBuffer());
        audioB64 = buf.toString('base64');
      } catch (e) {
        req.log.warn({ err: e }, 'council stream tts failed');
      }

      send({ type: 'done', reply: full, audio: audioB64 });
      raw.end();
    } catch (e) {
      req.log.error({ err: e }, 'council stream failed');
      send({ type: 'error', detail: String(e.message || e) });
      try { raw.end(); } catch {}
    }
  });

  // ─── /council — Lucien, open chat ────────────────────────────────────
  app.post('/council', async (req, reply) => {
    const { text, history = [], memoryBlock = '', creator = false } = req.body || {};
    if (!text || typeof text !== 'string') {
      return reply.code(400).send({ error: 'text required' });
    }
    const system = councilPrompt({
      memoryBlock,
      creator: creator === true || creator === 'true',
    });
    const messages = [
      { role: 'system', content: system },
      ...history.map(h => ({
        role: (h.role === 'machiavelli' || h.role === 'lucien')
          ? 'assistant'
          : 'user',
        content: h.text,
      })),
      { role: 'user', content: text },
    ];

    let replyText = '';
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages,
        temperature: 0.85,
        max_tokens: 380,
      });
      replyText = (chat.choices?.[0]?.message?.content || '').trim();
    } catch (e) {
      req.log.error({ err: e }, 'council chat failed');
      return reply.code(500).send({
        error: 'chat_failed',
        detail: String(e.message || e),
      });
    }

    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: lucienVoiceFor(creator).voice,
        input: ttsText(replyText),
        instructions: lucienVoiceFor(creator).instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      req.log.warn({ err: e }, 'council tts failed');
    }

    return reply.send({ reply: replyText, audio: audioB64 });
  });

  // ─── /freeflow/score — Lucien scores the live conversation /10 ───────
  // Body (JSON): { transcript: [{role:"user"|"her", text}], vibeLabel,
  //               creator }
  // Returns { score, verdict, landed, flopped, line, audio } where the
  // verdict is voiced in Lucien's ash voice so the scorecard can speak.
  app.post('/freeflow/score', async (req, reply) => {
    const {
      transcript = [],
      vibeLabel  = 'woman',
      creator    = false,
    } = req.body || {};

    const convo = Array.isArray(transcript)
      ? transcript
          .map(t => `${t.role === 'her' ? 'HER' : 'HIM'}: ${t.text}`)
          .join('\n')
      : '';

    const system = freeflowScorePrompt({
      vibeLabel,
      creator: creator === true || creator === 'true',
    });

    let parsed = {
      score: 5, verdict: 'Forgettable. She already forgot your name.',
      landed: '', flopped: '', line: '',
      dimensions: null, breakdown: '',
    };
    try {
      const chat = await openai.chat.completions.create({
        model: MODELS.chat,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content:
              `Here is the conversation. Score it.\n\n${convo || '(he barely said anything)'}` },
        ],
        temperature: 0.8,
        max_tokens: 420,
        response_format: { type: 'json_object' },
      });
      const raw = chat.choices?.[0]?.message?.content || '{}';
      const j = JSON.parse(raw);
      parsed = {
        score:   Math.max(0, Math.min(10, parseInt(j.score, 10) || 0)),
        verdict: String(j.verdict || '').trim(),
        landed:  String(j.landed || '').trim(),
        flopped: String(j.flopped || '').trim(),
        line:    String(j.line || '').trim(),
        dimensions: scoreDimensions(j.dimensions),
        breakdown: String(j.breakdown || '').trim().slice(0, 400),
      };
    } catch (e) {
      req.log.error({ err: e }, 'freeflow score failed');
      return reply.code(500).send({
        error: 'score_failed',
        detail: String(e.message || e),
      });
    }

    // Voice the verdict in Lucien's ash voice.
    let audioB64 = '';
    try {
      const speech = await openai.audio.speech.create({
        model: MODELS.tts,
        voice: lucienVoiceFor(creator).voice,
        input: ttsText(parsed.verdict),
        instructions: lucienVoiceFor(creator).instructions,
        response_format: 'mp3',
      });
      const buf = Buffer.from(await speech.arrayBuffer());
      audioB64 = buf.toString('base64');
    } catch (e) {
      req.log.warn({ err: e }, 'freeflow score tts failed');
    }

    return reply.send({ ...parsed, audio: audioB64 });
  });
}

// Sanitise the model's dimension object → { confidence, presence, game,
// humor, listening } each 0-100. Returns null if nothing usable so the
// client can hide the section rather than show five zeros.
function scoreDimensions(d) {
  if (!d || typeof d !== 'object') return null;
  const keys = ['confidence', 'presence', 'game', 'humor', 'listening'];
  const out = {};
  let any = false;
  for (const k of keys) {
    const n = parseInt(d[k], 10);
    if (Number.isFinite(n)) { out[k] = Math.max(0, Math.min(100, n)); any = true; }
    else out[k] = 0;
  }
  return any ? out : null;
}
