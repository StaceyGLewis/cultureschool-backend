-- ============================================================================
--  Reconciled with the EXISTING setup (shopify-membership + grant_membership
--  already live). This file ONLY adds the patch pieces + email-param gates.
--  It does NOT touch grant_membership or the existing has_all_access() — so the
--  live membership flow keeps working untouched.
-- ============================================================================

-- (1) pack_id column does not exist yet — add it (plain uuid, no FK, nullable).
alter table public.entitlements add column if not exists pack_id uuid;

-- RLS read-own (idempotent; safe if already present).
alter table public.entitlements enable row level security;
drop policy if exists "read own entitlements" on public.entitlements;
create policy "read own entitlements" on public.entitlements
  for select to authenticated
  using ( lower(email) = lower(auth.jwt() ->> 'email') );

-- (2) grant the ONE-TIME patch pass (called by the webhook via service role).
drop function if exists public.grant_pack(text, uuid);
drop function if exists public.grant_pack(text, uuid, timestamptz);
create or replace function public.grant_pack(p_email text, p_pack_id uuid, p_expires_at timestamptz default null)
returns void language sql security definer as $$
  insert into public.entitlements (product, email, pack_id, expires_at)
  values ('pack', lower(p_email), p_pack_id, p_expires_at);
$$;

-- (3) EMAIL-PARAM gate checks. Edge Functions call the DB with the service-role
--     client (no user JWT in the session), so auth.jwt() is null there. We pass
--     the already-verified email from the Edge Function instead.
create or replace function public.has_all_access(p_email text)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.entitlements
    where lower(email) = lower(p_email)
      and product = 'membership'
      and (expires_at is null or expires_at > now())
  );
$$;

create or replace function public.owns_pack(p_email text, p_pack_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.entitlements
    where lower(email) = lower(p_email)
      and product = 'pack' and pack_id = p_pack_id
      and (expires_at is null or expires_at > now())   -- pass still valid
  );
$$;

create or replace function public.can_use_patch_studio(p_email text)
returns boolean language sql security definer stable as $$
  select public.has_all_access(p_email)
      or public.owns_pack(p_email, '6b7f1d2a-3c4e-4f50-9a6b-1c2d3e4f5a6b'::uuid);
$$;

-- (4) Lock the email-param functions to the service role ONLY, so no client can
--     probe arbitrary emails' entitlement status.
revoke execute on function public.has_all_access(text)       from public;
revoke execute on function public.owns_pack(text, uuid)      from public;
revoke execute on function public.can_use_patch_studio(text) from public;
grant  execute on function public.has_all_access(text)       to service_role;
grant  execute on function public.owns_pack(text, uuid)      to service_role;
grant  execute on function public.can_use_patch_studio(text) to service_role;
