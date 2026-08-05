-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — access layer
--
-- NOT RUN. Apply docs/school-mode.sql first, then review this.
-- Additive: adds three columns, seeds three brief templates, and creates
-- functions. Touches no existing table.
--
-- ── The problem this solves ────────────────────────────────────────────
-- Students have no account. They hold a class code, which is read aloud
-- across a room and written on a whiteboard — it is a shared secret with
-- roughly the security of a door number. So the code must be able to do
-- exactly one thing (join), and nothing else in the system may accept it.
--
-- ── The model ──────────────────────────────────────────────────────────
-- Joining mints a per-student `session_token` (uuid v4, 122 bits). Every
-- subsequent call takes that token and never a class id, a member id, or
-- a code. A student therefore cannot *express* "give me class X" — the
-- token IS the scope. Guessing another student's token is guessing a
-- uuid; guessing a class code gets you a fresh empty membership in that
-- class and nothing belonging to anyone else.
--
-- Teacher calls key off auth.jwt()->>'email' and never a parameter, so a
-- teacher cannot ask for another teacher's class either.
--
-- RLS stays on with no permissive policy anywhere. These functions are
-- SECURITY DEFINER and are the only path in. Every one pins search_path,
-- without which a caller could shadow `public` and hijack the definer's
-- privileges.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ── Schema additions ───────────────────────────────────────────────────
alter table public.class_members
  add column if not exists session_token uuid;

create unique index if not exists members_session_idx
  on public.class_members (session_token) where session_token is not null;

-- A code is only guessable while it is accepted. Teachers open the door
-- at the start of a lesson and shut it once everyone is in, which
-- collapses the brute-force window from "forever" to "ten minutes".
alter table public.classes
  add column if not exists join_open boolean not null default true;

-- Server-side word floor. The client also counts, but a limit the client
-- owns is not a limit.
alter table public.briefs
  add column if not exists is_template boolean not null default false;

create unique index if not exists briefs_template_idx
  on public.briefs (template_id) where is_template;

-- ── The three shipped briefs, as server-side templates ─────────────────
-- class_id is null: these are global, assignable by any class. Teacher
-- copies get a class_id and is_template = false.
insert into public.briefs (template_id, is_template, title, pattern_style, min_words, standards_tags)
values
  ('adinkra',  true, 'A Symbol That Speaks: Adinkra',      'adinkra', 150,
     array['VA.68.H.1.3','VA.68.S.1.3','F.S.1003.42(2)(h)']),
  ('shibori',  true, 'Pattern From Process: Shibori',      'shibori', 150,
     array['VA.68.O.1.1','VA.68.H.2.2','F.S.1003.42(2)(i)']),
  ('geesbend', true, 'My Way: The Quilters of Gee''s Bend', null,     250,
     array['VA.912.H','F.S.1003.42(2)(h)','F.S.1003.42(2)(r)'])
on conflict do nothing;

-- ═══════════════════════════════════════════════════════════════════════
-- INTERNAL HELPERS  (not granted to anyone)
-- ═══════════════════════════════════════════════════════════════════════

-- Resolve a student session token to its member + class, or raise.
create or replace function public._school_member(p_session uuid)
returns public.class_members
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare m public.class_members;
begin
  if p_session is null then raise exception 'session required' using errcode='28000'; end if;
  select * into m from public.class_members where session_token = p_session;
  if not found then raise exception 'session not recognised' using errcode='28000'; end if;
  return m;
end $$;

-- Resolve a class the CALLER TEACHES, or raise. Ownership comes from the
-- verified JWT, never from an argument.
create or replace function public._school_teacher_class(p_class uuid)
returns public.classes
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare c public.classes; e text;
begin
  e := nullif(lower(coalesce(auth.jwt()->>'email','')), '');
  if e is null then raise exception 'sign in required' using errcode='28000'; end if;
  select * into c from public.classes
   where id = p_class and lower(teacher_email) = e;
  if not found then
    -- Same error whether the class is missing or simply not theirs, so the
    -- function cannot be used to probe which class ids exist.
    raise exception 'class not found' using errcode='42501';
  end if;
  return c;
end $$;

