create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text not null unique,
  display_name text,
  department text,
  phone_number text,
  street_address text,
  barangay text,
  city text,
  bio text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view their own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Users can insert their own profile"
  on public.profiles
  for insert
  with check (auth.uid() = id);

create table if not exists public.barangay_events (
  id text primary key,
  title text not null,
  location text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  day_key timestamptz not null,
  description text not null default '',
  has_attachment boolean not null default false,
  attachment_type text,
  attendance_status text,
  created_at timestamptz not null default now(),
  created_by_name text,
  created_by_department text
);

-- Migration for databases created before the department feature:
alter table public.profiles add column if not exists department text;
alter table public.barangay_events add column if not exists created_by_name text;
alter table public.barangay_events add column if not exists created_by_department text;

alter table public.barangay_events enable row level security;

alter publication supabase_realtime add table public.barangay_events;

-- ============================================================
-- Sharing feature: event types, ownership, share codes,
-- follow-the-author memberships, and visibility-aware policies.
-- Safe to re-run on an existing database.
-- ============================================================

-- Event ownership + type
alter table public.barangay_events add column if not exists event_type text not null default 'public';
alter table public.barangay_events add column if not exists created_by_id uuid;

-- One share code per user
alter table public.profiles add column if not exists share_code text unique
  default upper(substr(md5(random()::text), 1, 6));

-- Follow-the-author memberships
create table if not exists public.calendar_memberships (
  owner_id uuid not null references auth.users on delete cascade,
  member_id uuid not null references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, member_id)
);
alter table public.calendar_memberships enable row level security;

drop policy if exists "Members can view their memberships" on public.calendar_memberships;
create policy "Members can view their memberships"
  on public.calendar_memberships
  for select
  using (auth.uid() = member_id or auth.uid() = owner_id);

-- Join via code (security definer so the code lookup bypasses profiles RLS)
create or replace function public.join_shared_calendar(code text)
returns table(owner_name text, owner_department text)
language plpgsql security definer set search_path = public as $$
declare target record;
begin
  select id, display_name, department into target
    from profiles where share_code = upper(trim(code));
  if not found then raise exception 'Invalid share code'; end if;
  if target.id = auth.uid() then raise exception 'You cannot join your own calendar'; end if;
  insert into calendar_memberships (owner_id, member_id)
    values (target.id, auth.uid())
    on conflict (owner_id, member_id) do nothing;
  return query select target.display_name, target.department;
end $$;

-- Replace the wide-open event policies with visibility-aware ones
drop policy if exists "Public read access to barangay events" on public.barangay_events;
drop policy if exists "Read visible events" on public.barangay_events;
create policy "Read visible events"
  on public.barangay_events
  for select
  using (
    event_type = 'public'
    or created_by_id = auth.uid()
    or (event_type = 'shared' and exists (
          select 1 from calendar_memberships m
          where m.owner_id = barangay_events.created_by_id
            and m.member_id = auth.uid()))
  );

drop policy if exists "Public insert access to barangay events" on public.barangay_events;
drop policy if exists "Authenticated insert own events" on public.barangay_events;
create policy "Authenticated insert own events"
  on public.barangay_events
  for insert
  with check (auth.uid() is not null and created_by_id = auth.uid());

drop policy if exists "Public update access to barangay events" on public.barangay_events;
drop policy if exists "Authenticated update events" on public.barangay_events;
create policy "Authenticated update events"
  on public.barangay_events
  for update
  using (auth.uid() is not null)
  with check (auth.uid() is not null);

drop policy if exists "Creators delete own events" on public.barangay_events;
create policy "Creators delete own events"
  on public.barangay_events
  for delete
  using (created_by_id = auth.uid());
