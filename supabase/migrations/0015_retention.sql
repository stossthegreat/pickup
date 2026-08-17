-- ══════════════════════════════════════════════════════════════════════
--  0015 — RETENTION. Four tables in this schema grow forever.
--
--  Everything else is one row per user and stops growing when signups
--  do. These four get a row per ACTION, are never deleted from, and at
--  any real scale become the largest objects in the database:
--
--    chat_attempts    every graded text, with a jsonb rubric attached
--    voice_sessions   every call
--    daily_attempts   one per user per day
--    battles          every duel, kept after it settles
--
--  At 500k users and a conservative 10% daily active, chat_attempts
--  alone lands somewhere around 36M rows a year. With its rubric and
--  its three indexes that is tens of gigabytes of rows nothing reads.
--
--  ── AND NOTHING DOES READ THEM ──────────────────────────────────────
--
--  That's the part that makes this safe. Every board in the app reads
--  an AGGREGATE table, never the attempts:
--
--    chat_leaderboard    → chat_score   (points, best, attempts, average)
--    leaderboard_global  → rizz_elo     (rating)
--    battle_leaderboard  → rizz_elo     (battle_rating, wins, losses)
--
--  Those aggregates are maintained on write by the Edge Functions and
--  are untouched by anything here. The attempt rows exist to produce
--  them and to back the recent-history lists, and no screen in the app
--  looks further back than a few weeks.
--
--  So: keep 90 days, drop the rest. Nothing on screen changes. Deleting
--  an attempt does NOT change anyone's points, best, rating or record.
--
--  ── WHY DELETE RATHER THAN LET IT COST A FEW POUNDS ─────────────────
--
--  Storage overage is genuinely cheap and is not the reason. The reason
--  is that a table nobody prunes gets slower for everybody: indexes
--  bloat, autovacuum takes longer and holds resources while it runs,
--  the planner's estimates drift, and every backup and restore carries
--  years of dead weight. The bill is an afterthought; the tail latency
--  is the problem.
--
--  Safe to re-run — pg_cron.schedule() upserts by job name.
-- ══════════════════════════════════════════════════════════════════════

create extension if not exists pg_cron with schema extensions;

-- ── The prune ─────────────────────────────────────────────────────────
--
-- SECURITY DEFINER so the scheduler can delete rows the cron role has
-- no RLS grant for. search_path is pinned — a SECURITY DEFINER function
-- with a mutable search_path is a genuine privilege-escalation hole,
-- since anything it calls unqualified could be shadowed by a table the
-- caller controls.
create or replace function public.prune_history()
  returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  cutoff timestamptz := now() - interval '90 days';
begin
  -- Attempts and sessions: pure history, aggregates already banked.
  delete from chat_attempts  where created_at < cutoff;
  delete from voice_sessions where created_at < cutoff;
  delete from daily_attempts where created_at < cutoff;

  -- Battles only once SETTLED. An unsettled duel is an open loop the
  -- app is still waiting on — a rival who hasn't answered — and
  -- deleting one would strand the other player mid-fight forever. Age
  -- is not enough on its own here.
  delete from battles
   where created_at < cutoff
     and state = 'scored';

  -- Squad feed. Read only as "what happened while you were gone", and
  -- nothing looks back past a week, so this one is aggressive.
  delete from squad_events
   where created_at < now() - interval '30 days';
end;
$$;

revoke all on function public.prune_history() from public, anon, authenticated;

-- 04:00 UTC daily — off the back of the quietest hour, and well clear
-- of the day roll that decides streaks.
select cron.schedule(
  'prune-history',
  '0 4 * * *',
  $$select public.prune_history();$$
);
