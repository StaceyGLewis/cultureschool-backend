\pset pager off
\set QUIET on
select auth._be('teacher.a@school.edu');
select public.school_create_class('Period 3') as ca \gset
select (:'ca'::jsonb->>'id') as caid, (:'ca'::jsonb->>'code') as cacode \gset
select auth._be('teacher.b@school.edu');
select public.school_create_class('Period 7') as cb \gset
select (:'cb'::jsonb->>'id') as cbid \gset
select auth._be('teacher.a@school.edu');
\set QUIET off

\echo ''
\echo 'TEACHER AUTHORING'
select t_true('the three shipped briefs are listed',
  format('(select count(*) from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where (e->>''is_template'')::boolean)=3', :'caid'));
select t_true('shipped briefs now carry tradition, meta and turn-in',
  format('(select bool_and(e->>''tradition'' is not null and e->>''meta'' is not null
             and e->>''turnin'' is not null)
           from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where (e->>''is_template'')::boolean)', :'caid'));

\set QUIET on
select public.school_save_brief(:'caid'::uuid, null, 'Kuba Cloth: Improvised Geometry',
  'Kuba · Kuba Kingdom, DRC', 'Grades 9-12 · Visual Arts · 2 weeks',
  'Find a Kuba raffia panel and document how the makers break their own grid.',
  'Compose a panel that sets a rule and then breaks it exactly once.',
  'A statement of 200+ words naming the rule and the break.',
  'Notes · print · statement (200+ words)', 'kuba', 200,
  array['VA.912.H.1.1','F.S.1003.42(2)(h)']) as nb \gset
select (:'nb'::jsonb->>'id') as nbid \gset
\set QUIET off
select t_true('a teacher-written brief is created', format('%L <> ''''', :'nbid'));
\set QUIET on
select public.school_save_brief(:'caid'::uuid, :'nbid', 'Kuba Cloth, revised',
  'Kuba · Kuba Kingdom, DRC', 'Grades 9-12 · Visual Arts · 2 weeks',
  'Find a Kuba raffia panel and document how the makers break their own grid.',
  'Compose a panel that sets a rule and then breaks it exactly once.',
  'A statement of 200+ words naming the rule and the break.',
  'Notes · print · statement (200+ words)', 'kuba', 200, array['VA.912.H.1.1']);
\set QUIET off
select t_true('it is not a template',
  format('not ((public.school_save_brief(%L::uuid,%L,''Kuba Cloth: Improvised Geometry'',
     null,null,null,null,null,null,''kuba'',200,''{}''))->>''is_template'')::boolean',
     :'caid', :'nbid'));
select t_true('it appears in the class list',
  format('(select count(*) from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where e->>''title''=''Kuba Cloth: Improvised Geometry'')=1', :'caid'));
select t_true('its 200-word floor is stored',
  format('(select (e->>''words'')::int from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where e->>''id''=%L)=200', :'caid', :'nbid'));
select t_true('editing it changes the title and keeps the prompts',
  format('(public.school_save_brief(%L::uuid,%L,''Kuba Cloth, revised'',
     ''Kuba · Kuba Kingdom, DRC'',''Grades 9-12'',
     ''Find a Kuba raffia panel and document how the makers break their own grid.'',
     ''Compose a panel that sets a rule and then breaks it exactly once.'',
     ''A statement of 200+ words naming the rule and the break.'',
     ''Notes · print · statement'',''kuba'',200,''{}''))->>''title''=''Kuba Cloth, revised''',
     :'caid', :'nbid'));
