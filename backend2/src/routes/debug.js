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

const REALTIME_MODEL = 'gpt-realtime';

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
  app.post('/echo', async (req) => ({
    receivedBody: req.body,
    receivedHeaders: req.headers,
    method: req.method,
    url:    req.url,
    ts:     Date.now(),
  }));

  // ── /openai-test ────────────────────────────────────────────────────
  // Tries the absolute simplest Realtime client_secret create. Returns
  // the verbatim OpenAI response so you can see exactly what's failing
  // and why. No persona, no instructions, no syllabus — just "can we
  // even mint an ephemeral key with this account + model".
  app.get('/openai-test', async (_, reply) => {
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

    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type':  'application/json',
        },
        body: JSON.stringify(body),
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
        stack: e.stack,
      });
    }
  });
}
