do $$ begin if not exists (select 1 from pg_roles where rolname='anon')
  then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated')
  then create role authenticated nologin; end if; end $$;
create schema if not exists auth;
create table if not exists auth._who(email text);
delete from auth._who; insert into auth._who values (null);
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select case when (select email from auth._who limit 1) is null then '{}'::jsonb
              else jsonb_build_object('email', (select email from auth._who limit 1)) end $$;
create or replace function auth._be(p text) returns void language sql as $$
  update auth._who set email = p $$;
grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.jwt() to anon, authenticated;
\set QUIET on
create or replace function t_refuse(label text, stmt text) returns void
language plpgsql as $$
begin
  execute stmt;
  raise notice '  FAIL  % (expected refusal, was allowed)', label;
exception when others then raise notice '  PASS  %', label;
end $$;

create or replace function t_true(label text, cond text) returns void
language plpgsql as $$
declare ok boolean;
begin
  execute 'select ('||cond||')' into ok;
  if ok then raise notice '  PASS  %', label;
  else raise notice '  FAIL  %  (condition false)', label; end if;
exception when others then raise notice '  FAIL  %  (error: %)', label, SQLERRM;
end $$;
\set QUIET off
