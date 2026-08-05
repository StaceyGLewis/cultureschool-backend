-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — video on a brief
--
-- NOT RUN. Apply after school-mode-notes.sql.
--
-- A teacher-authored brief becomes a course when it can carry a video.
-- That is the upsell seam: anyone can write prompts, but a teacher who
-- films themselves demonstrating a technique has made something worth
-- selling, and a school that buys it is buying the person as much as
-- the platform.
--
-- Two slots, because Tell and Show are different jobs:
--   video_url        the tradition — what it is, who makes it, why
--   technique_url    the skill — someone actually doing it, hands on
-- ═══════════════════════════════════════════════════════════════════════

begin;

alter table public.briefs add column if not exists video_url     text;
alter table public.briefs add column if not exists technique_url text;

-- Only hosts we can embed without shipping third-party tracking into a
-- classroom. A raw file URL is allowed so a teacher can self-host.
create or replace function public._school_video_ok(u text)
returns boolean
language sql immutable set search_path = public, pg_temp as $$
  select u is null or btrim(u) = '' or
         u ~* '^https://(www\.)?(youtube\.com/watch\?v=|youtu\.be/|player\.vimeo\.com/video/|vimeo\.com/)[A-Za-z0-9_\-/?=&.]+$' or
         u ~* '^https://[A-Za-z0-9._\-/]+\.(mp4|webm|mov)(\?[A-Za-z0-9._\-=&%]*)?$'
$$;
revoke all on function public._school_video_ok(text) from public, anon, authenticated;

alter table public.briefs drop constraint if exists briefs_video_host_ok;
alter table public.briefs add  constraint briefs_video_host_ok
  check (public._school_video_ok(video_url) and public._school_video_ok(technique_url));

-- ── Carry both through to the client ───────────────────────────────────
create or replace function public._school_brief_json(b public.briefs)
returns jsonb
language sql immutable set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id',        coalesce(b.template_id, b.id::text),
    'is_template', b.is_template,
    'title',     b.title,
    'tradition', b.tradition,
    'meta',      b.meta,
    'find',      b.prompt_find,
    'interpret', b.prompt_interpret,
    'own',       b.prompt_own,
    'turnin',    b.turn_in,
    'style',     b.pattern_style,
    'words',     b.min_words,
    'min_notes', b.min_notes,
    'video',     b.video_url,
    'technique', b.technique_url,
    'standards', array_to_string(b.standards_tags, ' · '))
$$;
revoke all on function public._school_brief_json(public.briefs) from public, anon, authenticated;

-- ── The editor writes them ─────────────────────────────────────────────
drop function if exists public.school_save_brief(
  uuid,text,text,text,text,text,text,text,text,text,integer,text[],integer);

create or replace function public.school_save_brief(
  p_class     uuid,
  p_id        text default null,
  p_title     text default null,
  p_tradition text default null,
  p_meta      text default null,
  p_find      text default null,
  p_interpret text default null,
  p_own       text default null,
  p_turnin    text default null,
  p_style     text default null,
  p_words     integer default 150,
  p_standards text[] default '{}',
  p_min_notes integer default 0,
  p_video     text default null,
  p_technique text default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes; b public.briefs; bid uuid;
begin
  c := public._school_teacher_class(p_class);

  if btrim(coalesce(p_title,'')) = '' then
    raise exception 'a brief needs a title' using errcode='22023';
  end if;
  if length(coalesce(p_title,'')) > 160 then
    raise exception 'title too long' using errcode='22023';
  end if;
  if coalesce(p_words,150) < 25 or coalesce(p_words,150) > 2000 then
    raise exception 'the word count must be between 25 and 2000' using errcode='22023';
  end if;
  if coalesce(p_min_notes,0) < 0 or coalesce(p_min_notes,0) > 20 then
    raise exception 'documented sources must be between 0 and 20' using errcode='22023';
  end if;
  if not public._school_video_ok(p_video) or not public._school_video_ok(p_technique) then
    raise exception 'video must be a YouTube, Vimeo or direct mp4/webm link'
      using errcode='22023';
  end if;
  if p_style is not null and p_style <> '' and not exists (
       select 1 from public.patterns_public
        where style = p_style and heritage_origin is not null limit 1) then
    raise exception 'no patterns in the archive for style %', p_style using errcode='22023';
  end if;

  if p_id is null or btrim(p_id) = '' then
    insert into public.briefs (class_id, is_template, title, tradition, meta,
      prompt_find, prompt_interpret, prompt_own, turn_in, pattern_style,
      min_words, min_notes, video_url, technique_url, standards_tags, created_by)
    values (c.id, false, btrim(p_title), p_tradition, p_meta,
      p_find, p_interpret, p_own, p_turnin, nullif(p_style,''),
      coalesce(p_words,150), coalesce(p_min_notes,0),
      nullif(btrim(coalesce(p_video,'')),''), nullif(btrim(coalesce(p_technique,'')),''),
      coalesce(p_standards,'{}'), c.teacher_email)
    returning * into b;
  else
    begin bid := p_id::uuid;
    exception when invalid_text_representation then
      raise exception 'the shipped briefs cannot be edited — duplicate one instead'
        using errcode='42501';
    end;
    update public.briefs set
      title=btrim(p_title), tradition=p_tradition, meta=p_meta,
      prompt_find=p_find, prompt_interpret=p_interpret, prompt_own=p_own,
      turn_in=p_turnin, pattern_style=nullif(p_style,''),
      min_words=coalesce(p_words,150), min_notes=coalesce(p_min_notes,0),
      video_url=nullif(btrim(coalesce(p_video,'')),''),
      technique_url=nullif(btrim(coalesce(p_technique,'')),''),
      standards_tags=coalesce(p_standards,'{}')
     where id=bid and class_id=c.id and not is_template
    returning * into b;
    if not found then
      raise exception 'brief not found in this class' using errcode='42501';
    end if;
  end if;

  return public._school_brief_json(b) || jsonb_build_object('assigned',
    coalesce(b.template_id, b.id::text) = any(c.assigned));
end $$;

revoke execute on function public.school_save_brief(
  uuid,text,text,text,text,text,text,text,text,text,integer,text[],integer,text,text)
  from public, anon;
grant execute on function public.school_save_brief(
  uuid,text,text,text,text,text,text,text,text,text,integer,text[],integer,text,text)
  to authenticated;

-- ── The teacher's list keeps its assigned flag ─────────────────────────
create or replace function public.school_class_briefs(p_class uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  return coalesce((
    select jsonb_agg(public._school_brief_json(b)
             || jsonb_build_object('assigned',
                  coalesce(b.template_id, b.id::text) = any(c.assigned))
             order by b.is_template desc, b.created_at)
      from public.briefs b
     where b.is_template or b.class_id = c.id), '[]'::jsonb);
end $$;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFY
--   select template_id, video_url, technique_url from public.briefs
--    where is_template;
--   -- all null; the shipped three carry no video yet
--
-- A bad host must be refused:
--   select public._school_video_ok('https://evil.example/x.mp4');  -- false
--   select public._school_video_ok('https://youtu.be/abc123');     -- true
-- ═══════════════════════════════════════════════════════════════════════
