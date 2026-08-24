// Singleton OpenAI client. Key comes from Railway env var OPENAI_API_KEY.

import OpenAI from 'openai';

// A MISSING KEY MUST DEGRADE, NOT CRASH.
//
// The warning below used to be a lie. The OpenAI SDK constructor THROWS
// when apiKey is empty, and this module is imported at boot — so an
// unset or briefly-empty OPENAI_API_KEY did not "make those routes
// fail", it killed the process before app.listen(). On Railway that is
// an unrecoverable crash-loop: every replica dies on import, /health
// never answers, the platform sees no healthy target and there is
// nothing serving at all. The single most likely trigger is the most
// ordinary operation there is — rotating the key.
//
// Booting with a placeholder means the server comes up, /health and
// /version answer, the load balancer keeps a healthy target, and the
// AI routes return their normal clean error until the key is restored.
export const hasOpenAIKey = Boolean(process.env.OPENAI_API_KEY);
if (!hasOpenAIKey) {
  console.warn(
    '[auralay] WARNING: OPENAI_API_KEY not set — the AI routes will ' +
    'return errors until you set it in Railway. The server is up and ' +
    'serving /health so the platform keeps this instance alive.'
  );
}

export const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY || 'missing-openai-api-key',
  // Scale hardening: a hung OpenAI call must never hold one of our
  // request slots indefinitely. 45s covers the slowest legitimate
  // completion; one retry keeps transient 5xx recovery without
  // tripling latency under an OpenAI incident (the SDK default of 2
  // retries turns a 45s timeout into 135s of held socket).
  timeout: 45_000,
  maxRetries: 1,
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
