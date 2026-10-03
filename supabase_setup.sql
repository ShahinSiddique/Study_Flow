-- StudyFlow Cloud — Supabase database setup
-- Run this whole file once in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  min_weekly_hours numeric(6,2) not null default 0 check (min_weekly_hours >= 0),
  archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  subject_name text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  study_ms bigint not null default 0 check (study_ms >= 0),
  break_ms bigint not null default 0 check (break_ms >= 0),
  status text not null default 'running' check (status in ('running','paused','completed')),
  last_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists sessions_user_started_idx on public.sessions(user_id, started_at desc);
create index if not exists sessions_user_status_idx on public.sessions(user_id, status);

create unique index if not exists one_active_session_per_user
on public.sessions(user_id)
where status in ('running','paused');

alter table public.subjects enable row level security;
alter table public.sessions enable row level security;

drop policy if exists "subjects_select_own" on public.subjects;
drop policy if exists "subjects_insert_own" on public.subjects;
drop policy if exists "subjects_update_own" on public.subjects;
drop policy if exists "subjects_delete_own" on public.subjects;

create policy "subjects_select_own" on public.subjects for select using (auth.uid() = user_id);
create policy "subjects_insert_own" on public.subjects for insert with check (auth.uid() = user_id);
create policy "subjects_update_own" on public.subjects for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "subjects_delete_own" on public.subjects for delete using (auth.uid() = user_id);

drop policy if exists "sessions_select_own" on public.sessions;
drop policy if exists "sessions_insert_own" on public.sessions;
drop policy if exists "sessions_update_own" on public.sessions;
drop policy if exists "sessions_delete_own" on public.sessions;

create policy "sessions_select_own" on public.sessions for select using (auth.uid() = user_id);
create policy "sessions_insert_own" on public.sessions for insert with check (auth.uid() = user_id);
create policy "sessions_update_own" on public.sessions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sessions_delete_own" on public.sessions for delete using (auth.uid() = user_id);

create or replace function public.seed_default_subjects()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (select 1 from public.subjects where user_id = auth.uid()) then
    insert into public.subjects(user_id,name,min_weekly_hours) values
      (auth.uid(),'Signal Systems',3),
      (auth.uid(),'Embedded Systems',4),
      (auth.uid(),'Communication Systems',4),
      (auth.uid(),'Software Engineering',2),
      (auth.uid(),'Driving Licence',3),
      (auth.uid(),'Online Earning Course',2),
      (auth.uid(),'AI Engineering Course',0);
  end if;
end;
$$;

create or replace function public.start_study(p_subject_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_name text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  if exists (
    select 1 from public.sessions
    where user_id=auth.uid() and status in ('running','paused')
  ) then
    raise exception 'A study session is already active';
  end if;

  select name into v_name
  from public.subjects
  where id=p_subject_id and user_id=auth.uid() and archived=false;

  if v_name is null then raise exception 'Subject not found'; end if;

  insert into public.sessions(user_id,subject_id,subject_name,status,started_at,last_changed_at)
  values(auth.uid(),p_subject_id,v_name,'running',now(),now());
end;
$$;

create or replace function public.pause_study()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.sessions
  set study_ms = study_ms + round(extract(epoch from (now()-last_changed_at))*1000)::bigint,
      status='paused',
      last_changed_at=now()
  where user_id=auth.uid() and status='running';

  if not found then raise exception 'No running study session'; end if;
end;
$$;

create or replace function public.resume_study()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.sessions
  set break_ms = break_ms + round(extract(epoch from (now()-last_changed_at))*1000)::bigint,
      status='running',
      last_changed_at=now()
  where user_id=auth.uid() and status='paused';

  if not found then raise exception 'No paused study session'; end if;
end;
$$;

create or replace function public.stop_study()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.sessions
  set study_ms = study_ms +
        case when status='running' then round(extract(epoch from (now()-last_changed_at))*1000)::bigint else 0 end,
      break_ms = break_ms +
        case when status='paused' then round(extract(epoch from (now()-last_changed_at))*1000)::bigint else 0 end,
      status='completed',
      ended_at=now(),
      last_changed_at=now()
  where user_id=auth.uid() and status in ('running','paused');

  if not found then raise exception 'No active study session'; end if;
end;
$$;

revoke execute on function public.seed_default_subjects() from public, anon;
revoke execute on function public.start_study(uuid) from public, anon;
revoke execute on function public.pause_study() from public, anon;
revoke execute on function public.resume_study() from public, anon;
revoke execute on function public.stop_study() from public, anon;

grant execute on function public.seed_default_subjects() to authenticated;
grant execute on function public.start_study(uuid) to authenticated;
grant execute on function public.pause_study() to authenticated;
grant execute on function public.resume_study() to authenticated;
grant execute on function public.stop_study() to authenticated;

-- Enable realtime updates for cross-device refresh when available.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='subjects'
  ) then
    alter publication supabase_realtime add table public.subjects;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='sessions'
  ) then
    alter publication supabase_realtime add table public.sessions;
  end if;
end $$;
