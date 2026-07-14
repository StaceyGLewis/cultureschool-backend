-- ============================================================================
-- PURGE-RUNES.SQL
-- Editorial safety: remove all ADL-listed extremist Elder Futhark content.
--
-- Three palettes reference hate-associated rune symbols:
--   • Algiz (Lebensborn "life rune") — "Algiz and Aurolia"
--   • Sowilo/Siegrune (SS double lightning) — "Sowilo of the North"
--   • Berkano (Waffen-SS, appropriated) — "Berkano and Birch"
--
-- PROCEDURE (follow in order):
--   1. Run STEP 1 DISCOVER block — read-only; copy counts to the PR.
--   2. Run STEP 2 FIX block — wrapped in a transaction; ROLLBACK is the
--      default last line. Inspect before/after counts.
--   3. Run STEP 3 VERIFY block — every count must return 0.
--   4. Replace ROLLBACK with COMMIT and re-run Step 2.
--
-- Rules (from editorial brief):
--   • tags is text[] — use ARRAY[...]::text[]
--   • code is a URL slug — changing it breaks existing links; do it anyway.
--   • Do NOT flag "ss " as a hit (false positive in English).
--   • Only flag 88 as a standalone token, not inside UUIDs.
-- ============================================================================


-- ═══════════════════════════════════════════════════════════════════
-- STEP 1  DISCOVER  (read-only; run before touching anything)
-- ═══════════════════════════════════════════════════════════════════

-- ── 1a. palettes ──────────────────────────────────────────────────
SELECT
  'palettes' AS tbl, id,
  name, code, cultural_origin,
  LEFT(description, 100) AS description,
  LEFT(story, 100)       AS story,
  ARRAY_TO_STRING(tags, ', ') AS tags_flat
FROM public.palettes
WHERE
  name         ILIKE ANY(ARRAY[
    '%algiz%','%sowilo%','%siegrune%','%othala%','%odal%','%tiwaz%',
    '%tyr rune%','%wolfsangel%','%valknut%','%sonnenrad%','%black sun%',
    '%life rune%','%futhark%','%rune%','%runic%','%swastika%','%fylfot%',
    '%berkano%','%blood and soil%','%14 words%'
  ])
  OR code      ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%','%rune%'])
  OR description ILIKE ANY(ARRAY[
    '%algiz%','%sowilo%','%siegrune%','%othala%','%odal%','%tiwaz%',
    '%wolfsangel%','%valknut%','%sonnenrad%','%futhark%','%berkano%',
    '%swastika%','%fylfot%','%rune%','%runic%','%life rune%'
  ])
  OR story     ILIKE ANY(ARRAY[
    '%algiz%','%sowilo%','%berkano%','%futhark%','%rune%','%runic%',
    '%swastika%','%siegrune%','%othala%'
  ])
  OR EXISTS (
    SELECT 1 FROM UNNEST(tags) t
    WHERE t ILIKE ANY(ARRAY[
      '%rune%','%algiz%','%sowilo%','%berkano%','%futhark%','%norse%',
      '%siegrune%','%othala%'
    ])
  )
  OR cultural_origin ILIKE ANY(ARRAY['%rune%','%futhark%','%algiz%']);

-- ── 1b. patterns ──────────────────────────────────────────────────
SELECT
  'patterns' AS tbl, id,
  style, name, palette_name,
  LEFT(description, 100)      AS description,
  heritage_name,
  LEFT(heritage_meaning, 120) AS heritage_meaning_preview,
  ARRAY_TO_STRING(heritage_tags, ', ') AS heritage_tags_flat
FROM public.patterns
WHERE
  style        ILIKE ANY(ARRAY['%rune%','%runic%'])
  OR name      ILIKE ANY(ARRAY[
    '%algiz%','%sowilo%','%berkano%','%rune%','%futhark%'
  ])
  OR description ILIKE ANY(ARRAY[
    '%rune%','%runic%','%algiz%','%sowilo%','%berkano%','%futhark%'
  ])
  OR heritage_name ILIKE ANY(ARRAY['%rune%','%runic%','%algiz%','%futhark%'])
  OR heritage_meaning ILIKE ANY(ARRAY[
    '%algiz%','%sowilo%','%siegrune%','%othala%','%berkano%','%futhark%',
    '%rune%','%runic%','%tiwaz%','%wolfsangel%'
  ])
  OR heritage_significance ILIKE ANY(ARRAY['%rune%','%algiz%','%futhark%'])
  OR heritage_technique    ILIKE ANY(ARRAY['%rune%','%algiz%','%futhark%'])
  OR palette_name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])
  OR EXISTS (
    SELECT 1 FROM UNNEST(heritage_tags) t
    WHERE t ILIKE ANY(ARRAY['%rune%','%algiz%','%sowilo%','%berkano%','%futhark%'])
  );

