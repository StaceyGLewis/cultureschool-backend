-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — field notes
--
-- NOT RUN. Apply after school-mode-briefs.sql.
--
-- ── What this fixes ────────────────────────────────────────────────────
-- Every brief's turn-in checklist says "documented source notes". The
-- app had nowhere to put them. A student could attach a print and write
-- a statement; the Find step — the whole research half of the assignment
-- — captured nothing.
--
-- That threw away the most valuable thing in the product. A student who
-- went to a museum, photographed a textile, or asked their grandmother
-- has evidence no chatbot can produce. Now it is recorded, it counts
-- toward turn-in, and the teacher sees it beside the finished print.
--
-- Notes are deliberately off-platform-friendly: the source is a place, a
-- book, or a person as often as a link.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ── How many notes a brief demands before it can be turned in ──────────
alter table public.briefs
  add column if not exists min_notes integer not null default 0;

-- The shipped three all ask for documented sources in their checklist,
-- so make that real rather than decorative.
update public.briefs set min_notes = 2
 where is_template and template_id in ('adinkra','shibori');
update public.briefs set min_notes = 3
 where is_template and template_id = 'geesbend';   -- a named quilter needs more digging

-- ── The notes themselves ───────────────────────────────────────────────
create table if not exists public.class_notes (
  id         uuid primary key default gen_random_uuid(),
  class_id   uuid not null references public.classes(id)       on delete cascade,
  member_id  uuid not null references public.class_members(id) on delete cascade,
  brief_id   text not null,
  -- Where it was found. 'place', 'person' and 'object' are first-class
  -- on purpose: a link is the least interesting kind of source here.
  kind       text not null default 'other'
             check (kind in ('museum','book','person','place','object','web','other')),
  source     text,                    -- the museum, the book, "my grandmother"
  link       text,
  found      text not null,           -- what they actually found
  surprised  text,                    -- the question that earns the marks
  image_path text,                    -- their own photograph, in class-works
  created_at timestamptz not null default now()
);
create index if not exists notes_member_brief_idx
  on public.class_notes (class_id, member_id, brief_id, created_at);

alter table public.class_notes enable row level security;
revoke all on public.class_notes from anon, authenticated;

-- ── Receipts gain a kind ───────────────────────────────────────────────
-- class_events.kind is CHECK-constrained, so a new event type needs the
-- constraint rebuilt. Existing rows all satisfy the wider list.
alter table public.class_events drop constraint if exists class_events_kind_check;
alter table public.class_events add  constraint class_events_kind_check
  check (kind in ('join','open_brief','view_tradition','open_studio',
                  'attach','save_draft','submit','resubmit',
                  'field_note','note_photo'));

-- ── Shape a note for whoever is asking ─────────────────────────────────
create or replace function public._school_note_json(n public.class_notes)
returns jsonb
language sql immutable set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id', n.id, 'brief_id', n.brief_id, 'kind', n.kind,
    'source', n.source, 'link', n.link, 'found', n.found,
    'surprised', n.surprised, 'image_path', n.image_path,
    'created_at', n.created_at)
$$;
revoke all on function public._school_note_json(public.class_notes) from public, anon, authenticated;

