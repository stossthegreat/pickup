-- ══════════════════════════════════════════════════════════════════════
--  0017 — VOICE POINTS. The voice board ranks on what you scored,
--  accumulated — not on a rating that converges and stops.
--
--  THE RULE, stated once for every board: the higher you score the
--  higher you rank, and a man who plays more can catch a man who plays
--  less. Text got this in 0010 (chat_score.points). Voice never did —
--  leaderboard_global ranked on `rating`, an ELO that drifts toward
--  your skill level in ~10 sessions and then sits there. Two problems:
--
--    · Volume never catches up. Once rated, a hundred more sessions
--      move you nowhere. That's correct for matchmaking and dead wrong
--      for a leaderboard — a board you can't climb by playing is a
--      board you stop looking at.
--    · A new player's board position is mostly his starting 1000, not
--      anything he did.
--
--  `rating` stays — divisions and stakes still want a skill estimate —
--  it just stops being the board's sort key.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

alter table rizz_elo
  add column if not exists voice_points int not null default 0;

comment on column rizz_elo.voice_points is
  'Cumulative 0-100 session scores. THE voice board sort key. '
  'Written by score-voice only.';

-- Backfill from the sessions still on hand (0015 keeps 90 days, which
-- at migration time is everything). round(score/99.99) is exactly the
-- app's Economy.aiScoreFromVoice, so history and future land on the
-- same scale.
update rizz_elo e
set voice_points = coalesce((
  select sum(round(s.score / 99.99))::int
  from voice_sessions s
  where s.user_id = e.user_id
), 0)
where e.voice_points = 0;

create index if not exists rizz_elo_voice_points_idx
  on rizz_elo (voice_points desc);

-- The board, re-ranked. Dropped first — 0009's lesson: an older CREATE
-- OR REPLACE can never remove or reorder what a newer one added, so the
-- newest migration owns the view outright.
drop view if exists public.leaderboard_global;
create view public.leaderboard_global
  with (security_invoker = true) as
  select p.id,
         p.handle,
         p.avatar_url,
         e.rating,
         e.tier,
         e.voice_points
    from public.rizz_elo e
    join public.profiles p on p.id = e.user_id
   order by e.voice_points desc, e.rating desc;
