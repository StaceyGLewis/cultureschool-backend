-- ============================================================================
--  fix-misnomers.sql — style key renames + Bargello seed
--
--  DEPLOY SIMULTANEOUSLY with the patterng.html generator patch.
--  DB style values and generator key values must match, or patterns
--  stop resolving. Run this first, then deploy the generator.
--
--  Safe to run multiple times (idempotent WHERE clauses).
-- ============================================================================

-- ── 1. caribbeancarnival → madras ──────────────────────────────────────────
-- The artwork is a genuine madras plaid. The label was wrong.
-- heritage_name stays 'Madras' (correct); no heritage fields cleared.
UPDATE public.patterns
SET    style = 'madras'
WHERE  style = 'caribbeancarnival';

-- ── 2. philippine → songket  (T'nalak removed from generator — sacred status) ──
-- The artwork style was mislabelled 'philippine'. It was renamed to 'tnalak' in a
-- prior migration. The generator now uses 'songket' instead: T'nalak designs are
-- received in dreams by T'boli dreamweavers and are considered sacred. CFA review
-- would be required before any commercial use; removing the style is the safer path.
-- Run both UPDATEs: the first handles any rows still stuck on 'philippine'.
UPDATE public.patterns
SET    style        = 'songket',
       heritage_name = 'Songket',
       heritage_origin = 'Malaysia / Indonesia — supplementary-weft brocade with metallic threads',
       heritage_region = 'Southeast Asia'
WHERE  style = 'philippine';

UPDATE public.patterns
SET    style        = 'songket',
       heritage_name = 'Songket',
       heritage_origin = 'Malaysia / Indonesia — supplementary-weft brocade with metallic threads',
       heritage_region = 'Southeast Asia'
WHERE  style = 'tnalak';

-- ── 3. brazilian → mesh  (strip the false cultural claim) ──────────────────
-- The draw function is an open diamond lattice — not Bargello, not Brazilian.
-- Clear every heritage field to remove the wrong claim.
UPDATE public.patterns
SET    style            = 'mesh',
       heritage_name    = NULL,
       heritage_origin  = NULL,
       heritage_region  = NULL,
       heritage_era     = NULL,
       heritage_technique = NULL
WHERE  style = 'brazilian';

-- ── 4. navajo → chief-blanket  (remove trademark; description was already correct) ──
-- The Navajo Nation holds a federal trademark on "Navajo" for textiles.
-- The draw function comment already said "Chief's blanket stepped diamond."
UPDATE public.patterns
SET    style           = 'chief-blanket',
       heritage_name   = 'Chief''s Blanket',
       heritage_origin = NULL,
       heritage_region = NULL
WHERE  style = 'navajo';

-- ── 5. runes → ogham (handled by purge-runes.sql) ──────────────────────────
-- The comprehensive rune purge — palettes, patterns, heritage fields, cascades,
-- discovery sweep, and verify — is in atlas/purge-runes.sql.
-- Run that file instead of anything here.
-- Do NOT run this file and purge-runes.sql in the same transaction.

-- ── 6. Verify counts (run after the UPDATE block, before committing) ────────
-- SELECT style, count(*) AS n
-- FROM   public.patterns
-- WHERE  style IN ('madras','songket','mesh','bargello','chief-blanket','ogham',
--                  'caribbeancarnival','philippine','tnalak','brazilian','navajo','runes')
-- GROUP  BY style
-- ORDER  BY style;
-- Expected: madras, songket, mesh, chief-blanket all have rows;
--           caribbeancarnival, philippine, tnalak, brazilian, navajo return 0 rows.
--           runes: check before deciding restyle vs delete (see step 5 above).
--           bargello, ogham: 0 until seeded.

-- ── 7. Seed Bargello patterns ───────────────────────────────────────────────
-- The generator now has a real Bargello style. Seed one representative pattern
-- row per existing palette so the library has content to show.
--
-- PREREQUISITE: the patterns table must have a palette_id or palette column
-- that links to the palettes table. Adjust the sub-select to match your schema.
-- The INSERT below uses a minimal required set of columns. Add any NOT NULL
-- columns your schema requires.
--
-- Uncomment and run once you confirm the column names are correct:
--
-- INSERT INTO public.patterns
--   (style, heritage_name, heritage_origin, heritage_region, heritage_era,
--    heritage_technique, palette_id)
-- SELECT
--   'bargello',
--   'Bargello',
--   'Florence, Italy — European counted-thread needlework, named for the Bargello Palace',
--   'Europe / Mediterranean',
--   'The "flame stitch"; associated with 17th-century Florentine chairs',
--   'Counted-thread embroidery: vertical stitches stepped into peaks and valleys, worked in ombré bands',
--   id
-- FROM  public.palettes
-- ON CONFLICT DO NOTHING;