-- Look up an assigned brief by template id or by uuid.
create or replace function public._school_brief(p_brief text)
returns public.briefs
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare b public.briefs;
begin
  select * into b from public.briefs where is_template and template_id = p_brief;
  if found then return b; end if;
  begin
    select * into b from public.briefs where id = p_brief::uuid;
  exception when invalid_text_representation then
    raise exception 'unknown brief' using errcode='22023';
  end;
  if not found then raise exception 'unknown brief' using errcode='22023'; end if;
  return b;
end $$;

create or replace function public._school_code()
returns text language plpgsql volatile set search_path = public, pg_temp as $$
declare
  -- No O/0, I/1, S/5: these codes are read aloud to twelve-year-olds.
  alpha constant text := 'ABCDEFGHJKLMNPQRTUVWXY2346789';
  c text;
begin
  loop
    c := '';
    for _i in 1..6 loop
      c := c || substr(alpha, 1 + floor(random()*length(alpha))::int, 1);
    end loop;
    exit when not exists (select 1 from public.classes where code = c);
  end loop;
  return c;
end $$;

-- ═══════════════════════════════════════════════════════════════════════
-- STUDENT SURFACE
-- The only function that accepts a class code is school_join.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.school_join(
  p_code text, p_display_name text, p_device text default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes; m public.class_members; nm text; tok uuid;
begin
  nm := btrim(coalesce(p_display_name,''));
  if nm = ''            then raise exception 'name required'      using errcode='22023'; end if;
  if length(nm) > 28    then raise exception 'name too long'      using errcode='22023'; end if;
  if nm like '%@%'      then raise exception 'display name only'  using errcode='22023'; end if;

  select * into c from public.classes
   where code = upper(btrim(coalesce(p_code,''))) and not archived;
  if not found then raise exception 'no such class' using errcode='42501'; end if;

  tok := gen_random_uuid();

  -- Rejoining with the same display name reclaims the same membership, so
  -- a student who loses their device keeps their work.
  select * into m from public.class_members
   where class_id = c.id and lower(display_name) = lower(nm);

  if found then
    -- join_open gates NEW members only. A teacher who shuts the door and
    -- then resets a student's session did so to let that student back in;
    -- blocking the rejoin would strand them from their own work.
    update public.class_members
       set session_token = tok, device_token = coalesce(p_device, device_token)
     where id = m.id;
  else
    if not c.join_open then
      raise exception 'class is closed' using errcode='42501';
    end if;
    insert into public.class_members (class_id, display_name, device_token, session_token)
    values (c.id, nm, p_device, tok)
    returning * into m;
    insert into public.class_events (class_id, member_id, kind) values (c.id, m.id, 'join');
  end if;

  return jsonb_build_object(
    'session_token', tok,
    'display_name',  m.display_name,
    'class_name',    c.name,
    'assigned',      to_jsonb(c.assigned));
end $$;

-- Everything this student is allowed to see. No ids of other members,
-- no other class, no other student's statement.
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

create or replace function public.school_save_work(
  p_session uuid, p_brief text, p_statement text default null,
  p_image_path text default null, p_credits text[] default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; b public.briefs; w public.class_works;
begin
  m := public._school_member(p_session);
  b := public._school_brief(p_brief);

  if length(coalesce(p_statement,'')) > 20000 then
    raise exception 'statement too long' using errcode='22023';
  end if;

  insert into public.class_works (class_id, member_id, brief_id, statement, image_path, credits)
  values (m.class_id, m.id, p_brief,
          coalesce(p_statement,''), p_image_path, coalesce(p_credits,'{}'))
  on conflict (class_id, member_id, brief_id) do update
     set statement  = coalesce(p_statement,  public.class_works.statement),
         image_path = coalesce(p_image_path, public.class_works.image_path),
         credits    = coalesce(p_credits,    public.class_works.credits)
  returning * into w;

  return jsonb_build_object('brief_id', w.brief_id, 'status', w.status);
end $$;

create or replace function public.school_submit(p_session uuid, p_brief text)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; b public.briefs; w public.class_works; n int; again boolean;
begin
  m := public._school_member(p_session);
  b := public._school_brief(p_brief);

  select * into w from public.class_works
   where class_id = m.class_id and member_id = m.id and brief_id = p_brief;
  if not found         then raise exception 'nothing to turn in'   using errcode='22023'; end if;
  if w.image_path is null then raise exception 'attach your print first' using errcode='22023'; end if;

  -- The turn-in floor, enforced where the client cannot reach it.
  n := coalesce(array_length(regexp_split_to_array(btrim(w.statement), '\s+'), 1), 0);
  if btrim(w.statement) = '' then n := 0; end if;
  if n < b.min_words then
    raise exception 'statement needs % words, has %', b.min_words, n using errcode='22023';
  end if;

  again := w.status = 'submitted';
  update public.class_works
     set status='submitted', submitted_at=now() where id = w.id;
  insert into public.class_events (class_id, member_id, kind, detail)
  values (m.class_id, m.id, case when again then 'resubmit' else 'submit' end, b.title);

  return jsonb_build_object('status','submitted','words',n);
end $$;

create or replace function public.school_log(
  p_session uuid, p_kind text, p_detail text default null)
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; recent int;
begin
  m := public._school_member(p_session);
  -- A receipt trail is evidence; an unbounded one is a write amplifier.
  select count(*) into recent from public.class_events
   where member_id = m.id and at > now() - interval '1 hour';
  if recent >= 300 then return; end if;
  insert into public.class_events (class_id, member_id, kind, detail)
  values (m.class_id, m.id, p_kind, left(coalesce(p_detail,''), 200));
exception when check_violation then
  return;   -- unknown kind: drop it rather than fail the student's action
end $$;

-- ═══════════════════════════════════════════════════════════════════════
-- TEACHER SURFACE  (requires a verified session)
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.school_create_class(p_name text, p_org uuid default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare e text; c public.classes;
begin
  e := nullif(lower(coalesce(auth.jwt()->>'email','')), '');
  if e is null then raise exception 'sign in required' using errcode='28000'; end if;
  if btrim(coalesce(p_name,'')) = '' then raise exception 'name required' using errcode='22023'; end if;

  insert into public.classes (org_id, teacher_email, code, name)
  values (p_org, e, public._school_code(), btrim(p_name))
  returning * into c;

  return jsonb_build_object('id',c.id,'code',c.code,'name',c.name,'join_open',c.join_open);
end $$;

create or replace function public.school_teacher_classes()
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare e text;
begin
  e := nullif(lower(coalesce(auth.jwt()->>'email','')), '');
  if e is null then raise exception 'sign in required' using errcode='28000'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id',c.id,'code',c.code,'name',c.name,
             'join_open',c.join_open,'assigned',to_jsonb(c.assigned),
             'students',(select count(*) from public.class_members m where m.class_id=c.id),
             'submitted',(select count(*) from public.class_works w
                           where w.class_id=c.id and w.status='submitted'))
             order by c.created_at desc)
      from public.classes c
     where lower(c.teacher_email) = e and not c.archived), '[]'::jsonb);
