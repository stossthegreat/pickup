-- ══════════════════════════════════════════════════════════════════════
--  0010 — RIZZ POINTS. The text ladder becomes cumulative.
--
--  0009 shipped the chat board ranked by BEST score. That's the right
--  shape for voice, which is one graded shot a day — but it's the wrong
--  shape for text, and the difference matters.
--
--    VOICE  one attempt a day, skill-rated, ELO can go DOWN.
--           Rewards being good.
--    CHAT   unlimited, cumulative, only goes UP.
--           Rewards turning up and doing it again.
--
--  Ranking unlimited text by best-of makes the whole thing pointless
--  after a lucky run: your number is set, more reps can't move it, so
--  the one surface with no cap gives you no reason to use it. Summing it
--  instead means the man who has 200 conversations outranks the man who
--  had one good one, which is exactly the behaviour this app exists to
--  produce.
--
--  Every graded text conversation now adds its score to a running total,
--  from all three sources:
--    · battles   — text duels, the main driver
--    · roleplay  — the AI women
--    · mission   — the coached real-world task chats
--  and winning a battle banks a flat bonus on top, so volume climbs the
--  board but winning climbs it faster.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

-- ── Cumulative standing ───────────────────────────────────────────────
alter table chat_score add column if not exists points  int not null default 0;
alter table chat_score add column if not exists battles int not null default 0;
alter table chat_score add column if not exists wins    int not null default 0;

comment on column chat_score.points is
  'Cumulative RIZZ POINTS: sum of every graded text attempt (0..100 each) '
  'plus 50 per battle won. Only ever climbs.';

-- Backfill from attempts already recorded so nobody who used the b121
-- build starts this ladder on zero.
update chat_score c
set points = coalesce((
  select sum(a.score) from chat_attempts a where a.user_id = c.user_id
), 0)
where c.points = 0;

-- ── The board, re-ranked ──────────────────────────────────────────────
-- security_invoker so it runs as the caller and can't leak anything the
-- caller couldn't already read.
drop view if exists chat_leaderboard;
create view chat_leaderboard
  with (security_invoker = true) as
  select p.id, p.handle, p.avatar_url,
         c.points, c.battles, c.wins, c.best, c.attempts, c.average
  from chat_score c
  join profiles p on p.id = c.user_id
  where c.attempts > 0
  order by c.points desc;

-- Battles are the main feed into the board, so the attempt index wants
-- to cover the per-user sum this ladder recomputes on every write.
create index if not exists chat_attempts_points_idx
  on chat_attempts (user_id) include (score);
