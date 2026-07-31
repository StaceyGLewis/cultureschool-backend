-- ============================================================================
--  17-patterns-rls.sql
--
--  Locks down public.patterns so the archive is no longer readable in full
--  by anyone holding the anon key.
--
--  ⚠️  DO NOT RUN THIS FILE IN ONE GO.
--      Unlike 16-*, this one changes who can read 7,088 rows and touches five
--      consuming surfaces. Run SECTION 0, paste me the output, then we decide
--      together which of SECTION 3A / 3B you want before running anything else.
--
--  ── MEASURED STATE (2026-07-31, via anon key, no auth) ─────────────────────
--    • RLS is ENABLED on public.patterns, and NOT forced.  ← Section 0a result
--      "Not forced" is correct and expected: the table owner / service_role
--      bypasses RLS, which is what netlify/functions/skin-pattern.js relies on.
--
--    ── EXISTING POLICIES (0b result) ────────────────────────────────────────
--      patterns_public_select     SELECT  {public}         (is_public = true)
--      patterns_workspace_select  SELECT  {authenticated}  (workspace_enabled = true)
--
--      ⚠️  `patterns_public_select` IS THE LEAK, and it is the whole leak.
--          `{public}` is the PUBLIC pseudo-role — every role, anon included.
--          Its qual is `is_public = true`, and is_public is true on all 7,088
--          rows (0 rows have is_public = false). So it returns the entire
--          archive to everyone. It must be DROPPED, not supplemented:
--          PostgreSQL ORs permissive policies together, so adding tighter
--          policies alongside it would change nothing at all.
--
--      `patterns_workspace_select` currently matches 0 rows
--      (workspace_enabled = false on all 7,088), so it is inert today. It is
--      left in place — but note it grants ANY authenticated user, including a
--      free signed-up account, full read on any row that is later flipped to
--      workspace_enabled = true. See the note at the end of Section 3.
--
--    ── YOUR ACCOUNT (0e result) ─────────────────────────────────────────────
--      stacey.a.grant@gmail.com | is_subscriber t | all-access | admin t
--      → retains full access under every policy below. No lockout risk.
--
--    • public.patterns holds 7,088 rows
--    • is_public = true on ALL 7,088 — so `.eq('is_public', true)` filters nothing
--    • anon can SELECT every column of every row, including the full
--      heritage_* research text, `colors`, and `code`
--    • the library page requests limit=1000, but the REST endpoint will serve
--      all 7,088 to anyone who paginates
--
--  ── WHAT READS/WRITES THIS TABLE ───────────────────────────────────────────
--    dist/pattern-library.html      SELECT              anon   → to be gated
--    dist/index.html                SELECT              anon   → see SECTION 3
--    dist/planner.html              SELECT              anon   → see SECTION 3
--    patterng.html                  SELECT + INSERT     anon   → needs a write policy
--    public/generate-thumbs.html    SELECT + UPDATE     anon   → needs a write policy
--    netlify/functions/skin-pattern.js  SELECT     service_role → bypasses RLS, safe
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 0 — DIAGNOSTICS. RUN THIS FIRST, ON ITS OWN. CHANGES NOTHING.
-- ════════════════════════════════════════════════════════════════════════════

-- 0a. Is RLS already enabled on patterns, and is it forced?
select relname          as table_name,
       relrowsecurity   as rls_enabled,
       relforcerowsecurity as rls_forced
from pg_class
where oid = 'public.patterns'::regclass;

-- 0b. What policies already exist? (expect zero rows if RLS has never been set up)
select policyname, cmd, roles, permissive, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'patterns'
order by cmd, policyname;

-- 0c. What can anon/authenticated do at the GRANT level?
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'patterns'
  and grantee in ('anon','authenticated')
order by grantee, privilege_type;

-- 0d. Confirm the users table has the columns the access rule depends on.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'users'
  and column_name in ('email','is_subscriber','subscription_tier','admin')
order by column_name;

