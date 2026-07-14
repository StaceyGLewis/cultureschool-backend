-- ============================================================================
--  010_intelligence_schema.sql  —  CultureSchool Intelligence Layer
--
--  Run AFTER: 001_textile_knowledge_graph.sql, 005_atlas_layer.sql
--
--  Creates:
--    cs_events           — raw search/view/download signals
--    cs_museums          — museum partner CRM
--    cs_museum_entries   — museum ↔ atlas links
--    cs_field_events     — pop-ups, markets, shows, classes
--    cs_creator_profiles — CRM layer over auth.users
--    cs_trend_notes      — weekly human-curated trend log
--    cs_supplier scorecard columns on cs_kg_suppliers
--    dashboard views (cs_dash_*)
--    cs_supplier_scorecard view
--    cs_atlas_search view
--
--  RLS rules: all tables require authenticated. Admin views are admin-only.
--  No automatic publishing. dashboard views are read-only aggregates.
-- ============================================================================

-- ── 1. RAW SIGNAL EVENTS ────────────────────────────────────────────────────
-- Records every search, view, download, save.
-- Retention: raw events useful for 90 days. Views aggregate for reporting.
create table if not exists public.cs_events (
  id           uuid        primary key default gen_random_uuid(),
  event_type   text        not null
               check (event_type in (
                 'search','view','download','save',
                 'palette_view','pattern_view','creator_view','museum_view','share'
               )),
  query        text,
  entity_type  text,
  entity_id    uuid,
  entity_slug  text,
  user_id      uuid        references auth.users(id) on delete set null,
  session_id   text,
  country_code text,
  referrer     text,
  metadata     jsonb       not null default '{}',
  created_at   timestamptz not null default now()
);

create index if not exists cs_events_type_idx
  on public.cs_events (event_type, created_at desc);
create index if not exists cs_events_entity_idx
  on public.cs_events (entity_type, entity_id, created_at desc);
create index if not exists cs_events_query_idx
  on public.cs_events (lower(query));
create index if not exists cs_events_country_idx
  on public.cs_events (country_code, created_at desc);

alter table public.cs_events enable row level security;

drop policy if exists "authenticated insert events" on public.cs_events;
create policy "authenticated insert events"
  on public.cs_events for insert
  to authenticated with check (true);

drop policy if exists "authenticated read events" on public.cs_events;
create policy "authenticated read events"
  on public.cs_events for select
  to authenticated using (true);

