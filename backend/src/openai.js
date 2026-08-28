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
// MINI ONLY. NO EXCEPTIONS ON THE CHAT PATH.
//
// `chat` was gpt-4o, justified by a comment about a persona that no
// longer ships: "mini was too tame — it didn't execute the laughs /
// lean-ins / quote-the-word moves". That was written for the old
// AURALAY character and inherited wholesale.
//
// What it actually paid for: `POST /v1/villain/freeflow/score`, which
// free_flow_screen calls after EVERY live voice call to produce the
// score. Not a dead legacy screen — the scoring on the main feature,
// on the expensive model, on every session. 17x the price of mini for
// a call that returns a JSON rubric, which is the one job mini is
// unambiguously good at.
//
//   per voice call   gpt-4o $0.0185   ->   mini $0.0011
//   100k calls       $1,846           ->   $111
//
// The girl chat (/v1/date/turn) and the coach were already on mini and
// are untouched. If a persona ever genuinely needs more than mini, the
// fix is a better prompt — the realtime voice already proves a 34k-char
// prompt holds character on a mini model.
export const MODELS = {
  chat:      'gpt-4o-mini',
  judge:     'gpt-4o-mini',
  whisper:   'whisper-1',
  tts:       'gpt-4o-mini-tts',
};

// The rule, enforced rather than documented. A future edit that puts a
// full model back on a text path fails at BOOT with a named error
// instead of quietly costing 17x per call until someone reads a bill.
// whisper/tts are exempt — they have no mini/full split.
for (const key of ['chat', 'judge']) {
  const m = MODELS[key];
  if (!m.includes('mini')) {
    throw new Error(
      `[auralay] MODELS.${key} is "${m}" — text models must be mini. ` +
      'See the note above: full models on the chat path cost ~17x and ' +
      'the one that was there scored every voice call.',
    );
  }
}