select t_true('a whole-record update clears a field left blank',
  format('(public.school_save_brief(%L::uuid,%L,''Tmp'',null,null,null,null,null,null,''kuba'',200,''{}''))
          ->>''find'' is null', :'caid', :'nbid'));
\set QUIET on
-- restore, so the assertions below read a fully-written brief
select public.school_save_brief(:'caid'::uuid, :'nbid', 'Kuba Cloth, revised',
  'Kuba · Kuba Kingdom, DRC', 'Grades 9-12 · Visual Arts · 2 weeks',
  'Find a Kuba raffia panel and document how the makers break their own grid.',
  'Compose a panel that sets a rule and then breaks it exactly once.',
  'A statement of 200+ words naming the rule and the break.',
  'Notes · print · statement (200+ words)', 'kuba', 200, array['VA.912.H.1.1']);
\set QUIET off

\echo ''
\echo 'VALIDATION'
select t_refuse('a brief with no title is refused',
  format('select public.school_save_brief(%L::uuid,null,''   '')', :'caid'));
select t_refuse('a word floor of 5 is refused',
  format('select public.school_save_brief(%L::uuid,null,''X'',null,null,null,null,null,null,null,5,''{}'')', :'caid'));
select t_refuse('a word floor of 9000 is refused',
  format('select public.school_save_brief(%L::uuid,null,''X'',null,null,null,null,null,null,null,9000,''{}'')', :'caid'));
select t_refuse('binding to a style the archive cannot credit is refused',
  format('select public.school_save_brief(%L::uuid,null,''X'',null,null,null,null,null,null,''orphan'',150,''{}'')', :'caid'));
select t_refuse('binding to a style that does not exist is refused',
  format('select public.school_save_brief(%L::uuid,null,''X'',null,null,null,null,null,null,''nope'',150,''{}'')', :'caid'));
select t_true ('a real archive style is accepted',
  format('(public.school_save_brief(%L::uuid,null,''Ikat study'',null,null,null,null,null,null,''ikat'',150,''{}''))->>''style''=''ikat''', :'caid'));
select t_refuse('a shipped template cannot be edited',
  format('select public.school_save_brief(%L::uuid,''adinkra'',''Hijacked'')', :'caid'));
select t_refuse('a shipped template cannot be deleted',
  format('select public.school_delete_brief(%L::uuid,''adinkra'')', :'caid'));

\echo ''
\echo 'CROSS-TEACHER ISOLATION'
select auth._be('teacher.b@school.edu');
select t_refuse('teacher B cannot list A''s briefs',
  format('select public.school_class_briefs(%L::uuid)', :'caid'));
select t_refuse('teacher B cannot edit A''s brief',
  format('select public.school_save_brief(%L::uuid,%L,''Stolen'')', :'caid', :'nbid'));
select t_refuse('teacher B cannot delete A''s brief',
  format('select public.school_delete_brief(%L::uuid,%L)', :'caid', :'nbid'));
select t_refuse('teacher B cannot move A''s brief into their own class',
  format('select public.school_save_brief(%L::uuid,%L,''Moved'')', :'cbid', :'nbid'));
select t_true ('teacher B sees only the three templates in their own class',
  format('(select count(*) from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e)=3', :'cbid'));
select auth._be(null);
select t_refuse('signed-out cannot list briefs',
  format('select public.school_class_briefs(%L::uuid)', :'caid'));
select t_refuse('signed-out cannot write a brief',
  format('select public.school_save_brief(%L::uuid,null,''X'')', :'caid'));
select t_refuse('signed-out cannot list archive styles', 'select public.school_pattern_styles()');

\echo ''
\echo 'STUDENT SEES THE TEACHER''S OWN BRIEF'
select auth._be('teacher.a@school.edu');
\set QUIET on
select public.school_set_assigned(:'caid'::uuid, array['adinkra', :'nbid']);
select auth._be(null);
select public.school_join(:'cacode','Maya R.','d1') as j \gset
select (:'j'::jsonb->>'session_token') as sa \gset
\set QUIET off
select t_true('the student is assigned two briefs',
  format('jsonb_array_length((public.school_state(%L::uuid))->''briefs'')=2', :'sa'));
select t_true('one of them is the teacher''s own, in full',
  format('(select count(*) from jsonb_array_elements((public.school_state(%L::uuid))->''briefs'') e
           where e->>''title''=''Kuba Cloth, revised'' and e->>''find'' is not null)=1', :'sa'));
select t_true('the teacher''s 200-word floor reaches the student',
  format('(select (e->>''words'')::int from jsonb_array_elements((public.school_state(%L::uuid))->''briefs'') e
           where e->>''title''=''Kuba Cloth, revised'')=200', :'sa'));
select t_true('briefs arrive in the order the teacher assigned them',
  format('((public.school_state(%L::uuid))->''briefs''->0->>''id'')=''adinkra''', :'sa'));

\echo ''
\echo 'THE SERVER ENFORCES A CUSTOM FLOOR'
\set QUIET on
select public.school_save_work(:'sa'::uuid, :'nbid', repeat('word ',150), 'p.jpg', null);
\set QUIET off
select t_refuse('150 words is refused against a 200-word brief',
  format('select public.school_submit(%L::uuid,%L)', :'sa', :'nbid'));
\set QUIET on
select public.school_save_work(:'sa'::uuid, :'nbid', repeat('word ',210), 'p.jpg', null);
\set QUIET off
select t_true ('210 words is accepted',
  format('(public.school_submit(%L::uuid,%L))->>''status''=''submitted''', :'sa', :'nbid'));

\echo ''
\echo 'DELETE GUARD'
select auth._be('teacher.a@school.edu');
select t_refuse('a brief with student work cannot be deleted',
  format('select public.school_delete_brief(%L::uuid,%L)', :'caid', :'nbid'));
\set QUIET on
select (select e->>'id' from jsonb_array_elements(public.school_class_briefs(:'caid'::uuid)) e
        where e->>'title'='Ikat study') as ikid \gset
select jsonb_array_length(public.school_class_briefs(:'caid'::uuid)) as nbefore \gset
select public.school_delete_brief(:'caid'::uuid, :'ikid');
\set QUIET off
select t_true ('a brief with no work can be deleted',
  format('jsonb_array_length(public.school_class_briefs(%L::uuid)) = %s - 1', :'caid', :'nbefore'));
select t_true ('the deleted brief is gone from the list',
  format('(select count(*) from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where e->>''title''=''Ikat study'')=0', :'caid'));

\echo ''
\echo 'ARCHIVE STYLE PICKER'
select t_true('only styles with a creditable origin are offered',
  '(select count(*) from jsonb_array_elements(public.school_pattern_styles()) e
     where e->>''style''=''orphan'')=0');
select t_true('real styles are offered with a pattern count',
  '(select count(*) from jsonb_array_elements(public.school_pattern_styles()) e
     where (e->>''patterns'')::int >= 4) >= 4');

-- ═══════════════════════════════════════════════════════════════════════
-- Run against a throwaway Postgres, never production. Needs the prelude,
-- the storage stub, and a patterns_public stub (the brief validator
-- checks that a style has creditable patterns before accepting it).
-- Apply in order: prelude, stubs, school-mode, -rpc, -storage, -briefs,
-- then this file. 35 assertions, 0 failures as of this commit.
-- ═══════════════════════════════════════════════════════════════════════