-- ── Student: record a find ─────────────────────────────────────────────
create or replace function public.school_add_note(
  p_session   uuid,
  p_brief     text,
  p_found     text,
  p_kind      text default 'other',
  p_source    text default null,
  p_link      text default null,
  p_surprised text default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; n public.class_notes; cnt int;
begin
  m := public._school_member(p_session);
  perform public._school_brief(p_brief);

  if btrim(coalesce(p_found,'')) = '' then
    raise exception 'say what you found' using errcode='22023';
  end if;
  if length(p_found) > 4000 then
    raise exception 'that note is too long' using errcode='22023';
  end if;
  -- A cap per brief, so a stuck student cannot fill the table.
  select count(*) into cnt from public.class_notes
   where member_id = m.id and brief_id = p_brief;
  if cnt >= 40 then
    raise exception 'that is 40 notes on one brief — edit or delete some first'
      using errcode='22023';
  end if;

  insert into public.class_notes (class_id, member_id, brief_id, kind,
    source, link, found, surprised)
  values (m.class_id, m.id, p_brief,
    case when p_kind in ('museum','book','person','place','object','web','other')
         then p_kind else 'other' end,
    nullif(btrim(coalesce(p_source,'')),''), nullif(btrim(coalesce(p_link,'')),''),
    btrim(p_found), nullif(btrim(coalesce(p_surprised,'')),''))
  returning * into n;

  insert into public.class_events (class_id, member_id, kind, detail)
  values (m.class_id, m.id, 'field_note',
          left(coalesce(nullif(n.source,''), n.kind), 120));

  return public._school_note_json(n);
end $$;

create or replace function public.school_update_note(
  p_session uuid, p_note uuid,
  p_found text default null, p_kind text default null,
  p_source text default null, p_link text default null, p_surprised text default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; n public.class_notes;
begin
  m := public._school_member(p_session);
  if btrim(coalesce(p_found,'')) = '' then
    raise exception 'say what you found' using errcode='22023';
  end if;
  update public.class_notes set
    found     = btrim(p_found),
    kind      = case when p_kind in ('museum','book','person','place','object','web','other')
                     then p_kind else kind end,
    source    = nullif(btrim(coalesce(p_source,'')),''),
    link      = nullif(btrim(coalesce(p_link,'')),''),
    surprised = nullif(btrim(coalesce(p_surprised,'')),'')
   where id = p_note and member_id = m.id
  returning * into n;
  if not found then raise exception 'note not found' using errcode='42501'; end if;
  return public._school_note_json(n);
end $$;

create or replace function public.school_delete_note(p_session uuid, p_note uuid)
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members;
begin
  m := public._school_member(p_session);
  delete from public.class_notes where id = p_note and member_id = m.id;
end $$;

-- ── Where a note's photograph is allowed to go ─────────────────────────
-- Same rule as a finished print: the path is derived from the caller's
-- own membership, never supplied, so a photo cannot be aimed elsewhere.
create or replace function public.school_note_target(p_session uuid, p_note uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare m public.class_members; n public.class_notes;
begin
  m := public._school_member(p_session);
  select * into n from public.class_notes where id = p_note and member_id = m.id;
  if not found then raise exception 'note not found' using errcode='42501'; end if;
  return jsonb_build_object(
    'bucket','class-works',
    'path', m.class_id || '/' || m.id || '/notes/' || n.id || '.jpg');
end $$;

-- Called by the edge function once the object is written.
create or replace function public.school_note_photo(
  p_session uuid, p_note uuid, p_path text)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; n public.class_notes;
begin
  m := public._school_member(p_session);
  update public.class_notes set image_path = p_path
   where id = p_note and member_id = m.id
  returning * into n;
  if not found then raise exception 'note not found' using errcode='42501'; end if;
  insert into public.class_events (class_id, member_id, kind, detail)
  values (m.class_id, m.id, 'note_photo', left(coalesce(n.source, n.kind), 120));
  return public._school_note_json(n);
end $$;

-- ── Student state now carries notes and the notes requirement ──────────
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
               || jsonb_build_object('min_notes', b.min_notes)
               order by array_position(c.assigned, coalesce(b.template_id, b.id::text)))
        from public.briefs b
       where coalesce(b.template_id, b.id::text) = any(c.assigned)
         and (b.is_template or b.class_id = c.id)), '[]'::jsonb),
    'notes', coalesce((
      select jsonb_agg(public._school_note_json(n) order by n.created_at)
        from public.class_notes n
       where n.member_id = m.id), '[]'::jsonb),
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

-- ── Turn-in now checks the research, not just the making ───────────────
create or replace function public.school_submit(p_session uuid, p_brief text)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; b public.briefs; w public.class_works;
        n int; notes int; again boolean;
begin
  m := public._school_member(p_session);
  b := public._school_brief(p_brief);

  select * into w from public.class_works
   where class_id = m.class_id and member_id = m.id and brief_id = p_brief;
  if not found            then raise exception 'nothing to turn in'      using errcode='22023'; end if;
  if w.image_path is null then raise exception 'attach your print first' using errcode='22023'; end if;

  select count(*) into notes from public.class_notes
   where member_id = m.id and brief_id = p_brief;
  if notes < b.min_notes then
    raise exception 'this brief needs % source note(s), you have %', b.min_notes, notes
      using errcode='22023';
  end if;

  n := coalesce(array_length(regexp_split_to_array(btrim(w.statement), '\s+'), 1), 0);
  if btrim(w.statement) = '' then n := 0; end if;
  if n < b.min_words then
    raise exception 'statement needs % words, has %', b.min_words, n using errcode='22023';
  end if;

  again := w.status = 'submitted';
  update public.class_works set status='submitted', submitted_at=now() where id = w.id;
  insert into public.class_events (class_id, member_id, kind, detail)
  values (m.class_id, m.id, case when again then 'resubmit' else 'submit' end, b.title);

  return jsonb_build_object('status','submitted','words',n,'notes',notes);