-- 0e. YOUR OWN ROW — confirm you will not lock yourself out.
--     is_subscriber must be true AND (subscription_tier='all-access' OR admin).
select email, is_subscriber, subscription_tier, admin
from public.users
where lower(email) = lower('stacey.a.grant@gmail.com');

-- 0f. How many accounts would retain full access after this change?
--
--     NOTE: public.users.admin is TEXT, not boolean — an earlier version of
--     this query failed with "argument of OR must be type boolean, not type
--     text". Every comparison below normalises it explicitly. Do the same
--     anywhere else you touch this column.
select count(*) filter (
         where is_subscriber
           and (subscription_tier = 'all-access'
                or lower(trim(coalesce(admin,''))) = 'true')
       ) as keeps_full_access,
       count(*) filter (
         where is_subscriber
           and subscription_tier is distinct from 'all-access'
           and lower(trim(coalesce(admin,''))) <> 'true'
       ) as demoted_to_free,
       count(*) as total_users
from public.users;

-- 0g. What is actually stored in users.admin? Confirms the normalisation above
--     covers every value in use (expect 'true' / 'false' / null).
select coalesce(admin,'«null»') as admin_value, count(*)
from public.users group by 1 order by 2 desc;

--  ⛔ STOP HERE. Send me 0a–0f before continuing.


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 1 — ACCESS HELPER
--
--  BEFORE: no way to ask "is the caller an all-access member?" inside a policy.
--  AFTER:  cs_has_all_access() returns true/false for the current JWT.
--
--  SECURITY DEFINER is required: the caller cannot read public.users under its
--  own RLS, but the function must. search_path is pinned so the definer rights
--  cannot be hijacked by a shadowed table name.
--
--  This mirrors the client rule already used in my-world.html and
--  dist/pattern-library.html:
--      is_subscriber AND (subscription_tier = 'all-access' OR admin)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.cs_has_all_access()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.users u
    where lower(u.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and coalesce(u.is_subscriber, false)
      -- u.admin is TEXT, not boolean — normalise, never rely on a cast
      and (u.subscription_tier = 'all-access'
           or lower(trim(coalesce(u.admin, ''))) = 'true')
  );
$$;

revoke all on function public.cs_has_all_access() from public;
grant execute on function public.cs_has_all_access() to anon, authenticated;

comment on function public.cs_has_all_access() is
  'True when the current JWT belongs to an all-access subscriber or a subscribed admin. Used by RLS on public.patterns.';

-- Verify: should return false in the SQL editor (no JWT context there).
select public.cs_has_all_access() as should_be_false;


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 2 — THE FREE SUBSET
--
--  BEFORE: "free" is decided in the browser — pattern-library.html picks one
--          pattern per style from FREE_STYLES at render time. The other 7,082
--          rows are already in the client. The choice is cosmetic.
--  AFTER:  "free" is a column on the row. The database decides, and non-members
--          are never sent anything else.
--
--  Marks exactly one pattern per free style (6 rows), choosing the oldest of
--  each for stability so the free set does not shift as new patterns are added.
-- ════════════════════════════════════════════════════════════════════════════

alter table public.patterns
  add column if not exists is_free boolean not null default false;

create index if not exists patterns_is_free_idx
  on public.patterns (is_free) where is_free;

-- Preview which rows WILL be marked free — run this before the update.
with ranked as (
  select id, name, style,
         row_number() over (partition by style order by created_at, id) as rn
  from public.patterns
  where is_public
    and style in ('kente','zellige','shibori','mudcloth','ikat','adinkra')
)
select id, style, name from ranked where rn = 1 order by style;

-- Apply. Idempotent: clears any previous marking first.
update public.patterns set is_free = false where is_free;

with ranked as (
  select id,
         row_number() over (partition by style order by created_at, id) as rn
  from public.patterns
  where is_public
    and style in ('kente','zellige','shibori','mudcloth','ikat','adinkra')
)
update public.patterns p
   set is_free = true
  from ranked r
 where p.id = r.id and r.rn = 1;

