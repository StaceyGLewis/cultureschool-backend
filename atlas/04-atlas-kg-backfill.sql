-- ============================================================================
--  04-atlas-kg-backfill.sql
--
--  Links cs_atlas_entries.entry_id → cs_kg_entries for the 24 entries
--  that exist in both tables (same slug). Currently all 47 Atlas rows
--  have entry_id = NULL, so KG enrichment in the admin falls back to
--  slug-based lookup every time — this makes it permanent and queryable.
--
--  Also answers Open Question 1 from the brief:
--  - entry_id IS the intended join (it's the FK in 005_atlas_layer.sql)
--  - Backfill: match on slug (unique in both tables)
--  - New KG entries → Atlas: manual editorial act (no trigger), consistent
--    with "nothing publishes automatically"
--
--  After this runs, the admin can surface "linked / unlinked" status and
--  the txOpenEntry() view can use entry_id directly instead of slug lookup.
-- ============================================================================

-- ── DRY RUN: see what will be linked ───────────────────────────────────────
select
  a.id           as atlas_id,
  a.name         as atlas_name,
  a.slug,
  a.entry_id     as current_entry_id,
  k.id           as kg_id,
  k.name         as kg_name,
  k.entry_type   as kg_entry_type,
  k.source_status as kg_status
from public.cs_atlas_entries a
join public.cs_kg_entries k on k.slug = a.slug
where a.entry_id is null
order by a.name;

-- ── DRY RUN: Atlas entries with NO matching KG entry (will stay unlinked) ──
select a.id, a.name, a.slug
from public.cs_atlas_entries a
left join public.cs_kg_entries k on k.slug = a.slug
where a.entry_id is null
  and k.id is null
order by a.name;

-- ── APPLY: link the 24 matching entries ─────────────────────────────────────
update public.cs_atlas_entries a
set
  entry_id   = k.id,
  updated_at = now()
from public.cs_kg_entries k
where k.slug    = a.slug
  and a.entry_id is null;

-- ── VERIFY ──────────────────────────────────────────────────────────────────
select
  count(*) filter (where entry_id is not null) as linked,
  count(*) filter (where entry_id is null)     as unlinked,
  count(*)                                     as total
from public.cs_atlas_entries;

-- ── ALSO: update cs_atlas_search view to expose entry_id ──────────────────
-- The existing view in 010_intelligence_schema.sql doesn't include entry_id.
-- Recreate it with entry_id so the admin can filter by link status.
drop view if exists public.cs_atlas_search;
create view public.cs_atlas_search
  with (security_invoker = true)
as
select
  e.id,
  e.entry_id,
  e.name,
  e.slug,
  e.dictionary_style,
  e.entry_type,
  e.short_definition,
  e.sensitivity_level,
  e.source_status,
  e.is_public,
  e.is_living,
  e.reviewed_by,
  e.researched_by,
  e.sources_verified,
  e.updated_at,
  (select count(*) from public.cs_atlas_distinctions d
   where d.atlas_entry_id = e.id)                  as distinction_count,
  (select count(*) from public.cs_atlas_practice p
   where p.atlas_entry_id = e.id and p.is_public)  as practitioner_count
from public.cs_atlas_entries e;
