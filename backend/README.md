# MIRROR backend

Node/Express service that powers MIRROR's analysis and maximized-image pipeline.

## Endpoints

- `POST /analyse` — `{ imageBase64, geometry }` → GPT-4o structured analysis
- `POST /maximize` — `{ imageBase64, brief, geometry }` → Flux Kontext Max identity-preserving edit
- `POST /scan` — one-call pipeline: analyse → maximize

## Local dev

```bash
cp .env.example .env
# fill in OPENAI_API_KEY and REPLICATE_API_TOKEN
npm install
npm run dev
```

## Deploy to Railway

1. Push this folder to a GitHub repo
2. Create new Railway project → Deploy from GitHub
3. Set environment variables in Railway:
   - `OPENAI_API_KEY`
   - `REPLICATE_API_TOKEN`
4. Railway auto-detects Node, runs `npm start`

## Testing the image pipeline

Before wiring to the Flutter app, verify the maximized image passes the
"that's clearly me" bar on 9/10 test faces. If it fails, iterate the
prompt in `src/maximize.js` — it is the moat.
