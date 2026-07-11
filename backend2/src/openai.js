// Singleton OpenAI client. Key comes from Railway env var OPENAI_API_KEY.

import OpenAI from 'openai';

if (!process.env.OPENAI_API_KEY) {
  console.warn(
    '[auralay] WARNING: OPENAI_API_KEY not set — the /v1/diablo/turn and ' +
    '/v1/rhetoric/score routes will fail until you set it in Railway.'
  );
}

export const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Models — pinned so behaviour doesn't drift when OpenAI updates defaults.
//
// chat:   gpt-4o (full, not mini). gpt-4o-mini was too tame for the
//         persona — it acknowledged the rules but did not execute the
//         laughs / lean-ins / quote-the-word moves. gpt-4o follows
//         few-shot examples reliably and stays in character.
// judge:  gpt-4o-mini is fine (returns JSON, no character lift).
// whisper / tts: unchanged.
export const MODELS = {
  chat:      'gpt-4o',
  judge:     'gpt-4o-mini',
  whisper:   'whisper-1',
  tts:       'gpt-4o-mini-tts',
};
