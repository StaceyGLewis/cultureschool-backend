-- ============================================================================
--  20-pattern-thumbs-admin-read.sql
--
--  Fixes: "new row violates row-level security policy" when running the
--  thumbnail backfill after atlas/19.
--
--  WHAT WENT WRONG
--
--  atlas/19 dropped "pattern-thumbs public read" to stop anonymous visitors
--  enumerating the bucket. That policy was the ONLY SELECT policy on
--  storage.objects for this bucket.
--
--  Supabase storage needs SELECT to resolve an upsert — it checks whether the
--  object already exists before writing. With no SELECT policy, even an admin
--  fails on upload, which is what generate-thumbs.html reports as an RLS
--  violation on its `_ping.txt` probe.
--
--  atlas/19's reasoning was right about DISPLAY (public buckets serve
--  /object/public/ without RLS) and wrong about WRITES.
--
--  THE FIX: restore SELECT, but scoped to admins instead of everyone.
--    • anonymous visitors  → still cannot list the bucket
--    • public pages        → still load images via /object/public/
--    • the backfill tool   → can upsert again
-- ============================================================================


-- ── 1. Admin-only read ───────────────────────────────────────────────────────
drop policy if exists "pattern-thumbs admin read" on storage.objects;

create policy "pattern-thumbs admin read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'pattern-thumbs' and public.cs_is_admin());


-- ── 2. Verify — expect four policies, all authenticated ──────────────────────
select policyname, cmd, roles
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'pattern-thumbs%'
order by cmd;

--  Expected:
--    pattern-thumbs admin delete   DELETE   {authenticated}
--    pattern-thumbs admin insert   INSERT   {authenticated}
--    pattern-thumbs admin read     SELECT   {authenticated}
--    pattern-thumbs admin update   UPDATE   {authenticated}
--
--  Note: NO policy grants anon anything. That is correct — anon reaches
--  images only through the public URL path, which bypasses RLS entirely.


-- ── 3. Then clear thumb_url so the backfill picks the rows up again ──────────
--  The FILES do not need deleting — upload uses upsert:true and the path is
--  always <pattern_id>.png, so each is replaced in place. But the tool selects
--  `.is('thumb_url', null)`, so a populated column means it finds nothing.
--
--  Run this only when you are ready to re-run the backfill:
/*
update public.patterns set thumb_url = null;
select count(*) as rows_to_regenerate from public.patterns where thumb_url is null;
*/


-- ── 4. Verify after the backfill ─────────────────────────────────────────────
--  a) signed in as admin, in the browser console — should succeed:
--       await sb.storage.from('pattern-thumbs').list('', { limit: 5 })
--
--  b) signed OUT, from a terminal — should be blocked or empty:
--       curl -s -X POST \
--         'https://qwulthvbwujfehgdegtn.supabase.co/storage/v1/object/list/pattern-thumbs' \
--         -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
--         -H 'Content-Type: application/json' -d '{"prefix":"","limit":100}'
--
--  c) signed OUT — should still return the image:
--       curl -sI '…/storage/v1/object/public/pattern-thumbs/<id>.png'
--
--  d) open one regenerated thumbnail and confirm the "cultureschool.org"
--     watermark is present in the bottom-right corner.


-- ── 5. Rollback ──────────────────────────────────────────────────────────────
/*
drop policy if exists "pattern-thumbs admin read" on storage.objects;
*/
