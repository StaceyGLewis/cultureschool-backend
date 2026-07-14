-- ============================================================================
--  CULTURESCHOOL ATLAS  —  the cited, reviewed provenance layer
--
--  ARCHITECTURE (decided 2026-07-12):
--    Dictionary (existing)  = every generator style, cultural or not. Complete.
--                             Makes NO cultural claim about generic motifs.
--    Atlas      (this file) = only cited, reviewed cultural entries.
--                             What institutions consume AND contribute to.
--    Sourcing CRM (private) = vendors, MOQs, samples. NEVER provenance.
--
--  THE PRODUCT IS THE EDGES. Definitions are commodity (any LLM has them).
--  The traversable, cited map — tradition -> place -> practitioner -> technique
--  -> distinct-from -> our patterns/products — is not.
--
--  Run AFTER 001_textile_knowledge_graph.sql. Staging first. Never blind on prod.
-- ============================================================================

-- ── 1. ATLAS ENTRIES ────────────────────────────────────────────────────────
-- A curated promotion of a Dictionary style into a *cited* cultural record.
-- Nothing lands here automatically. Promotion is a human editorial act.
create table if not exists public.cs_atlas_entries (
  id                uuid primary key default gen_random_uuid(),
  entry_id          uuid references public.cs_kg_entries(id) on delete set null, -- the KG concept
  dictionary_style  text,                       -- the generator style key it maps to (nullable)
  name              text not null,
  slug              text not null unique,
  short_definition  text,
  cultural_context  text,
  cultural_protocol text,                       -- how it may/may not be used
  is_living         boolean default true,       -- still actively practiced?
  sensitivity_level text not null default 'general'
      check (sensitivity_level in ('general','context_required','restricted','sacred_private')),
  source_status     text not null default 'draft'
      check (source_status in ('draft','researched','reviewed','published','archived')),
  reviewed_by       text,                       -- named human. authority = accountability
  reviewed_at       timestamptz,
  is_public         boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ── 2. PRACTITIONERS  (the "living practice" proof layer) ───────────────────
-- ASPIRATIONAL TODAY: we have no verified tradition-bearers yet. Build the
-- table, make ZERO public claims until a real practitioner consents.
--
-- CRITICAL: a practitioner is NOT a supplier. A digital print vendor is not
-- evidence that a wax-resist tradition is alive. Conflating them is
-- authenticity-washing, and it is the one mistake that would destroy the
-- credibility of this entire layer.
create table if not exists public.cs_atlas_practitioners (
  id                uuid primary key default gen_random_uuid(),
  display_name      text not null,
  slug              text not null unique,
  practitioner_type text not null default 'artisan'
      check (practitioner_type in ('artisan','workshop','cooperative','master','community_org','educator')),
  place_id          uuid references public.cs_kg_places(id) on delete set null,

  -- CONSENT: nobody is named as cultural evidence without agreeing to it.
  consent_status    text not null default 'not_contacted'
      check (consent_status in ('not_contacted','contacted','consent_granted','consent_declined','consent_withdrawn')),
  consent_scope     text,                       -- exactly what they agreed to
  consent_source    text,                       -- how consent was captured (email, signed, in person)
  consent_at        timestamptz,

  verification_level text not null default 'unverified'
      check (verification_level in ('unverified','self_reported','community_verified','visited','audited')),
  public_profile_allowed boolean not null default false,
  bio               text,
  internal_notes    text,                       -- NEVER public
  created_at        timestamptz not null default now()
);

-- HARD RULE, enforced in the DB, not in a doc:
-- a practitioner may only be public with explicit consent AND verification.
create or replace function public.cs_atlas_practitioner_guard()
returns trigger language plpgsql as $$
begin
  if new.public_profile_allowed
     and (new.consent_status <> 'consent_granted'
          or new.verification_level in ('unverified','self_reported')) then
    raise exception
      'A practitioner cannot be public without consent_granted AND community verification.';
  end if;
  return new;
end $$;
drop trigger if exists trg_atlas_practitioner_guard on public.cs_atlas_practitioners;
create trigger trg_atlas_practitioner_guard
  before insert or update on public.cs_atlas_practitioners
  for each row execute function public.cs_atlas_practitioner_guard();

-- practitioner <-> tradition (the living-practice edge)
create table if not exists public.cs_atlas_practice (
  id              uuid primary key default gen_random_uuid(),
  atlas_entry_id  uuid not null references public.cs_atlas_entries(id) on delete cascade,
  practitioner_id uuid not null references public.cs_atlas_practitioners(id) on delete cascade,
  relationship    text not null default 'practices'
      check (relationship in ('practices','teaches','preserves','innovates_on')),
  evidence        text,                          -- what makes this credible
  is_public       boolean not null default false,
  unique (atlas_entry_id, practitioner_id, relationship)
);

-- ── 3. THE DIFFERENTIATOR: disambiguation edges ─────────────────────────────
-- "Bargello is routinely mislabeled Brazilian." "Madras is not Caribbean Carnival."
-- Nobody publishes this. An LLM will confidently get it wrong. A fashion school
-- needs exactly this. THIS is the map only we have.
create table if not exists public.cs_atlas_distinctions (
  id             uuid primary key default gen_random_uuid(),
  atlas_entry_id uuid not null references public.cs_atlas_entries(id) on delete cascade,
  confused_with  text not null,                 -- the wrong label / lookalike
  correction     text not null,                 -- what it actually is
  why_confused   text,                          -- the history of the error
  source_id      uuid references public.cs_kg_sources(id) on delete set null,
  is_public      boolean not null default false,
  created_at     timestamptz not null default now()
);

-- ── 4. CONTRIBUTIONS (institutions contribute, and get credited) ────────────
-- The network effect: named experts staking reputation on specific claims is the
-- one thing a chatbot structurally cannot have.
create table if not exists public.cs_atlas_contributions (
  id              uuid primary key default gen_random_uuid(),
  atlas_entry_id  uuid references public.cs_atlas_entries(id) on delete cascade,
  contributor_name text not null,               -- person
  contributor_org  text,                        -- e.g. Columbus Fashion Academy
  contributor_email text,
  contribution_type text not null default 'edit'
      check (contribution_type in ('new_entry','edit','citation','correction','review','practitioner_intro')),
  payload         jsonb not null default '{}',  -- the proposed content
  status          text not null default 'submitted'
      check (status in ('submitted','in_review','accepted','rejected','withdrawn')),
  reviewed_by     text,
  reviewed_at     timestamptz,
  credit_public   boolean not null default true, -- attribution is the incentive
  created_at      timestamptz not null default now()
);

-- ── 5. PUBLIC VIEW — the only thing the world sees ──────────────────────────
-- Published + public + not sacred. Everything else stays internal by default.
create or replace view public.cs_atlas_public as
select
  a.id, a.name, a.slug, a.short_definition, a.cultural_context, a.cultural_protocol,
  a.is_living, a.sensitivity_level, a.reviewed_by, a.reviewed_at,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'confused_with', d.confused_with, 'correction', d.correction, 'why', d.why_confused))
    from public.cs_atlas_distinctions d
    where d.atlas_entry_id = a.id and d.is_public
  ), '[]'::jsonb) as distinctions,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', pr.display_name, 'type', pr.practitioner_type, 'relationship', pp.relationship))
    from public.cs_atlas_practice pp
    join public.cs_atlas_practitioners pr on pr.id = pp.practitioner_id
    where pp.atlas_entry_id = a.id
      and pp.is_public
      and pr.public_profile_allowed            -- consent gate, again
      and pr.consent_status = 'consent_granted'
  ), '[]'::jsonb) as practitioners
