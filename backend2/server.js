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
});

await app.register(cors, { origin: true });
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

try {
  await app.listen({ port: PORT, host: HOST });
  app.log.info(
    `AURALAY backend version=${BUILD_VERSION} listening on ${HOST}:${PORT}`
  );
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
