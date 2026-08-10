# ImHim Rizz — THE GAME (v2 design)

## The honest diagnosis
What's built so far is a **dashboard, not a game**. Screens that *report
state* (a leaderboard, a grid, a feed) instead of mechanics that *create
tension*. Nothing expires, nothing can be lost, nothing happens at a
specific time, nobody you know is coming for you. A leaderboard with no
clock is a spreadsheet. Every legendary engagement system is built on
four things ours lacks:

1. **A clock** — something locks/expires soon (Duolingo's Sunday league
   lock, Clash war day, BeReal's moment).
2. **Loss** — something you own can be taken (streaks, crowns, league
   place). Fear of relegation outdrives hope of promotion.
3. **People you know** — competition vs 5 mates beats 100,000 strangers
   (fantasy leagues, clans, group chats).
4. **The same moment for everyone** — one shared daily thing makes
   results comparable and conversations automatic (Wordle, BeReal).

Duolingo's league system (30 people, weekly, top promoted / bottom 5
relegated, locks Monday) drove **+65% YoY daily usage** and lifted
retention from **12% to 55%**. Strava's stealable KOM crowns turn one
push notification ("you lost your crown") into instant re-engagement.
Snapchat streaks work because they're *mutual* — two people lose.

## THE GAME — one loop
**Every day there's a DROP. Every week there's a FIXTURE. Every Sunday
everything LOCKS.**

```
daily: THE DAILY drop (same scenario worldwide, ONE attempt)
         └─> score feeds → your FIXTURE (you vs one squadmate this week)
                             └─> feeds → your LEAGUE place (relegation!)
weekly: Sunday 21:00 — league locks, fixture settles, crowns audited,
        Monday: new fixtures, fresh league, new week. Repeat forever.
```

## The six mechanics (build order)
| # | Mechanic | Stolen from | What it is here |
|---|---|---|---|
| 1 | **THE DAILY** | Wordle/BeReal | One scenario, same for the whole world, ONE attempt, daily board, share card vs world average. The reason to open TODAY. |
| 2 | **FIXTURES** | Fantasy football | Monday: app pairs you vs ONE squadmate on weekly points (missions + daily + battles). Giant VS card on home with the score + days left. |
| 3 | **LEAGUES** | Duolingo | Divisions of ~30, weekly, top promote / bottom relegate, locks Sunday 21:00 with a live countdown. Promotion ceremony via AcademyModal. |
| 4 | **CROWNS** | Strava KOM | Best score per scenario holds a crown (KING OF COLD). Beaten → crown *transfers* → dethroned notification. Status that can be stolen. |
| 5 | **SQUAD WAR** | Clash of Clans | Weekend event: matched rival squad, every member's daily counts to the squad total, Sun 21:00 verdict. Group stakes. |
| 6 | **NEVER-EMPTY** | Racing ghosts | Boards seeded with the AI cast as house records + Ejay's real scores + your own last-week ghost. The game is alive from install #1. |

Connective tissue: rank badge worn on every surface, "WHILE YOU WERE
GONE" modal on open (fixture moved, crown lost, squad 3/5), promotion /
dethroned / victory ceremonies all through the one modal primitive.

## What already exists that this rides on
Scoring engine + ELO (done) · squads + pulse (done) · battles (done) ·
share cards (done) · modal primitive (done) · missions loop (done).
The v2 game is **rules + time on top of the machine we built** — the
infra was the hard part and it's live; this layer is fixtures, clocks
and ceremonies.

Sources: [Duolingo leagues +25% lesson completion](https://duolingo.deconstructoroffun.com/mechanics/leagues) ·
[Duolingo gamification case study](https://trophy.so/blog/duolingo-gamification-case-study) ·
[Duolingo retention strategy](https://www.trypropel.ai/resources/blogs/duolingo-customer-retention-strategy) ·
[Strava segmented leaderboards](https://trophy.so/blog/how-strava-uses-segmented-leaderboards-to-drive-engagement) ·
[Strava gamification](https://trophy.so/blog/strava-gamification-case-study) ·
[Snapchat streak psychology](https://www.sciencedirect.com/science/article/pii/S2451958822000069) ·
[Streaks in mobile apps](https://trophy.so/blog/streaks-feature-gamification-examples)
