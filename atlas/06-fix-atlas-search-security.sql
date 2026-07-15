-- ============================================================================
--  06-fix-atlas-search-security.sql
--
--  Fixes: Supabase linter ERROR — cs_atlas_search is SECURITY DEFINER.
--
--  Views created in the public schema default to SECURITY DEFINER in
--  Supabase, meaning they run as the view creator and bypass RLS on the
--  underlying tables. This allows any anon query of the view to see ALL
--  rows including sacred_private entries that RLS should be hiding.
--
--  Fix: recreate with security_invoker = true so the view runs as the
--  querying role and respects whatever RLS policies are on cs_atlas_entries.
--
--  Safe to re-run. The view definition is identical to the one in
--  04-atlas-kg-backfill.sql — only the security mode changes.
-- ============================================================================

drop view if exists public.cs_atlas_search;
create view public.cs_atlas_search
  with (security_invoker = true)
as
select
  e.id,
  e.entry_id,
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
  e.researched_by,
  e.sources_verified,
  e.updated_at,
  (select count(*) from public.cs_atlas_distinctions d
   where d.atlas_entry_id = e.id)                  as distinction_count,
  (select count(*) from public.cs_atlas_practice p
   where p.atlas_entry_id = e.id and p.is_public)  as practitioner_count
from public.cs_atlas_entries e;

-- ── VERIFY: confirm security_invoker is set ──────────────────────────────────
select viewname,
       (select option_value
        from pg_options_to_table(c.reloptions)
        where option_name = 'security_invoker') as security_invoker
from pg_views v
join pg_class c on c.relname = v.viewname
where v.schemaname = 'public'
  and v.viewname = 'cs_atlas_search';
-- Expected: security_invoker = 'true'
-- If null/missing, you are on PG < 15 — contact Supabase support.
