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

-- ============================================================
-- Friends/follow, directory search, and per-event join codes.
-- Safe to re-run on an existing database.
-- ============================================================

-- Follow directly from the app (search results), and unfollow
drop policy if exists "Members can follow" on public.calendar_memberships;
create policy "Members can follow"
  on public.calendar_memberships
  for insert
  with check (auth.uid() = member_id and auth.uid() <> owner_id);

drop policy if exists "Members can unfollow" on public.calendar_memberships;
create policy "Members can unfollow"
  on public.calendar_memberships
  for delete
  using (auth.uid() = member_id);

-- Directory search (safe columns only; excludes self)
create or replace function public.search_profiles(query text)
returns table(id uuid, display_name text, department text)
language sql security definer set search_path = public as $$
  select p.id, p.display_name, p.department from profiles p
  where p.id <> auth.uid()
    and (p.display_name ilike '%' || query || '%' or p.department ilike '%' || query || '%')
  order by p.display_name limit 20;
$$;

-- Who am I following (with names)
create or replace function public.list_following()
returns table(owner_id uuid, display_name text, department text)
language sql security definer set search_path = public as $$
  select m.owner_id, p.display_name, p.department
  from calendar_memberships m join profiles p on p.id = m.owner_id
  where m.member_id = auth.uid() order by p.display_name;
$$;

-- Whether an event requires a code (safe to expose); the code itself lives
-- in event_join_codes which only the author can read.
alter table public.barangay_events add column if not exists requires_join_code boolean not null default false;

create table if not exists public.event_join_codes (
  event_id text primary key references public.barangay_events(id) on delete cascade,
  code text not null,
  created_by uuid not null references auth.users on delete cascade
);
alter table public.event_join_codes enable row level security;

drop policy if exists "Authors manage their join codes" on public.event_join_codes;
create policy "Authors manage their join codes"
  on public.event_join_codes
  for all
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

-- Participants ("joined" users). Visible to anyone who can see the event.
create table if not exists public.event_participants (
  event_id text not null references public.barangay_events(id) on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  participant_name text,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table public.event_participants enable row level security;

drop policy if exists "Participants visible with event" on public.event_participants;
create policy "Participants visible with event"
  on public.event_participants
  for select
  using (exists (select 1 from barangay_events e where e.id = event_id)); -- inherits event RLS

drop policy if exists "Participants can leave" on public.event_participants;
create policy "Participants can leave"
  on public.event_participants
  for delete
  using (auth.uid() = user_id);

-- Inserts happen only through this RPC so the join code can be verified
-- server-side without ever sending it to non-authors.
create or replace function public.join_event(target_event_id text, code text default null)
returns void language plpgsql security definer set search_path = public as $$
declare ev record; expected text; my_name text;
begin
  select * into ev from barangay_events where id = target_event_id;
  if not found then raise exception 'Event not found'; end if;
  -- re-check visibility manually (security definer bypasses RLS)
  if not (ev.event_type = 'public' or ev.created_by_id = auth.uid()
          or (ev.event_type = 'shared' and exists (select 1 from calendar_memberships m
              where m.owner_id = ev.created_by_id and m.member_id = auth.uid()))) then
    raise exception 'You cannot join this event';
  end if;
  if ev.requires_join_code then
    select c.code into expected from event_join_codes c where c.event_id = target_event_id;
    if expected is null or expected <> upper(trim(coalesce(code, ''))) then
      raise exception 'Invalid join code';
    end if;
  end if;
  select display_name into my_name from profiles where id = auth.uid();
  insert into event_participants (event_id, user_id, participant_name)
  values (target_event_id, auth.uid(), my_name)
  on conflict (event_id, user_id) do nothing;
end $$;

-- ============================================================
-- GROUPS PIVOT (group-chat model). Groups replace the
-- follow-people system and per-event join codes entirely.
-- Safe to re-run on an existing database.
-- ============================================================

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique not null default upper(substr(md5(random()::text), 1, 6)),
  created_by uuid not null references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.groups enable row level security;

drop policy if exists "Authenticated can view groups" on public.groups;
create policy "Authenticated can view groups"
  on public.groups
  for select
  using (auth.uid() is not null); -- searchable directory

drop policy if exists "Users create their groups" on public.groups;
create policy "Users create their groups"
  on public.groups
  for insert
  with check (auth.uid() = created_by);

drop policy if exists "Creators delete their groups" on public.groups;
create policy "Creators delete their groups"
  on public.groups
  for delete
  using (auth.uid() = created_by);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
alter table public.group_members enable row level security;

drop policy if exists "Authenticated can view memberships" on public.group_members;
create policy "Authenticated can view memberships"
  on public.group_members
  for select
  using (auth.uid() is not null); -- needed for member counts

drop policy if exists "Users join groups themselves" on public.group_members;
create policy "Users join groups themselves"
  on public.group_members
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Members can leave groups" on public.group_members;
create policy "Members can leave groups"
  on public.group_members
  for delete
  using (auth.uid() = user_id);

-- Events belong to a group when shared
alter table public.barangay_events add column if not exists group_id uuid references public.groups(id) on delete set null;
alter table public.barangay_events add column if not exists group_name text;

drop policy if exists "Read visible events" on public.barangay_events;
create policy "Read visible events"
  on public.barangay_events
  for select
  using (
    event_type = 'public'
    or created_by_id = auth.uid()
    or (event_type = 'shared' and group_id is not null and exists (
          select 1 from group_members gm
          where gm.group_id = barangay_events.group_id
            and gm.user_id = auth.uid()))
  );

-- Remove the replaced follow-people / per-event-code machinery
drop function if exists public.join_event(text, text);
drop function if exists public.join_shared_calendar(text);
drop function if exists public.search_profiles(text);
drop function if exists public.list_following();
drop table if exists public.event_participants;
drop table if exists public.event_join_codes;
drop table if exists public.calendar_memberships;
alter table public.barangay_events drop column if exists requires_join_code;