-- ── 1c. Schema precheck — find text columns in secondary tables ───
-- Run this first to see what's actually searchable in each table.
-- The DO block below (1d) uses this same list dynamically.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('coco_art','cocoboards','asset_packs','market_items',
                     'shop_curations','collections')
  AND data_type IN ('text','character varying')
ORDER BY table_name, ordinal_position;

-- ── 1d. Dynamic sweep of all text columns in secondary tables ─────
-- Reports via RAISE NOTICE — check the Messages tab in Supabase.
DO $$
DECLARE
  rec       RECORD;
  hit_count INT;
  total     INT := 0;
  sql       TEXT;
BEGIN
  FOR rec IN
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('coco_art','cocoboards','asset_packs','market_items',
                         'shop_curations','collections')
      AND data_type IN ('text','character varying')
    ORDER BY table_name, column_name
  LOOP
    sql := format(
      $q$SELECT COUNT(*) FROM public.%I
         WHERE %I ILIKE ANY(ARRAY[
           '%%algiz%%','%%sowilo%%','%%siegrune%%','%%berkano%%',
           '%%futhark%%','%%rune%%','%%runic%%','%%othala%%',
           '%%tiwaz%%','%%wolfsangel%%','%%valknut%%','%%sonnenrad%%'
         ])$q$,
      rec.table_name, rec.column_name
    );
    EXECUTE sql INTO hit_count;
    IF hit_count > 0 THEN
      RAISE NOTICE 'HIT  %.%  — % row(s)', rec.table_name, rec.column_name, hit_count;
      total := total + hit_count;
    END IF;
  END LOOP;

  IF total = 0 THEN
    RAISE NOTICE 'All secondary tables CLEAN — 0 hits across all text columns.';
  ELSE
    RAISE NOTICE 'TOTAL secondary table hits: % — investigate before continuing.', total;
  END IF;
END $$;

-- ── 1i. Summarised hit counts (run last; paste these into the PR) ──
SELECT
  'palettes.rune_palette_names'    AS check_point,
  COUNT(*) AS hits
FROM public.palettes
WHERE name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%','%rune%','%runic%','%futhark%'])

UNION ALL

SELECT
  'patterns.style_runes',
  COUNT(*)
FROM public.patterns WHERE style = 'runes'

UNION ALL

SELECT
  'patterns.description_runes_tradition',
  COUNT(*)
FROM public.patterns
WHERE description ILIKE '%runes tradition%'

UNION ALL

SELECT
  'patterns.heritage_name_runes',
  COUNT(*)
FROM public.patterns WHERE heritage_name ILIKE '%rune%'

UNION ALL

SELECT
  'patterns.heritage_meaning_nazi_runes',
  COUNT(*)
FROM public.patterns
WHERE heritage_meaning ILIKE ANY(ARRAY[
  '%algiz%','%sowilo%','%siegrune%','%othala%','%berkano%','%futhark%'
])

UNION ALL

SELECT
  'patterns.palette_name_rune_palettes',
  COUNT(*)
FROM public.patterns
WHERE palette_name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])

ORDER BY check_point;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 2  FIX  (transaction — ROLLBACK is the default)
-- ═══════════════════════════════════════════════════════════════════

BEGIN;

-- ── Before counts ────────────────────────────────────────────────
SELECT 'BEFORE' AS phase,
  (SELECT COUNT(*) FROM public.palettes
   WHERE name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])) AS rune_palettes,
  (SELECT COUNT(*) FROM public.patterns WHERE style = 'runes')    AS rune_style_patterns,
  (SELECT COUNT(*) FROM public.patterns
   WHERE description ILIKE '%runes tradition%')                   AS desc_runes_tradition,
  (SELECT COUNT(*) FROM public.patterns WHERE heritage_name ILIKE '%rune%') AS heritage_name_runes,
  (SELECT COUNT(*) FROM public.patterns
   WHERE palette_name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])) AS rune_palette_patterns;


