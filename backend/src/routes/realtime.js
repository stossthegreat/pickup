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
// (~3x cheaper on audio I/O at the cost of weaker character
// maintenance and shallower instruction-following on big prompts).
// It is the model for EVERYTHING except creator mode — every woman,
// every Lucien step-in, every other mode. See pickRealtimeModel.
const OPENAI_REALTIME_MINI_MODEL = 'gpt-realtime-mini';

/// Pick the realtime model. CREATOR IS THE ONLY PATH TO THE FULL MODEL.
///
/// THE RULE, AND IT IS ABSOLUTE: creator mode gets gpt-realtime.
/// Everything else — every woman, every Lucien step-in, every mode —
/// gets mini. No exceptions, no "low volume" carve-outs.
///
/// WHAT THIS FIXES. Lucien used to return the full model for EVERYONE,
/// on the reasoning that coach cadence matters and volume is low. Both
/// halves were wrong. Lucien is one tap away inside every single voice
/// call and he is sold as a headline feature in onboarding — "Freeze?
/// Lucien is one tap away" — so his volume is not low, it scales with
/// every call the platform serves. That carve-out was quietly the most
/// expensive line in the product.
///
/// Creator is genuinely different: it is off by default, password-gated
/// in Settings, hand-granted, and its Vixen personas are 5k-token
/// prompts that mini does hold worse. That is the one place the bigger
/// model earns its keep, and it is the one place it runs.
///
/// If mini ever reads a stage-direction token ("[laughter]") aloud,
/// strip those tokens from the prompt — do NOT reach for the full model.
/// The cost delta is too big to give back.
function pickRealtimeModel({ creator }) {
  // `=== true`, not a truthy check. The only caller passes an already
  // coerced boolean, but a truthy test means any FUTURE caller that
  // forwards a raw body value hands the full model to anything
  // non-empty — `creator: "no"` and `creator: "0"` both read as yes.
  // The rule is absolute, so the gate is exact: one value opens it.
  return creator === true ? OPENAI_REALTIME_MODEL : OPENAI_REALTIME_MINI_MODEL;
}

// ── CREATOR MINT THROTTLE ────────────────────────────────────────────
//
// `creator` arrives in the request body, and this backend has no user
// auth — so the app's password gate on creator mode is a gate on the
// CLIENT, not on the server. Anyone who pulls the base URL out of the
// binary can post `creator: true` and mint full-model sessions on our
// account. That is the one remaining path by which the expensive model
// can be reached outside creator mode, and it cannot be fully closed
// without real accounts (any secret shipped in the app is extractable).
//
// What CAN be done is cap the blast radius. Creator mode is off by
// default, hand-granted, and used by a handful of people who each start
// a session at a time — 60 mints/hour per install is far past any real
// use and turns "unlimited full-model minting" into a trickle. Normal
// mini traffic is untouched.
//
// Bounded and swept on a fixed cadence: an unbounded Map keyed by
// caller-chosen ids would itself be the attack.
const CREATOR_MAX_PER_HOUR = parseInt(process.env.CREATOR_MINT_MAX || '60', 10);
const CREATOR_MAP_CAP = 10_000;
let creatorHits = new Map();
const creatorSweep = setInterval(() => { creatorHits = new Map(); }, 3_600_000);
creatorSweep.unref();

