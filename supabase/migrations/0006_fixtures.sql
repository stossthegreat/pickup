-- ══════════════════════════════════════════════════════════════════════
--  0006 — FIXTURES (the fantasy-football mechanic).
--
--  Every week, each squad member is paired against ONE squadmate.
--  The score is their weekly league points (dailies + sessions +
--  battles all feed it), head to head, locking with the league on
--  Sunday 21:00 UTC. Settled lazily; winners collect a career W.
--  Run after 0005.
-- ══════════════════════════════════════════════════════════════════════

create table if not exists fixtures (
  id         uuid primary key default gen_random_uuid(),
  week_start date not null,
  squad_id   uuid not null references squads(id) on delete cascade,
  player_a   uuid not null references profiles(id) on delete cascade,
  player_b   uuid not null references profiles(id) on delete cascade,
  winner     uuid references profiles(id) on delete set null,
  settled    boolean not null default false,
  created_at timestamptz not null default now()
);
alter table fixtures enable row level security;

drop policy if exists "squadmates read fixtures" on fixtures;
create policy "squadmates read fixtures"
  on fixtures for select to authenticated
  using (is_squad_member(squad_id));
-- pairing + settlement: service role only (the Edge Function referees).

create index if not exists fixtures_week_idx
  on fixtures (week_start, squad_id);

-- Career record, worn on profiles ("7W – 2L").
alter table profiles add column if not exists fixture_wins   int not null default 0;
alter table profiles add column if not exists fixture_losses int not null default 0;