-- ─────────────────────────────────────────────────────────────────
-- 2A. FIX PALETTES
-- Fix all five editable columns + null cultural_origin.
-- IDs taken from CSV export (algiz, berkano). Sowilo found by name.
-- ─────────────────────────────────────────────────────────────────

-- Palette 1: "Algiz and Aurolia" → "Aurolia Winter"
-- Algiz = Lebensborn "life rune". occasion "New Baby" is also removed.
UPDATE public.palettes
SET
  name           = 'Aurolia Winter',
  code           = 'aurolia-winter',
  description    = 'Icy aquas and winter light — a palette of shelter, watchfulness, and quiet strength.',
  story          = 'A Nordic winter palette: pale aqua, frost-lilac, and the still grey of a snow-quiet dawn. The colours of shelter, watchfulness, and a season held in stillness.',
  tags           = ARRAY['nordic','winter','protection','cool','textile']::text[],
  cultural_origin = NULL,
  occasion       = 'Winter'
WHERE id = '8c712a91-3c42-4c17-91c9-314b0d9404ea';

-- Palette 2: "Berkano and Birch" → "Birch and Thaw"
UPDATE public.palettes
SET
  name           = 'Birch and Thaw',
  code           = 'birch-and-thaw',
  description    = 'Birch-bark greys and thaw-blue — the first colours of a northern spring.',
  story          = 'The pale blue of thaw, the soft grey of birch bark, and the fresh cool light of a season turning. A palette for renewal and the long-anticipated return of spring.',
  tags           = ARRAY['nordic','birch','renewal','spring','textile']::text[],
  cultural_origin = NULL
WHERE id = 'b386cfcf-08e0-4d86-9945-395e055a6a63';

-- Palette 3: "Sowilo of the North" → "Northern Light"
-- Sowilo = Siegrune, the SS double lightning bolt — highest-risk symbol.
UPDATE public.palettes
SET
  name           = 'Northern Light',
  code           = 'northern-light',
  description    = REGEXP_REPLACE(
                     REGEXP_REPLACE(
                       REGEXP_REPLACE(description,
                         'sowilo[^,.;]*[,.]?\s*', '', 'gi'),
                       'sun.{0,10}rune[^,.;]*[,.]?\s*', '', 'gi'),
                     '\bsiegrune\b[^,.;]*[,.]?\s*', '', 'gi'),
  story          = REGEXP_REPLACE(
                     REGEXP_REPLACE(
                       REGEXP_REPLACE(story,
                         'sowilo[^.]*\.', 'Golden amber and long northern light.', 'gi'),
                       'siegrune[^.]*\.', '', 'gi'),
                     'sun.{0,10}rune[^.]*\.', '', 'gi'),
  tags           = ARRAY(
                     SELECT DISTINCT t
                     FROM UNNEST(tags) t
                     WHERE t NOT ILIKE ANY(ARRAY[
                       '%sowilo%','%rune%','%siegrune%','%norse%','%futhark%'
                     ])
                   ),
  cultural_origin = NULL
WHERE name = 'Sowilo of the North';

-- Verify exactly 3 palettes were updated
DO $$
DECLARE
  rune_count INT;
BEGIN
  SELECT COUNT(*) INTO rune_count
  FROM public.palettes
  WHERE name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%']);
  IF rune_count > 0 THEN
    RAISE EXCEPTION 'Palette update incomplete — % rune palette(s) still match', rune_count;
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────
-- 2B. CASCADE palette renames into patterns
-- Updates name, palette_name, and any embedded palette-name text
-- in description — for ALL pattern styles, not just runes.
-- ─────────────────────────────────────────────────────────────────

-- Algiz and Aurolia → Aurolia Winter
UPDATE public.patterns
SET
  name         = REPLACE(name,        'Algiz and Aurolia', 'Aurolia Winter'),
  palette_name = 'Aurolia Winter',
  description  = REPLACE(description, 'Algiz and Aurolia', 'Aurolia Winter')
WHERE palette_name = 'Algiz and Aurolia';

-- Berkano and Birch → Birch and Thaw
UPDATE public.patterns
SET
  name         = REPLACE(name,        'Berkano and Birch', 'Birch and Thaw'),
  palette_name = 'Birch and Thaw',
  description  = REPLACE(description, 'Berkano and Birch', 'Birch and Thaw')
