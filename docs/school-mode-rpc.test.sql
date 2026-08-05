\pset pager off
\set QUIET on
select auth._be('teacher.a@school.edu');
select public.school_create_class('Period 3') as ca \gset
select auth._be('teacher.b@school.edu');
select public.school_create_class('Period 7') as cb \gset
\set caid `echo` 
select (:'ca'::jsonb->>'id') as caid, (:'ca'::jsonb->>'code') as cacode \gset
select (:'cb'::jsonb->>'id') as cbid, (:'cb'::jsonb->>'code') as cbcode \gset
select auth._be('teacher.a@school.edu');
select public.school_set_assigned(:'caid'::uuid, array['adinkra','shibori']);
select auth._be('teacher.b@school.edu');
select public.school_set_assigned(:'cbid'::uuid, array['geesbend']);
select auth._be(null);
select public.school_join(:'cacode','Maya R.','d1')  as ja \gset
select public.school_join(:'cacode','Devon A.','d2') as jb \gset
select public.school_join(:'cbcode','Priya S.','d3') as jc \gset
select (:'ja'::jsonb->>'session_token') as sa \gset
select (:'jb'::jsonb->>'session_token') as sb \gset
select (:'jc'::jsonb->>'session_token') as sc \gset
select public.school_save_work(:'sa'::uuid,'adinkra',repeat('word ',160),'a.jpg',array['Akan people, Ghana']);
-- adinkra now demands 2 documented sources before it can be turned in
select public.school_add_note(:'sa'::uuid,'adinkra','A stamped cloth at the High Museum','museum','High Museum');
select public.school_add_note(:'sa'::uuid,'adinkra','My grandmother named three symbols','person','My grandmother');
select public.school_submit(:'sa'::uuid,'adinkra');
\set QUIET off

\echo ''
\echo 'STUDENT ISOLATION — can a student reach anything that is not theirs?'
select t_true  ('a student sees their own submitted work',
  format('jsonb_array_length((public.school_state(%L::uuid))->''works'')=1', :'sa'));
select t_true  ('a classmate sees none of it',
  format('jsonb_array_length((public.school_state(%L::uuid))->''works'')=0', :'sb'));
select t_true  ('a student in another class sees only their class',
  format('(public.school_state(%L::uuid))->>''class_name''=''Period 7''', :'sc'));
select t_true  ('a student never receives another member id',
  format('(public.school_state(%L::uuid))::text not like ''%%member_id%%''', :'sa'));
select t_refuse('a guessed session token is refused',
  'select public.school_state(''00000000-0000-0000-0000-000000000000''::uuid)');
select t_refuse('a null session token is refused', 'select public.school_state(null)');
select t_true  ('no student function even accepts a class id',
  '(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname=''public'' and p.proname like ''school\_%''
     and p.proname in (''school_state'',''school_save_work'',''school_submit'',''school_log'')
     and pg_get_function_arguments(p.oid) not like ''%class%'')=4');

\echo ''
\echo 'TEACHER ISOLATION'
select auth._be('teacher.b@school.edu');
select t_refuse('teacher B cannot read A''s roster',  format('select public.school_roster(%L::uuid)', :'caid'));
select t_refuse('teacher B cannot read A''s gallery', format('select public.school_gallery(%L::uuid)', :'caid'));
select t_refuse('teacher B cannot assign into A''s class',
  format('select public.school_set_assigned(%L::uuid,array[''adinkra''])', :'caid'));
select t_refuse('teacher B cannot reopen A''s class',
  format('select public.school_set_join_open(%L::uuid,true)', :'caid'));
select t_true  ('teacher B sees only their own class', 'jsonb_array_length(public.school_teacher_classes())=1');
select auth._be('teacher.a@school.edu');
select t_true  ('teacher A reads their own gallery',
  format('jsonb_array_length(public.school_gallery(%L::uuid))=1', :'caid'));
select t_true  ('teacher A sees the receipts behind a work',
  format('jsonb_array_length((public.school_work_detail(%L::uuid,
     ((public.school_gallery(%L::uuid))->0->>''work_id'')::uuid))->''receipts'')>0', :'caid', :'caid'));
select auth._be(null);
select t_refuse('signed-out cannot list classes',  'select public.school_teacher_classes()');
select t_refuse('signed-out cannot create a class','select public.school_create_class(''X'')');
select t_refuse('signed-out cannot read a gallery', format('select public.school_gallery(%L::uuid)', :'caid'));

