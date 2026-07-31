-- ============================================================================
--  13-fix-geo-view.sql
--
--  Recreates cs_dash_geography to guarantee null country_codes are excluded.
--  Safe to re-run. Run in Supabase SQL Editor.
-- ============================================================================

drop view if exists public.cs_dash_geography;
create view public.cs_dash_geography as
select
  country_code,
  count(*)                                                           as events,
  count(distinct session_id)                                         as sessions,
  count(*) filter (where event_type = 'download')                    as downloads,
  count(*) filter (where event_type = 'save')                        as saves,
  count(*) filter (where event_type = 'search')                      as searches
from public.cs_events
where created_at >= now() - interval '30 days'
  and country_code is not null
  and country_code <> ''
group by country_code
order by events desc
limit 30;

-- ── VERIFICATION ──────────────────────────────────────────────────────────────
-- select country_code, events, sessions from public.cs_dash_geography limit 10;
