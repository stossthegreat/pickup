-- ══════════════════════════════════════════════════════════════════════
--  0008 — a squad's creator can read it.
--
--  THE BUG. 0001 shipped these two together:
--
--    insert:  with check (auth.uid() = created_by)     -- creator may write
--    select:  using (is_squad_member(id))              -- members may read
--
--  Individually correct, jointly broken. The client created a squad with
--  `.insert(...).select().single()`, and PostgREST runs that RETURNING
--  clause through the SELECT policy. At that instant the creator is NOT
--  a member — the squad_members insert is the very next statement — so
--  the row was written and then read back as zero rows. .single() threw,
--  the catch swallowed it, and FOUND A SQUAD did nothing at all. No
--  error, no squad on screen, nothing to act on.
--
--  The client no longer asks for the row back (it mints the uuid itself),
--  so the button works with or without this migration. But the policy is
--  still wrong, and it would bite again the moment any other code path
--  reads a squad before joining it — checking a code before committing,
--  a preview, an admin view.
--
--  A creator reading their own squad is exactly as safe as a member
--  reading it: created_by is set by the insert policy to auth.uid() and
--  cannot be forged.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

drop policy if exists "members read their squads" on squads;
create policy "members read their squads"
  on squads for select to authenticated
  using (is_squad_member(id) or created_by = auth.uid());