\echo ''
\echo 'TURN-IN FLOOR — enforced server-side, where the client cannot reach'
select t_refuse('below the word floor is refused',
  format('select public.school_save_work(%1$L::uuid,''shibori'',''only three words'',''p.jpg'',null),
          public.school_submit(%1$L::uuid,''shibori'')', :'sb'));
select t_refuse('no print attached is refused',
  format('select public.school_save_work(%1$L::uuid,''shibori'',%2$L,null,null),
          public.school_submit(%1$L::uuid,''shibori'')', :'sb', repeat('word ',200)));
select t_refuse('geesbend rejects 200 words (needs 250)',
  format('select public.school_save_work(%1$L::uuid,''geesbend'',%2$L,''p.jpg'',null),
          public.school_submit(%1$L::uuid,''geesbend'')', :'sc', repeat('word ',200)));
\set QUIET on
select public.school_save_work(:'sc'::uuid,'geesbend',repeat('word ',260),'p.jpg',null);
\set QUIET off
select t_refuse('geesbend with 260 words but no source notes is refused',
  format('select public.school_submit(%L::uuid,''geesbend'')', :'sc'));
\set QUIET on
select public.school_add_note(:'sc'::uuid,'geesbend','Loretta Pettway, born 1942','book','Gee''''s Bend: The Women and Their Quilts');
select public.school_add_note(:'sc'::uuid,'geesbend','Housetop variation, 1970s','museum','Souls Grown Deep');
select public.school_add_note(:'sc'::uuid,'geesbend','She described working "my way"','web',null,'https://example.org');
\set QUIET off
select t_true  ('geesbend accepts 260 words once 3 sources are documented',
  format('(public.school_submit(%L::uuid,''geesbend''))->>''status''=''submitted''', :'sc'));
select t_refuse('an unknown brief is refused',
  format('select public.school_save_work(%L::uuid,''not-a-brief'',''x'',''p.jpg'',null)', :'sa'));

\echo ''
\echo 'JOIN GUARDS'
select t_refuse('an email as display name is refused', format('select public.school_join(%L,''kid@school.edu'',''d9'')', :'cacode'));
select t_refuse('a blank display name is refused',     format('select public.school_join(%L,''   '',''d9'')', :'cacode'));
select t_refuse('a 40-character name is refused',      format('select public.school_join(%L,%L,''d9'')', :'cacode', repeat('n',40)));
select t_refuse('a wrong code is refused',             'select public.school_join(''ZZZZZZ'',''Kid'',''d9'')');
select t_true  ('rejoining reclaims the same membership, not a second one',
  format('(select count(*) from public.class_members where class_id=%L::uuid)=2', :'caid'));
\set QUIET on
select (public.school_join(:'cacode','Maya R.','d1')->>'session_token') as sa2 \gset
\set QUIET off
select t_true  ('rejoining mints a new token',  format('%L::uuid <> %L::uuid', :'sa2', :'sa'));
select t_true  ('rejoining preserves the work', format('jsonb_array_length((public.school_state(%L::uuid))->''works'')=1', :'sa2'));
select t_refuse('the old token is dead after rejoin', format('select public.school_state(%L::uuid)', :'sa'));
select auth._be('teacher.a@school.edu');
select public.school_set_join_open(:'caid'::uuid,false);
select auth._be(null);
select t_refuse('a closed class refuses new joins', format('select public.school_join(%L,''Latecomer'',''d9'')', :'cacode'));

\echo ''
\echo 'GRANTS — is anything reachable that should not be?'
select t_true('anon has no privilege on any school table',
  '(select count(*) from information_schema.table_privileges
     where grantee=''anon'' and table_name in
     (''school_orgs'',''classes'',''class_members'',''briefs'',''class_works'',''class_events''))=0');
select t_true('authenticated has no privilege on any school table',
  '(select count(*) from information_schema.table_privileges
     where grantee=''authenticated'' and table_name in
     (''school_orgs'',''classes'',''class_members'',''briefs'',''class_works'',''class_events''))=0');
select t_true('RLS is on for all six tables',
  '(select count(*) from pg_tables where schemaname=''public'' and rowsecurity
     and tablename in (''school_orgs'',''classes'',''class_members'',''briefs'',''class_works'',''class_events''))=6');
select t_true('no permissive policy exists anywhere',
  '(select count(*) from pg_policies where schemaname=''public''
     and tablename in (''school_orgs'',''classes'',''class_members'',''briefs'',''class_works'',''class_events''))=0');
select t_true('anon cannot execute any teacher function',
  '(select count(*) from information_schema.routine_privileges
     where grantee=''anon'' and routine_name in
     (''school_create_class'',''school_teacher_classes'',''school_roster'',''school_gallery'',
      ''school_work_detail'',''school_set_assigned'',''school_reset_member''))=0');
select t_true('anon CAN execute the five student functions',
  '(select count(distinct routine_name) from information_schema.routine_privileges
     where grantee=''anon'' and routine_name in
     (''school_join'',''school_state'',''school_save_work'',''school_submit'',''school_log''))=5');
select t_true('no internal helper is callable by anon or authenticated',
  '(select count(*) from information_schema.routine_privileges
     where grantee in (''anon'',''authenticated'') and routine_name like ''\_school\_%'')=0');
select t_true('every security-definer function pins search_path',
  '(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname=''public'' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig,''{}'')) c
                     where c like ''search_path=%''))=0');

\echo ''
\echo 'TOKEN ROTATION'
select auth._be('teacher.a@school.edu');
select public.school_reset_member(:'caid'::uuid,
  ((select id from public.class_members where display_name='Devon A.'))::uuid);
select auth._be(null);
select t_refuse('a reset token stops working', format('select public.school_state(%L::uuid)', :'sb'));
\set QUIET on
select (public.school_join(:'cacode','Devon A.','d2')->>'session_token') as sb2 \gset
\set QUIET off
select t_true  ('a reset student can rejoin even though the class is closed',
  format('(public.school_state(%L::uuid))->>''class_name''=''Period 3''', :'sb2'));
select t_refuse('but a stranger still cannot join a closed class',
  format('select public.school_join(%L,''Stranger Z.'',''d99'')', :'cacode'));
