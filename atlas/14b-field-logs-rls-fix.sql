-- ============================================================================
--  14b-field-logs-rls-fix.sql
--
--  Run this if the Field Logs module shows a permissions / schema error
--  despite the table existing. Checks RLS state and installs anon policies.
--
--  Step 1: Run the SELECT below to see what's there.
--  Step 2: If rowsecurity = true but policies list is empty, run Step 2.
-- ============================================================================

-- ── STEP 1: Diagnose ─────────────────────────────────────────────────────────
select 'rls_status' as check,
       tablename,
       rowsecurity::text as rls_enabled
from   pg_tables
where  tablename = 'cs_field_logs'

union all

select 'policy' as check,
       policyname as tablename,
       cmd as rls_enabled
from   pg_policies
where  tablename = 'cs_field_logs';


-- ── STEP 2: Drop and recreate policies cleanly ───────────────────────────────
-- (safe to run even if policies don't exist yet)

drop policy if exists "anon read field logs"   on public.cs_field_logs;
drop policy if exists "anon insert field logs" on public.cs_field_logs;
drop policy if exists "anon update field logs" on public.cs_field_logs;

create policy "anon read field logs"
  on public.cs_field_logs
  for select
  to anon
  using (true);

create policy "anon insert field logs"
  on public.cs_field_logs
  for insert
  to anon
  with check (true);

create policy "anon update field logs"
  on public.cs_field_logs
  for update
  to anon
  using (true);

-- ── VERIFY ───────────────────────────────────────────────────────────────────
select policyname, cmd, roles
from   pg_policies
where  tablename = 'cs_field_logs'
order  by cmd;
-- Expected: 3 rows — SELECT, INSERT, UPDATE — all with roles = {anon}