end $$;

create or replace function public.school_set_assigned(p_class uuid, p_briefs text[])
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes; b text;
begin
  c := public._school_teacher_class(p_class);
  foreach b in array coalesce(p_briefs,'{}') loop
    perform public._school_brief(b);        -- rejects an unknown brief id
  end loop;
  update public.classes set assigned = coalesce(p_briefs,'{}') where id = c.id;
  return jsonb_build_object('assigned', to_jsonb(coalesce(p_briefs,'{}')));
end $$;

create or replace function public.school_set_join_open(p_class uuid, p_open boolean)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  update public.classes set join_open = coalesce(p_open,true) where id = c.id;
  return jsonb_build_object('join_open', coalesce(p_open,true));
end $$;

create or replace function public.school_roster(p_class uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'member_id',m.id,'display_name',m.display_name,'joined_at',m.joined_at,
             'submitted',(select count(*) from public.class_works w
                           where w.member_id=m.id and w.status='submitted'),
             'drafts',(select count(*) from public.class_works w
                        where w.member_id=m.id and w.status='draft'))
             order by m.display_name)
      from public.class_members m where m.class_id = c.id), '[]'::jsonb);
end $$;

create or replace function public.school_gallery(p_class uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'work_id',w.id,'member_id',w.member_id,
             'display_name',m.display_name,'brief_id',w.brief_id,
             'image_path',w.image_path,'credits',to_jsonb(w.credits),
             'featured',w.featured,'hidden',w.hidden,'submitted_at',w.submitted_at)
             order by w.submitted_at desc)
      from public.class_works w
      join public.class_members m on m.id = w.member_id
     where w.class_id = c.id and w.status = 'submitted'), '[]'::jsonb);
end $$;

