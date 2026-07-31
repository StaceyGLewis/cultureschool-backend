-- ============================================================================
--  11-fix-palette-trends-view.sql
--
--  Fixes cs_dash_growing_palettes so it actually returns data.
--
--  Root cause: the original view filtered on entity_slug is not null, but
--  palette_view events fired from all CoCo surfaces pass the palette UUID as
--  entity_id (not entity_slug). The view returned zero rows for every palette.
--
--  Fix: group by coalesce(entity_id, entity_slug), left-join palettes table
--  for a human-readable name, and expose palette_id + palette_name columns.
--
--  The dashboard panel (intelligence-platform.html) already calls this view
--  under the variable G — dashPalettePanel() now uses palette_name + palette_id.
--
--  Safe to re-run (create or replace). Run in Supabase SQL Editor.
-- ============================================================================

drop view if exists public.cs_dash_growing_palettes;
create view public.cs_dash_growing_palettes as
with base as (
  select
    coalesce(e.entity_id::text, e.entity_slug) as pal_key,
    e.created_at
  from public.cs_events e
  where e.event_type = 'palette_view'
    and (e.entity_id is not null or e.entity_slug is not null)
    and e.created_at >= now() - interval '90 days'
)
select
  b.pal_key                                                                as palette_id,
  coalesce(p.name, b.pal_key, '—')                                        as palette_name,
  count(*) filter (where b.created_at >= now() - interval '7 days')       as this_week,
  count(*) filter (where b.created_at >= now() - interval '14 days'
                     and b.created_at <  now() - interval '7 days')       as last_week,
  count(*)                                                                 as total
from base b
left join public.palettes p on cast(p.id as text) = b.pal_key
group by b.pal_key, p.name
order by this_week desc
limit 20;


-- ── VERIFICATION ─────────────────────────────────────────────────────────────
--
-- Run after deploying to confirm data flows:
--
--   select palette_name, this_week, last_week, total
--   from public.cs_dash_growing_palettes
--   limit 10;
--
-- If still empty, check that palette_view events have entity_id populated:
--
--   select entity_id, entity_slug, count(*)
--   from public.cs_events
--   where event_type = 'palette_view'
--   group by entity_id, entity_slug
--   order by count(*) desc
--   limit 10;
