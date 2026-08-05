-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — schema
--
-- NOT RUN. Review before applying. Additive only: creates new tables,
-- touches nothing that exists. No ALTER, no DROP, no data migration.
--
-- The prototype (dist/school.html) persists to localStorage through a
-- single `Store` object. Applying this schema and rewriting that one
-- object is the whole migration.
--
-- DESIGN CONSTRAINT, load-bearing: no student PII, anywhere.
-- A student is a display name plus a random device token. There is no
-- email column, no name column beyond the display name the teacher's
-- policy dictates, no date of birth, no free-text field a child could
-- put their own identity into except the artist statement itself.
-- That is what keeps this outside FERPA and COPPA rather than
-- compliant with them — there is no education record and no personal
-- information collected from a child under 13.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ── Orgs ───────────────────────────────────────────────────────────────
-- Licensing is per-school, annual. No payment integration in v1;
-- invoicing is manual at pilot scale, so this is a status flag only.
create table if not exists public.school_orgs (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  license_status text not null default 'pilot'
                 check (license_status in ('pilot','active','expired')),
  contact_email  text,                      -- a teacher/admin, never a student
  created_at     timestamptz not null default now()
);

-- ── Classes ────────────────────────────────────────────────────────────
create table if not exists public.classes (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid references public.school_orgs(id) on delete set null,
  teacher_email text not null,
  code          text not null unique
                check (code ~ '^[A-Z0-9]{6}$'),
  name          text not null,
  -- Teacher chooses per class how students identify themselves.
  name_policy   text not null default 'first_initial'
                check (name_policy in ('first_initial','alias')),
  assigned      text[] not null default '{}',   -- brief ids
  archived      boolean not null default false,
  created_at    timestamptz not null default now()
);
create index if not exists classes_teacher_idx on public.classes (lower(teacher_email));
create index if not exists classes_code_idx    on public.classes (code);

-- ── Members ────────────────────────────────────────────────────────────
-- display_name is the ONLY thing a student supplies. device_token is
-- generated client-side and identifies a returning browser, not a person.
create table if not exists public.class_members (
  id           uuid primary key default gen_random_uuid(),
  class_id     uuid not null references public.classes(id) on delete cascade,
  display_name text not null check (length(display_name) between 1 and 28),
  device_token text,
  joined_at    timestamptz not null default now(),
  unique (class_id, display_name)
);
create index if not exists members_class_idx on public.class_members (class_id);

-- Belt and braces: reject anything that looks like an email address in
-- the display name, whatever the client does.
alter table public.class_members
  drop constraint if exists class_members_display_name_not_email;
alter table public.class_members
  add  constraint class_members_display_name_not_email
       check (display_name !~ '@');

-- ── Briefs ─────────────────────────────────────────────────────────────
-- The three shipped briefs live in code (dist/school.html BRIEFS) so the
-- prototype needs no seed. This table is for teacher-authored copies.
create table if not exists public.briefs (
  id             uuid primary key default gen_random_uuid(),
  class_id       uuid references public.classes(id) on delete cascade,
  template_id    text,                     -- 'adinkra' | 'shibori' | 'geesbend' | null
  title          text not null,
  prompt_find      text,
  prompt_interpret text,
  prompt_own       text,
  pattern_style  text,                     -- joins patterns_public.style
  atlas_refs     text[] not null default '{}',
  standards_tags text[] not null default '{}',
  min_words      integer not null default 150,
  created_by     text,                     -- teacher email
  created_at     timestamptz not null default now()
);
create index if not exists briefs_class_idx on public.briefs (class_id);

-- ── Works ──────────────────────────────────────────────────────────────
create table if not exists public.class_works (
  id           uuid primary key default gen_random_uuid(),
  class_id     uuid not null references public.classes(id) on delete cascade,
  member_id    uuid not null references public.class_members(id) on delete cascade,
  brief_id     text not null,              -- template id, or briefs.id::text
  image_path   text,                       -- object in the private class-works bucket
  statement    text not null default '',
  credits      text[] not null default '{}',   -- the works-cited line
  status       text not null default 'draft'
               check (status in ('draft','submitted')),
  featured     boolean not null default false,
  hidden       boolean not null default false,
  created_at   timestamptz not null default now(),
  submitted_at timestamptz,
  unique (class_id, member_id, brief_id)
);
create index if not exists works_class_idx  on public.class_works (class_id);
create index if not exists works_member_idx on public.class_works (member_id);

-- ── Process receipts ───────────────────────────────────────────────────
-- AI-resistance evidence: what was looked at, tried, saved, and when.
-- Class-scoped, teacher-only, keyed to member_id. Never public.
create table if not exists public.class_events (
  id        bigserial primary key,
  class_id  uuid not null references public.classes(id) on delete cascade,
  member_id uuid references public.class_members(id) on delete cascade,
  kind      text not null
            check (kind in ('join','open_brief','view_tradition','open_studio',
                            'attach','save_draft','submit','resubmit')),
  detail    text,
  at        timestamptz not null default now()
);
create index if not exists events_class_member_idx on public.class_events (class_id, member_id, at);

-- ═══════════════════════════════════════════════════════════════════════
-- RLS
--
-- Enabled on every table with NO permissive policy for anon. Nothing
-- below grants direct browser access, deliberately: the student flow
-- must not be able to read another class, and PostgREST filters are
-- not a boundary a twelve-year-old can't edit in the URL bar.
--
-- Reads and writes go through security-definer RPCs that take the class
-- code and device token, so a caller can only ever reach the one class
-- they hold a code for. Those functions are NOT in this file — they are
-- the next piece of work, and shipping the tables locked-down-by-default
-- is the safe order.
-- ═══════════════════════════════════════════════════════════════════════
alter table public.school_orgs   enable row level security;
alter table public.classes       enable row level security;
alter table public.class_members enable row level security;
alter table public.briefs        enable row level security;
alter table public.class_works   enable row level security;
alter table public.class_events  enable row level security;

commit;

-- ── Storage ────────────────────────────────────────────────────────────
-- Run separately, after review.
--
-- Student work must NOT go to coco-drops or public-uploads: both are
-- public buckets on guessable paths (see docs/asset-library-audit.md
-- §1.2). A private bucket, served through signed URLs the teacher's
-- session mints, is the only acceptable home for a classroom artifact.
--
--   insert into storage.buckets (id, name, public)
--   values ('class-works', 'class-works', false);
--
-- Then a policy allowing insert/select only via the same RPC path.

-- ── Verification, after applying ───────────────────────────────────────
-- select tablename, rowsecurity from pg_tables
--  where schemaname='public'
--    and tablename in ('school_orgs','classes','class_members',
--                      'briefs','class_works','class_events');
--   -- every row must show rowsecurity = true
