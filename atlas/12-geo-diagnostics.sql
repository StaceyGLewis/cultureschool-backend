-- ============================================================================
--  12-geo-diagnostics.sql
--
--  Run these queries in Supabase SQL Editor to diagnose geographic tracking.
--  They do NOT modify anything — read-only.
-- ============================================================================

-- 1. How many events have a country_code vs null?
select
  country_code is not null as has_geo,
  count(*)                  as events
from public.cs_events
where created_at >= now() - interval '30 days'
group by has_geo
order by has_geo desc;

-- Expected after geo fix:
--   has_geo = true  → events logged AFTER deployment (should grow)
--   has_geo = false → events logged before geo fix (will never change)


-- 2. Which countries are we seeing? (same as cs_dash_geography, unfiltered)
select
  country_code,
  count(*)                                                          as events,
  count(distinct session_id)                                        as sessions,
  count(*) filter (where event_type = 'download')                   as downloads,
  count(*) filter (where event_type = 'search')                     as searches,
  min(created_at)::date                                             as first_seen
from public.cs_events
where country_code is not null
  and created_at >= now() - interval '90 days'
group by country_code
order by events desc
limit 20;


-- 3. Most recent 20 events — check if country_code is populating
select
  created_at,
  event_type,
  country_code,
  entity_slug,
  metadata->>'surface' as surface
from public.cs_events
order by created_at desc
limit 20;


-- 4. Geo events by surface — which CoCo surface is driving geo interest?
select
  metadata->>'surface'  as surface,
  country_code,
  count(*)              as events
from public.cs_events
where country_code is not null
  and created_at >= now() - interval '30 days'
group by surface, country_code
order by events desc
limit 30;