end $$;

-- ── The teacher reads the research beside the print ────────────────────
create or replace function public.school_work_detail(p_class uuid, p_work uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare c public.classes; w public.class_works; m public.class_members;
begin
  c := public._school_teacher_class(p_class);
  select * into w from public.class_works where id = p_work and class_id = c.id;
  if not found then raise exception 'work not found' using errcode='42501'; end if;
  select * into m from public.class_members where id = w.member_id;
  return jsonb_build_object(
    'name',m.display_name,'brief_id',w.brief_id,
    'image_path',w.image_path,'statement',w.statement,'credits',to_jsonb(w.credits),
    'status',w.status,'featured',w.featured,'submitted_at',w.submitted_at,
    'notes', coalesce((
      select jsonb_agg(public._school_note_json(n) order by n.created_at)
        from public.class_notes n
       where n.class_id = c.id and n.member_id = w.member_id
         and n.brief_id = w.brief_id), '[]'::jsonb),
    'receipts', coalesce((
      select jsonb_agg(jsonb_build_object('kind',e.kind,'detail',e.detail,'at',e.at)
               order by e.at)
        from public.class_events e
       where e.class_id = c.id and e.member_id = w.member_id), '[]'::jsonb));
end $$;

-- ── The brief editor can now set the sources requirement ───────────────
-- Extends school_save_brief with p_min_notes. Postgres treats this as a
-- new overload, so the old 12-argument signature is dropped explicitly —
-- otherwise a call omitting p_min_notes would stay ambiguous.
drop function if exists public.school_save_brief(
  uuid,text,text,text,text,text,text,text,text,text,integer,text[]);

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
  p_min_notes integer default 0)
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
  if p_style is not null and p_style <> '' and not exists (
       select 1 from public.patterns_public
        where style = p_style and heritage_origin is not null limit 1) then
    raise exception 'no patterns in the archive for style %', p_style using errcode='22023';
  end if;

  if p_id is null or btrim(p_id) = '' then
    insert into public.briefs (class_id, is_template, title, tradition, meta,
      prompt_find, prompt_interpret, prompt_own, turn_in, pattern_style,
      min_words, min_notes, standards_tags, created_by)
    values (c.id, false, btrim(p_title), p_tradition, p_meta,
      p_find, p_interpret, p_own, p_turnin, nullif(p_style,''),
      coalesce(p_words,150), coalesce(p_min_notes,0),
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
      standards_tags=coalesce(p_standards,'{}')
     where id=bid and class_id=c.id and not is_template
    returning * into b;
    if not found then
      raise exception 'brief not found in this class' using errcode='42501';
    end if;
  end if;

  return public._school_brief_json(b)
         || jsonb_build_object('min_notes', b.min_notes,
              'assigned', coalesce(b.template_id, b.id::text) = any(c.assigned));
end $$;

revoke execute on function public.school_save_brief(
  uuid,text,text,text,text,text,text,text,text,text,integer,text[],integer)
  from public, anon;
grant execute on function public.school_save_brief(
  uuid,text,text,text,text,text,text,text,text,text,integer,text[],integer)
  to authenticated;

-- The teacher's brief list must carry the requirement too.
create or replace function public.school_class_briefs(p_class uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  return coalesce((
    select jsonb_agg(public._school_brief_json(b)
             || jsonb_build_object('min_notes', b.min_notes,
                  'assigned', coalesce(b.template_id, b.id::text) = any(c.assigned))
             order by b.is_template desc, b.created_at)
      from public.briefs b
     where b.is_template or b.class_id = c.id), '[]'::jsonb);
end $$;

-- ── Grants ─────────────────────────────────────────────────────────────
grant execute on function
  public.school_add_note(uuid,text,text,text,text,text,text),
  public.school_update_note(uuid,uuid,text,text,text,text,text),
  public.school_delete_note(uuid,uuid),
  public.school_note_target(uuid,uuid),
  public.school_note_photo(uuid,uuid,text),
  public.school_state(uuid),
  public.school_submit(uuid,text)
  to anon, authenticated;

grant execute on function public.school_work_detail(uuid,uuid) to authenticated;
revoke execute on function public.school_work_detail(uuid,uuid) from anon;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFY
--   select template_id, min_notes, min_words from public.briefs
--    where is_template order by template_id;
--   -- adinkra 2, shibori 2, geesbend 3
--
--   select rowsecurity from pg_tables
--    where schemaname='public' and tablename='class_notes';   -- must be true
-- ═══════════════════════════════════════════════════════════════════════
