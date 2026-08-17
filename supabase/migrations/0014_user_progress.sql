-- ══════════════════════════════════════════════════════════════════════
--  0014 — THE THING THE APP ALREADY PROMISED
--
--  account_screen.dart tells every user, in two places:
--
--    "your rank, streak and squad die with a lost phone. Claim them
--     in one tap"
--    "Rank, streak and squad now survive a lost phone or a reinstall."
--
--  Neither was true. The squad survived because squad_members is a
--  table; the boards survived because rizz_elo and chat_score are
--  tables. XP and the streak lived in SharedPreferences and died with
--  the handset no matter what anyone signed in with.
--
--  That matters more here than in most apps. The whole retention engine
--  is loss aversion — shields, rescues, DAY WON, "63 days on the line."
--  Building a machine whose job is making a man afraid to lose his run,
--  and then letting a new phone take it for free, is the one bug that
--  turns the best user into the angriest one.
--
--  ── WHY THIS IS A MIRROR, NOT A SOURCE OF TRUTH ─────────────────────
--
--  The app still reads XP and streak from local storage on every frame,
--  and it must: they're on the masthead, they gate the roster, and they
--  have to work on a plane. This table is a backup that gets written
--  after the fact and read exactly once, at sign-in.
--
--  So it is deliberately NOT authoritative and deliberately NOT used
--  for any board. A device could lie to it. Nothing that decides rank
--  against other men is stored here — that stays in rizz_elo and
--  chat_score, which only the service role can write. The worst a
--  tampered row can do is give its own owner a bigger number on his own
--  phone, which he could already do by editing his own prefs.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

create table if not exists user_progress (
  user_id      uuid primary key references profiles(id) on delete cascade,

  -- Total XP. Drives level, and level alone.
  xp           int not null default 0,

  -- Live run and the best ever reached. Both, because the app shows
  -- "LONGEST 41" beside a current 12 and restoring one without the
  -- other would quietly erase a personal best.
  streak       int not null default 0,
  best_streak  int not null default 0,

  -- Earned ascension days — the RANK ladder (OBSERVER → BECOME HIM).
  -- A separate number from the streak by design; see standing.dart.
  earned_days  int not null default 0,

  updated_at   timestamptz not null default now()
);

alter table user_progress enable row level security;

-- HIS OWN ROW, AND ONLY HIS OWN — read and write.
--
-- Unlike every other ladder in this schema, the client writes this one.
-- That's safe for the reason in the header: nothing here ranks him
-- against anybody. It is his own progress, mirrored so he can get it
-- back, and the `with check` on both policies pins every write to the
-- authenticated user's own id.
drop policy if exists "own progress readable" on user_progress;
create policy "own progress readable"
  on user_progress for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "own progress writable" on user_progress;
create policy "own progress writable"
  on user_progress for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "own progress updatable" on user_progress;
create policy "own progress updatable"
  on user_progress for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- No index beyond the primary key on purpose. This table is only ever
-- touched by `where user_id = auth.uid()`, which the PK already serves,
-- and it is never sorted or scanned — it feeds no leaderboard.
