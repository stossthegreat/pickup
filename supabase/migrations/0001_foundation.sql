-- ══════════════════════════════════════════════════════════════════════
--  ImHim Rizz — Supabase foundation schema  (Phase 1–2)
--  Run in Supabase → SQL Editor. Re-runnable (drops policies before create).
--
--  SECURITY MODEL (the important bit):
--   · Anything that affects RANK or SCORE (rizz_elo, voice_sessions.score,
--     battle results) is written ONLY by the server via the service-role
--     key. Clients can READ scores (for leaderboards) but never write them.
--   · Everything a user owns (their profile, their missions, their squad
--     membership) is guarded by row-level security on auth.uid().
--
--  Seasons, creator challenges (Ejay) and the Day-60 Companion are Phase 3+
--  and intentionally NOT in this migration — we validate the core loops first.
-- ══════════════════════════════════════════════════════════════════════

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────
--  PROFILES — one row per auth user, auto-created on signup
-- ─────────────────────────────────────────────────────────────────────
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  handle      text unique,
  avatar_url  text,
  gender      text,
  age         int,
  onboarded   boolean not null default false,
  ai_consent  boolean not null default false,
  created_at  timestamptz not null default now()
);
alter table profiles enable row level security;

drop policy if exists "profiles readable by authenticated" on profiles;
create policy "profiles readable by authenticated"
  on profiles for select to authenticated using (true);

drop policy if exists "users insert own profile" on profiles;
create policy "users insert own profile"
  on profiles for insert to authenticated with check (auth.uid() = id);

drop policy if exists "users update own profile" on profiles;
create policy "users update own profile"
  on profiles for update to authenticated using (auth.uid() = id);

-- auto-create the profile row the moment a user signs up (Apple/etc.)
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  insert into public.rizz_elo (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function handle_new_user();

-- ─────────────────────────────────────────────────────────────────────
--  RIZZ ELO — server-owned. Readable by all (leaderboards), never client-written.
-- ─────────────────────────────────────────────────────────────────────
create table if not exists rizz_elo (
  user_id     uuid primary key references profiles(id) on delete cascade,
  rating      int not null default 1000,
  tier        text not null default 'OBSERVER',
  peak        int not null default 1000,
  updated_at  timestamptz not null default now()
);
alter table rizz_elo enable row level security;

drop policy if exists "elo readable by authenticated" on rizz_elo;
create policy "elo readable by authenticated"
  on rizz_elo for select to authenticated using (true);
-- no insert/update policy → only the service role (server) can write ELO.

-- ─────────────────────────────────────────────────────────────────────
--  VOICE SESSIONS — every scored roleplay. Score set by the server.
-- ─────────────────────────────────────────────────────────────────────
create table if not exists voice_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  scenario    text,
  score       int,
  rubric      jsonb,
  created_at  timestamptz not null default now()
);
alter table voice_sessions enable row level security;

drop policy if exists "users read own voice sessions" on voice_sessions;
create policy "users read own voice sessions"
  on voice_sessions for select to authenticated using (auth.uid() = user_id);
-- inserts + scoring come from the server (service role bypasses RLS).
create index if not exists voice_sessions_user_idx
  on voice_sessions (user_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────
--  SQUADS + membership
-- ─────────────────────────────────────────────────────────────────────
create table if not exists squads (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  invite_code text unique not null,
  created_by  uuid references profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
alter table squads enable row level security;

create table if not exists squad_members (
  squad_id  uuid not null references squads(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
  role      text not null default 'member',
  status    text not null default 'active',
  joined_at timestamptz not null default now(),
  primary key (squad_id, user_id)
);
alter table squad_members enable row level security;

-- SECURITY DEFINER so it doesn't recurse through squad_members' own RLS.
create or replace function is_squad_member(sid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from squad_members
    where squad_id = sid and user_id = auth.uid() and status = 'active'
  );
$$;

drop policy if exists "users create squads" on squads;
create policy "users create squads"
  on squads for insert to authenticated with check (auth.uid() = created_by);

drop policy if exists "members read their squads" on squads;
create policy "members read their squads"
  on squads for select to authenticated using (is_squad_member(id));

drop policy if exists "members read squad roster" on squad_members;
create policy "members read squad roster"
  on squad_members for select to authenticated using (is_squad_member(squad_id));

drop policy if exists "users join squads themselves" on squad_members;
create policy "users join squads themselves"
  on squad_members for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "users leave squads themselves" on squad_members;
create policy "users leave squads themselves"
  on squad_members for delete to authenticated using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
--  MISSIONS — catalog (read-only to clients) + per-user progress
-- ─────────────────────────────────────────────────────────────────────
create table if not exists missions (
  id         uuid primary key default gen_random_uuid(),
  tier       int not null default 1,        -- escalation-ladder level
  category   text,                          -- 'conversation' | 'approach' | ...
  title      text not null,
  prompt     text not null,
  proof_type text default 'discord',        -- how completion is proven
  active     boolean not null default true
);
alter table missions enable row level security;

drop policy if exists "missions readable by authenticated" on missions;
create policy "missions readable by authenticated"
  on missions for select to authenticated using (active);

create table if not exists user_missions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  mission_id   uuid not null references missions(id) on delete cascade,
  state        text not null default 'assigned', -- assigned|committed|completed|skipped
  committed_at timestamptz,
  completed_at timestamptz,
  proof_ref    text,
  created_at   timestamptz not null default now()
);
alter table user_missions enable row level security;

drop policy if exists "users read own missions" on user_missions;
create policy "users read own missions"
  on user_missions for select to authenticated using (auth.uid() = user_id);

drop policy if exists "users insert own missions" on user_missions;
create policy "users insert own missions"
  on user_missions for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "users update own missions" on user_missions;
create policy "users update own missions"
  on user_missions for update to authenticated using (auth.uid() = user_id);

create index if not exists user_missions_user_idx
  on user_missions (user_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────
--  BATTLES + matchmaking queue  (code-link duels + random "line up")
-- ─────────────────────────────────────────────────────────────────────
create table if not exists battles (
  id          uuid primary key default gen_random_uuid(),
  scenario    text not null,
  mode        text not null default 'random',  -- random | code
  invite_code text unique,
  player_a    uuid references profiles(id) on delete set null,
  player_b    uuid references profiles(id) on delete set null,
  a_score     int,
  b_score     int,
  winner      uuid references profiles(id) on delete set null,
  state       text not null default 'open',     -- open | active | scored
  created_at  timestamptz not null default now()
);
alter table battles enable row level security;

drop policy if exists "battle players read their battles" on battles;
create policy "battle players read their battles"
  on battles for select to authenticated
  using (auth.uid() = player_a or auth.uid() = player_b);
-- creation, pairing and scoring are done server-side (service role).

create table if not exists battle_queue (
  user_id     uuid primary key references profiles(id) on delete cascade,
  enqueued_at timestamptz not null default now()
);
alter table battle_queue enable row level security;

drop policy if exists "users manage own queue entry" on battle_queue;
create policy "users manage own queue entry"
  on battle_queue for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
--  LEADERBOARD — safe read-only view (handle + score only; runs as caller)
-- ─────────────────────────────────────────────────────────────────────
create or replace view leaderboard_global
  with (security_invoker = true) as
  select p.id, p.handle, p.avatar_url, e.rating, e.tier
  from rizz_elo e
  join profiles p on p.id = e.user_id
  order by e.rating desc;
