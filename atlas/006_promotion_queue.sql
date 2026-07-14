-- ============================================================================
--  ATLAS PROMOTION QUEUE — internal admin query
--
--  A Dictionary style is PROMOTED into the Atlas by a human editorial act:
--    1. Create an cs_atlas_entries row (source_status='draft')
--    2. Write cultural_context from cited sources
--    3. Attach cs_kg_sources rows via cs_kg_entry_sources
--    4. Set reviewed_by (named human), reviewed_at
--    5. Set source_status='published' + is_public=true  ← the publish gate
--
--  DO NOT auto-promote. Nothing publishes automatically.
--  A named human with cited sources is the only path to is_public=true.
-- ============================================================================


-- ── VIEW: cs_atlas_promotion_queue ──────────────────────────────────────────
-- Shows every pattern generator style that needs attention:
--   promoted     = has an Atlas entry (draft or published)
--   not_promoted = in cs_kg_entries as draft textile_tradition but no Atlas entry yet
--   needs_audit  = style key visible in live patterns, not yet in KG at all
--
-- Internal use only — never expose this view publicly.
create or replace view public.cs_atlas_promotion_queue as
with

-- all style keys that appear on live patterns
live_styles as (
  select distinct style as style_key, count(*) as pattern_count
  from public.patterns
  where style is not null
  group by style
),

-- Atlas entries that already exist (any status)
atlas_by_style as (
  select
    dictionary_style as style_key,
    slug             as atlas_slug,
    name             as atlas_name,
    source_status    as atlas_status,
    is_public        as atlas_is_public,
    reviewed_by      as atlas_reviewed_by
  from public.cs_atlas_entries
  where dictionary_style is not null
),

-- KG entries that are textile traditions (the source-of-record layer)
kg_traditions as (
  select
    slug  as kg_slug,
    name  as kg_name,
    source_status as kg_status
  from public.cs_kg_entries
  where entry_type = 'textile_tradition'
)

select
  coalesce(ls.style_key, ae.style_key)       as style_key,
  coalesce(ls.pattern_count, 0)              as live_pattern_count,

  case
    when ae.atlas_status = 'published' and ae.atlas_is_public then 'published'
    when ae.atlas_slug is not null            then 'draft'
    when ls.style_key  is not null            then 'not_promoted'
    else                                           'style_no_patterns'
  end                                         as promotion_status,

  ae.atlas_name,
  ae.atlas_status,
  ae.atlas_is_public,
  ae.atlas_reviewed_by,
  kt.kg_slug,
  kt.kg_status

from live_styles ls
full outer join atlas_by_style ae on ae.style_key = ls.style_key
left  join kg_traditions kt        on kt.kg_slug  = ls.style_key

order by
  -- prioritise by live exposure
  case when ae.atlas_slug is null then 0 else 1 end,
  ls.pattern_count desc nulls last,
  ls.style_key;

comment on view public.cs_atlas_promotion_queue is
'Internal admin view: maps live pattern style keys → Atlas entries → KG traditions.
 Use to decide which styles are ready to promote and what sourcing work remains.
 DO NOT expose publicly — shows unannotated style counts from live patterns.';


-- ── QUERY: what is ready to promote this sprint? ────────────────────────────
-- Run this ad-hoc to see highest-exposure styles with a sourced KG entry
-- but no Atlas entry yet.
--
-- select
--   style_key,
--   live_pattern_count,
--   kg_slug,
--   kg_status,
--   promotion_status
-- from public.cs_atlas_promotion_queue
-- where promotion_status = 'not_promoted'
--   and kg_status in ('researched','reviewed')    -- has content, needs Atlas shell
-- order by live_pattern_count desc;


-- ── QUERY: what is published and verified? ──────────────────────────────────
-- select
--   style_key,
--   atlas_name,
--   atlas_reviewed_by,
--   live_pattern_count
-- from public.cs_atlas_promotion_queue
-- where promotion_status = 'published'
-- order by live_pattern_count desc;
