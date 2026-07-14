-- CultureSchool Textile Atlas / Knowledge Graph
-- Target: PostgreSQL / Supabase
-- Safe default: new cs_kg_* tables; does not modify existing palettes, patterns, coco_art, market_items, or dictionary tables.

create extension if not exists pgcrypto;

-- ---------- Shared helpers ----------
create or replace function public.cs_kg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- Geography ----------
create table if not exists public.cs_kg_places (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.cs_kg_places(id) on delete set null,
  place_type text not null check (place_type in ('world_region','country','state_province','city','cultural_region','trade_region')),
  name text not null,
  slug text not null unique,
  iso_code text,
  summary text,
  latitude numeric,
  longitude numeric,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- Core public knowledge entries ----------
create table if not exists public.cs_kg_entries (
  id uuid primary key default gen_random_uuid(),
  entry_type text not null check (entry_type in (
    'textile_tradition','fabric','fiber','weave','print_method','dye_method','motif','symbol',
    'natural_dye_source','garment_type','product_use','certification','museum','book','organization'
  )),
  name text not null,
  slug text not null unique,
  alternate_names text[] not null default '{}',
  short_definition text,
  overview text,
  historical_context text,
  cultural_context text,
  cultural_protocol text,
  pronunciation text,
  hero_image_url text,
  source_status text not null default 'draft' check (source_status in ('draft','researched','reviewed','published','archived')),
  sensitivity_level text not null default 'general' check (sensitivity_level in ('general','context_required','restricted','sacred_private')),
  confidence_score numeric(4,3) check (confidence_score between 0 and 1),
  reviewed_by uuid,
  reviewed_at timestamptz,
  is_public boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(entry_type, name)
);

create table if not exists public.cs_kg_entry_places (
  entry_id uuid not null references public.cs_kg_entries(id) on delete cascade,
  place_id uuid not null references public.cs_kg_places(id) on delete cascade,
  relationship_type text not null check (relationship_type in ('origin','practiced_in','produced_in','associated_with','exported_from','inspired_by')),
  notes text,
  is_primary boolean not null default false,
  primary key (entry_id, place_id, relationship_type)
);

-- Typed relationships create the knowledge graph.
create table if not exists public.cs_kg_relationships (
  id uuid primary key default gen_random_uuid(),
  from_entry_id uuid not null references public.cs_kg_entries(id) on delete cascade,
  to_entry_id uuid not null references public.cs_kg_entries(id) on delete cascade,
  relationship_type text not null check (relationship_type in (
    'made_from','uses_weave','uses_print_method','uses_dye_method','features_motif','features_symbol',
    'related_to','often_confused_with','used_for','documented_by','certified_by','derived_from','modern_variant_of'
  )),
  direction_note text,
  strength numeric(4,3) check (strength between 0 and 1),
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  unique(from_entry_id, to_entry_id, relationship_type)
);

-- ---------- Sources and citations ----------
create table if not exists public.cs_kg_sources (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in ('museum','book','journal','government','trade_association','supplier','interview','field_note','website','archive')),
  title text not null,
  author_or_org text,
  url text,
  publisher text,
  publication_date date,
  accessed_at timestamptz,
  isbn_or_identifier text,
  reliability_tier smallint check (reliability_tier between 1 and 5),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.cs_kg_entry_sources (
  entry_id uuid not null references public.cs_kg_entries(id) on delete cascade,
  source_id uuid not null references public.cs_kg_sources(id) on delete cascade,
  claim_scope text,
  page_or_locator text,
  quote_excerpt text,
  is_primary_source boolean not null default false,
  primary key (entry_id, source_id, claim_scope)
);

-- ---------- Supplier intelligence (private by default) ----------
create table if not exists public.cs_kg_suppliers (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  display_name text,
  slug text not null unique,
  supplier_type text not null check (supplier_type in ('mill','printer','dye_house','garment_factory','artisan_cooperative','sourcing_agent','converter','trade_association','marketplace','studio')),
  headquarters_place_id uuid references public.cs_kg_places(id) on delete set null,
  website text,
  contact_name text,
  contact_email text,
  contact_phone text,
  languages text[] not null default '{}',
  manufactures_in_house boolean,
  prints_in_house boolean,
  exports_to_usa boolean,
  status text not null default 'researched' check (status in ('lead','researched','contacted','sampling','trial','approved','paused','rejected','archived')),
  verification_level text not null default 'public_research' check (verification_level in ('unverified','public_research','documents_checked','sampled','pilot_passed','audited')),
  risk_level text not null default 'unknown' check (risk_level in ('unknown','low','medium','high','blocked')),
  public_profile_allowed boolean not null default false,
  internal_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cs_kg_supplier_capabilities (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.cs_kg_suppliers(id) on delete cascade,
  entry_id uuid references public.cs_kg_entries(id) on delete set null,
  capability_type text not null check (capability_type in ('fiber','fabric','weave','print_method','dye_method','garment','product','service')),
  capability_name text not null,
  details text,
  minimum_order numeric,
  minimum_order_unit text,
  sample_available boolean,
  is_confirmed boolean not null default false,
  confirmed_at timestamptz,
  unique(supplier_id, capability_type, capability_name)
);

create table if not exists public.cs_kg_supplier_certifications (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.cs_kg_suppliers(id) on delete cascade,
  certification_entry_id uuid references public.cs_kg_entries(id) on delete set null,
  certificate_number text,
  issued_by text,
  valid_from date,
  valid_until date,
  document_url text,
  verification_status text not null default 'claimed' check (verification_status in ('claimed','document_received','issuer_verified','expired','invalid')),
  notes text
);

create table if not exists public.cs_kg_supplier_contacts (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.cs_kg_suppliers(id) on delete cascade,
  contacted_at timestamptz not null default now(),
  channel text check (channel in ('email','phone','video','whatsapp','trade_show','in_person','other')),
  contact_person text,
  summary text,
  next_step text,
  follow_up_at timestamptz,
  response_quality smallint check (response_quality between 1 and 5),
  created_by uuid
);

create table if not exists public.cs_kg_fabric_samples (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.cs_kg_suppliers(id) on delete cascade,
  sample_code text,
  base_name text not null,
  composition jsonb not null default '{}'::jsonb,
  weave text,
  gsm numeric,
  usable_width_cm numeric,
  print_method text,
  received_at date,
  cost_amount numeric(12,2),
  cost_currency text default 'USD',
  handfeel_score smallint check (handfeel_score between 1 and 5),
  color_score smallint check (color_score between 1 and 5),
  wash_score smallint check (wash_score between 1 and 5),
  drape_score smallint check (drape_score between 1 and 5),
  construction_score smallint check (construction_score between 1 and 5),
  traceability_score smallint check (traceability_score between 1 and 5),
  shrinkage_percent numeric,
  wash_cycles_tested integer,
  verdict text check (verdict in ('pending','pass','conditional','fail')) default 'pending',
  photos jsonb not null default '[]'::jsonb,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.cs_kg_supplier_quotes (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.cs_kg_suppliers(id) on delete cascade,
  fabric_sample_id uuid references public.cs_kg_fabric_samples(id) on delete set null,
  quoted_at date not null default current_date,
  quantity numeric,
  quantity_unit text,
  unit_price numeric(12,4),
  currency text not null default 'USD',
  incoterm text,
  lead_time_days integer,
  tooling_or_setup_cost numeric(12,2),
  shipping_estimate numeric(12,2),
  valid_until date,
  notes text
);

-- ---------- CultureSchool links ----------
-- Generic links prevent hard dependency on unknown existing PK types.
create table if not exists public.cs_kg_cultureschool_links (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.cs_kg_entries(id) on delete cascade,
  target_table text not null check (target_table in ('palettes','patterns','coco_art','asset_packs','market_items','dictionary','collections','creators')),
  target_id text not null,
  relationship_type text not null check (relationship_type in ('represents','inspired_by','recommended_for','uses','documents','licensed_from','made_by','sold_as','related')),
  sort_order integer not null default 0,
  is_public boolean not null default true,
  notes text,
  unique(entry_id, target_table, target_id, relationship_type)
);

-- Optional compatibility bridge for an existing dictionary table.
-- Configure dictionary rows without duplicating long-form knowledge.
create table if not exists public.cs_kg_dictionary_bindings (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.cs_kg_entries(id) on delete cascade,
  dictionary_record_id text,
  dictionary_slug text,
  publication_status text not null default 'draft' check (publication_status in ('draft','preview','published','hidden')),
  seo_title text,
  seo_description text,
  featured_rank integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(entry_id),
  unique(dictionary_slug)
);

-- ---------- Public read model for Dictionary ----------
create or replace view public.cs_kg_dictionary_public as
select
  e.id,
  e.entry_type,
  e.name,
  e.slug,
  e.alternate_names,
  e.short_definition,
  e.overview,
  e.historical_context,
  e.cultural_context,
  e.cultural_protocol,
  e.pronunciation,
  e.hero_image_url,
  e.sensitivity_level,
  b.dictionary_record_id,
  coalesce(b.dictionary_slug, e.slug) as dictionary_slug,
  b.seo_title,
  b.seo_description,
  coalesce(
    jsonb_agg(distinct jsonb_build_object(
      'id', p.id, 'name', p.name, 'slug', p.slug,
      'type', p.place_type, 'relationship', ep.relationship_type,
      'primary', ep.is_primary
    )) filter (where p.id is not null),
    '[]'::jsonb
  ) as places
from public.cs_kg_entries e
left join public.cs_kg_dictionary_bindings b on b.entry_id = e.id
left join public.cs_kg_entry_places ep on ep.entry_id = e.id
left join public.cs_kg_places p on p.id = ep.place_id
where e.is_public = true
  and e.source_status = 'published'
  and e.sensitivity_level <> 'sacred_private'
  and coalesce(b.publication_status, 'published') = 'published'
group by e.id, b.dictionary_record_id, b.dictionary_slug, b.seo_title, b.seo_description;

-- ---------- Search ----------
alter table public.cs_kg_entries
  add column if not exists search_document tsvector generated always as (
    setweight(to_tsvector('english'::regconfig, coalesce(name,'')), 'A') ||
    setweight(to_tsvector('english'::regconfig, coalesce(array_to_string(alternate_names,' '),'')), 'A') ||
    setweight(to_tsvector('english'::regconfig, coalesce(short_definition,'')), 'B') ||
    setweight(to_tsvector('english'::regconfig, coalesce(overview,'')), 'C') ||
    setweight(to_tsvector('english'::regconfig, coalesce(cultural_context,'')), 'C')
  ) stored;

create index if not exists cs_kg_entries_search_idx on public.cs_kg_entries using gin(search_document);
create index if not exists cs_kg_entries_type_idx on public.cs_kg_entries(entry_type);
create index if not exists cs_kg_entries_public_idx on public.cs_kg_entries(is_public, source_status);
create index if not exists cs_kg_places_parent_idx on public.cs_kg_places(parent_id);
create index if not exists cs_kg_supplier_status_idx on public.cs_kg_suppliers(status, verification_level);
create index if not exists cs_kg_links_target_idx on public.cs_kg_cultureschool_links(target_table, target_id);

-- ---------- Updated-at triggers ----------
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'cs_kg_places_updated_at') then
    create trigger cs_kg_places_updated_at before update on public.cs_kg_places
    for each row execute function public.cs_kg_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'cs_kg_entries_updated_at') then
    create trigger cs_kg_entries_updated_at before update on public.cs_kg_entries
    for each row execute function public.cs_kg_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'cs_kg_suppliers_updated_at') then
    create trigger cs_kg_suppliers_updated_at before update on public.cs_kg_suppliers
    for each row execute function public.cs_kg_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'cs_kg_dictionary_bindings_updated_at') then
    create trigger cs_kg_dictionary_bindings_updated_at before update on public.cs_kg_dictionary_bindings
    for each row execute function public.cs_kg_set_updated_at();
  end if;
