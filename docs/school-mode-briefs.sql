-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — teacher-authored briefs
--
-- NOT RUN. Apply after school-mode-rpc.sql.
-- Additive: three display columns, a backfill of the shipped templates,
-- and five functions. No existing column or function is dropped.
--
-- ── What this fixes ────────────────────────────────────────────────────
-- Until now a teacher could only assign one of the three briefs that
-- ship with the product. The briefs table always had room for their own
-- (class_id, prompt_find, prompt_interpret…) but nothing could write to
-- it, so the assignment layer was read-only in practice.
--
-- A teacher can now write a brief from scratch, or duplicate a shipped
-- one and edit it — which is how most will start. Their copy belongs to
-- their class; the templates stay untouched and global.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ── Display columns the client needs ───────────────────────────────────
alter table public.briefs add column if not exists tradition text;  -- "Adinkra · Akan people, Ghana"
alter table public.briefs add column if not exists meta      text;  -- grades / subject / duration
alter table public.briefs add column if not exists turn_in   text;  -- the hand-in checklist

-- ── Fill in the shipped three ──────────────────────────────────────────
update public.briefs set
  tradition = 'Adinkra · Akan people, Ghana',
  meta      = 'Grades 6–8 · Visual Arts or Integrated Social Studies · 2–3 weeks',
  turn_in   = 'Documented source notes · your finished print · an artist statement (150+ words)',
  prompt_find = 'Adinkra symbols from Ghana are a visual language: each mark carries a proverb or value, traditionally stamped onto cloth with carved calabash stamps. Choose ONE Adinkra symbol. Document: what it looks like, the proverb or meaning it carries, who historically made and wore Adinkra cloth, and one thing that surprised you.',
  prompt_interpret = 'Design a symbol of your own for a value YOU hold — then build a stamped-cloth-style repeat print around it, using what you learned about how Adinkra organizes symbols in a grid. Your symbol, Adinkra''s visual grammar.',
  prompt_own = 'An artist statement of 150+ words: what your symbol means, what you borrowed from the tradition, what you changed and why.'
where is_template and template_id = 'adinkra';

update public.briefs set
  tradition = 'Shibori · Japan',
  meta      = 'Grades 6–12 · Visual Arts · 2 weeks',
  turn_in   = 'Source notes · finished print · statement (150+ words)',
  prompt_find = 'In Japanese shibori, the pattern is a record of what was done to the cloth before the indigo dye touched it — bound, stitched, clamped, or folded, each technique leaves its own signature. Choose one shibori technique (kanoko, itajime, arashi…). Document how the physical process creates the pattern, and where and when the tradition developed.',
  prompt_interpret = 'Design a print where the pattern records a process — translate the idea of "resist" into your own rule (what stays untouched, and why?). Use an indigo-family palette and explain your rule in the statement.',
  prompt_own = 'An artist statement of 150+ words: your rule, the technique that inspired it, and how your digital "resist" differs from cloth and dye.'
where is_template and template_id = 'shibori';

update public.briefs set
  tradition = 'Gee''s Bend · Boykin, Alabama',
  meta      = 'Grades 9–12 · Visual Arts or American History · 3 weeks',
  turn_in   = 'Source notes · finished print · statement (250+ words)',
  prompt_find = 'In Gee''s Bend, Alabama, generations of African American women — including named artists like Loretta Pettway and Annie Mae Young — built one of America''s great art traditions: improvisational quilts whose bold, off-grid geometry now hangs in major museums. Choose ONE named quilter. Document: her life and circumstances, how she described her own way of working, and what makes her compositions recognizable.',
  prompt_interpret = 'Compose an improvisational print answering her principles — work "your way": break the grid deliberately, reuse and recombine pattern blocks the way the quilters reused cloth, and let the composition show its decisions.',
  prompt_own = 'An artist statement of 250+ words: who she was, one principle of hers you adopted, one place you departed from it, and why her work belongs in the story of American art.'
where is_template and template_id = 'geesbend';

-- A class brief is identified by its uuid; a template by its slug. This
-- keeps `classes.assigned` readable either way.
create index if not exists briefs_class_lookup on public.briefs (class_id) where class_id is not null;

-- ── Shape a brief for the client, whoever is asking ────────────────────
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
    'standards', array_to_string(b.standards_tags, ' · '))
$$;
revoke all on function public._school_brief_json(public.briefs) from public, anon, authenticated;

-- ── Teacher: everything assignable to this class ───────────────────────
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