-- Verify: expect 6.
select count(*) as free_rows from public.patterns where is_free;


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 3 — CHOOSE ONE. These are mutually exclusive.
--
--  The problem: dist/index.html and dist/planner.html are PUBLIC product
--  surfaces, and they select `colors` and `code` — which together are enough to
--  regenerate any pattern. Restricting rows alone does not close the leak while
--  those surfaces can read those columns.
-- ════════════════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────────────────
--  SECTION 3A — ROW GATE ONLY  (smaller change, partial protection)
--
--  Non-members see 6 rows. Members see all 7,088.
--  ⚠️  index.html and planner.html will drop to those same 6 rows for logged-out
--      visitors. Their grids and the palette→pattern planner WILL look broken.
--      Only choose 3A if you accept that, or if those surfaces move to a
--      service-role function.
-- ────────────────────────────────────────────────────────────────────────────

/*
alter table public.patterns enable row level security;

drop policy if exists "patterns free read"    on public.patterns;
drop policy if exists "patterns member read"  on public.patterns;

-- Anyone (signed in or not) may read the free subset.
create policy "patterns free read"
  on public.patterns for select
  to anon, authenticated
  using (is_public and is_free);

-- All-access members may read everything public.
-- Two PERMISSIVE policies OR together, so members get free ∪ all = all.
create policy "patterns member read"
  on public.patterns for select
  to authenticated
  using (is_public and public.cs_has_all_access());
*/

-- ────────────────────────────────────────────────────────────────────────────
--  SECTION 3B — COLUMN SPLIT  (recommended)
--
--  Public surfaces keep every row they need for display, but lose the two
--  columns that constitute the IP: `colors` and `code`. They render from
--  thumb_url instead. Members read the base table and get everything.
--
--  This is the option that actually matches the locked decision — the archive
--  stays visible as product, the engine inputs stay gated.
--
--  ⚠️  DEPLOY BEFORE YOU RUN THIS.
--      dist/index.html and dist/planner.html have been repointed to
--      patterns_public in the repo (commit 369b82b), but you deploy by
--      dropping files into Netlify — so the LIVE copies still query the
--      `patterns` base table until you drop them.
--
--      Run this section while the old files are live and, the moment
--      patterns_public_select is dropped, anonymous visitors on the shop grid
--      and the planner get 6 rows instead of 7,088. Deploy first, then run.
--
--      RUN 3B IN TWO PASSES. Do not paste the whole section at once — the
--      view must exist before the clients point at it, and the clients must be
--      live before the old policy is dropped.
--
--        PASS 1  → run ONLY the `create or replace view` + `grant` + `comment`
--                  below. This changes NO access: the base table policies are
--                  untouched, everything keeps working exactly as it does now.
--
--        DEPLOY  → drop dist/index.html + dist/planner.html into Netlify.
--                  They query patterns_public, which now exists. Reload both
--                  logged OUT and confirm the grids are full.
--                  (Deploying before PASS 1 would break them — the view would
--                  not exist and every query would 404.)
--
--        PASS 2  → run the `drop policy patterns_public_select` + the two
--                  `create policy` statements. This is the moment the archive
--                  actually closes.
--
--        VERIFY  → reload index + planner logged OUT. Grids should still be
--                  full. Then check the library: logged out you should see 6
--                  patterns, not 7,088.
-- ────────────────────────────────────────────────────────────────────────────

