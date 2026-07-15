-- Fix cs_dash_trending_prints to include pattern dictionary views
-- (dictionary fires entity_type='atlas_entry'; broadening to capture those too)
-- Run in Supabase SQL editor.

drop view if exists public.cs_dash_trending_prints;

create view public.cs_dash_trending_prints
  with (security_invoker = true)
as
select
  coalesce(entity_slug, entity_id::text)                                     as pattern_slug,
  entity_id                                                                   as pattern_id,
  entity_type,
  count(*) filter (where created_at >= now() - interval '7 days')            as this_week,
  count(*)                                                                    as total
from public.cs_events
where event_type in ('pattern_view', 'view')
  and entity_type in ('pattern', 'atlas_entry')
  and entity_slug is not null
  and created_at >= now() - interval '30 days'
group by entity_slug, entity_id, entity_type
order by this_week desc, total desc
limit 30;
