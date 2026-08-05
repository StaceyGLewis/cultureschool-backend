-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — storage
--
-- NOT RUN. Apply after school-mode.sql and school-mode-rpc.sql.
--
-- ── Why not the existing buckets ───────────────────────────────────────
-- coco-drops and public-uploads are both PUBLIC, on guessable paths
-- (docs/asset-library-audit.md §1.2). A child's artwork on a world-
-- readable URL is the one thing a district will actually check for.
-- class-works is private, and stays private.
--
-- ── Who can do what ────────────────────────────────────────────────────
-- WRITE  service role only, inside the school-upload edge function,
--        which derives the path from school_upload_target() so a student
--        can never aim a file at another class or member.
-- READ   the teacher who owns the class, via the policy below. Students
--        read their own work through a signed URL the same function
--        mints. anon gets nothing, ever.
-- ═══════════════════════════════════════════════════════════════════════

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('class-works', 'class-works', false, 8388608,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = false,                       -- never let this flip to public
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ── Path → class ownership ─────────────────────────────────────────────
-- Objects are stored at <class_id>/<member_id>/<brief>.jpg, so the first
-- path segment is the class. This resolves it and asks whether the
-- calling teacher owns that class.
create or replace function public._school_owns_object(p_name text)
returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare cid uuid; e text;
begin
  e := nullif(lower(coalesce(auth.jwt()->>'email','')), '');
  if e is null then return false; end if;
  begin
    cid := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;                            -- not one of ours
  end;
  return exists (select 1 from public.classes
                  where id = cid and lower(teacher_email) = e);
end $$;

-- authenticated MUST keep EXECUTE: the policy below calls this function,
-- and a policy is evaluated as the calling role. Revoking it here breaks
-- every teacher read with "permission denied for function", which the
-- client sees as a missing image rather than an error. anon never needs
-- it — students read their own files through the school-upload function.
revoke all on function public._school_owns_object(text) from public, anon;
grant execute on function public._school_owns_object(text) to authenticated;

-- ── Policies ───────────────────────────────────────────────────────────
-- Nothing here grants anon anything. Storage RLS is already enabled by
-- Supabase on storage.objects; these are the only policies for this
-- bucket, so the default deny stands for everyone else.
drop policy if exists "class-works teacher read" on storage.objects;
create policy "class-works teacher read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'class-works' and public._school_owns_object(name));

-- Deliberately no INSERT / UPDATE / DELETE policy. Writes happen with
-- the service role inside the edge function, which bypasses RLS. If a
-- policy is ever added here, it must not accept a client-supplied path.

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFY, after applying
--
--   select id, public, file_size_limit from storage.buckets
--    where id = 'class-works';
--   -- public must be false
--
--   select policyname, cmd, roles from pg_policies
--    where tablename = 'objects' and schemaname = 'storage'
--      and policyname like 'class-works%';
--   -- exactly one row: SELECT, {authenticated}
--
-- Then, from a browser holding only the anon key, confirm a 400/404:
--   GET /storage/v1/object/public/class-works/<any>/<any>/adinkra.jpg
-- ═══════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════
-- RETENTION — decide before a district asks, not after
--
-- Nothing purges class_works, class_events, or these objects today.
-- A defensible default is: delete at the end of the school year unless
-- the teacher exports first. Sketch, deliberately not enabled:
--
--   delete from public.class_works
--    where created_at < now() - interval '13 months';
--   -- plus the matching storage objects, and class_events by class_id
--
-- Whatever the policy is, it belongs in the licence agreement in words
-- before it belongs here in SQL.
-- ═══════════════════════════════════════════════════════════════════════
