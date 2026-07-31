-- ============================================================================
--  03-atlas-hygiene.sql
--
--  Name-only fixes for cs_atlas_entries. Corrects:
--  1. Garbled slug: mudcloth-b-g-lanfini  → bogolan-mudcloth
--     Name order: Mudcloth (Bògòlanfini)  → Bògòlanfini / Mudcloth (endonym first)
--  2. Garbled slug: navajo-din            → navajo-dine
--     Name fix:    Navajo / DinÃ©         → Navajo / Diné  (encoding repair)
--  3. Garbled name: Ã- East Asian…        → East Asian Geometric Tradition
--
--  T'nalak ×2: two rows exist with the same name but different slugs
--  (tnalak / philippine). These are noted but NOT deleted here — a human
--  must decide which is the canonical entry.
--
--  Run the DRY RUN SELECTs first, confirm the rows, then run the UPDATEs.
--  Each UPDATE targets its row by current (garbled) slug — will touch
--  exactly 1 row or 0 rows if already fixed.
-- ============================================================================

-- ── DRY RUN: verify the rows you're about to touch ─────────────────────────

-- Entry 1: Mudcloth / endonym
select id, name, slug, updated_at
from public.cs_atlas_entries
where slug = 'mudcloth-b-g-lanfini';

-- Entry 2: Navajo / Diné
select id, name, slug, updated_at
from public.cs_atlas_entries
where slug = 'navajo-din';

-- Entry 3: Garbled East Asian name
select id, name, slug, updated_at
from public.cs_atlas_entries
where name not ilike 'East Asian%'
  and name ilike '%East Asian Geometric%';

-- T'nalak duplicates
select id, name, slug, updated_at
from public.cs_atlas_entries
where name ilike '%nalak%'
order by created_at;

-- ── FIX 1: Mudcloth — endonym first, slug fixed ─────────────────────────────
update public.cs_atlas_entries
set
  name       = 'Bògòlanfini / Mudcloth',
  slug       = 'bogolan-mudcloth',
  updated_at = now()
where slug = 'mudcloth-b-g-lanfini';

-- ── FIX 2: Navajo / Diné — repair encoding, fix slug ───────────────────────
update public.cs_atlas_entries
set
  name       = 'Navajo / Diné',
  slug       = 'navajo-dine',
  updated_at = now()
where slug = 'navajo-din';

-- ── FIX 3: East Asian — strip garbled prefix ────────────────────────────────
update public.cs_atlas_entries
set
  name       = 'East Asian Geometric Tradition',
  updated_at = now()
where name not ilike 'East Asian%'
  and name ilike '%East Asian Geometric%';

-- ── VERIFY ──────────────────────────────────────────────────────────────────
select id, name, slug from public.cs_atlas_entries
where slug in ('bogolan-mudcloth','navajo-dine')
   or name = 'East Asian Geometric Tradition'
order by name;

-- ── T'NALAK DUPLICATES: human decision needed ────────────────────────────────
-- Two rows exist: slug 'tnalak' and slug 'philippine' (restricted, possibly a
-- mislabel-catcher). Review both and delete whichever is not the canonical entry.
-- DO NOT auto-delete — this is a data governance call, not a hygiene fix.
select id, name, slug, sensitivity_level, source_status, is_public
from public.cs_atlas_entries
where name ilike '%nalak%'
order by created_at;
