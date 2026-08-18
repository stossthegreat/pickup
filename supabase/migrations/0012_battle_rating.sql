-- ═══════════════════════════════════════════════════════════════════════
--  0012 — SPLIT THE RATING IN TWO
-- ═══════════════════════════════════════════════════════════════════════
--
-- THE FAULT. rizz_elo.rating was written by two unrelated systems:
--
--   · score-voice   drifts it toward the rating a solo voice session
--                   implies — up to ±40 EVERY session
--   · battle-action swings it on the result of a duel
--
-- One column, two meanings. A man who never fought anyone climbed the
-- "competitive" ladder by doing his daily; a man who fought and won saw
-- his gain wiped out by a mediocre practice run an hour later. And
-- because the client named tiers off that column, two good voice
-- sessions promoted his IDENTITY — he read INITIATE on Home while every
-- ascension surface still called him OBSERVER, and both were right.
--
-- THE FIX. Two columns, two meanings, no overlap:
--
--   rating         VOICE RATING. How well he speaks. Ranks the voice
--                  leaderboard. Still written by score-voice only.
--
--   battle_rating  RIZZ RATING (RR). Moved by duels and NOTHING else,
--                  which is rule 1 of economy.dart and the only reason
--                  a ladder is worth climbing. Drives the BRONZE III →
--                  LEGEND I divisions. Written by battle-action only.
--
-- Everyone starts level at 1000 so nobody's existing standing is
-- destroyed — but from here the two numbers move independently, and
-- neither can be farmed with the other's activity.
--
-- SAFE TO RE-RUN.

alter table public.rizz_elo
  add column if not exists battle_rating int not null default 1000,
  add column if not exists battle_peak   int not null default 1000,
  add column if not exists battles_won   int not null default 0,
  add column if not exists battles_lost  int not null default 0;

-- Seed the battle rating from the existing one ONCE, for anyone already
-- on the ladder. Guarded on the default so a re-run can't overwrite a
-- rating someone has since earned in a duel.
update public.rizz_elo
   set battle_rating = rating,
       battle_peak   = greatest(rating, 1000)
 where battle_rating = 1000
   and rating <> 1000;

comment on column public.rizz_elo.rating is
  'VOICE RATING — written by score-voice only. Ranks the voice board.';
comment on column public.rizz_elo.battle_rating is
  'RIZZ RATING (RR) — written by battle-action only. Drives divisions.';

-- The voice board is unchanged and still ranks on `rating`; it is
-- recreated here only so a fresh database gets it in the right shape.
--
-- security_invoker IS NOT OPTIONAL HERE. 0001 created this view with it,
-- and CREATE OR REPLACE VIEW rewrites the view's options as well as its
-- body — omitting the clause does not inherit the old setting, it resets
-- it. Without it the view runs as its owner, which is a superuser, and a
-- board that ignores RLS is the one place a leak actually ships.
create or replace view public.leaderboard_global
  with (security_invoker = true) as
  select p.id,
         p.handle,
         p.avatar_url,
         e.rating,
         e.tier
    from public.rizz_elo e
    join public.profiles p on p.id = e.user_id
   order by e.rating desc;

-- THE DUEL BOARD. Ranked on wins, then win rate, then RR — wins first
-- on purpose, because a rate-first board is topped by whoever has
-- played least, which is the opposite of what a ladder should reward.
--
-- Dropped first rather than replaced. This is the newest definition of
-- this view, so it owns the shape — and a column added here later would
-- otherwise fail exactly the way 0009 did, with 42P16.
drop view if exists public.battle_leaderboard;
create view public.battle_leaderboard
  with (security_invoker = true) as
  select p.id,
         p.handle,
         p.avatar_url,
         e.battle_rating,
         e.battles_won,
         e.battles_lost,
         (e.battles_won + e.battles_lost) as battles
    from public.rizz_elo e
    join public.profiles p on p.id = e.user_id
   where (e.battles_won + e.battles_lost) > 0
   order by e.battles_won desc,
            case when (e.battles_won + e.battles_lost) = 0 then 0
                 else e.battles_won::numeric
                      / (e.battles_won + e.battles_lost) end desc,
            e.battle_rating desc;

-- The grant lets them address the view; RLS on rizz_elo still decides
-- what comes back, and that table is readable by authenticated only. So
-- anon can query this board and gets an empty list, which is the right
-- answer for an app nobody uses signed out.
grant select on public.battle_leaderboard to anon, authenticated;
