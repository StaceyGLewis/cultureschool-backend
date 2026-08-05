\pset pager off
\set QUIET on
select auth._be('t.a@school.edu');
select public.school_create_class('P3') as ca \gset
select (:'ca'::jsonb->>'id') as caid, (:'ca'::jsonb->>'code') as cacode \gset
select public.school_set_assigned(:'caid'::uuid, array['adinkra']);
select auth._be(null);
select public.school_join(:'cacode','Maya R.','d1') as j1 \gset
select public.school_join(:'cacode','Devon A.','d2') as j2 \gset
select (:'j1'::jsonb->>'session_token') as sa \gset
select (:'j2'::jsonb->>'session_token') as sb \gset
select public.school_handoff_create(:'sa'::uuid,'adinkra') as h \gset
select (:'h'::jsonb->>'token') as tok \gset
\set QUIET off

\echo ''
\echo 'MINTING'
select t_true('a handoff is minted',        format('%L <> ''''', :'tok'));
select t_true('it expires within 4 hours',
  format('(select expires_at <= now() + interval ''4 hours'' + interval ''1 minute''
           from public.class_handoffs where id=%L::uuid)', :'tok'));
select t_refuse('a bad session cannot mint one',
  'select public.school_handoff_create(''00000000-0000-0000-0000-000000000000''::uuid,''adinkra'')');
select t_refuse('an unknown brief cannot mint one',
  format('select public.school_handoff_create(%L::uuid,''nope'')', :'sa'));
select t_true('opening the studio leaves a receipt',
  '(select count(*) from public.class_events where kind=''open_studio'' and detail=''handoff'')>=1');

\echo ''
\echo 'THE TOKEN IS SCOPED AND SINGLE-USE'
select t_true('the path is under the minting student''s own class and member',
  format('(public.school_handoff_target(%L::uuid))->>''path'' like %L', :'tok', :'caid'||'/%/adinkra.jpg'));
select t_true('it names the brief it was minted for',
  format('(public.school_handoff_target(%L::uuid))->>''brief_id''=''adinkra''', :'tok'));
select t_true('completing it attaches the image',
  format('((public.school_handoff_complete(%L::uuid,''p/x.jpg''))->>''ok'')::boolean', :'tok'));
select t_true('the work now carries that path',
  format('(select image_path from public.class_works where class_id=%L::uuid)=''p/x.jpg''', :'caid'));
select t_refuse('the same token cannot be spent twice',
  format('select public.school_handoff_complete(%L::uuid,''p/y.jpg'')', :'tok'));
select t_refuse('a spent token yields no path either',
  format('select public.school_handoff_target(%L::uuid)', :'tok'));
select t_refuse('a made-up token is refused',
  'select public.school_handoff_target(''00000000-0000-0000-0000-000000000000''::uuid)');
select t_true('sending from the studio leaves an attach receipt',
  '(select count(*) from public.class_events where kind=''attach''
     and detail=''sent from Print Studio'')=1');

\echo ''
\echo 'ONE STUDENT CANNOT WRITE TO ANOTHER'
\set QUIET on
select public.school_handoff_create(:'sb'::uuid,'adinkra') as h2 \gset
select (:'h2'::jsonb->>'token') as tok2 \gset
select public.school_handoff_complete(:'tok2'::uuid,'p/devon.jpg');
\set QUIET off
select t_true('Devon''s handoff wrote to Devon''s own work, not Maya''s',
  '(select count(*) from public.class_works)=2');
select t_true('Maya''s image is untouched',
  format('(select count(*) from public.class_works w join public.class_members m on m.id=w.member_id
           where m.display_name=''Maya R.'' and w.image_path=''p/x.jpg'')=1', :'caid'));

\echo ''
\echo 'EXPIRY AND CHURN'
\set QUIET on
select public.school_handoff_create(:'sa'::uuid,'adinkra') as h3 \gset
select (:'h3'::jsonb->>'token') as tok3 \gset
update public.class_handoffs set expires_at = now() - interval '1 minute' where id = :'tok3'::uuid;
\set QUIET off
select t_refuse('an expired token is refused',
  format('select public.school_handoff_target(%L::uuid)', :'tok3'));
\set QUIET on
select public.school_handoff_create(:'sa'::uuid,'adinkra') as h4 \gset
select (:'h4'::jsonb->>'token') as tok4 \gset
select public.school_handoff_create(:'sa'::uuid,'adinkra') as h5 \gset
select (:'h5'::jsonb->>'token') as tok5 \gset
\set QUIET off
select t_refuse('minting a new one retires the previous',
  format('select public.school_handoff_target(%L::uuid)', :'tok4'));
select t_true ('the newest one still works',
  format('(public.school_handoff_target(%L::uuid))->>''brief_id''=''adinkra''', :'tok5'));

\echo ''
\echo 'LOCKDOWN'
select t_true('RLS is on for class_handoffs',
  '(select rowsecurity from pg_tables where schemaname=''public'' and tablename=''class_handoffs'')');
select t_true('no policy grants direct access',
  '(select count(*) from pg_policies where tablename=''class_handoffs'')=0');
select t_true('anon holds no table privilege on it',
  '(select count(*) from information_schema.table_privileges
     where table_name=''class_handoffs'' and grantee in (''anon'',''authenticated''))=0');
select t_true('every security-definer function still pins search_path',
  '(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname=''public'' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig,''{}'')) c
                     where c like ''search_path=%''))=0');

-- ═══════════════════════════════════════════════════════════════════════
-- Throwaway Postgres only. Apply prelude, stubs, then school-mode, -rpc,
-- -storage, -briefs, -notes, -video, -handoff, harness, then this file.
-- 22 assertions. Full suite across all six files: 174.
-- ═══════════════════════════════════════════════════════════════════════
