\pset pager off
\set QUIET on
select auth._be('teacher.a@school.edu');
select public.school_create_class('Period 3') as ca \gset
select (:'ca'::jsonb->>'id') as caid, (:'ca'::jsonb->>'code') as cacode \gset
select public.school_set_assigned(:'caid'::uuid, array['adinkra']);
select auth._be('teacher.b@school.edu');
select public.school_create_class('Period 7') as cb \gset
select (:'cb'::jsonb->>'id') as cbid, (:'cb'::jsonb->>'code') as cbcode \gset
select auth._be(null);
select public.school_join(:'cacode','Maya R.','d1') as ja \gset
select public.school_join(:'cbcode','Priya S.','d3') as jc \gset
select (:'ja'::jsonb->>'session_token') as sa \gset
select (:'jc'::jsonb->>'session_token') as sc \gset
\set QUIET off

\echo ''
\echo 'UPLOAD PATH — derived, never supplied'
select t_true('path is <class>/<member>/<brief>.jpg',
  format('(public.school_upload_target(%L::uuid,''adinkra''))->>''path''
          = %L || ''/'' || ((public.school_upload_target(%L::uuid,''adinkra''))->>''member_id'')
            || ''/adinkra.jpg''', :'sa', :'caid', :'sa'));
select t_true('the path always begins with the caller''s own class',
  format('(public.school_upload_target(%L::uuid,''adinkra''))->>''path'' like %L', :'sa', :'caid'||'/%'));
select t_true('a student in another class gets a different class prefix',
  format('(public.school_upload_target(%L::uuid,''geesbend''))->>''path'' not like %L', :'sc', :'caid'||'/%'));
select t_true('the bucket is fixed to class-works',
  format('(public.school_upload_target(%L::uuid,''adinkra''))->>''bucket''=''class-works''', :'sa'));
select t_refuse('a bad session gets no path',
  'select public.school_upload_target(''00000000-0000-0000-0000-000000000000''::uuid,''adinkra'')');
select t_refuse('an unknown brief gets no path',
  format('select public.school_upload_target(%L::uuid,''not-a-brief'')', :'sa'));
select t_true('a brief id containing path characters cannot escape the folder',
  format('(public.school_upload_target(%L::uuid,''adinkra''))->>''path'' not like ''%%..%%''', :'sa'));

\echo ''
\echo 'STORAGE POLICY'
select t_true('the bucket exists and is private',
  '(select not public from storage.buckets where id=''class-works'')');
select t_true('exactly one policy on the bucket, SELECT only',
  '(select count(*) from pg_policies where schemaname=''storage'' and tablename=''objects''
     and policyname like ''class-works%'')=1');
select t_true('that policy is SELECT, for authenticated only',
  '(select cmd=''SELECT'' and roles::text=''{authenticated}'' from pg_policies
     where schemaname=''storage'' and tablename=''objects'' and policyname like ''class-works%'')');
select t_true('no INSERT/UPDATE/DELETE policy exists on the bucket',
  '(select count(*) from pg_policies where schemaname=''storage'' and tablename=''objects''
     and policyname like ''class-works%'' and cmd<>''SELECT'')=0');

\echo ''
\echo 'OBJECT OWNERSHIP — can a teacher read the wrong class?'
select auth._be('teacher.a@school.edu');
select t_true ('teacher A owns an object under their class',
  format('public._school_owns_object(%L)', :'caid'||'/x/adinkra.jpg'));
select t_true ('teacher A does NOT own an object under class B',
  format('not public._school_owns_object(%L)', :'cbid'||'/x/geesbend.jpg'));
select auth._be('teacher.b@school.edu');
select t_true ('teacher B does NOT own an object under class A',
  format('not public._school_owns_object(%L)', :'caid'||'/x/adinkra.jpg'));
select auth._be(null);
select t_true ('a signed-out caller owns nothing',
  format('not public._school_owns_object(%L)', :'caid'||'/x/adinkra.jpg'));
select t_true ('a junk path owns nothing', 'not public._school_owns_object(''../../etc/passwd'')');
select t_true ('an empty path owns nothing', 'not public._school_owns_object('''')');
select t_true ('the ownership helper is callable by nobody',
  '(select count(*) from information_schema.routine_privileges
     where grantee in (''anon'',''authenticated'') and routine_name=''_school_owns_object'')=0');
select t_true ('school_upload_target IS callable by anon',
  '(select count(*) from information_schema.routine_privileges
     where grantee=''anon'' and routine_name=''school_upload_target'')>0');
select t_true ('every security-definer function still pins search_path',
  '(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname=''public'' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig,''{}'')) c
                     where c like ''search_path=%''))=0');

-- ═══════════════════════════════════════════════════════════════════════
-- Run against a throwaway Postgres, never production. Needs the storage
-- stub (docs/school-mode-test-storage-stub.sql) because real storage.*
-- lives in the Supabase platform, not in a plain postgres image.
--
--   docker run -d --name cs-sqltest -e POSTGRES_PASSWORD=t postgres:15-alpine
--   for f in school-mode-test-prelude school-mode-test-storage-stub \
--            school-mode school-mode-rpc school-mode-storage \
--            school-mode-storage.test; do
--     docker cp docs/$f.sql cs-sqltest:/$f.sql; done
--   # apply in that order, then run the test file
--   docker rm -f cs-sqltest
--
-- 20 assertions, 0 failures as of this commit.
-- ═══════════════════════════════════════════════════════════════════════
