-- ══════════════════════════════════════════════════════════════════════
--  0011 — Two holes in identity, closed.
--
--  1 · HANDLES WERE ONLY CASE-SENSITIVELY UNIQUE
--      profiles.handle carried a plain UNIQUE, so "Marcus", "marcus" and
--      "MARCUS" were three different people. On a board where the whole
--      point is that a name means a man, that's an impersonation hole:
--      anyone could sit next to the top player under a name nobody can
--      tell apart at a glance. Trailing spaces did the same job.
--
--  2 · A MAN COULD BE IN SEVERAL SQUADS AT ONCE
--      join_squad_by_code only checked membership of the squad being
--      joined, so entering a second code just added you to a second
--      squad. Everything downstream assumes one: mySquad() takes
--      whichever row comes back first, so his moves would land on an
--      arbitrary board, his squadmates would see a man who is scored
--      somewhere else, and the room's numbers stop meaning anything.
--
--  Squad NAMES stay non-unique on purpose. You join a squad by CODE, so
--  two squads called THE BOYS can never misdirect anyone — and forcing
--  global uniqueness would just mean the hundredth man can't use the
--  obvious name for his own private group of four.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

-- ── 1 · One name, however you capitalise it ──────────────────────────
-- Normalise what's already there so the index can be built. Trailing
-- and leading whitespace goes too — " Jake" was a separate handle.
update profiles set handle = btrim(handle) where handle <> btrim(handle);

-- Any genuine collisions that predate this (same name, different case)
-- keep the OLDEST claim and the later ones are released rather than
-- deleted, so nobody loses their account — they just pick again.
with dupes as (
  select id,
         row_number() over (
           partition by lower(handle) order by created_at asc
         ) as rn
  from profiles
  where handle is not null
)
update profiles p set handle = null
from dupes d
where p.id = d.id and d.rn > 1;

create unique index if not exists profiles_handle_lower_idx
  on profiles (lower(handle));

-- ── 2 · One active squad per man ─────────────────────────────────────
-- Retire any extra memberships before the constraint lands, keeping the
-- one he joined first.
with extra as (
  select squad_id, user_id,
         row_number() over (
           partition by user_id order by joined_at asc
         ) as rn
  from squad_members
  where status = 'active'
)
update squad_members m set status = 'left'
from extra e
where m.squad_id = e.squad_id and m.user_id = e.user_id and e.rn > 1;

create unique index if not exists squad_members_one_active_idx
  on squad_members (user_id) where status = 'active';

-- ── The join, re-cut ─────────────────────────────────────────────────
-- Now refuses a second squad with a message the client can show,
-- rather than letting the unique index throw something unreadable.
-- Leaving is deliberate and already has its own button; being silently
-- moved out of your squad by typing a code is not something anyone
-- should be able to do to you by accident.
create or replace function join_squad_by_code(code text)
returns table (id uuid, name text, invite_code text)
language plpgsql security definer set search_path = public as $$
declare
  s record;
  member_count int;
begin
  select sq.id, sq.name, sq.invite_code into s
    from squads sq where sq.invite_code = upper(btrim(code));
  if not found then
    raise exception 'invalid invite code';
  end if;

  -- Already in THIS squad → hand the row back instead of raising, so
  -- re-entering your own code is a harmless no-op.
  if exists (
    select 1 from squad_members m
    where m.squad_id = s.id and m.user_id = auth.uid() and m.status = 'active'
  ) then
    return query select s.id, s.name, s.invite_code;
    return;
  end if;

  -- Already in a DIFFERENT squad → stop. One man, one room.
  if exists (
    select 1 from squad_members m
    where m.user_id = auth.uid() and m.status = 'active'
  ) then
    raise exception 'already in a squad';
  end if;

  select count(*) into member_count
    from squad_members
    where squad_id = s.id and status = 'active';
  if member_count >= 5 then
    raise exception 'squad is full';
  end if;

  insert into squad_members (squad_id, user_id, role)
    values (s.id, auth.uid(), 'member')
    on conflict (squad_id, user_id)
    do update set status = 'active';

  return query select s.id, s.name, s.invite_code;
end; $$;

revoke all on function join_squad_by_code(text) from public;
grant execute on function join_squad_by_code(text) to authenticated;
