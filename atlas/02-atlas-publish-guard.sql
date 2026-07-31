-- ============================================================================
--  02-atlas-publish-guard.sql
--
--  Enforces the Atlas governance contract at the DB level so no UI bug,
--  direct API call, or future migration can accidentally publish
--  unverified entries.
--
--  Also adds the full verification-workflow columns if they don't already
--  exist (researched_by, researched_at, sources_verified, entry_type).
--
--  Run AFTER 005_atlas_layer.sql and 01-unpublish-unverified-atlas.sql.
--  Safe to re-run (uses CREATE OR REPLACE / IF NOT EXISTS / DROP IF EXISTS).
-- ============================================================================

-- ── 1. ADD MISSING WORKFLOW COLUMNS ─────────────────────────────────────────
-- These columns support the 4-stage workflow: draft → researched → reviewed → published.
-- Use IF NOT EXISTS so this is safe to re-run on a DB that already has them.

alter table public.cs_atlas_entries
  add column if not exists entry_type       text,
  add column if not exists researched_by    text,
  add column if not exists researched_at    timestamptz,
  add column if not exists sources_verified boolean not null default false;

-- ── 2. THE GUARD FUNCTION ────────────────────────────────────────────────────
create or replace function public.cs_atlas_publish_guard()
returns trigger language plpgsql as $$
begin
  -- Only enforce when is_public is being set to true
  if new.is_public = true then

    -- REVIEWER: named human required. Authority = accountability.
    if new.reviewed_by is null or trim(new.reviewed_by) = '' then
      raise exception
        'Atlas publish blocked: reviewed_by must be a named person. '
        'Authority requires accountability.';
    end if;

    -- STATUS: must be explicitly published, not just reviewed
    if new.source_status not in ('published') then
      raise exception
        'Atlas publish blocked: source_status must be ''published'', got ''%''. '
        'Set status to published first.', new.source_status;
    end if;

    -- SENSITIVITY: sacred_private is never public, ever
    if new.sensitivity_level = 'sacred_private' then
      raise exception
        'Atlas publish blocked: sacred_private entries can never be public. '
        'This is a hard rule.';
    end if;

    -- CULTURAL CONTEXT: required before going public
    if new.cultural_context is null or trim(new.cultural_context) = '' then
      raise exception
        'Atlas publish blocked: cultural_context is required before publishing. '
        'This is what reviewers are verifying.';
    end if;

    -- SELF-REVIEW: researcher and reviewer must be different people
    -- Only enforce if both are set (allows legacy entries where researched_by is NULL)
    if new.researched_by is not null
       and trim(new.researched_by) <> ''
       and trim(new.researched_by) = trim(new.reviewed_by) then
      raise exception
        'Atlas publish blocked: researched_by and reviewed_by cannot be the same person. '
        'Two-person rule: researcher != reviewer.';
    end if;

  end if;
  return new;
end;
$$;

-- ── 3. WIRE THE TRIGGER ──────────────────────────────────────────────────────
drop trigger if exists trg_atlas_publish_guard on public.cs_atlas_entries;
create trigger trg_atlas_publish_guard
  before insert or update on public.cs_atlas_entries
  for each row execute function public.cs_atlas_publish_guard();

-- ── 4. VERIFY THE GUARD FIRES ───────────────────────────────────────────────
-- These should all raise exceptions. Run each in a separate transaction to test.

-- Test 1: no reviewer → should fail
-- begin;
-- update public.cs_atlas_entries set is_public=true, source_status='published', cultural_context='test', reviewed_by=null where slug='adinkra';
-- rollback;

-- Test 2: status not published → should fail
-- begin;
-- update public.cs_atlas_entries set is_public=true, source_status='reviewed', cultural_context='test', reviewed_by='Test Person' where slug='adinkra';
-- rollback;

-- Test 3: sacred_private → should fail
-- begin;
-- update public.cs_atlas_entries set is_public=true, source_status='published', cultural_context='test', reviewed_by='Test Person', sensitivity_level='sacred_private' where slug='adinkra';
-- rollback;

-- Test 4: researcher = reviewer → should fail
-- begin;
-- update public.cs_atlas_entries set is_public=true, source_status='published', cultural_context='test', reviewed_by='Stacey Grant', researched_by='Stacey Grant' where slug='adinkra';
-- rollback;