end $$;

-- ---------- RLS ----------
alter table public.cs_kg_places enable row level security;
alter table public.cs_kg_entries enable row level security;
alter table public.cs_kg_entry_places enable row level security;
alter table public.cs_kg_relationships enable row level security;
alter table public.cs_kg_sources enable row level security;
alter table public.cs_kg_entry_sources enable row level security;
alter table public.cs_kg_suppliers enable row level security;
alter table public.cs_kg_supplier_capabilities enable row level security;
alter table public.cs_kg_supplier_certifications enable row level security;
alter table public.cs_kg_supplier_contacts enable row level security;
alter table public.cs_kg_fabric_samples enable row level security;
alter table public.cs_kg_supplier_quotes enable row level security;
alter table public.cs_kg_cultureschool_links enable row level security;
alter table public.cs_kg_dictionary_bindings enable row level security;

-- Public knowledge can be read anonymously only when explicitly published.
drop policy if exists "Public reads published KG places" on public.cs_kg_places;
create policy "Public reads published KG places" on public.cs_kg_places for select using (is_public = true);

drop policy if exists "Public reads published KG entries" on public.cs_kg_entries;
create policy "Public reads published KG entries" on public.cs_kg_entries for select using (
  is_public = true and source_status = 'published' and sensitivity_level <> 'sacred_private'
);

drop policy if exists "Public reads public KG relationships" on public.cs_kg_relationships;
create policy "Public reads public KG relationships" on public.cs_kg_relationships for select using (is_public = true);

drop policy if exists "Public reads public KG links" on public.cs_kg_cultureschool_links;
create policy "Public reads public KG links" on public.cs_kg_cultureschool_links for select using (is_public = true);

-- Authenticated access is intentionally not granted here. Add role-based admin/editor policies
-- after confirming your auth model (e.g., coco_personas.role). Service role bypasses RLS.

comment on view public.cs_kg_dictionary_public is
'Public dictionary read model. The knowledge graph is the source of truth; supplier operations remain private.';