WHERE palette_name = 'Berkano and Birch';

-- Sowilo of the North → Northern Light
UPDATE public.patterns
SET
  name         = REPLACE(name,        'Sowilo of the North', 'Northern Light'),
  palette_name = 'Northern Light',
  description  = REPLACE(description, 'Sowilo of the North', 'Northern Light')
WHERE palette_name = 'Sowilo of the North';


-- ─────────────────────────────────────────────────────────────────
-- 2C. RUNES → OGHAM
-- Replaces style, name, description, and all heritage_* fields.
-- The brief explicitly flags that description was missed in a
-- prior attempt and still reads "inspired by the Runes tradition."
-- ─────────────────────────────────────────────────────────────────

UPDATE public.patterns
SET
  -- Style key
  style            = 'ogham',

  -- Name: "* — Runes" → "* — Ogham"
  name             = REPLACE(name, '— Runes', '— Ogham'),

  -- Description: "Runes tradition" → "Ogham tradition" (case-insensitive via both cases)
  description      = REPLACE(
                       REPLACE(description, 'Runes tradition', 'Ogham tradition'),
                       'runes tradition', 'Ogham tradition'),

  -- Heritage — full replacement with Ogham content
  heritage_name    = 'Ogham',
  heritage_origin  = 'Celtic peoples of Ireland, Britain, and the Gaelic world',
  heritage_region  = 'Northern and Western Europe',
  heritage_era     = '4th–8th century CE, inscribed on standing stones',
  heritage_meaning = 'Ogham is the early Irish alphabet, inscribed as notches branching from or crossing a central stem-line. Each of the 25 letters belongs to one of four aicme (families): Beithe (right strokes), hÚatha (left strokes), Ailme (horizontal crossings), and Muine (diagonal strokes). Used for names, territorial markers, and dedications.',
  heritage_technique      = 'Vertical or angled strokes carved across a central stem-line, read bottom to top. In textile form: a repeating stemline with 1–5 notches cycling through the four aicme families.',
  heritage_significance   = 'A distinctively Celtic script with no association with any extremist movement — the literate heritage of early medieval Ireland and the Gaelic world.',
  heritage_tags    = ARRAY['celtic','irish','gaelic','alphabet','ancient-script','northern-europe']::text[]

WHERE style = 'runes';

-- Belt-and-suspenders: catch any rune-style rows that were already partially
-- updated in a prior attempt (style changed but description still reads Runes).
UPDATE public.patterns
SET
  description = REPLACE(
                  REPLACE(description, 'Runes tradition', 'Ogham tradition'),
                  'runes tradition', 'Ogham tradition'),
  heritage_name = 'Ogham',
  heritage_meaning = 'Ogham is the early Irish alphabet, inscribed as notches branching from or crossing a central stem-line. Each of the 25 letters belongs to one of four aicme (families): Beithe (right strokes), hÚatha (left strokes), Ailme (horizontal crossings), and Muine (diagonal strokes). Used for names, territorial markers, and dedications.',
  heritage_significance = 'A distinctively Celtic script with no association with any extremist movement — the literate heritage of early medieval Ireland and the Gaelic world.'
WHERE style = 'ogham'
  AND (
    description   ILIKE '%runes tradition%'
    OR heritage_name   ILIKE '%rune%'
    OR heritage_meaning ILIKE ANY(ARRAY[
      '%algiz%','%sowilo%','%siegrune%','%berkano%','%othala%','%futhark%'
    ])
  );

-- ── After counts ─────────────────────────────────────────────────
SELECT 'AFTER' AS phase,
  (SELECT COUNT(*) FROM public.palettes
   WHERE name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])) AS rune_palettes,
  (SELECT COUNT(*) FROM public.patterns WHERE style = 'runes')    AS rune_style_patterns,
  (SELECT COUNT(*) FROM public.patterns
   WHERE description ILIKE '%runes tradition%')                   AS desc_runes_tradition,
  (SELECT COUNT(*) FROM public.patterns WHERE heritage_name ILIKE '%rune%') AS heritage_name_runes,
  (SELECT COUNT(*) FROM public.patterns
   WHERE palette_name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])) AS rune_palette_patterns;

