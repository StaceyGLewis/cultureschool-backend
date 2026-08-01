-- ============================================================================
--  19-pattern-thumbs-no-listing.sql
--
--  Stops anonymous visitors enumerating the whole pattern-thumbs bucket.
--
--  MEASURED 2026-07-31, with the anon key and no auth:
--
--    POST /storage/v1/object/list/pattern-thumbs  →  1,500+ filenames returned
--
--  Every object is named <pattern_id>.png, so a listing hands over the full
--  index of the archive, and each file is then one GET away.
--
--  WHY THIS HAPPENED: atlas/18 created
--
--    create policy "pattern-thumbs public read"
--      on storage.objects for select to anon, authenticated
--      using (bucket_id = 'pattern-thumbs');
--
--  That policy governs the storage API — including list(). It is NOT what
--  makes the images load on your public pages. A bucket with public = true
--  serves objects at
--
--    /storage/v1/object/public/pattern-thumbs/<file>
--
--  which bypasses RLS entirely. So the SELECT policy buys nothing for display
--  and grants enumeration for free.
--
--  ⚠️  VERIFY AFTER RUNNING: reload dist/index.html and dist/planner.html
--      logged out and confirm thumbnails still render. They should — they use
--      the /object/public/ path. If they break, re-create the policy from the
--      rollback below and tell me.
-- ============================================================================


-- ── 1. Drop the listing grant ────────────────────────────────────────────────
drop policy if exists "pattern-thumbs public read" on storage.objects;


-- ── 2. Verify ────────────────────────────────────────────────────────────────
--  Expect only the three admin write policies to remain.
select policyname, cmd, roles
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'pattern-thumbs%'
order by cmd;

--  Then, from a terminal:
--
--    # should now be BLOCKED / empty
--    curl -s -X POST \
--      'https://qwulthvbwujfehgdegtn.supabase.co/storage/v1/object/list/pattern-thumbs' \
--      -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
--      -H 'Content-Type: application/json' -d '{"prefix":"","limit":100}'
--
--    # should STILL WORK — public path bypasses RLS
--    curl -sI 'https://qwulthvbwujfehgdegtn.supabase.co/storage/v1/object/public/pattern-thumbs/<some-id>.png'


-- ── 3. Rollback ──────────────────────────────────────────────────────────────
/*
create policy "pattern-thumbs public read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'pattern-thumbs');
*/


-- ============================================================================
--  NOTE — this does not make the thumbnails secret.
--
--  patterns_public still exposes thumb_url for all 7,088 rows, because
--  index.html and planner.html need it to render. Anyone can read those URLs
--  and fetch the images one by one. That is intentional: thumbnails are the
--  public, non-generative representation of a pattern.
--
--  What this section closes is BULK enumeration — you can no longer ask the
--  API for the entire index in a single call.
--
--  What makes the images safe to expose is the WATERMARK, which was missing.
--  public/generate-thumbs.html renderThumb() now calls stampCanvas(). The
--  7,088 thumbnails already uploaded are CLEAN and must be regenerated:
--
--    1. deploy the updated public/generate-thumbs.html
--    2. sign in as admin
--    3. clear thumb_url so the tool picks the rows up again:
--         update public.patterns set thumb_url = null;
--    4. re-run the backfill (upload uses upsert:true, so files are replaced)
-- ============================================================================
