# Charmr

**Practice on AI. Level up in real life.**

A roleplay-confidence app for men. Text the AI women, get coached live by **Bro**
(he cuts in mid-chat and shows you the move), take **real-world missions**, and
watch one number go up: your **Aura Level**.

- **App id:** `com.firstmove.app` · **Name:** Charmr
- **Flutter** app in [`lib/`](lib/) — default entry is [`lib/main.dart`](lib/main.dart)
- **Backend** (Fastify) in [`backend/`](backend/) — deployed on Railway

## App structure (`lib/pickup/`)

| Tab | What it is |
|-----|------------|
| 🌍 Missions | Screen one. Real-world action ladder + roleplay reps, all feed Aura Level |
| 🎭 Chat | The roster of AI women; learn-as-you-go roleplay with Bro cut-ins |
| 💬 Her | One relationship that warms as you level (fastest from real-world wins) |
| 👤 You | Aura Level + the 5 metrics (Confidence · Presence · Humor · Listening · Game) |

## Backend (`backend/`)

One Fastify service. Env: `OPENAI_API_KEY`.

| Route | Purpose |
|-------|---------|
| `POST /v1/date/turn` | Texting roleplay — returns her reply + Bro's coach cut-in + score |
| `POST /v1/coach/lines` | Elite line-writer (screenshot/text → 3 ranked lines) |
| `POST /v1/villain/*` | Voice roleplay scenes + creator mode |
| `GET /health` | Liveness |

### Run

```bash
# App
flutter pub get
flutter run                      # builds Charmr (com.firstmove.app)

# Backend
cd backend && npm install
OPENAI_API_KEY=sk-... npm start  # http://localhost:8080/health
```

## Deploy

Railway builds from the repo root (`railway.json` → `cd backend && npm start`).
Set `OPENAI_API_KEY` in the Railway service. Health check: `/health`.
