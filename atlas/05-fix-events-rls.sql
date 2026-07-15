-- ============================================================================
--  05-fix-events-rls.sql
--
--  ROOT CAUSE FIX: cs_events RLS was blocking all anonymous inserts.
--
--  cs-track.js uses the anon key for every event (even when a user is logged
--  in on the page — the fetch uses the hardcoded anon key, not the session
--  token). The existing policy only allowed `authenticated` role to insert,
--  so 100% of events from every public tool were silently rejected by RLS.
--
--  Fix: add an anon INSERT policy. Keep SELECT restricted to authenticated
--  (so the raw event feed in the intelligence dashboard is not public).
--
--  Safe to re-run. Run this in Supabase SQL editor, then verify by
--  doing a search on pattern-dictionary.cultureschool.org and checking
--  the Live Events panel in the intelligence dashboard within 5 seconds.
-- ============================================================================

-- ── FIX: allow anon inserts ──────────────────────────────────────────────────
drop policy if exists "anon insert events" on public.cs_events;
create policy "anon insert events"
  on public.cs_events for insert
  to anon
  with check (true);

-- ── VERIFY: list all policies on cs_events ──────────────────────────────────
select policyname, roles, cmd, qual
from pg_policies
where tablename = 'cs_events'
order by policyname;
