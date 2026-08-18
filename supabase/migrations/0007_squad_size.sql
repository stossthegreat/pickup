-- ══════════════════════════════════════════════════════════════════════
--  0007 — SQUAD SIZE: maximum 5.
--
--  0002 capped squads at 8. Five is the real ceiling: past that a squad
--  stops being a handful of men who each feel personally responsible and
--  becomes a crowd where nobody's absence is noticed — which is the
--  entire mechanism the feature runs on.
--
--  This has to live in the database, not the client. join_squad_by_code
--  is SECURITY DEFINER and runs with elevated rights, so a replayed
--  request would walk straight past any check the app makes.
--
--  TWO is the minimum to SCORE a day, and that rule deliberately stays
--  in the client: a one-man squad is legal (you just made it and haven't
--  recruited yet), it simply doesn't post a Squad Form until someone
--  joins. That's a display rule, not an integrity rule.
--
--  Signature, return type and role value are kept EXACTLY as 0002 left
--  them — the client reads id/name/invite_code from the result, and
--  Postgres refuses to `create or replace` a function whose return type
--  changed. Only the number moved.
--
--  Safe to re-run.
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

  -- Already a member → hand the row back instead of raising, so
  -- re-entering your own code is a harmless no-op rather than an error
  -- the user has to decode.
  if exists (
    select 1 from squad_members m
    where m.squad_id = s.id and m.user_id = auth.uid() and m.status = 'active'
  ) then
    return query select s.id, s.name, s.invite_code;
    return;
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
