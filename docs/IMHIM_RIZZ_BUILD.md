# ImHim Rizz — Master Build Plan

The evolution from *"an app you use when you need help"* into *"an academy of
social confidence you progress through every day."* One principle drives every
decision: **make usage create the reason for the next usage.**

---

## The product, in one line
AI voice/text practice + real-world missions + squads + competition — a 60-day
programme that turns shy men into people who **connect**, sold on the outcome
("never think *why didn't I say something* again").

**Two personas, one funnel:**
- **Roleplayers** — here for the AI practice alone. Low friction, huge volume,
  convert on the voice. → *top of funnel.*
- **Doers** — running missions + squads through the 60-day programme. High
  retention, high LTV. → *the academy / the movement.*

Let people in through roleplay; convert them into doers with squads + missions.

---

## Architecture (final)
```
Flutter client (this repo)
   │  Supabase Auth (Sign in with Apple — one tap)
   ▼
Supabase = Postgres + Row-Level Security + Realtime (leaderboards/presence)
   │
   ├─ Edge Functions (Deno) — hold the secrets + all score-affecting logic:
   │     OpenAI voice scoring · ELO calc · battle pairing · RevenueCat webhooks
   └─ Discord bot (small persistent worker) — squad accountability + roles
```
- **No LiveKit.** Battles are *independent* (each user plays the AI solo, scores
  compared after) and squad socialising lives in **Discord** — so there is no
  live user-to-user video/audio, which removes the entire 18+ live-moderation
  burden that stalls App Review.
- **Security rule:** OpenAI + RevenueCat keys live server-side only. Anything
  that changes rank/score is written by the server, never the client.

---

## What we reuse from Rivlr (`stossthegreat/whatif`) vs. build new
| Need | Rivlr has it | Action |
|---|---|---|
| Auth / identity | `auth.ts` (custom HMAC) | **Replace** with Supabase Auth |
| Postgres on Railway | `db.ts`, `railway.json` | **Move** to Supabase Postgres |
| Matchmaking / pairing | `matching.ts` (interests, rep-quarantine, anti-rematch) | **Port** for battle queue |
| In-session games/scenarios | `games.ts` (681 lines) | **Port / adapt** to Rizz scenarios |
| Subscriptions | `iap.ts`, `revenuecat.ts` | **Port** webhook handling; switch to monthly+annual |
| Push / re-engagement | `push.ts` | **Port** |
| Reports / blocks / moderation | `moderation.ts`, `reports`/`blocks` tables | **Port light** (no live video) |
| Live video | `livekit.ts`, `calls.ts`, `media.ts` | **Drop — not needed** |

**~60–70% of the backend already exists.** That's why this is fast.

---

## Build phases (ship stunning, then expand)
1. **Foundation** — Supabase project, `0001_foundation.sql`, Sign in with Apple,
   profile auto-create. *(client already "auth-ready" on the consent screen)*
2. **Voice → scored ELO + global leaderboard** — first visible "whoa." Rides the
   existing OpenAI voice; add a scoring rubric returned server-side.
3. **Squads via Discord** — invite codes + commit/report loop + Discord bot role
   sync. *Validate the accountability thesis cheaply before building native.*
4. **Battles** — code links + random "line up" matchmaking (port `matching.ts`).
5. **Missions v2** — the escalation ladder + commit-before-do + adaptive + proof.
6. **Fear Button** ("I'm bottling it") — cheap, parallel, ship anytime.
7. **Ejay profile + challenges** — the creator flywheel.
8. **Seasons → 60-day journey → Companion** — LTV crown, last (Companion needs
   60 days of stored history before it can be real).

---

## ⚠️ Mission framing — non-negotiable (App Store + brand safety)
We've already been stuck in review. Missions phrased as *"approach a girl while
she's with her friends"* read as **encouraging harassment** → rejection + public
backlash. **Sell the transformation, not tactics on women.** Same outcome, clean
framing:
- ✅ "Start one real conversation today." "Give a genuine compliment." "Don't
  freeze — say the thing." "Hold eye contact and smile first."
- ❌ Anything that targets/pressures a specific person or frames women as objectives.

This is both the right thing **and** what keeps us approved and the movement clean.

---

## The engagement engine (why it compounds)
```
Kim's audience → install (roleplay hook) → voice "whoa" → squad/mission
     ↑                                                          │
 creator content ← leaderboards + "beat Ejay" ← users record real-world proof
```
Missions produce **proof content** → feeds **creator leaderboards/challenges** →
Kim amplifies → **installs** → loop. We manufacture attention instead of buying it.

---

## Schema
See [`supabase/migrations/0001_foundation.sql`](../supabase/migrations/0001_foundation.sql).
Foundation tables: `profiles`, `rizz_elo`, `voice_sessions`, `squads`,
`squad_members`, `missions`, `user_missions`, `battles`, `battle_queue`, and the
`leaderboard_global` view. Score-affecting tables are server-write-only by RLS.

---

## Do-this-now checklist (Supabase)
1. Create the project (region closest to your users). Save the **Project URL**,
   **anon key**, and **service-role key** (service-role = server only, never in
   the app).
2. **SQL Editor** → paste `supabase/migrations/0001_foundation.sql` → Run.
3. **Authentication → Providers → Apple** → enable (needs your Apple Services ID
   + key from the new `SVK282935V` account).
4. Keep the **service-role key** for Edge Functions only.
5. Tell me it's done — I'll wire the Flutter client (Supabase init + Apple
   sign-in on the consent screen) and scaffold the first Edge Function
   (voice scoring → ELO).
