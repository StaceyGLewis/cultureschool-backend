-- ============================================================================
--  08-maker-network-atlas-linkage.sql
--
--  Wires the existing maker_network table into the Atlas knowledge graph.
--  Pattern mirrors cs_museum_entries — a junction table + a surfacing view.
--
--  Creates:
--    cs_maker_network_atlas  — maker_network row ↔ Atlas tradition link
--    cs_maker_network_places — maker_network row ↔ kg_place link (region)
--    cs_maker_network_detail — view for Intelligence Platform + subscriber surface
--
--  Safe to re-run (idempotent). Run in Supabase SQL Editor.
-- ============================================================================


-- ── 1. TRADITION LINKS ───────────────────────────────────────────────────────
-- One maker org can practice/preserve multiple traditions.
-- One tradition can have many maker orgs keeping it alive.

create table if not exists public.cs_maker_network_atlas (
  id             uuid        primary key default gen_random_uuid(),
  maker_id       bigint      not null references public.maker_network(id) on delete cascade,
  atlas_entry_id uuid        not null references public.cs_atlas_entries(id) on delete cascade,
  kg_entry_id    uuid        references public.cs_kg_entries(id) on delete set null,
  link_type      text        not null default 'practices'
                 check (link_type in (
                   'practices',   -- actively makes / produces this tradition
                   'preserves',   -- archival or documentation role
                   'teaches',     -- educational programs
                   'sources',     -- sources materials or components from this tradition
                   'adjacent'     -- related tradition, not primary
                 )),
  is_primary     boolean     not null default false,
  notes          text,
  linked_by      text,        -- staff name who made the link (accountability)
  linked_at      timestamptz not null default now()
);

create unique index if not exists cs_maker_atlas_unique
  on public.cs_maker_network_atlas (maker_id, atlas_entry_id);

create index if not exists cs_maker_atlas_entry_idx
  on public.cs_maker_network_atlas (atlas_entry_id);

create index if not exists cs_maker_atlas_maker_idx
  on public.cs_maker_network_atlas (maker_id);

alter table public.cs_maker_network_atlas enable row level security;

create policy "staff read maker_atlas"
  on public.cs_maker_network_atlas for select
  to authenticated using (cs_can_read());

create policy "admin insert maker_atlas"
  on public.cs_maker_network_atlas for insert
  to authenticated with check (cs_is_admin());

create policy "admin update maker_atlas"
  on public.cs_maker_network_atlas for update
  to authenticated using (cs_is_admin());

create policy "admin delete maker_atlas"
  on public.cs_maker_network_atlas for delete
  to authenticated using (cs_is_admin());


-- ── 2. PLACE LINKS ───────────────────────────────────────────────────────────
-- Links a maker org to the geographic place in the knowledge graph.
-- Enables "Makers in this region" queries on Atlas place entries.

create table if not exists public.cs_maker_network_places (
  id         uuid    primary key default gen_random_uuid(),
  maker_id   bigint  not null references public.maker_network(id) on delete cascade,
  place_id   uuid    not null references public.cs_kg_places(id) on delete cascade,
  linked_by  text,
  linked_at  timestamptz not null default now()
);

create unique index if not exists cs_maker_places_unique
  on public.cs_maker_network_places (maker_id, place_id);

create index if not exists cs_maker_places_place_idx
  on public.cs_maker_network_places (place_id);

alter table public.cs_maker_network_places enable row level security;

create policy "staff read maker_places"
  on public.cs_maker_network_places for select
  to authenticated using (cs_can_read());

create policy "admin insert maker_places"
  on public.cs_maker_network_places for insert
  to authenticated with check (cs_is_admin());

create policy "admin update maker_places"
  on public.cs_maker_network_places for update
  to authenticated using (cs_is_admin());

create policy "admin delete maker_places"
  on public.cs_maker_network_places for delete
  to authenticated using (cs_is_admin());


-- ── 3. DETAIL VIEW ───────────────────────────────────────────────────────────
-- Used by both the Intelligence Platform admin and eventually the subscriber
-- Atlas surface ("Organizations keeping this tradition alive today").
-- NEVER includes contact_email, partnership_notes, or internal CRM fields.

create or replace view public.cs_maker_network_detail as
select
  mn.id                                                   as maker_id,
  mn."Organization / Group"                               as organization,
  mn."Entity Type"                                        as entity_type,
  mn."Continent"                                          as continent,
  mn."Subregion"                                          as subregion,
  mn."Country / Territory"                               as country,
  mn."Crafts / Techniques"                               as crafts_techniques,
  mn."Can Make"                                           as can_make,
  mn."Engagement Potential"                              as engagement_potential,
  mn."Source URL"                                         as source_url,
  mn."Qualification Status"                              as qualification_status,
  mn.contact_status,
  mn.listed,
  -- Atlas tradition links
  array_agg(distinct ae.name)
    filter (where ae.id is not null)                      as linked_traditions,
  array_agg(distinct ae.slug)
    filter (where ae.id is not null)                      as linked_tradition_slugs,
  array_agg(distinct mna.link_type)
    filter (where mna.id is not null)                     as link_types,
  -- Place links
  array_agg(distinct kp.name)
    filter (where kp.id is not null)                      as linked_places,
  count(distinct mna.atlas_entry_id)                      as tradition_count,
  count(distinct mnp.place_id)                            as place_count
from public.maker_network mn
left join public.cs_maker_network_atlas mna  on mna.maker_id = mn.id
left join public.cs_atlas_entries ae          on ae.id = mna.atlas_entry_id
left join public.cs_maker_network_places mnp  on mnp.maker_id = mn.id
left join public.cs_kg_places kp              on kp.id = mnp.place_id
group by
  mn.id,
  mn."Organization / Group", mn."Entity Type", mn."Continent", mn."Subregion",
  mn."Country / Territory", mn."Crafts / Techniques", mn."Can Make",
  mn."Engagement Potential", mn."Source URL", mn."Qualification Status",
  mn.contact_status, mn.listed;


-- ── 4. ATLAS-FACING VIEW ─────────────────────────────────────────────────────
-- Used on Atlas entry detail pages to surface linked maker orgs.
-- Subscriber-safe: no CRM internals.

create or replace view public.cs_atlas_makers as
select
  ae.id                                                   as atlas_entry_id,
  ae.name                                                 as tradition_name,
  ae.slug                                                 as tradition_slug,
  mn.id                                                   as maker_id,
  mn."Organization / Group"                               as organization,
  mn."Entity Type"                                        as entity_type,
  mn."Continent"                                          as continent,
  mn."Subregion"                                          as subregion,
  mn."Country / Territory"                               as country,
  mn."Crafts / Techniques"                               as crafts_techniques,
  mn."Engagement Potential"                              as engagement_potential,
  mn."Source URL"                                         as source_url,
  mna.link_type,
  mna.is_primary
from public.cs_atlas_entries ae
join public.cs_maker_network_atlas mna  on mna.atlas_entry_id = ae.id
join public.maker_network mn            on mn.id = mna.maker_id
where ae.is_public = true
  and mn.listed = true
order by ae.name, mna.is_primary desc, mn."Organization / Group";


-- ── 5. VERIFICATION ──────────────────────────────────────────────────────────
-- Run after to confirm tables exist and views are valid:
--
-- select table_name from information_schema.tables
-- where table_schema = 'public'
--   and table_name in ('cs_maker_network_atlas','cs_maker_network_places');
--
-- select tradition_name, organization, link_type
-- from public.cs_atlas_makers limit 10;
--
-- select organization, linked_traditions, tradition_count
-- from public.cs_maker_network_detail limit 10;
