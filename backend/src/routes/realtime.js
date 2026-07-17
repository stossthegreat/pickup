// POST /v1/realtime/session
//
// Mints an ephemeral OpenAI Realtime session. The frontend uses the
// returned `client_secret.value` to open a WebSocket directly to
// wss://api.openai.com/v1/realtime — our backend never touches the
// audio bytes themselves.
//
// Body (application/json):
//   {
//     "teacherId": "machiavelli" | "diabla",
//     "mode":      "lesson" | "practice",
//     "topic":     "rhetoric" | "rizz",
//     // When mode === 'lesson':
//     "lessonName":  "Conviction",
//     "targetLines": [
//       { "line": "I am the right person for this.",
//         "cue":  "drop the pitch on 'right'" },
//       ...
//     ]
//   }
//
// Returns the OpenAI session object verbatim (client_secret + config).

import {
  buildLessonInstructions,
  buildPracticeInstructions,
  buildRoleplayInstructions,
  buildFreeFlowInstructions,
  buildSeleneInstructions,
  teacherFor,
} from '../personas.js';
import { buildLucienRealtimeInstructions } from '../villain_personas.js';
import {
  initialStateFor,
  applyTurn,
  formatStateBlock,
  formatStateNote,
} from '../voice_state.js';

// OpenAI's Realtime API went GA in 2025 — the preview model
// (gpt-4o-realtime-preview-2024-12-17) was deprecated, requests now
// return "Application not found". `gpt-realtime` is the GA model name.
// If OpenAI renames again, change here only.
const OPENAI_REALTIME_MODEL = 'gpt-realtime';
// `gpt-realtime-mini` is the smaller/cheaper sibling of the GA model
// (~3× cheaper on audio I/O at the cost of weaker character
// maintenance and shallower instruction-following on big prompts).
// We use it for normal-mode women in Free Flow / The Arena, where
// the prompt is ~1.2k tokens and the character is a simple
// archetype. Creator-mode Vixen (5k-token persona + bipolar trigger
// scripts + screech cues) and Lucien step-in (king-of-seduction
// performance cadence) BOTH stay on the full model — that's where
// the bigger model earns its keep.
const OPENAI_REALTIME_MINI_MODEL = 'gpt-realtime-mini';

/// Pick the right realtime model for the session.
///
/// COST SPLIT (the lever that makes the voice allowance affordable):
///   • NORMAL-MODE women  → gpt-realtime-mini (~3× cheaper audio I/O).
///     With the directive per-character prompts (identity + temperature
///     + reward/punish + "never quote the tone samples verbatim") the
///     quality gap is negligible for tight push-to-talk turns — this is
///     the same setup that held up in production before.
///   • CREATOR-MODE women → full gpt-realtime. Creator is a premium
///     unlock (the unhinged Vixen personas), low volume, so the bigger
///     model earns its keep there.
///   • LUCIEN step-in     → full gpt-realtime. Coach cadence matters and
///     volume is low.
///
/// Note: if mini ever reads a stage-direction token (e.g. "[laughter]")
/// out loud, strip those tokens from the normal-mode VOICE prompt rather
/// than reverting the model — the cost delta is too big to give back.
function pickRealtimeModel({ mode, creator, isLucien }) {
  if (isLucien) return OPENAI_REALTIME_MODEL;   // coach → full
  if (creator)  return OPENAI_REALTIME_MODEL;   // creator mode → full
  return OPENAI_REALTIME_MINI_MODEL;            // normal-mode women → mini
}

// Free Flow women are ALWAYS female. Older / merged app builds send some
// personas with MALE OpenAI voices (e.g. TESTING YOU=ballad, ICE THEN
// FIRE=verse), which made the woman sound like a man. We force a female
// voice on the backend so it's fixed for EVERY app version without an app
// rebuild — male/unknown voices are remapped to a female one. (Lucien and
// the male teachers are untouched: this guard only runs for freeflow.)
const FEMALE_REALTIME_VOICES = new Set([
  'sage', 'coral', 'shimmer', 'marin', 'alloy',
]);
const MALE_TO_FEMALE_VOICE = {
  ballad: 'marin',    // TESTING YOU
  verse:  'alloy',    // ICE THEN FIRE
  ash:    'sage',
  echo:   'coral',
  cedar:  'shimmer',
};
function forceFemaleVoice(v) {
  const key = (typeof v === 'string' ? v.trim().toLowerCase() : '');
  if (FEMALE_REALTIME_VOICES.has(key)) return key;
  return MALE_TO_FEMALE_VOICE[key] || 'sage';
}

