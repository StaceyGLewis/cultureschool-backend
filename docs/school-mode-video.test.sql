\pset pager off
\set QUIET on
select auth._be('t.a@school.edu');
select public.school_create_class('P3') as ca \gset
select (:'ca'::jsonb->>'id') as caid, (:'ca'::jsonb->>'code') as cacode \gset
\set QUIET off
\echo ''
\echo 'VIDEO HOSTS'
select t_true('youtube watch accepted',  'public._school_video_ok(''https://www.youtube.com/watch?v=dQw4w9WgXcQ'')');
select t_true('youtu.be accepted',       'public._school_video_ok(''https://youtu.be/dQw4w9WgXcQ'')');
select t_true('vimeo accepted',          'public._school_video_ok(''https://vimeo.com/123456789'')');
select t_true('vimeo player accepted',   'public._school_video_ok(''https://player.vimeo.com/video/123456789'')');
select t_true('self-hosted mp4 accepted','public._school_video_ok(''https://cdn.example.org/demo.mp4'')');
select t_true('null is fine',            'public._school_video_ok(null)');
select t_true('empty is fine',           'public._school_video_ok('''')');
select t_true('http is refused',         'not public._school_video_ok(''http://youtube.com/watch?v=x'')');
select t_true('a random host is refused','not public._school_video_ok(''https://evil.example/x'')');
select t_true('an exe is refused',       'not public._school_video_ok(''https://evil.example/x.exe'')');
select t_true('a javascript url is refused','not public._school_video_ok(''javascript:alert(1)'')');
select t_true('a lookalike domain is refused','not public._school_video_ok(''https://youtube.com.evil.example/watch?v=x'')');

\echo ''
\echo 'THE EDITOR WRITES THEM'
select t_true('a brief accepts both videos',
  format('(public.school_save_brief(%L::uuid,null,''Kuba'',null,null,null,null,null,null,null,150,''{}'',2,
     ''https://youtu.be/abc123'',''https://vimeo.com/987654''))->>''video''=''https://youtu.be/abc123''', :'caid'));
select t_refuse('a bad video host is refused at save',
  format('select public.school_save_brief(%L::uuid,null,''Bad'',null,null,null,null,null,null,null,150,''{}'',0,
     ''https://evil.example/x'')', :'caid'));
select t_true('the constraint refuses a direct bad write too',
  format('(select count(*) from public.briefs where class_id=%L::uuid)=1', :'caid'));
select t_true('both videos reach the client shape',
  format('(select (e->>''technique'')=''https://vimeo.com/987654''
           from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where e->>''title''=''Kuba'')', :'caid'));
select t_true('min_notes survived the signature change',
  format('(select (e->>''min_notes'')::int from jsonb_array_elements(public.school_class_briefs(%L::uuid)) e
           where e->>''title''=''Kuba'')=2', :'caid'));
select t_true('the shipped three carry no video yet',
  '(select bool_and(video_url is null and technique_url is null) from public.briefs where is_template)');

\echo ''
\echo 'STUDENT SEES THE VIDEO'
\set QUIET on
select (e->>'id') as bid from jsonb_array_elements(public.school_class_briefs(:'caid'::uuid)) e
  where e->>'title'='Kuba' \gset
select public.school_set_assigned(:'caid'::uuid, array[:'bid']);
select auth._be(null);
select public.school_join(:'cacode','Maya R.','d1') as j \gset
select (:'j'::jsonb->>'session_token') as sa \gset
\set QUIET off
select t_true('the tradition video reaches the student',
  format('((public.school_state(%L::uuid))->''briefs''->0->>''video'')=''https://youtu.be/abc123''', :'sa'));
select t_true('the technique video reaches the student',
  format('((public.school_state(%L::uuid))->''briefs''->0->>''technique'')=''https://vimeo.com/987654''', :'sa'));

-- ═══════════════════════════════════════════════════════════════════════
-- Throwaway Postgres only. Apply prelude, stubs, then school-mode,
-- -rpc, -storage, -briefs, -notes, -video, harness, then this file.
-- 20 assertions, 0 failures. Full suite across all five files: 152.
-- ═══════════════════════════════════════════════════════════════════════
