-- ══════════════════════════════════════════════════════════════════════
--  0013 — THE INDEXES THIS SCHEMA IS MISSING
--
--  Everything here is fast at a thousand users and falls over at a
--  hundred thousand. Nothing in this file changes behaviour; every
--  statement changes how long the existing behaviour takes.
--
--  Postgres does not warn you about this. A sequential scan of 50k rows
--  is a few milliseconds, so a missing index looks exactly like a
--  present one right up until it doesn't, and the failure arrives as
--  timeouts under load rather than as an error anyone can reproduce.
--
--  Safe to re-run. `create index if not exists` is idempotent, and
--  CONCURRENTLY is deliberately NOT used so this runs inside the
--  dashboard's transaction — on a table under a million rows the brief
--  write lock is not worth the operational complexity.
-- ══════════════════════════════════════════════════════════════════════


-- ── 1. BATTLES: the worst one in the schema ───────────────────────────
--
-- BattleService.myBattles() runs:
--
--   select * from battles order by created_at desc limit 20
--
-- with NO user filter — it leans entirely on RLS
-- (`auth.uid() = player_a or auth.uid() = player_b`) to cut the rows
-- down. That is correct and safe, but it means Postgres must evaluate
-- that predicate across the table and then sort what survives.
--
-- With no index on either player column that is a sequential scan of
-- every battle ever played, per call. And the Battles tab polls it on a
-- 20-second timer while it is open, three round-trips a time. At any
-- real concurrency this single query is the thing that takes the
-- database down.
--
-- Two separate indexes, not one composite: the predicate is an OR
-- across two columns, and Postgres can BitmapOr two indexes but cannot
-- use a composite (player_a, player_b) for a match on either one alone.
create index if not exists battles_player_a_idx
  on battles (player_a, created_at desc);
create index if not exists battles_player_b_idx
  on battles (player_b, created_at desc);

-- Joining by code, and the matchmaker's hunt for an unclaimed battle.
-- Partial, because `open` is a vanishing fraction of the table after a
-- few weeks and there is no reason to index the settled ones.
create index if not exists battles_open_idx
  on battles (created_at desc) where state = 'open';


-- ── 2. THE BOARDS ─────────────────────────────────────────────────────
--
-- Every leaderboard is `order by <column> desc limit N`, which is the
-- exact shape a descending index turns from a full sort into a walk of
-- the first N entries.

-- leaderboard_global — the voice board.
create index if not exists rizz_elo_rating_idx
  on rizz_elo (rating desc);

-- battle_leaderboard ranks on wins first, then win rate, then RR. Only
-- the first sort key can use an index — the win-rate tiebreak is a
-- computed expression — but that is where the work is: it means the
-- planner walks the top of this index instead of sorting the table, and
-- only resolves ties within it.
create index if not exists rizz_elo_wins_idx
  on rizz_elo (battles_won desc);

-- Divisions are read straight off this, and the app asks for one man's
-- RR by id constantly (the primary key covers that) but also sorts by
-- it on the duel board.
create index if not exists rizz_elo_battle_rating_idx
  on rizz_elo (battle_rating desc);

-- chat_leaderboard — the text board, ranked on points since 0010.
create index if not exists chat_score_points_idx
  on chat_score (points desc);


-- ── 3. SQUADS ─────────────────────────────────────────────────────────
--
-- squad_members is keyed (squad_id, user_id). A composite index serves
-- a lookup on its FIRST column, so "who is in this squad" is fast and
-- "which squad am I in" — the query that runs on almost every screen —
-- cannot use the primary key at all and scans the table.
create index if not exists squad_members_user_idx
  on squad_members (user_id) where status = 'active';


-- ── 4. THE DAILY needs nothing ────────────────────────────────────────
--
-- Noted rather than left silent, so nobody adds it later thinking it
-- was an oversight: "has this man already played today" is served by
-- the `unique (user_id, ymd)` constraint from 0005, which Postgres
-- implements as a real index. The board's (score desc) index is there
-- too. This table is already covered.


-- ── 5. VOICE SESSIONS ─────────────────────────────────────────────────
--
-- Minute accounting reads a user's sessions inside the current period.
-- 0001 indexed (user_id) only, so the time filter is applied after the
-- fact; this covers both halves.
create index if not exists voice_sessions_user_time_idx
  on voice_sessions (user_id, created_at desc);