export default async function realtimeRoute(app) {
  app.post('/session', async (req, reply) => {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return reply.code(500).send({ error: 'OPENAI_API_KEY missing' });
    }

    const {
      teacherId  = 'machiavelli',
      mode       = 'lesson',
      topic      = teacherId === 'diabla' ? 'rizz' : 'rhetoric',
      lessonName = 'Conviction',
      targetLines = [],
      scenarioName,
      scenarioSetting,
      vibeLabel,      // free-flow: the woman "type" label
      voice,          // free-flow: per-type OpenAI realtime voice
      creator,        // free-flow: Creator UNCHAINED mode
      lastHer,        // lucien step-in: the woman's last line
      lastYou,        // lucien step-in: the apprentice's last line
      memoryBlock,    // built client-side by UserMemory.buildSystemPromptBlock
      userProfile,    // free-flow: { name, ageGroup } from onboarding
      drill,          // selene: which named eye-contact / aura move tonight
      metricsContext, // selene: optional initial MediaPipe snapshot text
    } = req.body || {};
    const isFreeflow = mode === 'freeflow';
    const isLucien   = mode === 'lucien';
    const isSelene   = mode === 'selene';

    // Roleplay + free-flow use the female persona teacher; Lucien uses
    // his own (ash voice); Selene is her own teacher (marin voice).
    const effectiveTeacher =
      (mode === 'roleplay' || mode === 'freeflow') ? 'roleplay'
      : isLucien ? 'lucien'
      : isSelene ? 'selene'
      : teacherId;
    const teacher = teacherFor(effectiveTeacher);

    let instructions;
    if (isLucien) {
      instructions = buildLucienRealtimeInstructions({
        lastHer, lastYou, vibeLabel,
        creator: creator === true || creator === 'true',
      });
    } else if (mode === 'freeflow') {
      // Free Flow women are STRANGERS — pickup scenarios with no prior
      // history with the user. We deliberately drop `memoryBlock` here:
      // it's UserMemory filtered to topic='rizz' (Arena scenes + Diabla
      // lessons). Pasting that into Sofia / Lola / Chaos Girl made
      // every persona "remember" past conversations she was never in.
      instructions = buildFreeFlowInstructions({
        vibeLabel,
        scenarioSetting,
        creator: creator === true || creator === 'true',
        userProfile,
      });
    } else if (isSelene) {
      instructions = buildSeleneInstructions({
        drill, metricsContext, memoryBlock,
      });
    } else if (mode === 'roleplay') {
      instructions = buildRoleplayInstructions({
        scenarioName:    scenarioName    || 'The Bar',
        scenarioSetting: scenarioSetting ||
          'A loud bar at 11pm on a Friday. She just sat down two stools ' +
          'away. Half a glass of wine. Glanced over. Looked away. Glanced ' +
          'again.',
        memoryBlock,
      });
    } else if (mode === 'practice') {
      instructions = buildPracticeInstructions({
        teacherId, topic, memoryBlock,
      });
    } else {
      instructions = buildLessonInstructions({
        teacherId, topic, lessonName, targetLines, memoryBlock,
      });
    }

    // Model split: full gpt-realtime for Lucien + creator-mode women,
    // gpt-realtime-mini for everyone else (saves ~3× on audio I/O
    // without losing character quality on simple archetypes).
    const creatorFlag = creator === true || creator === 'true';
    const realtimeModel = pickRealtimeModel({
      mode, creator: creatorFlag, isLucien,
    });

    const openAIUrl = 'https://api.openai.com/v1/realtime/client_secrets';
    const requestBody = {
      session: {
        type: 'realtime',
        model: realtimeModel,
        instructions,
        output_modalities: ['audio'],
        audio: {
          input: {
            format: { type: 'audio/pcm', rate: 24000 },
            // Pin Whisper to English so the user's mic input is
            // always transcribed as English text. Without this, a
            // single ambiguous syllable can flip whisper into
            // Spanish / French / Portuguese and drag the model's
            // response language with it. Output language is also
            // locked via the system prompt's LANGUAGE LOCK rule.
            transcription: { model: 'whisper-1', language: 'en' },
            // Free-flow is PUSH-TO-TALK: the client holds the button,
            // streams audio, then commits + requests a response. Server
            // VAD is disabled so the model never auto-replies or fires
            // spurious speech-start/stop turns. Other modes keep VAD.
            turn_detection: (isFreeflow || isLucien) ? null : {
              type: 'server_vad',
              threshold: 0.5,
              prefix_padding_ms: 300,
              silence_duration_ms: 500,
            },
          },
          output: {
            format: { type: 'audio/pcm', rate: 24000 },
            // Free-flow picks a distinct voice per woman type; Selene
            // uses her own female teacher voice ('coral'). Both are
            // ALWAYS women, so force a female voice — remap any
            // male/unknown voice an old/stale client sends so a male
            // voice can never reach the model on these modes. Lucien
            // and the male teachers fall through untouched.
            voice: (isFreeflow || isSelene)
              ? forceFemaleVoice(voice || teacher.voiceCfg.voice)
              : ((typeof voice === 'string' && voice.trim().length)
                  ? voice
                  : teacher.voiceCfg.voice),
          },
        },
      },
    };

    req.log.info({
      msg:    'realtime client_secret create — POST →',
      url:    openAIUrl,
      mode,
      teacherId: effectiveTeacher,
      voice:  teacher.voiceCfg.voice,
      model:  realtimeModel,
      modelTier: realtimeModel === OPENAI_REALTIME_MODEL ? 'full' : 'mini',
      creator: creatorFlag,
      instructionsLen: instructions.length,
    });

    try {
      const resp = await fetch(openAIUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      });

      // Always read the body as text first so we can ship the verbatim
      // response back to the client when something fails — even if it's
      // not JSON-decodable (e.g. an HTML 404 page).
      const rawText = await resp.text();
      let data;
      try { data = JSON.parse(rawText); } catch { data = rawText; }

      req.log.info({
        msg:    'realtime client_secret create — ← response',
        status: resp.status,
        statusText: resp.statusText,
        bodyKind:   typeof data,
        bodyKeys:   typeof data === 'object' && data ? Object.keys(data) : null,
      });

      if (!resp.ok) {
        req.log.error({
          msg:    'realtime client_secret create FAILED',
          status: resp.status,
          response: data,
          requestBody,
        });
        return reply.code(resp.status || 500).send({
          error: 'session_failed',
          openAIStatus: resp.status,
          openAIUrl,
          openAIResponse: data,
          requestSent: {
            ...requestBody,
            session: {
              ...requestBody.session,
              instructions: `(${instructions.length} chars elided)`,
            },
          },
        });
      }
      // Normalise the response so the frontend's existing extractor
      // (sessionConfig['client_secret']['value']) keeps working.
      // GA shape:  { value, expires_at, ... }
      // Old shape: { client_secret: { value, expires_at }, model, id, ... }
      const ephemeralValue =
        (data && data.value) ||
        (data && data.client_secret && data.client_secret.value);
      const expiresAt =
        (data && data.expires_at) ||
        (data && data.client_secret && data.client_secret.expires_at);
      if (!ephemeralValue) {
        req.log.error({
          msg: 'realtime client_secret create returned 200 but no value',
          response: data,
        });
        return reply.code(500).send({
          error: 'session_failed_no_value',
          openAIResponse: data,
        });
      }
      const normalised = {
        ...(typeof data === 'object' ? data : {}),
        model: (data && data.model) || realtimeModel,
        client_secret: { value: ephemeralValue, expires_at: expiresAt },
      };
      return reply.send(normalised);
    } catch (e) {
      req.log.error({ err: e }, 'realtime session exception');
      return reply.code(500).send({
        error: 'session_failed',
        detail: String(e.message || e),
      });
    }
  });

  // ─── POST /v1/realtime/turn ──────────────────────────────────
  //
  // Per-turn state update for normal-mode women in Free Flow.
  // The client maintains the conversation state object locally,
  // POSTs it in along with the user's latest transcribed message,
  // and gets back an updated state + a formatted state block to
  // inject into the system instructions via session.update.
  //
  // The backend is STATELESS — no per-session memory. Client owns
  // the state, server runs the heuristic.
  //
  // Body:
  //   {
  //     vibeLabel: string,    // 'INTO YOU' | 'COLD' | 'CHAOS' |
  //                           // 'TESTING YOU' | 'ICE THEN FIRE'
  //     userTranscript: string,
  //     currentState: object | null  // null = first turn, init fresh
  //   }
  // Response:
  //   {
  //     state: object,        // updated state to store on the client
  //     stateBlock: string,   // text block to inject in instructions
  //   }
  app.post('/turn', async (req, reply) => {
    try {
      const {
        vibeLabel,
        userTranscript,
        currentState,
        scenarioSetting,
      } = req.body || {};
      const text = (userTranscript || '').toString();

      // Initialize from starting vector on first call.
      const baseState = currentState
        ? currentState
        : initialStateFor(vibeLabel);

      const nextState  = applyTurn(baseState, text);
      const stateBlock = formatStateBlock(nextState);
      const stateNote  = formatStateNote(nextState);

      // `stateNote` is the cheap path: a ~50-token bracketed cue the
      // client injects via conversation.item.create. The character
      // prompt (set once at connect) stays cached for the whole
      // session, so per-turn input bills drop ~85%.
      //
      // `instructions` is kept for back-compat with older app builds
      // that still call session.update with the full prompt — they'll
      // keep working at the old (expensive) cost until the user
      // updates the app. New builds use stateNote and ignore this.
      const character = buildFreeFlowInstructions({
        vibeLabel, scenarioSetting, creator: false,
      });
      const instructions = `${character}\n\n${stateBlock}`;

      req.log.info({
        msg: 'realtime turn — state update',
        vibe: nextState.vibe,
        turn: nextState.turnCount,
        category: nextState.lastCategory,
        attraction: nextState.attraction,
        momentum: nextState.momentum,
        sharpStreak: nextState.sharpStreak,
        weakStreak: nextState.weakStreak,
        inStreakTesting: nextState.inStreakTesting,
        hasFlipped: nextState.hasFlipped,
        stateNoteLen: stateNote.length,
        instructionsLen: instructions.length,
      });

      return reply.send({
        state: nextState,
        stateBlock,
        stateNote,
        instructions,
      });
    } catch (e) {
      req.log.error({ err: e }, 'realtime /turn exception');
      return reply.code(500).send({
        error: 'turn_failed',
        detail: String(e.message || e),
      });
    }
  });
}