-- ─────────────────────────────────────────────────────────────────
-- DEFAULT: ROLLBACK
-- After verifying AFTER counts are all zero, swap to COMMIT.
-- ─────────────────────────────────────────────────────────────────
ROLLBACK;
-- COMMIT; -- ← uncomment only when STEP 3 VERIFY returns all zeros


-- ═══════════════════════════════════════════════════════════════════
-- STEP 3  VERIFY  (run after COMMIT; every count must be 0)
-- ═══════════════════════════════════════════════════════════════════

SELECT
  'palettes.name_rune_terms'         AS check_point, COUNT(*) AS hits
FROM public.palettes
WHERE name ILIKE ANY(ARRAY[
  '%algiz%','%sowilo%','%siegrune%','%berkano%','%rune%','%runic%','%futhark%',
  '%othala%','%odal%','%tiwaz%','%wolfsangel%','%valknut%','%sonnenrad%'
])
UNION ALL
SELECT 'palettes.code_rune_terms', COUNT(*)
FROM public.palettes
WHERE code ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%','%rune%'])
UNION ALL
SELECT 'palettes.description_rune_terms', COUNT(*)
FROM public.palettes
WHERE description ILIKE ANY(ARRAY[
  '%algiz%','%sowilo%','%berkano%','%rune%','%runic%','%futhark%'
])
UNION ALL
SELECT 'palettes.story_rune_terms', COUNT(*)
FROM public.palettes
WHERE story ILIKE ANY(ARRAY[
  '%algiz%','%sowilo%','%berkano%','%rune%','%runic%','%futhark%'
])
UNION ALL
SELECT 'palettes.tags_rune_terms', COUNT(*)
FROM public.palettes
WHERE EXISTS (
  SELECT 1 FROM UNNEST(tags) t
  WHERE t ILIKE ANY(ARRAY['%rune%','%algiz%','%sowilo%','%berkano%','%futhark%'])
)
UNION ALL
SELECT 'patterns.style_runes', COUNT(*)
FROM public.patterns WHERE style = 'runes'
UNION ALL
SELECT 'patterns.name_rune_terms', COUNT(*)
FROM public.patterns
WHERE name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%','%rune%','%futhark%'])
UNION ALL
SELECT 'patterns.description_rune_terms', COUNT(*)
FROM public.patterns
WHERE description ILIKE ANY(ARRAY[
  '%rune%','%runic%','%algiz%','%sowilo%','%berkano%','%futhark%'
])
UNION ALL
SELECT 'patterns.heritage_name_rune_terms', COUNT(*)
FROM public.patterns WHERE heritage_name ILIKE ANY(ARRAY['%rune%','%runic%','%futhark%'])
UNION ALL
SELECT 'patterns.heritage_meaning_nazi_runes', COUNT(*)
FROM public.patterns
WHERE heritage_meaning ILIKE ANY(ARRAY[
  '%algiz%','%sowilo%','%siegrune%','%othala%','%berkano%','%futhark%','%tiwaz%','%wolfsangel%'
])
UNION ALL
SELECT 'patterns.heritage_tags_rune_terms', COUNT(*)
FROM public.patterns
WHERE EXISTS (
  SELECT 1 FROM UNNEST(heritage_tags) t
  WHERE t ILIKE ANY(ARRAY['%rune%','%algiz%','%sowilo%','%berkano%','%futhark%'])
)
UNION ALL
SELECT 'patterns.palette_name_rune_palettes', COUNT(*)
FROM public.patterns
WHERE palette_name ILIKE ANY(ARRAY['%algiz%','%sowilo%','%berkano%'])

ORDER BY check_point;

-- Every row above must show hits = 0 before this migration is considered complete.
-- If any return > 0, investigate and fix before shipping.

-- ─────────────────────────────────────────────────────────────────
-- STEP 4  SHOPIFY CHECK  (manual — cannot run via Supabase editor)
-- ─────────────────────────────────────────────────────────────────
-- In the Shopify Admin, run Product searches for:
--   "rune"              "runic"          "algiz"
--   "sowilo"            "berkano"        "futhark"
--   "Algiz and Aurolia" "Sowilo of the North" "Berkano and Birch"
--   "norse"             "viking"
-- Any matches that reference these terms in title, description, or
-- tags must be updated to use the new palette names or have rune
-- language removed before the DB commit goes live.
-- ─────────────────────────────────────────────────────────────────