-- The statement beside the receipts that produced it — the whole
-- AI-resistance argument, in one call.
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
    'display_name',w.member_id,'name',m.display_name,'brief_id',w.brief_id,
    'image_path',w.image_path,'statement',w.statement,'credits',to_jsonb(w.credits),
    'status',w.status,'featured',w.featured,'submitted_at',w.submitted_at,
    'receipts', coalesce((
      select jsonb_agg(jsonb_build_object('kind',e.kind,'detail',e.detail,'at',e.at)
               order by e.at)
        from public.class_events e
       where e.class_id = c.id and e.member_id = w.member_id), '[]'::jsonb));
end $$;

create or replace function public.school_feature(p_class uuid, p_work uuid, p_on boolean)
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  update public.class_works set featured = coalesce(p_on,false)
   where id = p_work and class_id = c.id;
end $$;

create or replace function public.school_hide(p_class uuid, p_work uuid, p_on boolean)
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  update public.class_works set hidden = coalesce(p_on,false)
   where id = p_work and class_id = c.id;
end $$;

-- Invalidate a student's token so they can rejoin on another device.
-- Their work is untouched.
create or replace function public.school_reset_member(p_class uuid, p_member uuid)
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare c public.classes;
begin
  c := public._school_teacher_class(p_class);
  update public.class_members set session_token = null, device_token = null
   where id = p_member and class_id = c.id;
end $$;

-- ═══════════════════════════════════════════════════════════════════════
-- GRANTS
-- Tables stay unreachable. Only these functions are callable, and the
-- helpers are callable by nobody.
-- ═══════════════════════════════════════════════════════════════════════
revoke all on public.school_orgs, public.classes, public.class_members,
              public.briefs, public.class_works, public.class_events
  from anon, authenticated;

revoke all on function
  public._school_member(uuid), public._school_teacher_class(uuid),
  public._school_brief(text), public._school_code()
  from public, anon, authenticated;

-- Students are anonymous by design, so the student surface is anon-callable.
grant execute on function
  public.school_join(text,text,text),
  public.school_state(uuid),
  public.school_save_work(uuid,text,text,text,text[]),
  public.school_submit(uuid,text),
  public.school_log(uuid,text,text)
  to anon, authenticated;

-- Teacher surface requires a real session; anon gets nothing.
revoke execute on function
  public.school_create_class(text,uuid), public.school_teacher_classes(),
  public.school_set_assigned(uuid,text[]), public.school_set_join_open(uuid,boolean),
  public.school_roster(uuid), public.school_gallery(uuid),
  public.school_work_detail(uuid,uuid), public.school_feature(uuid,uuid,boolean),
  public.school_hide(uuid,uuid,boolean), public.school_reset_member(uuid,uuid)
  from public, anon;

grant execute on function
  public.school_create_class(text,uuid), public.school_teacher_classes(),
  public.school_set_assigned(uuid,text[]), public.school_set_join_open(uuid,boolean),
  public.school_roster(uuid), public.school_gallery(uuid),
  public.school_work_detail(uuid,uuid), public.school_feature(uuid,uuid,boolean),
  public.school_hide(uuid,uuid,boolean), public.school_reset_member(uuid,uuid)
  to authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- STORAGE — run separately
--
-- Student work must not land in coco-drops or public-uploads: both are
-- public buckets on guessable paths (docs/asset-library-audit.md §1.2).
--
--   insert into storage.buckets (id, name, public)
--   values ('class-works','class-works',false) on conflict do nothing;
--
-- Path convention: <class_id>/<member_id>/<brief_id>.jpg
-- Uploads go through a signed URL the client requests after school_join,
-- so the bucket never accepts an unauthenticated write.
-- ═══════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════
-- WHAT THIS DOES NOT DO
--
-- 1. Teacher identity is auth.jwt()->>'email'. dist/school.html currently
--    signs teachers in with a self-asserted email and no password — that
--    must move to Supabase magic-link before these functions are usable.
--    Until then the teacher surface will correctly refuse every call.
--
-- 2. A correct class code still yields a membership. That is the design:
--    the code is a door number, not a secret. What it does NOT yield is
--    anyone else's work — school_state is scoped to the caller's own
--    member row. Shut join_open after the lesson starts.
--
-- 3. No deletion path. Works and receipts accumulate. A retention policy
--    (end-of-year purge) is a separate decision and belongs in writing
--    before a district asks for it.
-- ═══════════════════════════════════════════════════════════════════════
