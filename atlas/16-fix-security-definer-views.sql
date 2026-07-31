-- ============================================================================
--  16-fix-security-definer-views.sql
--
--  Fixes "Security Definer View" linter errors flagged by Supabase.
--  Views created via the Supabase UI are SECURITY DEFINER by default —
--  they bypass RLS and run as the view creator (postgres role).
--
--  Fix: set security_invoker = on so views run as the querying user,
--  respecting that user's RLS policies.
--
--  Run this entire file in one go in the Supabase SQL Editor.
-- ============================================================================

-- ── 1. Fix SECURITY DEFINER on all flagged views ─────────────────────────────

alter view public.cs_dash_field_logs        set (security_invoker = on);
alter view public.cs_maker_network_detail   set (security_invoker = on);
alter view public.cs_atlas_makers           set (security_invoker = on);
alter view public.cs_atlas_featured         set (security_invoker = on);
alter view public.cs_palette_context        set (security_invoker = on);
alter view public.cs_dash_growing_palettes  set (security_invoker = on);
alter view public.cs_dash_geography         set (security_invoker = on);


-- ── 2. Re-confirm anon RLS on cs_field_logs ──────────────────────────────────
-- (safe to re-run — drop is idempotent)

drop policy if exists "anon read field logs"   on public.cs_field_logs;
drop policy if exists "anon insert field logs" on public.cs_field_logs;
drop policy if exists "anon update field logs" on public.cs_field_logs;

create policy "anon read field logs"
  on public.cs_field_logs for select to anon using (true);

create policy "anon insert field logs"
  on public.cs_field_logs for insert to anon with check (true);

create policy "anon update field logs"
  on public.cs_field_logs for update to anon using (true);


-- ── 3. Grant SELECT on cs_field_logs to anon explicitly ──────────────────────
-- RLS policies alone don't override missing table-level grants.

grant select on public.cs_field_logs to anon;
grant select on public.cs_dash_field_logs to anon;


-- ── 4. Verify ────────────────────────────────────────────────────────────────

select policyname, cmd, roles
from   pg_policies
where  tablename = 'cs_field_logs'
order  by cmd;
-- Expected: 3 rows — INSERT, SELECT, UPDATE — all with roles = {anon}

select count(*) as total_field_logs from public.cs_field_logs;
-- Expected: 2+ rows (your real logs, or 5 if seed was run)
