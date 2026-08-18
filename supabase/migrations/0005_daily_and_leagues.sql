-- ══════════════════════════════════════════════════════════════════════
--  0005 — THE DAILY + LEAGUES (the Duolingo engine).
--
--  THE DAILY: one scenario per day, same worldwide, ONE attempt each.
--  LEAGUES:  weekly divisions of ~30. Top 10 promote, bottom 5 drop,
--            locks Sunday 21:00 UTC. Enrolment is automatic on any
--            scored activity — casual roleplayers appear in the game
--            without doing anything extra (Duolingo's trick).
--  All writes go through Edge Functions (service role). Run after 0004.
-- ══════════════════════════════════════════════════════════════════════

-- ── THE DAILY ─────────────────────────────────────────────────────────
create table if not exists daily_attempts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  ymd        int not null,            -- 20260810 (UTC day)
  scenario   text not null,           -- vibe key of the day
  score      int not null,
  rubric     jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, ymd)               -- ONE attempt. The whole point.
);
alter table daily_attempts enable row level security;

-- Scores are public sport (like rizz_elo) — today's board needs them.
drop policy if exists "daily attempts readable" on daily_attempts;
create policy "daily attempts readable"
  on daily_attempts for select to authenticated using (true);
-- inserts: service role only (the Edge Function is the referee).

create index if not exists daily_attempts_board_idx
  on daily_attempts (ymd, score desc);

-- ── LEAGUES ───────────────────────────────────────────────────────────
create table if not exists leagues (
  id         uuid primary key default gen_random_uuid(),
  week_start date not null,           -- the Monday (UTC)
  division   int not null default 1,  -- 1=ROOKIE .. 5=HIM LEAGUE
  created_at timestamptz not null default now()
);
alter table leagues enable row level security;

drop policy if exists "leagues readable" on leagues;
create policy "leagues readable"
  on leagues for select to authenticated using (true);

create table if not exists league_members (
  league_id uuid not null references leagues(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
  points    int not null default 0,
  settled   boolean not null default false, -- week-end verdict applied?
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);
alter table league_members enable row level security;

drop policy if exists "league members readable" on league_members;
create policy "league members readable"
  on league_members for select to authenticated using (true);
-- membership + points: service role only.

create index if not exists league_members_rank_idx
  on league_members (league_id, points desc);

-- Current division rides on the profile (persists across weeks).
alter table profiles add column if not exists division int not null default 1;
