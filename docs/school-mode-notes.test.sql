\pset pager off
\set QUIET on
select auth._be('t.a@school.edu');
select public.school_create_class('Period 3') as ca \gset
select (:'ca'::jsonb->>'id') as caid, (:'ca'::jsonb->>'code') as cacode \gset
select public.school_set_assigned(:'caid'::uuid, array['adinkra']);
select auth._be('t.b@school.edu');
select public.school_create_class('Period 7') as cb \gset
select (:'cb'::jsonb->>'id') as cbid, (:'cb'::jsonb->>'code') as cbcode \gset
select public.school_set_assigned(:'cbid'::uuid, array['adinkra']);
select auth._be(null);
select public.school_join(:'cacode','Maya R.','d1') as j1 \gset
select public.school_join(:'cacode','Devon A.','d2') as j2 \gset
select public.school_join(:'cbcode','Priya S.','d3') as j3 \gset
select (:'j1'::jsonb->>'session_token') as sa \gset
select (:'j2'::jsonb->>'session_token') as sb \gset
select (:'j3'::jsonb->>'session_token') as sc \gset
\set QUIET off

\echo ''
\echo 'RECORDING A FIND'
select t_true('a museum visit is recorded',
  format('(public.school_add_note(%L::uuid,''adinkra'',
     ''A stamped Adinkra cloth, indigo on russet, about 2m long.'',
     ''museum'',''High Museum, Atlanta'',null,
     ''The stamps do not line up. I thought they would.''))->>''kind''=''museum''', :'sa'));
select t_true('a person counts as a source',
  format('(public.school_add_note(%L::uuid,''adinkra'',''My grandmother named three symbols.'',
     ''person'',''My grandmother'',null,''She called Sankofa by a different name.''))
     ->>''source''=''My grandmother''', :'sa'));
select t_true('both notes come back on state',
  format('jsonb_array_length((public.school_state(%L::uuid))->''notes'')=2', :'sa'));
