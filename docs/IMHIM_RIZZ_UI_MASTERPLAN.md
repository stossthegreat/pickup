# ImHim Rizz — The Academy Layer · UI Master Plan

The social/competitive layer, designed to be **stunning, coherent, and
mechanically addictive**. Companion to [IMHIM_RIZZ_BUILD.md](./IMHIM_RIZZ_BUILD.md)
(architecture) — this doc is the product/UI spec.

## Design law
Extend the existing signature — never invent a second language:
- **Palette:** true black `#000`, blood red (`AppColors.red`), neon pulse
  `#2EE87A` (wins/scores only), tile `#111113`. Nothing else.
- **Type:** Inter w800/w900. Huge numerals. Letterspaced micro-labels.
- **Motion:** silent until it matters — count-ups, staggered reveals, one
  pulse on promotion. `flutter_animate` (already a dep).
- **Haptics** on every meaningful event (commit, score land, rank-up).

**The ladder IS the rank system.** Paywall rungs OBSERVER → INITIATE →
CONTENDER → DANGEROUS → HIM become the live ELO tiers. Proposed bands:
<1100 · 1100–1299 · 1300–1599 · 1600–1899 · 1900+. Tier colors: dim
silver → white → red → red-glow → neon.

---

## Surface 1 — SQUAD ROOM (new tab, shield icon + unread badge dot)
| Zone | What it is |
|---|---|
| Header | Squad crest + name, weekly points bar, division chip |
| **Week Grid** | Rows = members (sorted by weekly points), cols = Mon–Sun. Cell states: red check = mission completed · hollow ring = committed, not done · dim = silence. Today's column highlighted. Tap cell → bottom sheet (mission, time, Discord proof link) |
| Call Your Shot | Today's mission card + COMMIT button → fires `committed` pulse event with timestamp |
| The Pulse | Realtime feed from `squad_events`: joined/committed/completed/scored/rankup/streak |
| War Room | Deep-link button to the squad's Discord channel |
| Invite | Mints invite code as a **share card** (not a dialog) |

Psychology: public commitment (consistency), loss aversion (empty cell
next to your name), social proof (the grid filling), belonging (crest).

## Surface 2 — SCORE REVEAL (after every voice session)
Full-screen takeover: score counts up with haptic ticks → five rubric
bars stagger in — **Confidence · Flow · Wit · Recovery · Close** (0–100
each, server-weighted into the headline score) → ELO delta chip (+24)
→ tier progress bar. CTAs: **SHARE / RUN IT BACK / NEXT**.
"Run it back" is the replay engine — the gap to the next rank is always
on screen when the button appears.

## Surface 3 — LEADERBOARD
Scope tabs: **SQUAD · FRIENDS · WEEKLY · GLOBAL**. Podium top-3 (avatar +
tier glow), ranked list, **own row permanently pinned at bottom** so the
gap to the next rank is always visible. WEEKLY resets Monday ("I can win
this one"). Data: `leaderboard_global` view + scoped queries.

## Surface 4 — SHARE CARDS (viral engine)
1080×1350 (IG 4:5) images rendered in-app (RepaintBoundary → PNG →
`share_plus`, already a dep). Variants: score · rank-up · streak · squad
victory · **challenge** ("JAMES · 8,942 · Think you'd survive? [code]")
with `imhim://` deep link into the exact scenario + code fallback.
Sharing = status for the user, acquisition for us.

## Surface 5 — POP-UP PRIMITIVE
One modal component (black glass, red edge-glow, single motion curve,
entry haptic) reused for rank-up, promotion, challenge received, squad
vote, streak milestone. One primitive = zero tackiness drift.

---

## The loop (why it compounds)
mission → grid fills → pulse fires → squadmate opens app → sees
leaderboard gap → runs session → score reveal → share card → challenge
link → new user joins squad → repeat. Usage manufactures the next usage;
shares manufacture new users.

## Build order
1. Pop-up primitive + Score Reveal (every feature celebrates through these)
2. Scoring Edge Function (rubric → score → ELO; service-role writes only)
3. Leaderboard screen
4. Squad Room + tab (needs migration 0003)
5. Share-card engine
6. Push notifications (APNs/FCM) for closed-app alerts — Realtime covers in-app until then

## Data notes
- Migration `0003_squad_room.sql`: `same_squad()` read policy on
  `user_missions` (Week Grid) + `squad_events` Pulse table on Realtime.
- Scores/ELO remain server-write-only. Clients read, never write.
