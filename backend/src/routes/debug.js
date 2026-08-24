// /v1/debug/*  — diagnostic endpoints for live troubleshooting.
//
//   GET  /v1/debug/health         basic backend liveness
//   GET  /v1/debug/openai-test    tries to mint a minimal Realtime
//                                 client_secret + reports verbatim
//                                 what OpenAI accepted/rejected
//   GET  /v1/debug/voices         lists which OpenAI voice each persona
//                                 is configured to use
//   POST /v1/debug/echo           echoes whatever body was posted
//   GET  /v1/debug/env            redacted env snapshot
//
// These are intentionally cheap to call. They exist so when the realtime
// loop breaks we can curl the backend and read the actual OpenAI response
// instead of guessing through a 404.

import { TEACHERS } from '../personas.js';

// THE SECOND DOOR TO THE FULL MODEL.
//
// The rule is absolute: outside creator mode nothing may ever touch
// `gpt-realtime`. routes/realtime.js enforces that — and this file
// quietly walked around it, because it hardcoded its OWN copy of the
// model name instead of importing the picker. `GET /v1/debug/openai-test`
// was a public, unauthenticated endpoint that minted a real FULL-model
// ephemeral key on our account and handed it to whoever asked. Anyone
// who found the URL could mint them in a loop and burn full-model
// realtime minutes on our bill.
//
// It now mints the mini model — the same one real users get — so the
// probe still answers the only question it exists to answer ("can this
// account mint a realtime key at all") without ever being a route to
// the expensive model.
const REALTIME_MODEL = 'gpt-realtime-mini';

// …and the probe is no longer free to call. It is the one endpoint here
// that spends money, so it requires DEBUG_TOKEN (set it in Railway) in
// an `x-debug-token` header. With no DEBUG_TOKEN configured the probe
// is simply off — fail closed, never open. The read-only endpoints
// below cost nothing and stay open.
function debugAuthed(req) {
  const want = process.env.DEBUG_TOKEN;
  if (!want) return false;
  const got = req.headers['x-debug-token'];
  return typeof got === 'string' && got === want;
}

export default async function debugRoute(app) {

  // ── /health ─────────────────────────────────────────────────────────
  app.get('/health', async () => ({
    ok: true,
    backend: 'auralay',
    ts: Date.now(),
    hasOpenAIKey: Boolean(process.env.OPENAI_API_KEY),
    nodeVersion: process.version,
    realtimeModel: REALTIME_MODEL,
  }));

  // ── /env  (redacted) ────────────────────────────────────────────────
  app.get('/env', async () => ({
    hasOpenAIKey: Boolean(process.env.OPENAI_API_KEY),
    openAIKeyPrefix: process.env.OPENAI_API_KEY
      ? process.env.OPENAI_API_KEY.slice(0, 7) + '…'
      : null,
    port: process.env.PORT || '(default 8080)',
    logLevel: process.env.LOG_LEVEL || 'info',
    railwayService: process.env.RAILWAY_SERVICE_NAME || null,
    railwayDeploymentId: process.env.RAILWAY_DEPLOYMENT_ID || null,
  }));

  // ── /voices ─────────────────────────────────────────────────────────
  app.get('/voices', async () => ({
    realtimeModel: REALTIME_MODEL,
    teachers: Object.fromEntries(
      Object.entries(TEACHERS).map(([id, t]) => [id, {
        voice: t.voiceCfg.voice,
        instructionsLen: (t.voiceCfg.instructions || '').length,
      }]),
    ),
  }));

  // ── /echo ───────────────────────────────────────────────────────────
  // Headers are deliberately NOT reflected: this endpoint is public and
  // an echo of arbitrary request headers is a gift to anyone probing
  // what the proxy in front of us injects. The body is what we ever
  // needed to see.
  app.post('/echo', async (req) => ({
    receivedBody: req.body,
    method: req.method,
    url:    req.url,
    ts:     Date.now(),
  }));

  // ── /openai-test ────────────────────────────────────────────────────
  // Tries the absolute simplest Realtime client_secret create. Returns
  // the verbatim OpenAI response so you can see exactly what's failing
  // and why. No persona, no instructions, no syllabus — just "can we
  // even mint an ephemeral key with this account + model".
  app.get('/openai-test', async (req, reply) => {
    if (!debugAuthed(req)) {
      // 404, not 401 — an unauthenticated caller learns nothing about
      // whether this endpoint exists.
      return reply.code(404).send({ error: 'not_found' });
    }
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return reply.send({
        ok: false,
        stage: 'precheck',
        error: 'OPENAI_API_KEY env var is not set',
      });
    }

    const url = 'https://api.openai.com/v1/realtime/client_secrets';
    const body = {
      session: {
        type:  'realtime',
        model: REALTIME_MODEL,
        audio: {
          output: { voice: 'alloy' },
        },
      },
    };

    // A hung upstream call must never hold a request slot open — same
    // 15s ceiling the real mint uses.
    const ac = new AbortController();
    const killer = setTimeout(() => ac.abort(), 15_000);
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type':  'application/json',
        },
        body: JSON.stringify(body),
        signal: ac.signal,
      });
      const text = await resp.text();
      let parsed;
      try { parsed = JSON.parse(text); } catch { parsed = text; }
      return reply.send({
        ok: resp.ok,
        stage: 'openai',
        url,
        status: resp.status,
        statusText: resp.statusText,
        requestBody: body,
        responseHeaders: Object.fromEntries(resp.headers.entries()),
        response: parsed,
      });
    } catch (e) {
      return reply.code(500).send({
        ok: false,
        stage: 'fetch',
        url,
        error: String(e.message || e),
      });
    } finally {
      clearTimeout(killer);
    }
  });
}
