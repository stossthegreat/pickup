# AURALAY backend

Diablo persona + scoring + TTS, behind one OpenAI key. Deployed on Railway.

## Endpoints

| Method | Path                  | Body                                                | Returns                                             |
| ------ | --------------------- | --------------------------------------------------- | --------------------------------------------------- |
| `GET`  | `/health`             | —                                                   | `{ ok: true, ts }`                                  |
| `POST` | `/v1/diablo/turn`     | multipart: `audio` + `mode` + `context` + `history` | `{ transcript, reply, audio (b64 mp3), mode }`      |
| `POST` | `/v1/rhetoric/score`  | json: `{ lessonId, transcript }`                    | `{ dimensions{6}, verdict, total }`                 |

## Deploy to Railway

1. **New project** → **Deploy from GitHub** → pick `stossthegreat/auralayai`.
2. **Settings → Service → Root Directory:** `backend`
3. **Variables:** add `OPENAI_API_KEY = sk-...`
4. **Settings → Networking → Generate Domain.** That URL is what the Flutter app talks to.

Railway will detect `Dockerfile` + `railway.json` and build automatically. `/health` is the liveness check.

## Local dev

```
cd backend
cp .env.example .env     # paste your OpenAI key
npm install
npm run dev              # http://localhost:8080
```

Quick smoke test:
```
curl http://localhost:8080/health
curl -X POST http://localhost:8080/v1/rhetoric/score \
  -H 'content-type: application/json' \
  -d '{"lessonId":"conviction","transcript":"I am the right person for this. I have run nine campaigns and won eight."}'
```

## Personas

Four modes ratchet the cruelty dial:

- **`charm`** — App Store-safe default. Warm but composed mentor.
- **`heat`** — Sharper. Cuts hedging. No warmth.
- **`thirst`** — Slow, drawling, mildly amused mockery.
- **`diablo`** — Unleashed. Paragraph-length devastations. Hidden behind the in-app settings password — never the default.

Edit prompts in `src/personas.js`. Voice direction (TTS instructions) lives in the same file — that's the killer feature of `gpt-4o-mini-tts`.

## Wire the Flutter app to it

Once Railway gives you a public URL (e.g. `https://auralay-backend.up.railway.app`), the Flutter app reads it from a compile-time `--dart-define` flag.

In Codemagic:

1. **Environment variables** → add `AURALAY_API = https://your-railway-url.up.railway.app`
2. **iOS workflow → Build → Flutter build arguments** (or edit codemagic.yaml):
   ```
   --release --dart-define=AURALAY_API=$AURALAY_API
   ```
3. Re-run the build. The app now talks to your Railway service. Diablo speaks in her real OpenAI voice; the heuristic local stubs go silent.

If `AURALAY_API` is unset the app falls back to deterministic local stubs (typewriter Diablo + heuristic scorer) so nothing crashes.

## Why this stack

- **Fastify** over Express: smaller cold starts on Railway.
- **node:20-alpine**: ~80MB final image.
- **base64 audio in JSON**: simpler than chunked streaming for v1, swap to SSE/streaming once the UX demands it.
