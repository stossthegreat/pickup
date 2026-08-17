-- ══════════════════════════════════════════════════════════════════════
--  0009 — CHAT SCORES. Real numbers for text, the way voice already has.
--
--  Until now an AI text mission paid a FLAT +50 XP whether you wrote
--  something devastating or mashed "hey". That makes a text leaderboard
--  impossible — everyone who finishes is identical — and it quietly
--  teaches people that effort doesn't matter, which is the opposite of
--  the whole product.
--
--  So text gets graded on its own rubric and stored per attempt. It is
--  deliberately a SEPARATE ladder from voice:
--
--    voice  →  rizz_elo       competitive ELO, moves only on voice
--    chat   →  chat_score     best-of, moves only on text
--
--  Mixing them would let someone grind text to a voice rank they never
--  earned, and the two skills genuinely aren't the same thing.
--
--  Scores are written by the score-chat Edge Function under the service
--  role. There is deliberately NO client insert/update policy — exactly
--  like rizz_elo — so a phone can't write its own number.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

-- ── Every graded text attempt ─────────────────────────────────────────
create table if not exists chat_attempts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  surface    text not null default 'roleplay', -- roleplay | rizz | mission
  scenario   text,
  score      int not null,                     -- 0..100, the real number
  rubric     jsonb,                            -- per-axis breakdown
  created_at timestamptz not null default now()
);
alter table chat_attempts enable row level security;

-- Scores are public sport, same as daily_attempts — a board needs them.
drop policy if exists "chat attempts readable" on chat_attempts;
create policy "chat attempts readable"
  on chat_attempts for select to authenticated using (true);
-- No insert/update policy: the Edge Function (service role) is the only
-- writer. RLS denies by default, so this is the whole enforcement.

create index if not exists chat_attempts_user_idx
  on chat_attempts (user_id, created_at desc);
create index if not exists chat_attempts_board_idx
  on chat_attempts (score desc);

-- ── The standing: best score + how many attempts ─────────────────────
create table if not exists chat_score (
  user_id    uuid primary key references profiles(id) on delete cascade,
  best       int not null default 0,
  attempts   int not null default 0,
  average    int not null default 0,
  updated_at timestamptz not null default now()
);
alter table chat_score enable row level security;

drop policy if exists "chat score readable" on chat_score;
create policy "chat score readable"
  on chat_score for select to authenticated using (true);
-- Server-write only, as above.

-- ── The board ─────────────────────────────────────────────────────────
-- security_invoker so it runs as the caller and can't leak anything the
-- caller couldn't already read.
--
-- CREATED ONLY IF IT ISN'T THERE, and that guard is the whole point.
-- 0010 drops this view and rebuilds it on the points ladder with three
-- extra columns. Postgres CREATE OR REPLACE VIEW can only APPEND columns
-- — it cannot remove or rename one — so re-running this file against a
-- database that already has 0010's nine-column view fails with 42P16,
-- "cannot drop columns from view".
--
-- A plain `drop view if exists` here would fix the error and cause a
-- worse one: it would quietly demote the board back to the six-column
-- shape and the points ladder would read empty. So the rule is that the
-- LATEST migration owns the view, and an older one never overwrites a
-- newer definition — it just steps aside.
do $chat_board$
begin
  if to_regclass('public.chat_leaderboard') is null then
    execute $v$
      create view chat_leaderboard
        with (security_invoker = true) as
        select p.id, p.handle, p.avatar_url, c.best, c.attempts, c.average
        from chat_score c
        join profiles p on p.id = c.user_id
        where c.attempts > 0
        order by c.best desc
    $v$;
  end if;
end
$chat_board$;