select t_true('the note carries what surprised them',
  format('(select count(*) from jsonb_array_elements((public.school_state(%L::uuid))->''notes'') e
           where e->>''surprised'' is not null)=2', :'sa'));
select t_refuse('an empty find is refused',
  format('select public.school_add_note(%L::uuid,''adinkra'',''   '')', :'sa'));
select t_refuse('a note on an unknown brief is refused',
  format('select public.school_add_note(%L::uuid,''nope'',''x'')', :'sa'));
select t_true('an unrecognised kind falls back to other',
  format('(public.school_add_note(%L::uuid,''adinkra'',''x'',''wormhole''))->>''kind''=''other''', :'sb'));

\echo ''
\echo 'NOTES ARE PRIVATE TO THE STUDENT WHO WROTE THEM'
select t_true('a classmate sees only their own note',
  format('jsonb_array_length((public.school_state(%L::uuid))->''notes'')=1', :'sb'));
select t_true('a student in another class sees none',
  format('jsonb_array_length((public.school_state(%L::uuid))->''notes'')=0', :'sc'));
\set QUIET on
select (e->>'id') as n1 from jsonb_array_elements((public.school_state(:'sa'::uuid))->'notes') e limit 1 \gset
\set QUIET off
select t_refuse('a classmate cannot edit someone else''s note',
  format('select public.school_update_note(%L::uuid,%L::uuid,''hijacked'')', :'sb', :'n1'));
\set QUIET on
select public.school_delete_note(:'sb'::uuid, :'n1'::uuid);   -- a classmate tries
\set QUIET off
select t_true ('a classmate deleting it does NOT delete it',
  format('jsonb_array_length((public.school_state(%L::uuid))->''notes'')=2', :'sa'));
select t_true ('the row is still there in the table',
  format('(select count(*) from public.class_notes where id=%L::uuid)=1', :'n1'));
select t_refuse('a classmate cannot get a photo path for it',
  format('select public.school_note_target(%L::uuid,%L::uuid)', :'sb', :'n1'));
select t_true ('the owner can edit it',
  format('(public.school_update_note(%L::uuid,%L::uuid,''revised finding''))->>''found''=''revised finding''',
          :'sa', :'n1'));

\echo ''
\echo 'PHOTO PATH IS DERIVED'
select t_true('a note photo lands under the caller''s own class and member',
  format('(public.school_note_target(%L::uuid,%L::uuid))->>''path'' like %L',
          :'sa', :'n1', :'caid'||'/%/notes/%'));
select t_true('the note id is the filename, so one note cannot overwrite another',
  format('(public.school_note_target(%L::uuid,%L::uuid))->>''path'' like %L',
          :'sa', :'n1', '%/'||:'n1'||'.jpg'));
select t_true('recording the photo sets image_path',
  format('(public.school_note_photo(%L::uuid,%L::uuid,''p/x.jpg''))->>''image_path''=''p/x.jpg''',
          :'sa', :'n1'));

\echo ''
\echo 'TURN-IN NOW CHECKS THE RESEARCH'
select t_true('adinkra demands 2 notes',
  format('(select (e->>''min_notes'')::int from jsonb_array_elements((public.school_state(%L::uuid))->''briefs'') e
           where e->>''id''=''adinkra'')=2', :'sa'));
select t_true('geesbend demands 3',
  '(select min_notes from public.briefs where is_template and template_id=''geesbend'')=3');
\set QUIET on
select public.school_save_work(:'sb'::uuid,'adinkra',repeat('word ',160),'p.jpg',null);
\set QUIET off
select t_refuse('one note is not enough to turn in',
  format('select public.school_submit(%L::uuid,''adinkra'')', :'sb'));
\set QUIET on
select public.school_add_note(:'sb'::uuid,'adinkra','a second find','book','Kente and Adinkra, Ross');
\set QUIET off
select t_true ('two notes plus a print plus the words is accepted',
  format('(public.school_submit(%L::uuid,''adinkra''))->>''status''=''submitted''', :'sb'));
select t_true ('the receipt of that submission records the note count',
  format('((public.school_submit(%L::uuid,''adinkra''))->>''notes'')::int=2', :'sb'));
\set QUIET on
select public.school_save_work(:'sa'::uuid,'adinkra',repeat('word ',10),'p.jpg',null);
\set QUIET off
select t_refuse('enough notes still does not excuse a short statement',
  format('select public.school_submit(%L::uuid,''adinkra'')', :'sa'));

\echo ''
\echo 'RECEIPTS'
select t_true('a field note leaves a receipt',
  format('(select count(*) from public.class_events where member_id=
           (select member_id from public.class_notes where id=%L::uuid) and kind=''field_note'')>=2', :'n1'));
select t_true('a note photo leaves its own receipt',
  '(select count(*) from public.class_events where kind=''note_photo'')>=1');
select t_true('the widened kind constraint still rejects nonsense',
  '(select not exists(select 1 from public.class_events where kind=''hacking''))');

\echo ''
\echo 'THE TEACHER READS THE RESEARCH BESIDE THE PRINT'
select auth._be('t.a@school.edu');
\set QUIET on
select (e->>'work_id') as wid from jsonb_array_elements(public.school_gallery(:'caid'::uuid)) e limit 1 \gset
\set QUIET off
select t_true('work detail carries the notes',
  format('jsonb_array_length((public.school_work_detail(%L::uuid,%L::uuid))->''notes'')=2', :'caid', :'wid'));
select t_true('the notes are the right student''s',
  format('(select bool_and(e->>''found'' is not null)
           from jsonb_array_elements((public.school_work_detail(%L::uuid,%L::uuid))->''notes'') e)',
          :'caid', :'wid'));
select t_true('receipts and notes arrive together',
  format('jsonb_array_length((public.school_work_detail(%L::uuid,%L::uuid))->''receipts'')>0', :'caid', :'wid'));
select auth._be('t.b@school.edu');
select t_refuse('another teacher cannot read those notes',
  format('select public.school_work_detail(%L::uuid,%L::uuid)', :'caid', :'wid'));

\echo ''
\echo 'TABLE LOCKDOWN'
select t_true('RLS is on for class_notes',
  '(select rowsecurity from pg_tables where schemaname=''public'' and tablename=''class_notes'')');
select t_true('no policy grants anyone direct access',
  '(select count(*) from pg_policies where tablename=''class_notes'')=0');
select t_true('anon and authenticated hold no privilege on class_notes',
  '(select count(*) from information_schema.table_privileges
     where table_name=''class_notes'' and grantee in (''anon'',''authenticated''))=0');
select t_true('every security-definer function still pins search_path',
  '(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname=''public'' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig,''{}'')) c
                     where c like ''search_path=%''))=0');

-- ═══════════════════════════════════════════════════════════════════════
-- Throwaway Postgres only. Apply in order: prelude, storage stub,
-- patterns stub, school-mode, -rpc, -storage, -briefs, -notes, harness,
-- then this file. 34 assertions, 0 failures as of this commit.
--
-- school-mode-rpc.test.sql was updated in the same commit: adinkra and
-- geesbend now demand documented sources, so its submit sequences add
-- notes first. That is the new contract, not a regression.
-- ═══════════════════════════════════════════════════════════════════════
