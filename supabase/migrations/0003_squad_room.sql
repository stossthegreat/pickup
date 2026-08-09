-- ══════════════════════════════════════════════════════════════════════
--  0003 — Squad Room: the Week Grid + the Pulse feed.
--
--  · Week Grid needs squadmates to SEE each other's mission completions
--    (0001 correctly limited user_missions to owner-only reads). The
--    same_squad() helper opens reads to ACTIVE squadmates only.
--  · squad_events is the Pulse: joins, commits, completions, scores,
--    rank-ups — streamed to the room over Supabase Realtime.
--  Run after 0002. Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

-- SECURITY DEFINER so the check doesn't recurse through RLS.
create or replace function same_squad(other uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1
    from squad_members a
    join squad_members b on a.squad_id = b.squad_id
    where a.user_id = auth.uid() and b.user_id = other
      and a.status = 'active' and b.status = 'active'
  );
$$;

drop policy if exists "squadmates read completions" on user_missions;
create policy "squadmates read completions"
  on user_missions for select to authenticated
  using (same_squad(user_id));

-- ─────────────────────────────────────────────────────────────────────
--  THE PULSE — squad activity feed
-- ─────────────────────────────────────────────────────────────────────
create table if not exists squad_events (
  id         uuid primary key default gen_random_uuid(),
  squad_id   uuid not null references squads(id) on delete cascade,
  actor      uuid not null references profiles(id) on delete cascade,
  kind       text not null,   -- joined|committed|completed|scored|rankup|streak
  payload    jsonb,           -- e.g. {"mission":"...","score":8942}
  created_at timestamptz not null default now()
);
alter table squad_events enable row level security;

drop policy if exists "members read squad pulse" on squad_events;
create policy "members read squad pulse"
  on squad_events for select to authenticated
  using (is_squad_member(squad_id));

drop policy if exists "members post own pulse events" on squad_events;
create policy "members post own pulse events"
  on squad_events for insert to authenticated
  with check (auth.uid() = actor and is_squad_member(squad_id));

create index if not exists squad_events_feed_idx
  on squad_events (squad_id, created_at desc);

-- Stream the Pulse over Realtime (no-op if already added).
do $$ begin
  alter publication supabase_realtime add table squad_events;
exception when duplicate_object then null; end $$;
