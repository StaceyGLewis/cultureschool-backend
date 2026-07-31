-- ============================================================================
--  09-atlas-content-enrichment.sql
--
--  Seeds the Atlas with educational content fields and wires palettes to
--  traditions via a junction table. Powers:
--    · "Today's Cultural Moment" hero pull-quote on My World
--    · "Tradition of the Week" spotlight card
--    · One-line cultural context on palette cards
--    · Glossary term defined per tradition
--
--  Alters:
--    cs_atlas_entries       — adds hook, body, hero_image_url, key_term,
--                             key_term_def, color_symbolism, featured_at
--  Creates:
--    cs_palette_atlas_links — palette ↔ tradition junction
--    cs_atlas_featured      — view: this week's featured tradition
--    cs_palette_context     — view: best cultural note per palette
--
--  Safe to re-run (idempotent). Run in Supabase SQL Editor.
-- ============================================================================


-- ── 1. ENRICH cs_atlas_entries ───────────────────────────────────────────────
--
--  hook            One punchy sentence for the hero pull-quote.
--                  Should work out of context — read by someone who knows nothing.
--                  Example: "Kente cloth speaks a visual language: every stripe
--                  a word, every color a meaning."
--
--  body            2–4 paragraphs of editorial content. Written for curious
--                  subscribers, not academics. No jargon without definition.
--
--  hero_image_url  Feature image URL for Tradition of the Week card.
--                  Must be rights-cleared. Leave null until confirmed.
--
--  key_term        The single most important vocabulary word for this tradition.
--                  Often the tradition name itself; sometimes more specific
--                  (e.g., for Adinkra: "Sankofa").
--
--  key_term_def    Plain-language definition of key_term. One or two sentences.
--                  No citations needed — just clear, accurate explanation.
--
--  color_symbolism What colors mean *in this tradition*. Fallback when no
--                  palette is linked. E.g., "Gold = royalty, Red = blood / danger,
--                  Black = maturity in Akan culture."
--
--  featured_at     Set to any date within the desired feature week.
--                  The cs_atlas_featured view matches by ISO week + year.
--                  Only one entry should be featured per week.

alter table public.cs_atlas_entries
  add column if not exists hook             text,
  add column if not exists body             text,
  add column if not exists hero_image_url   text,
  add column if not exists key_term         text,
  add column if not exists key_term_def     text,
  add column if not exists color_symbolism  text,
  add column if not exists featured_at      date;

create index if not exists cs_atlas_featured_idx
  on public.cs_atlas_entries (featured_at)
  where featured_at is not null;


-- ── 2. PALETTE → ATLAS JUNCTION ──────────────────────────────────────────────
--
--  Links a palette to the tradition(s) its colors represent or draw from.
--  One palette can link to multiple traditions; one tradition can have many palettes.
--
--  palette_id is text to accommodate both uuid and bigint palette IDs.
--  Verify public.palettes.id type and tighten this if it is always uuid.
--
--  color_note is the subscriber-facing sentence:
--    "Gold here represents royalty and wealth in Akan tradition."
--  Keep it under ~100 characters — it sits below the palette name on the card.

create table if not exists public.cs_palette_atlas_links (
  id             uuid        primary key default gen_random_uuid(),
  palette_id     text        not null,
  atlas_entry_id uuid        not null references public.cs_atlas_entries(id) on delete cascade,
  link_type      text        not null default 'tradition'
                 check (link_type in (
                   'tradition',     -- palette directly represents this tradition
                   'color_system',  -- palette uses this tradition's color symbolism
                   'regional',      -- palette is from the same cultural sphere
                   'technique',     -- palette tied to a technique entry
                   'inspired_by'    -- contemporary palette inspired by this tradition
                 )),
  color_note     text,        -- subscriber-facing one-liner shown on palette card
  linked_by      text,        -- staff name for accountability
  linked_at      timestamptz  not null default now()
);

create unique index if not exists cs_palette_atlas_unique
  on public.cs_palette_atlas_links (palette_id, atlas_entry_id);

create index if not exists cs_palette_atlas_palette_idx
  on public.cs_palette_atlas_links (palette_id);

create index if not exists cs_palette_atlas_entry_idx
  on public.cs_palette_atlas_links (atlas_entry_id);

