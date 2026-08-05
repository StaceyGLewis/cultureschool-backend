-- ═══════════════════════════════════════════════════════════════════════
-- PRINT STUDIO FOR SCHOOLS — handoff to the studio and back
--
-- NOT RUN. Apply after school-mode-video.sql.
--
-- ── The problem ────────────────────────────────────────────────────────
-- A student left School Mode, arrived at a blank canvas in a differently
-- coloured app, made something, exported it, found the file, came back,
-- and uploaded it. Five steps, five places to lose a fifteen-year-old.
--
-- Going OUT is already solved: print.html has applyLaunchParams(), built
-- for the pattern-library handoff, which reads ?colors=&name=&palette=.
-- School Mode can use the same door, so a student arrives with their
-- tradition's palette already loaded rather than a blank canvas. That is
-- the pedagogy — the assignment is set up around them before they draw.
--
-- ── Coming BACK ────────────────────────────────────────────────────────
-- The session token must never travel in a URL: it would sit in browser
-- history, in referrer headers, and in any screenshot of the address bar,
-- and it is the key to everything that student has.
--
-- So this mints a separate handoff token that can do exactly one thing:
-- attach one image to one assignment, once, within four hours. It cannot
-- read, cannot submit, cannot see another student. A leaked handoff is
-- worth one image on one brief.
-- ═══════════════════════════════════════════════════════════════════════

begin;

create table if not exists public.class_handoffs (
  id         uuid primary key default gen_random_uuid(),
  class_id   uuid not null references public.classes(id)       on delete cascade,
  member_id  uuid not null references public.class_members(id) on delete cascade,
  brief_id   text not null,
  created_at timestamptz not null default now(),
  -- One class period plus the walk home. Long enough to finish, short
  -- enough that a token in someone's history is stale by tomorrow.
  expires_at timestamptz not null default now() + interval '4 hours',
  used_at    timestamptz
);
create index if not exists handoffs_member_idx
  on public.class_handoffs (member_id, brief_id, created_at desc);

alter table public.class_handoffs enable row level security;
revoke all on public.class_handoffs from anon, authenticated;

-- ── Student: mint one ──────────────────────────────────────────────────
create or replace function public.school_handoff_create(p_session uuid, p_brief text)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare m public.class_members; h public.class_handoffs; recent int;
begin
  m := public._school_member(p_session);
  perform public._school_brief(p_brief);

  -- A student who taps "open the studio" twenty times should not mint
  -- twenty live tokens.
  select count(*) into recent from public.class_handoffs
   where member_id = m.id and created_at > now() - interval '10 minutes';
  if recent >= 12 then
    raise exception 'too many studio sessions just now — wait a minute'
      using errcode='22023';
  end if;

  -- Retire any earlier live token for this brief, so only the newest works.
  update public.class_handoffs set used_at = now()
   where member_id = m.id and brief_id = p_brief and used_at is null;

  insert into public.class_handoffs (class_id, member_id, brief_id)
  values (m.class_id, m.id, p_brief)
  returning * into h;

  insert into public.class_events (class_id, member_id, kind, detail)
  values (m.class_id, m.id, 'open_studio', 'handoff');

  return jsonb_build_object('token', h.id, 'expires_at', h.expires_at);
end $$;

-- ── The edge function: where may this handoff write? ───────────────────
create or replace function public.school_handoff_target(p_token uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare h public.class_handoffs;
begin
  select * into h from public.class_handoffs
   where id = p_token and used_at is null and expires_at > now();
  -- One error for expired, spent, and never-existed alike, so the
  -- endpoint cannot be used to probe which tokens are real.
  if not found then raise exception 'handoff not valid' using errcode='28000'; end if;
  return jsonb_build_object(
    'bucket','class-works',
    'path', h.class_id || '/' || h.member_id || '/' ||
            regexp_replace(h.brief_id, '[^a-zA-Z0-9_-]', '', 'g') || '.jpg',
    'brief_id', h.brief_id);
end $$;

-- ── The edge function: record it, and spend the token ──────────────────
create or replace function public.school_handoff_complete(p_token uuid, p_path text)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare h public.class_handoffs;
begin
  update public.class_handoffs set used_at = now()
   where id = p_token and used_at is null and expires_at > now()
  returning * into h;
  if not found then raise exception 'handoff not valid' using errcode='28000'; end if;

  insert into public.class_works (class_id, member_id, brief_id, image_path)
  values (h.class_id, h.member_id, h.brief_id, p_path)
  on conflict (class_id, member_id, brief_id) do update
     set image_path = excluded.image_path;

  insert into public.class_events (class_id, member_id, kind, detail)
  values (h.class_id, h.member_id, 'attach', 'sent from Print Studio');

  return jsonb_build_object('ok', true, 'brief_id', h.brief_id);
end $$;

-- ── Grants ─────────────────────────────────────────────────────────────
-- All three are anon-callable: a student has no account, and the tokens
-- carry their own authorisation.
grant execute on function
  public.school_handoff_create(uuid,text),
  public.school_handoff_target(uuid),
  public.school_handoff_complete(uuid,text)
  to anon, authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFY
--   select rowsecurity from pg_tables
--    where schemaname='public' and tablename='class_handoffs';   -- true
--
--   select count(*) from pg_policies where tablename='class_handoffs';  -- 0
--
-- Housekeeping, whenever retention is decided:
--   delete from public.class_handoffs where expires_at < now() - interval '7 days';
-- ═══════════════════════════════════════════════════════════════════════
