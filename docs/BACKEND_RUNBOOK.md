# ImHim Backend — Emergency Runbook

For whoever is on call when the backend misbehaves and the founder is not
around. Everything here has been checked against the code in this repo.

## What the backend actually is

A single stateless Node service (Fastify) that lives in `backend/`, runs on
Railway, and does three jobs:

- mints short-lived OpenAI Realtime sessions so the app can do live voice
- answers text-roleplay turns (`/v1/date`) and rizz replies (`/v1/rizz`)
- scores conversations

It stores nothing. No database, no user data, no sessions in memory. That is
why almost every outage is one of the four things below, and why restarting
is always safe.

## First: is it actually down?

Open these two URLs in a browser. They are deliberately exempt from rate
limiting, so they always answer if the service is alive.

- `<backend-url>/health` — expect `{"ok":true, ...}`
- `<backend-url>/version` — expect a version string and a node version

Both load → the service is UP; the problem is the app, the network, or
OpenAI (see below).
Neither loads → the service is DOWN. Go to Railway → the backend service →
**Deployments** and read the log of the most recent one.

## The four things that actually go wrong

### 1. Deploy failed: "npm ci can only install when package.json and package-lock.json are in sync"

Someone added a dependency without updating the lock file. Fix:

```
cd backend
npm install --package-lock-only
git add package-lock.json
git commit -m "sync package-lock"
git push
```

### 2. Everything answers but the AI says nothing

The log will say `OPENAI_API_KEY missing` or every AI reply comes back as
`ai_unavailable`. Railway → the service → **Variables** → confirm
`OPENAI_API_KEY` is set and has not expired. The app is built to fail
gracefully here: users see an error, nothing crashes.

### 3. Users report "it stopped working" but health is fine

Usually OpenAI itself is degraded. Check https://status.openai.com. Nothing
to fix on our side — the timeouts in the service mean a slow OpenAI cannot
pile up and take the process down.

### 4. One user hammering it

There is a per-IP rate limit of 120 requests/minute; over that they get HTTP
429 and everyone else is unaffected. This is cost protection, working as
designed. No action needed.

## The one switch worth knowing

`REVIEW_SAFE_MODE` (Railway → Variables):

- **not set / `0`** — normal. The AI women flirt (never explicit).
- **`1`** — hard content lock. Every AI surface goes clean and non-sexual
  while keeping each character's personality. Set this whenever a build is
  in App Review; delete it once approved.

It takes effect on the restart Railway does automatically, roughly 30
seconds. No deploy, no app update needed.

## Restarting

Railway → the service → **⋮** → Restart. Safe at any time: the service holds
no state, finishes in-flight requests on shutdown, and the app reconnects on
its own.

## What NOT to do in a panic

- Do not roll back the app build to fix a backend problem — they deploy
  independently and a backend fix needs no app release.
- Do not change `pubspec.yaml`. It is the app's version train and touching
  it can block App Store uploads.
- Do not disable the rate limit to "let traffic through". It is what stops a
  runaway client burning the OpenAI budget.
