create schema if not exists storage;
create table if not exists storage.buckets(
  id text primary key, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
create table if not exists storage.objects(
  id uuid default gen_random_uuid() primary key, bucket_id text, name text);
alter table storage.objects enable row level security;
