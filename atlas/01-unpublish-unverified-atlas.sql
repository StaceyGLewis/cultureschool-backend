-- ============================================================================
--  01-unpublish-unverified-atlas.sql
--
--  PROBLEM: 24 cs_atlas_entries rows have is_public=true while
--  source_status != 'published' and/or reviewed_by is NULL.
--  Two are restricted (Hawaiian Quilt, Toile de Jouy) — high risk.
--
--  RULE: nothing is public without source_status='published' AND
--  a named reviewer. This is the governance guarantee for licensing.
--
--  RUN: run the DRY RUN SELECT first, review, then run the UPDATE.
--  Safe to run multiple times (idempotent).
-- ============================================================================

-- ── DRY RUN: see exactly what will change before applying ──────────────────
SELECT
  id,
  name,
  slug,
  source_status,
  sensitivity_level,
  reviewed_by,
  is_public,
  created_at
FROM public.cs_atlas_entries
WHERE is_public = true
  AND (
    source_status NOT IN ('published')
    OR reviewed_by IS NULL
    OR trim(reviewed_by) = ''
  )
ORDER BY sensitivity_level desc, name;

-- ── APPLY: unpublish every entry that doesn't meet the governance bar ───────
-- Note: source_status is NOT changed — only is_public is set to false.
-- The entries remain at whatever workflow stage they're in so researchers
-- can continue work and re-publish once they've met the bar.

UPDATE public.cs_atlas_entries
SET
  is_public   = false,
  updated_at  = now()
WHERE is_public = true
  AND (
    source_status NOT IN ('published')
    OR reviewed_by IS NULL
    OR trim(reviewed_by) = ''
  );

-- ── VERIFY: should return 0 rows after the update ──────────────────────────
SELECT count(*) AS still_public_unverified
FROM public.cs_atlas_entries
WHERE is_public = true
  AND (
    source_status NOT IN ('published')
    OR reviewed_by IS NULL
    OR trim(reviewed_by) = ''
  );
