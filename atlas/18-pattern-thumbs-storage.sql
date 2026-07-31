-- ============================================================================
--  18-pattern-thumbs-storage.sql
--
--  Creates the `pattern-thumbs` storage bucket and its access policies, plus
--  a cs_is_admin() helper.
--
--  MEASURED 2026-07-31:
--    • bucket `pattern-thumbs` does NOT exist yet (404 NoSuchBucket)
--    • public/generate-thumbs.html has NO auth — it writes with the anon key
--
--  ⚠️  DEPENDENCY. atlas/17 Section 4 revokes anon INSERT/UPDATE on
--      public.patterns. generate-thumbs.html calls
--      `.update({ thumb_url }).eq('id', …)` — so once Section 4 runs, the
--      backfill CANNOT write results back unless it is signed in as an admin.
--      The matching admin gate has been added to that file. Deploy it.
--
--  Run order: this file, then atlas/17 Section 4, then the backfill.
-- ============================================================================


-- ── 1. Admin helper ──────────────────────────────────────────────────────────
--  Mirrors cs_has_all_access() but checks only the admin flag.
--  users.admin is TEXT, not boolean — normalise, never cast.

create or replace function public.cs_is_admin()
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
      and lower(trim(coalesce(u.admin, ''))) = 'true'
  );
$$;

revoke all on function public.cs_is_admin() from public;
grant execute on function public.cs_is_admin() to anon, authenticated;

comment on function public.cs_is_admin() is
  'True when the current JWT belongs to a user with users.admin = ''true''. users.admin is TEXT — compared explicitly, never cast.';

-- Verify: expect false here (SQL editor has no JWT).
select public.cs_is_admin() as should_be_false;


-- ── 2. The bucket ────────────────────────────────────────────────────────────
--  public = true so thumbnails can be served straight from the CDN to
--  anonymous shop visitors. That is the whole point of thumbnails: they are
--  the safe, non-generative representation of a pattern.
--
--  Public READ is intentional. Public WRITE is not — see section 3.

insert into storage.buckets (id, name, public)
values ('pattern-thumbs', 'pattern-thumbs', true)
on conflict (id) do update set public = true;

-- Verify: expect one row, public = true.
select id, name, public from storage.buckets where id = 'pattern-thumbs';


-- ── 3. Object policies ───────────────────────────────────────────────────────
--  Storage access is RLS on storage.objects, scoped by bucket_id.
--
--  READ  → everyone. Thumbnails are public product imagery.
--  WRITE → admins only. The backfill tool is internal; nobody browsing the
--          site should be able to add, overwrite or delete a thumbnail.
--          Overwrite matters most: without this, anyone holding the anon key
--          could replace every pattern image on the storefront.

drop policy if exists "pattern-thumbs public read"   on storage.objects;
drop policy if exists "pattern-thumbs admin insert"  on storage.objects;
drop policy if exists "pattern-thumbs admin update"  on storage.objects;
drop policy if exists "pattern-thumbs admin delete"  on storage.objects;

create policy "pattern-thumbs public read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'pattern-thumbs');

create policy "pattern-thumbs admin insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'pattern-thumbs' and public.cs_is_admin());

-- upsert:true on an existing key needs UPDATE as well as INSERT.
create policy "pattern-thumbs admin update"
  on storage.objects for update
  to authenticated
  using      (bucket_id = 'pattern-thumbs' and public.cs_is_admin())
  with check (bucket_id = 'pattern-thumbs' and public.cs_is_admin());

-- generate-thumbs.html writes and then removes a `_ping.txt` probe on startup.
create policy "pattern-thumbs admin delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'pattern-thumbs' and public.cs_is_admin());


-- ── 4. Verify ────────────────────────────────────────────────────────────────

select policyname, cmd, roles
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'pattern-thumbs%'
order by cmd;

--  Then, from a browser signed in as an admin, on any CoCo surface:
--    await sb.storage.from('pattern-thumbs')
--      .upload('_probe.txt', new Blob(['x']), { upsert: true })
--  Expect success. Repeat signed OUT — expect a row-level security error.


-- ── 5. Rollback ──────────────────────────────────────────────────────────────
/*
drop policy if exists "pattern-thumbs public read"  on storage.objects;
drop policy if exists "pattern-thumbs admin insert" on storage.objects;
drop policy if exists "pattern-thumbs admin update" on storage.objects;
drop policy if exists "pattern-thumbs admin delete" on storage.objects;
delete from storage.buckets where id = 'pattern-thumbs';   -- only if empty
drop function if exists public.cs_is_admin();
*/