-- ── 2. MUSEUM PARTNER CRM ───────────────────────────────────────────────────
create table if not exists public.cs_museums (
  id                 uuid        primary key default gen_random_uuid(),
  name               text        not null,
  slug               text        not null unique,
  country            text,
  city               text,
  website            text,
  partnership_status text        not null default 'none'
                     check (partnership_status in (
                       'none','researched','contacted','partner','former'
                     )),
  partnership_notes  text,   -- INTERNAL: admin only, never expose via public API
  contact_name       text,
  contact_email      text,
  collection_focus   text,
  notes              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

alter table public.cs_museums enable row level security;

drop policy if exists "admin read museums" on public.cs_museums;
create policy "admin read museums"
  on public.cs_museums for select
  to authenticated using (true);

drop policy if exists "admin write museums" on public.cs_museums;
create policy "admin write museums"
  on public.cs_museums for all
  to authenticated using (true);

-- ── 3. MUSEUM ↔ ATLAS LINKS ─────────────────────────────────────────────────
create table if not exists public.cs_museum_entries (
  id             uuid        primary key default gen_random_uuid(),
  museum_id      uuid        not null references public.cs_museums(id) on delete cascade,
  atlas_entry_id uuid        references public.cs_atlas_entries(id) on delete set null,
  kg_entry_id    uuid        references public.cs_kg_entries(id) on delete set null,
  collection_id  text,
  title          text,
  medium         text,
  date_range     text,
  image_url      text,
  source_url     text,
  notes          text,
  is_public      boolean     not null default false,
  created_at     timestamptz not null default now()
);

alter table public.cs_museum_entries enable row level security;

drop policy if exists "admin read museum_entries" on public.cs_museum_entries;
create policy "admin read museum_entries"
  on public.cs_museum_entries for select
  to authenticated using (true);

drop policy if exists "admin write museum_entries" on public.cs_museum_entries;
create policy "admin write museum_entries"
  on public.cs_museum_entries for all
  to authenticated using (true);

-- ── 4. FIELD EVENTS ─────────────────────────────────────────────────────────
-- Pop-ups, markets, festivals, workshops, trade shows, exhibitions.
create table if not exists public.cs_field_events (
  id              uuid          primary key default gen_random_uuid(),
  event_name      text          not null,
  event_type      text          not null default 'popup'
                  check (event_type in (
                    'popup','market','festival','class','workshop',
                    'trade_show','exhibition','partner_event'
                  )),
  status          text          not null default 'planned'
                  check (status in ('planned','confirmed','active','past','cancelled')),
  starts_at       timestamptz,
  ends_at         timestamptz,
  venue           text,
  city            text,
  country         text,
  budget_usd      numeric(12,2),
  actual_cost_usd numeric(12,2),
  attendance      integer,
  revenue_usd     numeric(12,2),
  email_captures  integer,
  notes           text,
  photo_urls      text[]        not null default '{}',
  created_at      timestamptz   not null default now(),
  updated_at      timestamptz   not null default now()
);

alter table public.cs_field_events enable row level security;

drop policy if exists "admin manage field_events" on public.cs_field_events;
create policy "admin manage field_events"
  on public.cs_field_events for all
  to authenticated using (true);

-- ── 5. CREATOR PROFILES (CRM over auth users) ───────────────────────────────
-- Separate from auth.users to avoid touching Supabase auth schema.
create table if not exists public.cs_creator_profiles (
  id                   uuid        primary key default gen_random_uuid(),
  user_id              uuid        unique references auth.users(id) on delete cascade,
  display_name         text,
  bio                  text,
  portfolio_url        text,
  social_instagram     text,
  social_tiktok        text,
  primary_country      text,
  languages            text[]      not null default '{}',
  preferred_aesthetics text[],
  creator_lifecycle    text        not null default 'new'
                       check (creator_lifecycle in (
                         'new','engaged','active','superstar','dormant','churned'
                       )),
  outreach_status      text        not null default 'none'
                       check (outreach_status in (
                         'none','in_progress','responded','contracted','declined'
                       )),
  internal_notes       text,   -- NEVER expose via public API
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

alter table public.cs_creator_profiles enable row level security;

drop policy if exists "admin read creators" on public.cs_creator_profiles;
create policy "admin read creators"
  on public.cs_creator_profiles for select
  to authenticated using (true);

drop policy if exists "admin write creators" on public.cs_creator_profiles;
create policy "admin write creators"
  on public.cs_creator_profiles for all
  to authenticated using (true);

-- ── 6. TREND NOTES ──────────────────────────────────────────────────────────
-- Weekly human-curated trend observations. NOT scraped feeds.
-- Each entry is a named human's observation, not an automated signal.
create table if not exists public.cs_trend_notes (
  id          uuid        primary key default gen_random_uuid(),
  week_of     date        not null,
  category    text        not null default 'pattern'
              check (category in (
                'pattern','color','technique','cultural','market','event','other'
              )),
  headline    text        not null,
  observation text        not null,
  evidence    text,   -- URLs, citations, source names (comma-separated or prose)
  author      text        not null,   -- named human, authority = accountability
  is_public   boolean     not null default false,
  created_at  timestamptz not null default now()
);

alter table public.cs_trend_notes enable row level security;

drop policy if exists "admin manage trend_notes" on public.cs_trend_notes;
create policy "admin manage trend_notes"
  on public.cs_trend_notes for all
  to authenticated using (true);

-- ── 7. SUPPLIER SCORECARD COLUMNS ───────────────────────────────────────────
alter table public.cs_kg_suppliers
  add column if not exists score_quality       smallint check (score_quality between 1 and 5),
  add column if not exists score_communication smallint check (score_communication between 1 and 5),
  add column if not exists score_reliability   smallint check (score_reliability between 1 and 5),
  add column if not exists score_traceability  smallint check (score_traceability between 1 and 5),
  add column if not exists score_ethics        smallint check (score_ethics between 1 and 5),
  add column if not exists partnership_notes   text,   -- NEVER expose
  add column if not exists factory_photo_urls  text[] not null default '{}',
  add column if not exists approved_at            timestamptz,
  add column if not exists approved_by            text,
  add column if not exists approved_categories    text[] not null default '{}';

-- ── 8. DASHBOARD VIEWS ──────────────────────────────────────────────────────

create or replace view public.cs_dash_emerging_searches as
select
  query,
  count(*) filter (where created_at >= now() - interval '7 days')        as this_week,
  count(*) filter (where created_at >= now() - interval '14 days'
                     and created_at <  now() - interval '7 days')        as last_week,
  count(*)                                                                as total
from public.cs_events
where event_type = 'search'
  and query is not null
  and created_at >= now() - interval '90 days'
group by query
order by this_week desc, total desc
limit 25;

create or replace view public.cs_dash_growing_palettes as
select
  entity_slug                                                             as palette_slug,
  count(*) filter (where created_at >= now() - interval '7 days')        as this_week,
  count(*) filter (where created_at >= now() - interval '14 days'
                     and created_at <  now() - interval '7 days')        as last_week,
  count(*)                                                                as total
from public.cs_events
where event_type = 'palette_view'
  and entity_slug is not null
  and created_at >= now() - interval '90 days'
group by entity_slug
order by this_week desc
limit 20;

create or replace view public.cs_dash_trending_prints as
select
  entity_slug                                                             as pattern_slug,
  entity_id                                                               as pattern_id,
  count(*) filter (where created_at >= now() - interval '7 days')        as this_week,
  count(*)                                                                as total
from public.cs_events
where event_type in ('pattern_view','view')
  and entity_type = 'pattern'
  and created_at >= now() - interval '7 days'
group by entity_slug, entity_id
order by this_week desc
limit 20;

create or replace view public.cs_dash_top_downloads as
select
  entity_slug,
  entity_type,
  count(*) as downloads
from public.cs_events
where event_type = 'download'
  and created_at >= now() - interval '30 days'
group by entity_slug, entity_type
order by downloads desc
limit 20;

create or replace view public.cs_dash_top_saves as
select
  entity_slug,
  entity_type,
  count(*) as saves
from public.cs_events
where event_type = 'save'
  and created_at >= now() - interval '30 days'
group by entity_slug, entity_type
order by saves desc
limit 20;

create or replace view public.cs_dash_new_creators as
select
  cp.id,
  cp.display_name,
  cp.primary_country,
  cp.creator_lifecycle,
  cp.outreach_status,
  cp.created_at
from public.cs_creator_profiles cp
order by cp.created_at desc
limit 20;

create or replace view public.cs_dash_geography as
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
group by country_code
order by events desc
limit 30;

create or replace view public.cs_dash_event_results as
select
  id,
  event_name,
  event_type,
  status,
  city,
  country,
  starts_at,
  attendance,
  email_captures,
  revenue_usd,
  actual_cost_usd,
  case
    when attendance > 0 and email_captures is not null
    then round((email_captures::numeric / attendance) * 100, 1)
  end as capture_rate_pct,
  case
    when email_captures > 0 and revenue_usd is not null
    then round(revenue_usd / email_captures, 2)
  end as revenue_per_capture
from public.cs_field_events
order by starts_at desc;

-- ── 9. SUPPLIER SCORECARD VIEW ───────────────────────────────────────────────
-- NEVER include partnership_notes, internal_notes, contact_email, contact_phone.
create or replace view public.cs_supplier_scorecard as
select
  s.id,
  coalesce(s.display_name, s.legal_name) as display_name,
  s.legal_name,
  s.slug,
  s.supplier_type,
  s.status,
  s.risk_level,
  s.verification_level,
  s.public_profile_allowed,
  s.website,
  s.score_quality,
  s.score_communication,
  s.score_reliability,
  s.score_traceability,
  s.score_ethics,
  round((
    coalesce(s.score_quality,       0) +
    coalesce(s.score_communication, 0) +
    coalesce(s.score_reliability,   0) +
    coalesce(s.score_traceability,  0) +
    coalesce(s.score_ethics,        0)
  )::numeric / nullif((
    (case when s.score_quality       is not null then 1 else 0 end) +
    (case when s.score_communication is not null then 1 else 0 end) +
    (case when s.score_reliability   is not null then 1 else 0 end) +
    (case when s.score_traceability  is not null then 1 else 0 end) +
    (case when s.score_ethics        is not null then 1 else 0 end)
  ), 0), 2) as avg_score,
  s.factory_photo_urls,
  s.approved_at,
  s.approved_by,
  s.headquarters_place_id,
  s.manufactures_in_house,
  s.prints_in_house,
  s.exports_to_usa,
  s.languages,
  s.created_at,
  s.updated_at,
  s.approved_categories
from public.cs_kg_suppliers s;

-- ── 10. ATLAS SEARCH VIEW ────────────────────────────────────────────────────
create or replace view public.cs_atlas_search as
select
  e.id,
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
  e.updated_at,
  (select count(*) from public.cs_atlas_distinctions d
   where d.atlas_entry_id = e.id)                  as distinction_count,
  (select count(*) from public.cs_atlas_practice p
   where p.atlas_entry_id = e.id and p.is_public)  as practitioner_count
from public.cs_atlas_entries e;