from public.cs_atlas_entries a
where a.is_public = true
  and a.source_status = 'published'
  and a.sensitivity_level <> 'sacred_private';

-- ── 6. RLS: closed by default ───────────────────────────────────────────────
alter table public.cs_atlas_entries        enable row level security;
alter table public.cs_atlas_practitioners  enable row level security;
alter table public.cs_atlas_practice       enable row level security;
alter table public.cs_atlas_distinctions   enable row level security;
alter table public.cs_atlas_contributions  enable row level security;

-- anyone may read ONLY published, public, non-sacred entries
drop policy if exists "atlas public read" on public.cs_atlas_entries;
create policy "atlas public read" on public.cs_atlas_entries
  for select to anon, authenticated
  using (is_public and source_status = 'published' and sensitivity_level <> 'sacred_private');

-- a signed-in person may SUBMIT a contribution, and read back their own
drop policy if exists "contribute" on public.cs_atlas_contributions;
create policy "contribute" on public.cs_atlas_contributions
  for insert to authenticated with check (true);
drop policy if exists "read own contributions" on public.cs_atlas_contributions;
create policy "read own contributions" on public.cs_atlas_contributions
  for select to authenticated
  using (lower(contributor_email) = lower(auth.jwt() ->> 'email'));

-- practitioners / practice / distinctions: NO public table access.
-- The world reads them only through cs_atlas_public, which enforces consent.