alter table public.cs_palette_atlas_links enable row level security;

-- Palette context is subscriber-facing and public-safe — no CRM data here
create policy "public read palette_atlas"
  on public.cs_palette_atlas_links for select
  to anon, authenticated using (true);

create policy "admin insert palette_atlas"
  on public.cs_palette_atlas_links for insert
  to authenticated with check (cs_is_admin());

create policy "admin update palette_atlas"
  on public.cs_palette_atlas_links for update
  to authenticated using (cs_is_admin());

create policy "admin delete palette_atlas"
  on public.cs_palette_atlas_links for delete
  to authenticated using (cs_is_admin());


-- ── 3. FEATURED TRADITION VIEW ───────────────────────────────────────────────
--
--  Returns the single tradition to feature this ISO week.
--  Set featured_at on the row you want featured — the view does the rest.
--
--  Fallback order if no exact-week match:
--    1. Most recently featured entry
--    2. Most recently published entry

create or replace view public.cs_atlas_featured as
select
  ae.id,
  ae.name,
  ae.slug,
  ae.entry_type,
  ae.short_definition,
  ae.hook,
  ae.body,
  ae.hero_image_url,
  ae.key_term,
  ae.key_term_def,
  ae.color_symbolism,
  ae.featured_at,
  ae.cultural_context
from public.cs_atlas_entries ae
where ae.is_public     = true
  and ae.source_status = 'published'
order by
  case
    when extract(week from ae.featured_at) = extract(week from current_date)
     and extract(year from ae.featured_at) = extract(year  from current_date)
    then 0
    else 1
  end,
  ae.featured_at desc nulls last,
  ae.created_at  desc
limit 1;


-- ── 4. PALETTE CONTEXT VIEW ───────────────────────────────────────────────────
--
--  Used by My World palette cards to surface one-line cultural context.
--  Returns the single best link per palette — primary tradition takes priority.
--
--  Query from the client:
--    db.from('cs_palette_context').select('*').in('palette_id', paletteIds)

create or replace view public.cs_palette_context as
select distinct on (pal.palette_id)
  pal.palette_id,
  pal.color_note,
  pal.link_type,
  ae.name             as tradition_name,
  ae.slug             as tradition_slug,
  ae.hook             as tradition_hook,
  ae.color_symbolism  as tradition_color_symbolism
from public.cs_palette_atlas_links pal
join public.cs_atlas_entries ae
  on ae.id             = pal.atlas_entry_id
 and ae.is_public      = true
 and ae.source_status  = 'published'
order by
  pal.palette_id,
  case pal.link_type
    when 'tradition'    then 1
    when 'color_system' then 2
    when 'regional'     then 3
    when 'technique'    then 4
    when 'inspired_by'  then 5
  end;


-- ── 5. VERIFICATION ──────────────────────────────────────────────────────────
--
-- After running, confirm columns were added:
--
--   select column_name, data_type
--   from information_schema.columns
--   where table_schema = 'public'
--     and table_name   = 'cs_atlas_entries'
--     and column_name  in ('hook','body','hero_image_url','key_term',
--                          'key_term_def','color_symbolism','featured_at');
--
-- Confirm table and views:
--
--   select table_name from information_schema.tables
--   where table_schema = 'public'
--     and table_name = 'cs_palette_atlas_links';
--
--   select * from public.cs_atlas_featured;          -- null until rows are seeded
--   select * from public.cs_palette_context limit 5; -- empty until links are seeded
--
-- To feature a tradition this week (example):
--
--   update public.cs_atlas_entries
--   set featured_at = current_date
--   where slug = 'kente'
--     and source_status = 'published';
--
-- To link a palette to a tradition (example):
--   palette_id is the raw UUID from the palettes table — NOT the full URL.
--   The URL (coco-palettes.cultureschool.org/?id=<uuid>) is built at display time.
--
--   insert into public.cs_palette_atlas_links
--     (palette_id, atlas_entry_id, link_type, color_note, linked_by)
--   select
--     '9a0a8794-2df5-54b0-ab5c-61a9bc8232ad',   -- palette UUID only
--     ae.id,
--     'tradition',
--     'Gold here represents royalty and wealth in Akan culture.',
--     'Stacey'
--   from public.cs_atlas_entries ae
--   where ae.slug = 'kente';