/*
-- Display-safe projection for public product surfaces.
--
--  MEASURED before choosing these columns:
--    heritage_meaning     non-null on 7,088 / 7,088   ← the researched IP
--    code                 non-null on 0               ← column unused today
--    palette_story        non-null on 0               ← column unused today
--    contributor_email    non-null on 0               ← no PII exposure
--
--  EXCLUDED (this is the point of the view):
--    heritage_meaning, heritage_technique, heritage_significance, heritage_tags
--      → the deep cultural research text on all 7,088 rows. Neither index.html
--        nor planner.html renders it, so removing it breaks nothing. The
--        pattern library still shows it, because the library reads the base
--        table and non-members will only see the 6 free rows there — heritage
--        stays visible as the hook, exactly as intended.
--    description, palette_story, code, color_descriptor,
--    contributed_by, contributor_email
--
--  ⚠️  INCLUDED FOR NOW, AND IT SHOULDN'T BE: `colors`
--      index.html renders tiles to canvas from `colors`, and planner.html's
--      Step-C deltaE fallback computes palette distance from `colors`. Both
--      break without it, and thumb_url is null on all 7,088 rows so there is
--      no image to fall back to.
--
--      → Remove `colors` from this view once the thumbnail backfill is done
--        (Phase 1 in ENGINE-SPLIT-SCOPE.md). Until then, colors + the public
--        engine still permit regeneration. This view is an increment, not the
--        finish line. Do not describe the archive as closed until `colors` is
--        out of it.
--  ⚠️ SECURITY_INVOKER MUST BE OFF HERE — this is deliberate and load-bearing.
--
--     An earlier draft of this file said `security_invoker = on`, copying the
--     pattern from atlas/16. That would have broken the entire design:
--
--       security_invoker = on  → the view runs as the CALLER, so the caller's
--                                RLS on public.patterns applies. After
--                                patterns_public_select is dropped, anon would
--                                get 6 rows from this view, not 7,088. The
--                                shop grid and planner would still break —
--                                exactly what 3B exists to prevent.
--
--       security_invoker = off → the view runs as its OWNER (postgres), which
--                                bypasses RLS on the base table. Public
--                                surfaces get every public row, but only the
--                                columns selected below.
--
--     The view IS the privilege boundary. That is the point: the base table is
--     locked to members, and this projection is the controlled public window.
--
--     Consequence: Supabase's linter will flag this as a "Security Definer
--     View", the same warning atlas/16 cleaned up. That warning is CORRECT and
--     is being accepted deliberately here. Do not "fix" it by flipping this to
--     on — that silently empties the public surfaces. Leave this comment.
create or replace view public.patterns_public
with (security_invoker = off) as
select id, name, style, colors, occasion, thumb_url,
       palette_name, palette_id, grab_count, workspace_enabled, is_public,
       heritage_name, heritage_origin, heritage_region, heritage_era,
       continent, tags, search_tags, aesthetic_tags, created_at,
       -- `code` appended LAST on purpose: CREATE OR REPLACE VIEW can only add
       -- columns at the end. If you already ran an earlier version of this
       -- view, re-running this statement upgrades it in place.
       --
       -- It is included because index.html and planner.html both `select`
       -- it, and PostgREST errors on a column the view does not expose —
       -- planner would silently show "No patterns found". It is null on all
       -- 7,088 rows today, so exposing it leaks nothing.
       code
from public.patterns
where is_public;

grant select on public.patterns_public to anon, authenticated;

comment on view public.patterns_public is
  'Display-safe pattern projection for public product surfaces (index, planner). Excludes the deep heritage research text, description and palette_story. Still exposes colors as an interim measure until thumb_url is backfilled — see atlas/ENGINE-SPLIT-SCOPE.md.';

alter table public.patterns enable row level security;

-- ⚠️ REQUIRED FIRST — this is the line that actually closes the archive.
--    Without it the two policies below are decorative: permissive policies OR
--    together, so patterns_public_select would keep returning all 7,088 rows.
drop policy if exists "patterns_public_select" on public.patterns;

drop policy if exists "patterns free read"   on public.patterns;
drop policy if exists "patterns member read" on public.patterns;

create policy "patterns free read"
  on public.patterns for select
  to anon, authenticated
  using (is_public and is_free);

create policy "patterns member read"
  on public.patterns for select
  to authenticated
  using (is_public and public.cs_has_all_access());
*/