function creatorMintAllowed(req) {
  const id = req.headers['x-client-id'];
  const key = (typeof id === 'string' && /^[a-f0-9]{16,64}$/i.test(id))
    ? `c:${id}`
    : `i:${req.ip}`;
  const n = (creatorHits.get(key) || 0) + 1;
  if (n > 1 || creatorHits.size < CREATOR_MAP_CAP) creatorHits.set(key, n);
  return n <= CREATOR_MAX_PER_HOUR;
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
// ─── LANGUAGE ────────────────────────────────────────────────────────
//
// THE FEATURE THAT DID NOTHING. Settings has a language picker, the app
// has always sent the chosen code, and voice ignored it twice over:
// Whisper was pinned to `language: 'en'`, so a Spanish speaker's mic was
// transcribed AS English; and the prompt carried a LANGUAGE LOCK telling
// her to reply in English no matter what — literally scripting her to
// answer a Spanish speaker with "english only here, sorry".
//
// Both were fixes for a real bug: one misheard syllable used to flip her
// into another language mid-call. But the cure removed the feature. The
// answer is not to unlock the language — it is to lock it to HIS
// language instead of to English. The anti-drift protection survives
// intact; it just points at the right target.
//
// Whisper's own codes. Anything unknown falls back to English, which is
// today's behaviour byte for byte.
const LANGUAGE_NAMES = {
  en: 'English',    es: 'Spanish',    pt: 'Portuguese', fr: 'French',
  de: 'German',     it: 'Italian',    nl: 'Dutch',      tr: 'Turkish',
  pl: 'Polish',     ru: 'Russian',    ar: 'Arabic',     hi: 'Hindi',
  id: 'Indonesian', ja: 'Japanese',   ko: 'Korean',
};
function normaliseLanguage(v) {
  const raw = (typeof v === 'string' ? v.trim().toLowerCase() : '');
  // Accept 'pt-BR' / 'en_US' style tags — the primary subtag is what
  // both Whisper and the prompt need.
  const primary = raw.split(/[-_]/)[0];
  return LANGUAGE_NAMES[primary] ? primary : 'en';
}

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
      language,       // BCP-47 tag from the app's Settings language picker
    } = req.body || {};
    const lang = normaliseLanguage(language);
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
        lastHer, lastYou, vibeLabel, language: lang,
        creator: creator === true || creator === 'true',
      });
    } else if (mode === 'freeflow') {
      // Free Flow women default to STRANGERS — pickup scenarios. But the
      // client now sends a PER-GIRL relationship block (not the old
      // rizz-topic UserMemory that made everyone "remember" Arena/Diabla):
      // if he's actually built something with this woman over text or a
      // past call, `memoryBlock` tells her to pick up from that stage
      // instead of acting like a first meeting. Empty → she stays a fresh
      // pickup, exactly as before.
      instructions = buildFreeFlowInstructions({
        vibeLabel,
        scenarioSetting,
        memoryBlock,
        creator: creator === true || creator === 'true',
        userProfile,
        language: lang,
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

    // Model split: full gpt-realtime for creator mode ONLY. Everything
    // else — including Lucien — runs mini. See pickRealtimeModel.
    let creatorFlag = creator === true || creator === 'true';
    if (creatorFlag && !creatorMintAllowed(req)) {
      // Past the cap we do NOT fail the call — we serve the session on
      // mini. A real creator user gets a working session with a weaker
      // model; a forger gets nothing they couldn't already have. The
      // expensive outcome is the only one denied.
      req.log.warn({ ip: req.ip }, 'creator mint throttled — serving mini');
      creatorFlag = false;
    }
    const realtimeModel = pickRealtimeModel({ creator: creatorFlag });

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
            // PINNED TO HIS LANGUAGE, NOT TO ENGLISH. Pinning matters —
            // leaving Whisper to auto-detect is what let one ambiguous
            // syllable flip the transcript mid-call and drag her reply
            // with it. Pinning it to the WRONG language is what made the
            // picker useless: a Spanish speaker was transcribed as
            // English, so she answered gibberish. It follows the picker
            // now, and 'en' is the default, so nothing changes for the
            // overwhelming majority.
            transcription: { model: 'whisper-1', language: lang },
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
      language: lang,
      instructionsLen: instructions.length,
    });

    try {
      // 15s abort — minting a client_secret is a sub-second call when
      // OpenAI is healthy. Without this, an OpenAI stall holds our
      // request slot for the platform default (minutes) and stalled
      // session-mints pile up under load.
      const ac = new AbortController();
      const killer = setTimeout(() => ac.abort(), 15_000);
      let resp;
      try {
        resp = await fetch(openAIUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(requestBody),
          signal: ac.signal,
        });
      } finally {
        clearTimeout(killer);
      }

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
        language,       // BCP-47 tag from the app's Settings language picker
      } = req.body || {};
      const text = (userTranscript || '').toString();
      const lang = normaliseLanguage(language);

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
        vibeLabel, scenarioSetting, creator: false, language: lang,
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
        language: lang,
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
