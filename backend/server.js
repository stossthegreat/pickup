// AURALAY backend — Fastify on Railway. One env var: OPENAI_API_KEY.
//
// Three endpoints today:
//   POST /v1/diablo/turn   — Whisper transcribe → GPT in-persona reply → TTS audio
//   POST /v1/rhetoric/score — judge a transcript across 6 charisma dimensions
//   GET  /health           — Railway liveness check
//   GET  /version          — hardcoded build string; exists ONLY to confirm
//                            Railway is serving the new container, not a
//                            cached old image. If this returns 404, Railway
//                            redeployed from a stale image; if it returns
//                            the BUILD_VERSION string, the new code is live
//                            and any further failures are application-level.

import 'dotenv/config';
import Fastify from 'fastify';
import multipart from '@fastify/multipart';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';

import debugRoute from './src/routes/debug.js';
import diabloRoute from './src/routes/diablo.js';
import presenceRoute from './src/routes/presence.js';
import realtimeRoute from './src/routes/realtime.js';
import rhetoricRoute from './src/routes/rhetoric.js';
import rizzRoute     from './src/routes/rizz.js';
import villainRoute from './src/routes/villain.js';
// ── Pickup app additions ──────────────────────────────────────────────────
import dateRoute  from './src/routes/date.js';   // texting roleplay (the girls)
import coachRoute from './src/routes/coach.js';  // ported im-him rizz brain (Bro)

// Bumped on every backend push so we can confirm at runtime which build
// Railway is actually serving. Do NOT remove — diagnostic checks rely on
// this string.
const BUILD_VERSION = '2026-07-11-pickup-unified-date+coach';

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = '0.0.0.0';

const app = Fastify({
  logger: { level: process.env.LOG_LEVEL || 'info' },
  bodyLimit: 25 * 1024 * 1024,   // 25MB — audio uploads
  // ── SCALE HARDENING (500k-user readiness) ────────────────────────────
  // trustProxy — Railway terminates TLS at its load balancer, so without
  // this every request appears to come FROM the LB's IP. Rate limiting
  // keyed by IP would then throttle the entire userbase as one client.
  trustProxy: true,
  // keepAliveTimeout must exceed the upstream LB's idle timeout or the
  // node closes sockets the LB still considers live → random 502s under
  // sustained load. Railway's edge idle timeout is well under 75s.
  keepAliveTimeout: 76_000,
  // A request that hasn't completed in 2 minutes is dead weight — kill
  // it and free the socket instead of letting hung upstream calls pile
  // up until the process starves. Longest legitimate request (villain
  // audio scoring) finishes far inside this.
  requestTimeout: 120_000,
});

await app.register(cors, { origin: true });
// Global per-IP rate limit — cost armour, not UX. Every request here
// fans out to a paid OpenAI call, so one abusive client (or one bug in
// a retry loop) can burn real money at line rate. 120 req/min is far
// above any human's real usage (voice minting is ~1/session, a text
// turn every few seconds at worst) and far below what a runaway script
// would attempt. Health/version stay unthrottled for Railway probes.
await app.register(rateLimit, {
  max: 120,
  timeWindow: '1 minute',
  allowList: (req) => req.url === '/health' || req.url === '/version',
});
await app.register(multipart, {
  limits: { fileSize: 25 * 1024 * 1024 },
});

app.get('/health', async () => ({
  ok: true,
  ts: Date.now(),
  version: BUILD_VERSION,
}));

app.get('/version', async () => ({
  version: BUILD_VERSION,
  ts: Date.now(),
  node: process.version,
  pid: process.pid,
}));

await app.register(diabloRoute,   { prefix: '/v1/diablo'   });
await app.register(rhetoricRoute, { prefix: '/v1/rhetoric' });
await app.register(realtimeRoute, { prefix: '/v1/realtime' });
await app.register(villainRoute,  { prefix: '/v1/villain'  });
await app.register(presenceRoute, { prefix: '/v1/presence' });
await app.register(rizzRoute,     { prefix: '/v1/rizz'     });
await app.register(dateRoute,     { prefix: '/v1/date'     });
await app.register(coachRoute,    { prefix: '/v1/coach'    });
await app.register(debugRoute,    { prefix: '/v1/debug'    });

// ── LAST-RESORT ERROR HANDLER ────────────────────────────────────────
// Any route that throws past its own try/catch lands here instead of
// leaking a stack trace to the client. The request gets a clean JSON
// 500, the error gets logged with its route, and the process carries on
// serving everyone else.
app.setErrorHandler((err, req, reply) => {
  // Fastify tags framework-origin errors (body too large, bad JSON,
  // rate limit) with a statusCode — pass those through untouched.
  const code = err.statusCode && err.statusCode >= 400 ? err.statusCode : 500;
  if (code >= 500) {
    req.log.error({ err, url: req.url }, 'unhandled route error');
  }
  reply.code(code).send({ error: code >= 500 ? 'internal' : err.message });
});

// ── PROCESS-LEVEL ARMOUR ─────────────────────────────────────────────
// Node kills the entire process on an unhandled promise rejection —
// one stray .then() without a .catch() anywhere in the codebase and
// every concurrent user is dropped mid-request. At hundreds of
// thousands of users that is not a bug report, it is an outage. Log
// it loudly, keep serving.
process.on('unhandledRejection', (reason) => {
  app.log.error({ reason: String(reason) }, 'UNHANDLED REJECTION — survived');
});
// A truly uncaught synchronous throw means unknown state: log, close
// the listener so the platform LB stops routing to us, and exit so
// Railway restarts a clean instance. In-flight requests get their
// replies; new ones go to the other replicas.
process.on('uncaughtException', (err) => {
  app.log.fatal({ err }, 'UNCAUGHT EXCEPTION — draining and restarting');
  app.close().finally(() => process.exit(1));
  // Belt-and-braces: never hang in a broken state.
  setTimeout(() => process.exit(1), 8_000).unref();
});

// ── GRACEFUL SHUTDOWN ────────────────────────────────────────────────
// Railway sends SIGTERM on every deploy and restart. Without this, the
// old instance is killed mid-request and every user in a voice-session
// mint or a text turn at that moment gets a dropped connection. With
// it: stop accepting new sockets, finish what's in flight, then exit.
let shuttingDown = false;
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    if (shuttingDown) return;
    shuttingDown = true;
    app.log.info(`${sig} — draining in-flight requests, then exiting`);
    app.close().then(() => process.exit(0), () => process.exit(1));
    // Hard deadline so a stuck request can't block the deploy forever.
    setTimeout(() => process.exit(0), 10_000).unref();
  });
}

try {
  await app.listen({ port: PORT, host: HOST });
  app.log.info(
    `AURALAY backend version=${BUILD_VERSION} listening on ${HOST}:${PORT}`
  );
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