-- ────────────────────────────────────────────────────────────────────────────
--  NOTE ON patterns_workspace_select
--
--  It is inert today (0 rows have workspace_enabled = true) so neither 3A nor
--  3B touches it. But as written it grants EVERY authenticated user — including
--  a free account that just signed up — full read on any row flipped to
--  workspace_enabled = true. If workspace is meant to be a members' feature,
--  tighten it at the same time:
--
--    drop policy if exists "patterns_workspace_select" on public.patterns;
--    create policy "patterns_workspace_select"
--      on public.patterns for select to authenticated
--      using (workspace_enabled and public.cs_has_all_access());
--
--  Leave it alone if workspace is deliberately open to all signed-in users.
-- ────────────────────────────────────────────────────────────────────────────


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 4 — WRITE POLICIES
--
--  Enabling RLS with SELECT policies only will silently break two tools:
--    • patterng.html               INSERT  → pattern creation stops working
--    • public/generate-thumbs.html UPDATE  → thumbnail backfill stops working
--
--  Both currently write with the anon key, which means anyone with the key can
--  insert or overwrite patterns today. Restricting them to members is a
--  security improvement in its own right.
--
--  Run this in the SAME session as whichever of 3A/3B you pick.
-- ════════════════════════════════════════════════════════════════════════════

/*
drop policy if exists "patterns member insert" on public.patterns;
drop policy if exists "patterns member update" on public.patterns;

create policy "patterns member insert"
  on public.patterns for insert
  to authenticated
  with check (public.cs_has_all_access());

create policy "patterns member update"
  on public.patterns for update
  to authenticated
  using (public.cs_has_all_access())
  with check (public.cs_has_all_access());

-- No DELETE policy: deletion stays service-role only, matching cs_field_logs.

-- Drop the anon write grants entirely — they are no longer needed and are a
-- standing risk while the key is embedded in every page.
revoke insert, update, delete on public.patterns from anon;
*/

--  NOTE: after this, patterng.html and generate-thumbs.html must be signed in
--  as an all-access account to write. If you would rather they keep working
--  unauthenticated, they need to move to a Netlify function using the service
--  key — the same shape as netlify/functions/skin-pattern.js. Tell me which and
--  I will do that conversion.


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 5 — VERIFICATION (run after whichever option you chose)
-- ════════════════════════════════════════════════════════════════════════════

/*
-- 5a. Policies now in place.
select policyname, cmd, roles, permissive, qual
from pg_policies
where schemaname = 'public' and tablename = 'patterns'
order by cmd, policyname;

-- 5b. RLS is on.
select relrowsecurity from pg_class where oid = 'public.patterns'::regclass;

-- 5c. Row counts by audience. Run as the anon role to simulate a logged-out visitor:
set local role anon;
select count(*) as anon_can_see from public.patterns;   -- expect 6
reset role;

select count(*) as total_rows from public.patterns;     -- expect 7088
*/

--  5d. FINAL CHECK — from a browser console, logged OUT, on any CoCo surface:
--        await sb.from('patterns').select('id').limit(2000)
--      Expect: 6 rows. Anything more means a policy is too permissive.
--
--      Then log in as an all-access account and repeat. Expect 1000+ (page limit).


-- ════════════════════════════════════════════════════════════════════════════
--  SECTION 6 — ROLLBACK. Restores the current behaviour exactly.
-- ════════════════════════════════════════════════════════════════════════════

-- NOTE: RLS was already ENABLED before this migration — do NOT disable it.
-- Restoring means putting patterns_public_select back exactly as it was.
/*
drop policy if exists "patterns free read"     on public.patterns;
drop policy if exists "patterns member read"   on public.patterns;
drop policy if exists "patterns member insert" on public.patterns;
drop policy if exists "patterns member update" on public.patterns;

-- restore the original permissive read (verbatim from 0b)
create policy "patterns_public_select"
  on public.patterns for select
  to public
  using (is_public = true);

grant insert, update, delete on public.patterns to anon;
-- drop view if exists public.patterns_public;          -- only if 3B was run
-- drop function if exists public.cs_has_all_access();  -- only if fully reverting
-- alter table public.patterns drop column if exists is_free;
*/
