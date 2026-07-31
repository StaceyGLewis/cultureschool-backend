-- RLS Hardening — closes broad `qual = true` policies on authenticated role
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Safe to re-run; uses DROP IF EXISTS before recreating.
--
-- Pattern: cs_can_read()  → SELECT (staff + admin)
--          cs_is_admin()  → INSERT / UPDATE / DELETE (admin only)
--
-- After running this, also go to:
--   Supabase Dashboard → Authentication → Settings
--   → Disable "Enable email signups" so no new accounts can be created

-- ── cs_creator_profiles ──────────────────────────────────────────
-- Old: "admin write creators" ALL true, "admin read creators" SELECT true
drop policy if exists "admin write creators"  on public.cs_creator_profiles;
drop policy if exists "admin read creators"   on public.cs_creator_profiles;

create policy "staff read creators"
  on public.cs_creator_profiles for select
  to authenticated using (cs_can_read());

create policy "admin insert creators"
  on public.cs_creator_profiles for insert
  to authenticated with check (cs_is_admin());

create policy "admin update creators"
  on public.cs_creator_profiles for update
  to authenticated using (cs_is_admin());

create policy "admin delete creators"
  on public.cs_creator_profiles for delete
  to authenticated using (cs_is_admin());


-- ── cs_museums ───────────────────────────────────────────────────
-- Old: "admin write museums" ALL true, "admin read museums" SELECT true
-- (keeps existing "staff read" cs_can_read(), "admin delete/update" cs_is_admin())
drop policy if exists "admin write museums"   on public.cs_museums;
drop policy if exists "admin read museums"    on public.cs_museums;

-- INSERT and UPDATE were covered by the broad ALL — restore them properly
create policy "admin insert museums"
  on public.cs_museums for insert
  to authenticated with check (cs_is_admin());

create policy "admin update museums"
  on public.cs_museums for update
  to authenticated using (cs_is_admin());


-- ── cs_trend_notes ───────────────────────────────────────────────
-- Old: "admin manage trend_notes" ALL true
drop policy if exists "admin manage trend_notes" on public.cs_trend_notes;

create policy "staff read trend_notes"
  on public.cs_trend_notes for select
  to authenticated using (cs_can_read());

create policy "admin insert trend_notes"
  on public.cs_trend_notes for insert
  to authenticated with check (cs_is_admin());

create policy "admin update trend_notes"
  on public.cs_trend_notes for update
  to authenticated using (cs_is_admin());

create policy "admin delete trend_notes"
  on public.cs_trend_notes for delete
  to authenticated using (cs_is_admin());


-- ── cs_field_events ──────────────────────────────────────────────
-- Old: "admin manage field_events" ALL true
-- (keeps existing "staff read" cs_can_read(), "admin delete/update" cs_is_admin())
drop policy if exists "admin manage field_events" on public.cs_field_events;

-- INSERT was covered by the broad ALL — restore it properly
create policy "admin insert field_events"
  on public.cs_field_events for insert
  to authenticated with check (cs_is_admin());


-- ── cs_kg_entries ────────────────────────────────────────────────
-- Old: "kg_entries_auth_read" SELECT true, "kg_entries_auth_update" UPDATE true
-- (Public published read policy stays — it's correct)
drop policy if exists "kg_entries_auth_read"   on public.cs_kg_entries;
drop policy if exists "kg_entries_auth_update" on public.cs_kg_entries;

create policy "staff read kg_entries"
  on public.cs_kg_entries for select
  to authenticated using (cs_can_read());

create policy "admin update kg_entries"
  on public.cs_kg_entries for update
  to authenticated using (cs_is_admin());


-- ── cs_kg_places ─────────────────────────────────────────────────
-- Old: "kg_places_auth_read" SELECT true, "kg_places_auth_update" UPDATE true
drop policy if exists "kg_places_auth_read"    on public.cs_kg_places;
drop policy if exists "kg_places_auth_update"  on public.cs_kg_places;

create policy "staff read kg_places"
  on public.cs_kg_places for select
  to authenticated using (cs_can_read());

create policy "admin update kg_places"
  on public.cs_kg_places for update
  to authenticated using (cs_is_admin());


-- ── Verification query ───────────────────────────────────────────
-- Run this after the above to confirm no `qual = true` remain
-- (should return 0 rows for authenticated-role policies):
--
-- select tablename, policyname, cmd, qual
-- from pg_policies
-- where schemaname = 'public'
--   and roles && '{authenticated}'::name[]
--   and qual = 'true'
-- order by tablename;
