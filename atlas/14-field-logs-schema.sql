-- ============================================================================
--  14-field-logs-schema.sql
--
--  Creates cs_field_logs — the backing store for the Field Log tool.
--  An intern drops up to 20 field photos; the tool distills palette,
--  heritage signals, and Atlas matches, then saves the session here.
--
--  Safe to re-run. Run in Supabase SQL Editor.
-- ============================================================================

create table if not exists public.cs_field_logs (
  id                uuid        primary key default gen_random_uuid(),

  -- Who / where / when
  title             text        not null,
  location          text,
  observed_date     date,
  source_type       text        default 'field',   -- market|supplier|event|archive|online|studio
  technique         text,                           -- free-text: "Batik, Adire, Kente…"
  logged_by         text,

  -- Corpus metadata
  corpus_label      text,                           -- user's raw label for the batch
  image_count       integer     default 0,

  -- Intelligence (written by the Field Log tool after processing)
  master_palette    jsonb,      -- [{hex, r, g, b, weight, img_count}]  ranked by share
  matched_palettes  jsonb,      -- [{id, name, code, colors[], score}]  top CultureSchool palettes
  heritage_signals  jsonb,      -- {feeling, occasion, vibe, patterns[], cultural_markers[]}
  atlas_matches     jsonb,      -- [{id, title, heritage_group, score}] top Atlas entry matches

  -- Researcher's own notes
  notes             text,

  created_at        timestamptz default now()
);

-- ── RLS (same pattern as cs_events — anon read + insert) ─────────────────────

alter table public.cs_field_logs enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'cs_field_logs' and policyname = 'anon read field logs'
  ) then
    create policy "anon read field logs"
      on public.cs_field_logs for select using (true);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'cs_field_logs' and policyname = 'anon insert field logs'
  ) then
    create policy "anon insert field logs"
      on public.cs_field_logs for insert with check (true);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'cs_field_logs' and policyname = 'anon update field logs'
  ) then
    create policy "anon update field logs"
      on public.cs_field_logs for update using (true);
  end if;
end $$;

-- ── Dashboard view ────────────────────────────────────────────────────────────
-- Used by the Intelligence Platform Field Logs module

create or replace view public.cs_dash_field_logs as
select
  id,
  title,
  location,
  observed_date,
  source_type,
  technique,
  logged_by,
  image_count,
  master_palette,
  matched_palettes,
  heritage_signals,
  atlas_matches,
  notes,
  created_at
from public.cs_field_logs
order by created_at desc
limit 50;

-- ── VERIFICATION ──────────────────────────────────────────────────────────────
-- select id, title, location, image_count, source_type, created_at
-- from public.cs_field_logs
-- order by created_at desc
-- limit 10;
