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
create or replace view public.leaderboard_global as
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
create or replace view public.battle_leaderboard as
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

grant select on public.battle_leaderboard to anon, authenticated;
