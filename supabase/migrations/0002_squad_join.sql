-- ══════════════════════════════════════════════════════════════════════
--  0002 — join a squad by invite code.
--
--  RLS (correctly) stops a non-member from reading squads, so a joiner
--  can't even look a squad up by its code. This SECURITY DEFINER
--  function is the single sanctioned door: it resolves the code,
--  enforces the size cap, inserts the membership, and returns the squad.
--  Run after 0001. Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

create or replace function join_squad_by_code(code text)
returns table (id uuid, name text, invite_code text)
language plpgsql security definer set search_path = public as $$
declare
  s squads%rowtype;
  member_count int;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;

  select * into s from squads where squads.invite_code = code;
  if not found then
    raise exception 'invalid invite code';
  end if;

  select count(*) into member_count
    from squad_members
    where squad_id = s.id and status = 'active';
  if member_count >= 8 then
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