-- ── Teacher: write one ─────────────────────────────────────────────────
-- p_id null  → create. p_id set → edit that class's own brief.
-- A template can never be edited; duplicating one is a create with its
-- text pre-filled, which the client does.
--
-- WHOLE-RECORD UPDATE. Every field is written as given, so omitting one
-- clears it. That is what lets a teacher empty a prompt they no longer
-- want, and it is safe because the only caller is a form that always
-- submits every field. Any future partial-update path must read the row
-- first and merge, or it will silently wipe a teacher's writing.
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
  p_standards text[] default '{}')
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
  -- A floor below 25 defeats the point of the exercise; above 2000 is a
  -- typo rather than an assignment.
  if coalesce(p_words,150) < 25 or coalesce(p_words,150) > 2000 then
    raise exception 'the word count must be between 25 and 2000' using errcode='22023';
  end if;
  -- Binding to a style the archive cannot credit would give students a
  -- reference strip with no works-cited line.
  if p_style is not null and p_style <> '' and not exists (
       select 1 from public.patterns_public
        where style = p_style and heritage_origin is not null limit 1) then
    raise exception 'no patterns in the archive for style %', p_style using errcode='22023';
  end if;

  if p_id is null or btrim(p_id) = '' then
    insert into public.briefs (class_id, is_template, title, tradition, meta,
      prompt_find, prompt_interpret, prompt_own, turn_in, pattern_style,
      min_words, standards_tags, created_by)
    values (c.id, false, btrim(p_title), p_tradition, p_meta,
      p_find, p_interpret, p_own, p_turnin, nullif(p_style,''),
      coalesce(p_words,150), coalesce(p_standards,'{}'), c.teacher_email)
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
      min_words=coalesce(p_words,150), standards_tags=coalesce(p_standards,'{}')
     where id=bid and class_id=c.id and not is_template
    returning * into b;
    if not found then
      raise exception 'brief not found in this class' using errcode='42501';
    end if;
  end if;

  return public._school_brief_json(b) || jsonb_build_object('assigned',
    coalesce(b.template_id, b.id::text) = any(c.assigned));
end $$;

-- ── Teacher: remove one ────────────────────────────────────────────────
create or replace function public.school_delete_brief(p_class uuid, p_id text)
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes; bid uuid; n int;
begin
  c := public._school_teacher_class(p_class);
  begin bid := p_id::uuid;
  exception when invalid_text_representation then
    raise exception 'the shipped briefs cannot be deleted' using errcode='42501';
  end;

  select count(*) into n from public.class_works
   where class_id = c.id and brief_id = p_id;
  if n > 0 then
    raise exception 'this brief has % piece(s) of student work — unassign it instead', n
      using errcode='23503';
  end if;

  delete from public.briefs where id = bid and class_id = c.id and not is_template;
  update public.classes set assigned = array_remove(assigned, p_id) where id = c.id;
end $$;

-- ── Teacher: which traditions the archive can actually back ────────────
-- Only styles with a creditable origin appear, because the credit line is
-- the student's works-cited entry.
create or replace function public.school_pattern_styles()
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare e text;
begin
  e := nullif(lower(coalesce(auth.jwt()->>'email','')), '');
  if e is null then raise exception 'sign in required' using errcode='28000'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('style',style,'patterns',n,'origin',origin)
             order by style)
      from (select style, count(*) n, min(heritage_origin) origin
              from public.patterns_public
             where heritage_origin is not null and style is not null
             group by style having count(*) >= 4) s), '[]'::jsonb);
end $$;

-- ── Student: assigned briefs, in full ──────────────────────────────────
-- Replaces the id-only `assigned` list. The client no longer holds brief
-- text at all, so a teacher's own brief renders exactly like a shipped
-- one. `assigned` is kept in the payload for compatibility.
create or replace function public.school_state(p_session uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare m public.class_members; c public.classes;
begin
  m := public._school_member(p_session);
  select * into c from public.classes where id = m.class_id;
  return jsonb_build_object(
    'display_name', m.display_name,
    'class_name',   c.name,
    'assigned',     to_jsonb(c.assigned),
    'briefs', coalesce((
      select jsonb_agg(public._school_brief_json(b)
               order by array_position(c.assigned, coalesce(b.template_id, b.id::text)))
        from public.briefs b
       where coalesce(b.template_id, b.id::text) = any(c.assigned)
         and (b.is_template or b.class_id = c.id)), '[]'::jsonb),
    'works', coalesce((
      select jsonb_agg(jsonb_build_object(
               'brief_id',   w.brief_id,
               'image_path', w.image_path,
               'statement',  w.statement,
               'credits',    to_jsonb(w.credits),
               'status',     w.status,
               'submitted_at', w.submitted_at))
        from public.class_works w
       where w.class_id = m.class_id and w.member_id = m.id), '[]'::jsonb));
end $$;

-- ── Grants ─────────────────────────────────────────────────────────────
revoke execute on function
  public.school_class_briefs(uuid),
  public.school_save_brief(uuid,text,text,text,text,text,text,text,text,text,integer,text[]),
  public.school_delete_brief(uuid,text),
  public.school_pattern_styles()
  from public, anon;

grant execute on function
  public.school_class_briefs(uuid),
  public.school_save_brief(uuid,text,text,text,text,text,text,text,text,text,integer,text[]),
  public.school_delete_brief(uuid,text),
  public.school_pattern_styles()
  to authenticated;

grant execute on function public.school_state(uuid) to anon, authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFY
--   select template_id, tradition, meta, min_words from public.briefs
--    where is_template order by template_id;
--   -- all three must have tradition, meta and turn_in filled in
-- ═══════════════════════════════════════════════════════════════════════
