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

-- ============================================================
-- Push notifications (Firebase Cloud Messaging).
-- No new tables/columns needed — barangay_events already has everything
-- the notification text and audience targeting require (event_type,
-- group_id, group_name, created_by_name, created_by_department).
--
-- Wiring (all done outside SQL, via the Supabase dashboard/CLI):
--   1. Deploy the Edge Function in supabase/functions/send-event-notification
--      (`supabase functions deploy send-event-notification --use-api`).
--   2. Set its secret, base64-encoded (from Firebase Console > Project
--      Settings > Service accounts > Generate new private key):
--        $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Raw "key.json")))
--        supabase secrets set "FCM_SERVICE_ACCOUNT_JSON_B64=$b64"
--      Base64 is required, not optional — plain JSON is all double quotes,
--      and PowerShell mangles that when passing it to a native exe as a
--      command-line argument (learned this the hard way: the secret got
--      silently corrupted and the function crashed on every call).
--   3. Project > Integrations > Webhooks (Supabase dashboard) > create a new
--      webhook: table barangay_events, event INSERT, type "Supabase Edge
--      Functions" (not "HTTP Request" — this type auto-attaches valid
--      auth), function: send-event-notification.
--
-- The function maps each new row to an FCM topic and skips personal
-- events entirely: event_type='public' -> topic "public-events" (every
-- device); event_type='shared' -> topic "group-<group_id>" (only that
-- group's members, who subscribe/unsubscribe automatically as they join
-- or leave groups in the app). See README.md's "Push Notifications"
-- section for the full walkthrough.
-- ============================================================

-- ============================================================
-- Private groups (join-request/approval workflow).
-- A private group is hidden from search; the only way in is entering its
-- code, which files a join request the creator must accept.
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.groups add column if not exists is_private boolean not null default false;

-- Tighten visibility: private groups only show to their creator and members
-- (this is what actually makes them "unsearchable" — searchGroups/listMyGroups
-- both just do a plain `select` under this policy, no client-side filtering
-- needed).
drop policy if exists "Authenticated can view groups" on public.groups;
drop policy if exists "View public groups, or your own/joined private ones" on public.groups;
create policy "View public groups, or your own/joined private ones"
  on public.groups
  for select
  using (
    is_private = false
    or created_by = auth.uid()
    or exists (select 1 from group_members gm where gm.group_id = groups.id and gm.user_id = auth.uid())
  );

-- Tighten self-serve joins: direct inserts into group_members only work for
-- public groups, or for a group's own creator (covers createGroup's second
-- insert for a private group). Anyone else joining a private group must go
-- through the request_or_join_group() RPC below, which is security definer
-- and so bypasses this policy entirely for the accept step.
drop policy if exists "Users join groups themselves" on public.group_members;
drop policy if exists "Users join public groups or their own" on public.group_members;
create policy "Users join public groups or their own"
  on public.group_members
  for insert
  with check (
    auth.uid() = user_id
    and (
      exists (select 1 from groups g where g.id = group_id and g.is_private = false)
      or exists (select 1 from groups g where g.id = group_id and g.created_by = auth.uid())
    )
  );

create table if not exists public.group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  requester_id uuid not null references auth.users on delete cascade,
  status text not null default 'pending', -- pending | accepted | declined
  created_at timestamptz not null default now(),
  unique (group_id, requester_id)
);
alter table public.group_join_requests enable row level security;

drop policy if exists "Requester or group creator can view a request" on public.group_join_requests;
create policy "Requester or group creator can view a request"
  on public.group_join_requests
  for select
  using (
    requester_id = auth.uid()
    or exists (select 1 from groups g where g.id = group_id and g.created_by = auth.uid())
  );
-- No direct insert/update policies: both go through the RPCs below, which
-- run security definer specifically so the "is this group private" and
-- "am I the creator" checks can't be bypassed by a hand-crafted request.

-- Looks up a group by code and either joins instantly (public) or files a
-- pending request (private). Security definer so it can find a private
-- group by code even though the caller's own SELECT is blocked from seeing it.
--
-- Two separate PL/pgSQL name-collision bugs have lived in this function:
-- (1) the input parameter was named "code" — same as groups.code — making
--     `where code = ...` ambiguous. Fixed by naming it p_code.
-- (2) the RETURNS TABLE columns were named group_id/status — same as real
--     columns on group_members/group_join_requests used later in the body
--     (e.g. `insert ... on conflict (group_id, ...)`) — same ambiguity,
--     just masked until (1) was fixed since the function errored out
--     earlier every time. Fixed by prefixing the return columns with
--     out_ so they can never collide with any table's column names, no
--     matter what the function body later touches. The Dart caller
--     (SupabaseEventRepository.requestOrJoinGroupByCode in
--     lib/event_store.dart) reads out_group_id/out_group_name/out_status.
drop function if exists public.request_or_join_group(text);
create or replace function public.request_or_join_group(p_code text)
returns table(out_group_id uuid, out_group_name text, out_status text)
language plpgsql security definer set search_path = public as $$
declare target record;
begin
  select id, name, is_private into target from groups where code = upper(trim(p_code));
  if not found then raise exception 'Invalid group code'; end if;

  if exists (select 1 from group_members gm where gm.group_id = target.id and gm.user_id = auth.uid()) then
    return query select target.id, target.name, 'already_member'::text;
    return;
  end if;

  if not target.is_private then
    insert into group_members (group_id, user_id) values (target.id, auth.uid())
      on conflict (group_id, user_id) do nothing;
    return query select target.id, target.name, 'joined'::text;
    return;
  end if;

  insert into group_join_requests (group_id, requester_id, status)
    values (target.id, auth.uid(), 'pending')
    on conflict (group_id, requester_id) do update set status = 'pending', created_at = now();
  return query select target.id, target.name, 'pending'::text;
end $$;

-- Lists pending requests for groups the CALLER created (their approval inbox).
create or replace function public.list_pending_join_requests()
returns table(
  request_id uuid, group_id uuid, group_name text,
  requester_id uuid, requester_name text, requester_department text, created_at timestamptz
)
language sql security definer set search_path = public as $$
  select gjr.id, gjr.group_id, g.name, gjr.requester_id, p.display_name, p.department, gjr.created_at
  from group_join_requests gjr
  join groups g on g.id = gjr.group_id
  join profiles p on p.id = gjr.requester_id
  where g.created_by = auth.uid() and gjr.status = 'pending'
  order by gjr.created_at asc;
$$;

-- Accept or decline; only the group's creator may call this for their group.
create or replace function public.respond_to_join_request(request_id uuid, accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare req record;
begin
  select gjr.group_id, gjr.requester_id, g.created_by into req
    from group_join_requests gjr join groups g on g.id = gjr.group_id
    where gjr.id = request_id;
  if not found then raise exception 'Request not found'; end if;
  if req.created_by <> auth.uid() then raise exception 'Only the group creator can respond to requests'; end if;

  if accept then
    insert into group_members (group_id, user_id) values (req.group_id, req.requester_id)
      on conflict (group_id, user_id) do nothing;
    update group_join_requests set status = 'accepted' where id = request_id;
  else
    update group_join_requests set status = 'declined' where id = request_id;
  end if;
end $$;

-- ============================================================
-- User preferences (appearance), synced across devices.
-- theme_mode: 'system' | 'light' | 'dark'. ui_style: 'liquid' | 'solid'.
-- Both mirror the ThemeMode/UiStyle enum .name values used client-side.
-- Safe to re-run on an existing database.
-- ============================================================
alter table public.profiles add column if not exists theme_mode text not null default 'dark';
alter table public.profiles add column if not exists ui_style text not null default 'liquid';

-- ============================================================
-- Hotfix: stale wide-open policies from the original (pre-private-groups)
-- setup can still be active even after the Private groups block above has
-- been run, if it was ever applied out of order or only partially in the
-- SQL editor. Postgres RLS policies for the same command are OR'd
-- together, so an old permissive policy left in place defeats a newer,
-- more restrictive one sitting right next to it — this is exactly why
-- private groups could still show up in search (old "Authenticated can
-- view groups" on public.groups) and could still be self-joined directly,
-- bypassing the approval flow (old "Users join groups themselves" on
-- public.group_members). Unconditionally drop both old policy names here,
-- last, so this always wins regardless of what ran before it.
-- Safe/idempotent to re-run.
-- ============================================================
drop policy if exists "Authenticated can view groups" on public.groups;
drop policy if exists "Users join groups themselves" on public.group_members;

-- ============================================================
-- Group member roles (admin/member) + member list display info.
-- display_name/avatar_url are denormalized onto group_members at join
-- time (same convention as barangay_events.created_by_name) so the member
-- list never needs to read OTHER users' rows in `profiles`, which stays
-- locked to "select your own row only" — no new profiles policy needed.
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.group_members add column if not exists role text not null default 'member';
alter table public.group_members add column if not exists display_name text;
alter table public.group_members add column if not exists avatar_url text;

do $$ begin
  if not exists (
    select 1 from pg_constraint where conname = 'group_members_role_check'
  ) then
    alter table public.group_members
      add constraint group_members_role_check check (role in ('admin', 'member'));
  end if;
end $$;

-- Backfill: every group's creator becomes an admin; everyone else's
-- display_name/avatar_url is filled in from their current profile (a
-- one-time snapshot — later profile edits don't retroactively update it,
-- same tradeoff barangay_events.created_by_name already made).
update public.group_members gm
set role = 'admin'
from public.groups g
where g.id = gm.group_id and g.created_by = gm.user_id and gm.role <> 'admin';

update public.group_members gm
set display_name = coalesce(p.display_name, p.email), avatar_url = p.avatar_url
from public.profiles p
where p.id = gm.user_id and gm.display_name is null;

-- Any admin can promote a fellow member to admin (or edit their own denorm
-- fields via the app's own update calls, which only ever touch `role`).
drop policy if exists "Admins promote members" on public.group_members;
create policy "Admins promote members"
  on public.group_members
  for update
  using (
    exists (
      select 1 from group_members admin_row
      where admin_row.group_id = group_members.group_id
        and admin_row.user_id = auth.uid()
        and admin_row.role = 'admin'
    )
  )
  with check (role in ('admin', 'member'));

-- Any admin can remove a regular member; only the group's creator can
-- remove a fellow admin. OR'd together with the existing "Members can
-- leave groups" self-delete policy above — both are intentionally
-- permissive and meant to coexist (self-leave vs. admin-removes-someone).
drop policy if exists "Admins remove members" on public.group_members;
create policy "Admins remove members"
  on public.group_members
  for delete
  using (
    exists (
      select 1 from group_members admin_row
      where admin_row.group_id = group_members.group_id
        and admin_row.user_id = auth.uid()
        and admin_row.role = 'admin'
    )
    and (
      group_members.role = 'member'
      or exists (
        select 1 from groups g
        where g.id = group_members.group_id and g.created_by = auth.uid()
      )
    )
  );

-- Row visibility for group_members stays as broad as it already was
-- ("Authenticated can view memberships", further up this file) — group
-- membership rows (and therefore member COUNTS) need to stay visible for
-- groups a user hasn't joined yet, since searchGroups shows "N members"
-- on results the caller isn't a member of. Tightening that to
-- members-only would silently zero out those counts. Instead, the new
-- display_name/avatar_url columns are only ever read through
-- list_group_members() below, which checks membership itself before
-- returning them — the raw columns exist for storage/denormalization,
-- not for direct client selects.

-- Full member roster (with names/avatars) for a group, callable only by
-- one of that group's own members. Security definer so it can read
-- display_name/avatar_url regardless of table-level grants.
-- Reads display_name/avatar_url LIVE from profiles (via a left join),
-- falling back to the group_members snapshot columns only if a profile
-- row is somehow missing. Originally this read the snapshot columns
-- directly, which meant a member's own profile edits (name, and
-- especially avatar — see avatar_picker_page.dart) never showed up in
-- any group's roster after the fact; being security definer, this
-- function can read every member's profiles row regardless of the
-- "select your own row only" RLS policy, so there was never a need for
-- the snapshot in the first place. The group_members.display_name/
-- avatar_url columns are left in place (still written at join time) but
-- are now dead weight for this read path — harmless, not worth a
-- migration to drop them.
-- member_account_role is the person's app-wide role (citizen/lgu_member/
-- superadmin, from profiles.role) — NOT the same thing as member_role
-- (their admin/member standing within THIS group). Added so the member
-- list can show each person's account-role badge (RoleAvatarFrame in the
-- Flutter app), alongside their existing group-admin star.
create or replace function public.list_group_members(p_group_id uuid)
returns table(
  member_user_id uuid, member_display_name text, member_avatar_url text,
  member_role text, member_joined_at timestamptz, member_account_role text
)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from group_members gm where gm.group_id = p_group_id and gm.user_id = auth.uid()
  ) then
    raise exception 'Not a member of this group';
  end if;

  return query
    select
      gm.user_id,
      coalesce(p.display_name, p.email, gm.display_name),
      coalesce(p.avatar_url, gm.avatar_url),
      gm.role,
      gm.joined_at,
      coalesce(p.role, 'citizen')
    from group_members gm
    left join profiles p on p.id = gm.user_id
    where gm.group_id = p_group_id
    order by (gm.role = 'admin') desc, coalesce(p.display_name, gm.display_name) asc nulls last;
end $$;

-- request_or_join_group's instant-join path and respond_to_join_request's
-- accept path both insert group_members rows on the joiner's behalf; both
-- are security definer, so they can read the joiner's profile directly to
-- fill in display_name/avatar_url without needing a profiles policy change.
create or replace function public.request_or_join_group(p_code text)
returns table(out_group_id uuid, out_group_name text, out_status text)
language plpgsql security definer set search_path = public as $$
declare target record; joiner record;
begin
  select id, name, is_private into target from groups where code = upper(trim(p_code));
  if not found then raise exception 'Invalid group code'; end if;

  if exists (select 1 from group_members gm where gm.group_id = target.id and gm.user_id = auth.uid()) then
    return query select target.id, target.name, 'already_member'::text;
    return;
  end if;

  if not target.is_private then
    select coalesce(display_name, email) as name, avatar_url into joiner from profiles where id = auth.uid();
    insert into group_members (group_id, user_id, role, display_name, avatar_url)
      values (target.id, auth.uid(), 'member', joiner.name, joiner.avatar_url)
      on conflict (group_id, user_id) do nothing;
    return query select target.id, target.name, 'joined'::text;
    return;
  end if;

  insert into group_join_requests (group_id, requester_id, status)
    values (target.id, auth.uid(), 'pending')
    on conflict (group_id, requester_id) do update set status = 'pending', created_at = now();
  return query select target.id, target.name, 'pending'::text;
end $$;

create or replace function public.respond_to_join_request(request_id uuid, accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare req record; joiner record;
begin
  select gjr.group_id, gjr.requester_id, g.created_by into req
    from group_join_requests gjr join groups g on g.id = gjr.group_id
    where gjr.id = request_id;
  if not found then raise exception 'Request not found'; end if;
  if req.created_by <> auth.uid() then raise exception 'Only the group creator can respond to requests'; end if;

  if accept then
    select coalesce(display_name, email) as name, avatar_url into joiner from profiles where id = req.requester_id;
    insert into group_members (group_id, user_id, role, display_name, avatar_url)
      values (req.group_id, req.requester_id, 'member', joiner.name, joiner.avatar_url)
      on conflict (group_id, user_id) do nothing;
    update group_join_requests set status = 'accepted' where id = request_id;
  else
    update group_join_requests set status = 'declined' where id = request_id;
  end if;
end $$;

-- ============================================================
-- User roles + permissions (July 2026).
-- citizen (default, self-registers in the app) | lgu_member (registers via
-- the separate GitHub Pages admin portal, docs/lgu-admin/, and needs
-- superadmin approval — or is created directly by a superadmin, see below)
-- | superadmin (approves LGU applications and is the only role that can
-- post Public events; originally a single account, but a superadmin can
-- now create additional superadmin/lgu_member accounts directly from the
-- dashboard's "Add account" card — see
-- supabase/functions/admin-create-account).
-- Citizens can only ever create Personal events and cannot create groups.
-- LGU members can create groups and post Group events, but not Public.
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.profiles add column if not exists role text not null default 'citizen';
alter table public.profiles add column if not exists lgu_request_status text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_role_check') then
    alter table public.profiles add constraint profiles_role_check
      check (role in ('citizen', 'lgu_member', 'superadmin'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_lgu_status_check') then
    alter table public.profiles add constraint profiles_lgu_status_check
      check (lgu_request_status is null or lgu_request_status in ('pending', 'approved', 'rejected'));
  end if;
end $$;

-- Stops a user granting themselves a role/LGU status through the normal
-- "update your own profile" path — that RLS policy (further up this file)
-- is, and should stay, wide open on auth.uid() = id for every OTHER
-- column. Only the two security-definer functions below may change role/
-- lgu_request_status, via a session-local flag they set immediately
-- before their own UPDATE — any UPDATE that doesn't set that flag
-- (i.e. every ordinary client write) has these two columns silently
-- forced back to their previous value instead of erroring, since the
-- app's normal profile-save call also touches this row and shouldn't
-- fail just because it isn't role-aware.
create or replace function public.guard_profile_role_columns()
returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('app.bypass_role_guard', true), 'off') <> 'on' then
    new.role := old.role;
    new.lgu_request_status := old.lgu_request_status;
  end if;
  return new;
end $$;

drop trigger if exists guard_profile_role_columns on public.profiles;
create trigger guard_profile_role_columns
  before update on public.profiles
  for each row execute function public.guard_profile_role_columns();

-- Self-service: a signed-in user (from the main app OR the LGU admin
-- portal) applies for LGU verification. Callable again after a rejection
-- to re-apply.
create or replace function public.request_lgu_status(p_department text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  perform set_config('app.bypass_role_guard', 'on', true);
  update profiles
    set lgu_request_status = 'pending',
        department = coalesce(nullif(trim(p_department), ''), department)
    where id = auth.uid();
end $$;

-- Superadmin-only: everyone currently awaiting approval.
create or replace function public.list_pending_lgu_applications()
returns table(
  user_id uuid, email text, display_name text, department text, requested_at timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can view LGU applications';
  end if;
  return query
    select p.id, p.email, p.display_name, p.department, p.updated_at
    from profiles p
    where p.lgu_request_status = 'pending'
    order by p.updated_at asc;
end $$;

-- Superadmin-only: approve (-> role = lgu_member) or reject an application.
create or replace function public.respond_to_lgu_application(p_user_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can respond to LGU applications';
  end if;
  perform set_config('app.bypass_role_guard', 'on', true);
  if p_approve then
    update profiles set role = 'lgu_member', lgu_request_status = 'approved' where id = p_user_id;
  else
    update profiles set lgu_request_status = 'rejected' where id = p_user_id;
  end if;
end $$;

-- Event creation, gated by role: Public is superadmin-only; Group
-- (shared) needs lgu_member or superadmin; Personal is open to everyone
-- signed in. Replaces the older, role-blind "Authenticated insert own
-- events" policy.
drop policy if exists "Authenticated insert own events" on public.barangay_events;
drop policy if exists "Role-gated event creation" on public.barangay_events;
create policy "Role-gated event creation"
  on public.barangay_events
  for insert
  with check (
    auth.uid() is not null
    and created_by_id = auth.uid()
    and (
      event_type = 'personal'
      or (event_type = 'shared' and exists (
            select 1 from profiles p where p.id = auth.uid() and p.role in ('lgu_member', 'superadmin')))
      or (event_type = 'public' and exists (
            select 1 from profiles p where p.id = auth.uid() and p.role = 'superadmin'))
    )
  );

-- Group creation: LGU members and the superadmin only — "create a gc" is
-- an LGU-level permission; citizens can still join existing groups by
-- search/code, just not create new ones.
drop policy if exists "Users create their groups" on public.groups;
drop policy if exists "LGU members create groups" on public.groups;
create policy "LGU members create groups"
  on public.groups
  for insert
  with check (
    auth.uid() = created_by
    and exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('lgu_member', 'superadmin'))
  );

-- One-time seed: mark the app's single superadmin account by email. Only
-- takes effect once that email has actually signed up (via the app or the
-- LGU admin portal) and has a profiles row — re-run this block after that
-- if it doesn't seem to have taken effect yet. Needs the bypass flag like
-- the RPCs above, since guard_profile_role_columns otherwise resets any
-- UPDATE's role/lgu_request_status back to their old value — including a
-- plain SQL-editor UPDATE, not just app-side writes.
select set_config('app.bypass_role_guard', 'on', true);
update public.profiles set role = 'superadmin' where email = 'anime10315466@gmail.com';

-- ============================================================
-- Event editing (July 2026).
-- The event's creator, or an admin of the group it's posted to (for
-- Group events), can now fully edit it — title/location/description/
-- date(s)/time(s)/type/group, not just RSVP status. Also adds per-day
-- time-of-day overrides for multi-day events (see DailyOverride in
-- lib/event_store.dart) — e.g. day 1 all day, day 2 just 1-5 PM.
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.barangay_events add column if not exists daily_overrides jsonb not null default '[]'::jsonb;

-- Replaces the old "Authenticated update events" policy, which let ANY
-- signed-in user update ANY event row — harmless back when the only
-- update path was updateAttendanceStatus, but not once full content
-- editing existed. Creator can always edit their own; for a Group event,
-- any admin of that specific group can too (see [[project-event-sharing-model]]
-- for why "promote to admin" already existing was reused here rather than
-- inventing a separate edit-permission concept).
drop policy if exists "Authenticated update events" on public.barangay_events;
drop policy if exists "Creator or group admin can edit events" on public.barangay_events;
create policy "Creator or group admin can edit events"
  on public.barangay_events
  for update
  using (
    created_by_id = auth.uid()
    or (
      event_type = 'shared'
      and group_id is not null
      and exists (
        select 1 from group_members gm
        where gm.group_id = barangay_events.group_id
          and gm.user_id = auth.uid()
          and gm.role = 'admin'
      )
    )
  )
  with check (
    created_by_id = auth.uid()
    or (
      event_type = 'shared'
      and group_id is not null
      and exists (
        select 1 from group_members gm
        where gm.group_id = barangay_events.group_id
          and gm.user_id = auth.uid()
          and gm.role = 'admin'
      )
    )
  );

-- ============================================================
-- Language preference (July 2026).
-- Synced like theme_mode/ui_style (targeted UPDATE from the app, not a
-- security-definer RPC — this isn't security-sensitive like role/
-- lgu_request_status, so it doesn't need guard_profile_role_columns'
-- protection). 'en' (English) or 'fil' (Filipino) — see ThemeController's
-- locale handling in lib/theme_controller.dart.
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.profiles add column if not exists language text not null default 'en';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_language_check') then
    alter table public.profiles add constraint profiles_language_check
      check (language in ('en', 'fil'));
  end if;
end $$;

-- ============================================================
-- LGU-admin dashboard: full user list + role management (July 2026).
-- Broader than list_pending_lgu_applications/respond_to_lgu_application
-- (which only cover the apply -> approve/reject flow) — this lets the
-- superadmin browse every account and change ANY user's role directly.
-- Safe to re-run on an existing database.
-- ============================================================

-- Superadmin-only: every user, for the dashboard's "All Users" table.
create or replace function public.list_all_users()
returns table(
  user_id uuid, email text, display_name text, department text,
  phone_number text, role text, lgu_request_status text, created_at timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can list all users';
  end if;
  return query
    select p.id, p.email, p.display_name, p.department, p.phone_number,
           p.role, p.lgu_request_status, p.created_at
    from profiles p
    order by p.created_at desc;
end $$;

-- Superadmin-only: the groups a given user belongs to — fetched on demand
-- when the dashboard's "View" details row is expanded for that user, not
-- upfront for everyone in list_all_users().
create or replace function public.list_user_groups(p_user_id uuid)
returns table(group_id uuid, group_name text, member_role text, joined_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can view another user''s groups';
  end if;
  return query
    select g.id, g.name, gm.role, gm.joined_at
    from group_members gm
    join groups g on g.id = gm.group_id
    where gm.user_id = p_user_id
    order by gm.joined_at asc;
end $$;

-- Superadmin-only: set any user's role directly (citizen/lgu_member/
-- superadmin), independent of the apply/approve LGU flow. Two safeguards:
-- can't change your own role (locks you out of the dashboard with no way
-- back short of direct DB access) and can't demote the last remaining
-- superadmin (would leave zero accounts able to approve/manage anything).
create or replace function public.admin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare
  target_current_role text;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can change roles';
  end if;
  if p_role not in ('citizen', 'lgu_member', 'superadmin') then
    raise exception 'Invalid role: %', p_role;
  end if;
  if p_user_id = auth.uid() then
    raise exception 'You cannot change your own role';
  end if;

  select role into target_current_role from profiles where id = p_user_id;
  if target_current_role is null then
    raise exception 'User not found';
  end if;

  if target_current_role = 'superadmin' and p_role <> 'superadmin'
     and (select count(*) from profiles where role = 'superadmin') <= 1 then
    raise exception 'Cannot remove the last remaining superadmin';
  end if;

  perform set_config('app.bypass_role_guard', 'on', true);
  update profiles
    set role = p_role,
        lgu_request_status = case
          when p_role = 'lgu_member' then 'approved'
          when p_role = 'citizen' then null
          else lgu_request_status
        end
    where id = p_user_id;
end $$;

-- ============================================================
-- Group join policy: "requires approval" independent of "private"
-- (July 2026). Previously is_private did double duty — hidden from
-- search AND "needs approval to join" were the same flag. Now a group
-- can be any combination: public+open (old public default), public+
-- approval-gated (discoverable, but an admin must accept requests),
-- private+open (hidden, but anyone with the code joins instantly), or
-- private+approval-gated (old private default).
-- Safe to re-run on an existing database.
-- ============================================================

-- One-time backfill, guarded so re-running this file later (after an
-- admin has since used admin_set_group_requires_approval to pick their
-- own value) never clobbers that choice — it only runs the moment the
-- column is first added.
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'groups' and column_name = 'requires_approval'
  ) then
    alter table public.groups add column requires_approval boolean not null default false;
    update public.groups set requires_approval = true where is_private = true;
  end if;
end $$;

-- Join-by-code now branches on requires_approval instead of is_private.
create or replace function public.request_or_join_group(p_code text)
returns table(out_group_id uuid, out_group_name text, out_status text)
language plpgsql security definer set search_path = public as $$
declare target record; joiner record;
begin
  select id, name, requires_approval into target from groups where code = upper(trim(p_code));
  if not found then raise exception 'Invalid group code'; end if;

  if exists (select 1 from group_members gm where gm.group_id = target.id and gm.user_id = auth.uid()) then
    return query select target.id, target.name, 'already_member'::text;
    return;
  end if;

  if not target.requires_approval then
    select coalesce(display_name, email) as name, avatar_url into joiner from profiles where id = auth.uid();
    insert into group_members (group_id, user_id, role, display_name, avatar_url)
      values (target.id, auth.uid(), 'member', joiner.name, joiner.avatar_url)
      on conflict (group_id, user_id) do nothing;
    return query select target.id, target.name, 'joined'::text;
    return;
  end if;

  insert into group_join_requests (group_id, requester_id, status)
    values (target.id, auth.uid(), 'pending')
    on conflict (group_id, requester_id) do update set status = 'pending', created_at = now();
  return query select target.id, target.name, 'pending'::text;
end $$;

-- Search-result join (no code — the group's own id, since it's already
-- discoverable). Only meaningful for public groups; a private group must
-- still be joined via its code, which is the whole point of hiding it.
create or replace function public.request_or_join_group_by_id(p_group_id uuid)
returns table(out_group_id uuid, out_group_name text, out_status text)
language plpgsql security definer set search_path = public as $$
declare target record; joiner record;
begin
  select id, name, is_private, requires_approval into target from groups where id = p_group_id;
  if not found then raise exception 'Group not found'; end if;
  if target.is_private then
    raise exception 'This group is private — join it with its code instead';
  end if;

  if exists (select 1 from group_members gm where gm.group_id = target.id and gm.user_id = auth.uid()) then
    return query select target.id, target.name, 'already_member'::text;
    return;
  end if;

  if not target.requires_approval then
    select coalesce(display_name, email) as name, avatar_url into joiner from profiles where id = auth.uid();
    insert into group_members (group_id, user_id, role, display_name, avatar_url)
      values (target.id, auth.uid(), 'member', joiner.name, joiner.avatar_url)
      on conflict (group_id, user_id) do nothing;
    return query select target.id, target.name, 'joined'::text;
    return;
  end if;

  insert into group_join_requests (group_id, requester_id, status)
    values (target.id, auth.uid(), 'pending')
    on conflict (group_id, requester_id) do update set status = 'pending', created_at = now();
  return query select target.id, target.name, 'pending'::text;
end $$;

-- Any admin of the group (not just its creator/a superadmin) can change
-- this — it's an ordinary group setting, not a trust/verification signal.
create or replace function public.admin_set_group_requires_approval(p_group_id uuid, p_requires_approval boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from group_members where group_id = p_group_id and user_id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Only an admin of this group can change its join settings';
  end if;
  update groups set requires_approval = p_requires_approval where id = p_group_id;
end $$;

-- Tightens the group_members INSERT policy now that every join path
-- (open or approval-gated, public or private) goes through one of the
-- two RPCs above, or respond_to_join_request's accept step — all three
-- are security definer and so bypass this policy entirely. The only
-- direct client-side insert left is createGroup's own bootstrap row
-- (the new creator, inserting themselves as admin of the group they
-- just created). This closes a real gap the old, broader policy left
-- open: it only checked "is this group public, or mine" and never
-- pinned the `role` column, so any signed-in user could previously
-- insert themselves directly as 'admin' of any public group and use the
-- existing "Admins promote/remove members" policies to take it over.
drop policy if exists "Users join public groups or their own" on public.group_members;
drop policy if exists "Creator bootstraps their own admin row" on public.group_members;
create policy "Creator bootstraps their own admin row"
  on public.group_members
  for insert
  with check (
    auth.uid() = user_id
    and role = 'admin'
    and exists (select 1 from groups g where g.id = group_id and g.created_by = auth.uid())
  );

-- ============================================================
-- Display-size preference synced across devices (July 2026).
-- Previously local-only (SharedPreferences), by design, so a phone and a
-- kiosk signed into the same account could each keep their own size —
-- now synced like theme_mode/ui_style/language instead, so a kiosk device
-- (or a reinstall) doesn't need the size re-picked from scratch every
-- time. 'auto' | 'mobile' | 'tablet' | 'windows' — mirrors DisplayMode's
-- .name values client-side (lib/responsive_scale.dart).
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.profiles add column if not exists display_mode text not null default 'auto';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_display_mode_check') then
    alter table public.profiles add constraint profiles_display_mode_check
      check (display_mode in ('auto', 'mobile', 'tablet', 'windows'));
  end if;
end $$;

-- ============================================================
-- Kiosk mode (July 2026). A superadmin-designated account gets a
-- one-tap "Enable Kiosk Mode" affordance in the app — a stripped-down,
-- full-screen calendar + upcoming-events view meant for an unattended
-- public display (e.g. at the barangay hall), with no Add Event button
-- and no navigation menu. Purely an app-side UI mode: is_kiosk_account
-- doesn't grant or remove any permission, it only controls whether that
-- entry point shows up. See supabase/functions and docs/lgu-admin's All
-- Users table for how a superadmin flips it.
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.profiles add column if not exists is_kiosk_account boolean not null default false;

create or replace function public.admin_set_kiosk_account(p_user_id uuid, p_is_kiosk boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can designate a kiosk account';
  end if;
  update profiles set is_kiosk_account = p_is_kiosk where id = p_user_id;
end $$;

-- Widened to also return is_kiosk_account for the dashboard's All Users
-- table — return-shape change needs a drop first (create or replace
-- can't alter an existing function's output columns).
drop function if exists public.list_all_users();
create or replace function public.list_all_users()
returns table(
  user_id uuid, email text, display_name text, department text,
  phone_number text, role text, lgu_request_status text, created_at timestamptz,
  is_kiosk_account boolean
)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'superadmin') then
    raise exception 'Only a superadmin can list all users';
  end if;
  return query
    select p.id, p.email, p.display_name, p.department, p.phone_number,
           p.role, p.lgu_request_status, p.created_at, p.is_kiosk_account
    from profiles p
    order by p.created_at desc;
end $$;

-- ============================================================
-- Group verification badge + ownership transfer (July 2026).
-- Any lgu_member can name a public group anything, including something
-- official-sounding ("Barangay Health Office") — is_verified is a purely
-- informational badge (no permission changes) so citizens can tell a real
-- department's group apart from a same-named impostor. Ownership transfer
-- exists so a group isn't permanently stuck with an absentee owner after
-- staff turnover (only created_by can currently delete the group or
-- remove a fellow admin).
-- Safe to re-run on an existing database.
-- ============================================================

alter table public.groups add column if not exists is_verified boolean not null default false;

-- Superadmin-only: mark/unmark a group as verified/official.
create or replace function public.admin_set_group_verified(p_group_id uuid, p_verified boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can verify a group';
  end if;
  update groups set is_verified = p_verified where id = p_group_id;
end $$;

-- Hands a group's creator-only privileges to another of its members.
-- Callable by the group's CURRENT creator, or a superadmin as a fallback
-- for a group whose creator already left/was demoted and can't do this
-- themselves. The new owner must already be a member — they're promoted
-- to admin as part of the handoff, since owning a group without being
-- able to manage it wouldn't make sense.
create or replace function public.transfer_group_ownership(p_group_id uuid, p_new_owner_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  current_owner uuid;
  caller_is_superadmin boolean;
begin
  select created_by into current_owner from groups where id = p_group_id;
  if current_owner is null then
    raise exception 'Group not found';
  end if;

  select exists(select 1 from profiles where id = auth.uid() and role = 'superadmin')
    into caller_is_superadmin;

  if auth.uid() <> current_owner and not caller_is_superadmin then
    raise exception 'Only the group''s current owner (or a superadmin) can transfer ownership';
  end if;

  if p_new_owner_id = current_owner then
    raise exception 'That member is already the owner';
  end if;

  if not exists (
    select 1 from group_members where group_id = p_group_id and user_id = p_new_owner_id
  ) then
    raise exception 'The new owner must already be a member of this group';
  end if;

  update groups set created_by = p_new_owner_id where id = p_group_id;
  update group_members set role = 'admin' where group_id = p_group_id and user_id = p_new_owner_id;
end $$;

-- ============================================================
-- Event reminders (July 2026). A user picks 'off' | '1h' | '1d' in
-- Settings — synced across devices like theme_mode/ui_style/language/
-- display_mode. Delivery is push-based (Firebase), driven by a scheduled
-- Edge Function (supabase/functions/send-event-reminders) rather than a
-- database webhook, since "remind me before this starts" is a
-- time-based condition, not a row-change event.
--
-- Reminders can't ride the existing public-events/group-<id> FCM topics
-- (see push_notifications.dart) — those broadcast to every subscriber
-- regardless of that person's own reminder_preference, and a Personal
-- event has no group/topic to broadcast to at all. Instead each device
-- also subscribes to its own account's topic ('user-<uid>', see
-- push_notifications.dart's userTopic()), and the Edge Function sends
-- each qualifying (user, event) reminder individually to that topic.
--
-- One-time setup this SQL block genuinely can't do for you (Postgres has
-- no way to set its own secrets from inside a migration):
--   1. supabase functions deploy send-event-reminders --use-api --no-verify-jwt
--      The --no-verify-jwt is REQUIRED, not optional. This function is called
--      by pg_cron with 'Bearer <reminder_cron_secret>' — a random string, not
--      a JWT. Left verify_jwt on, Supabase's gateway rejects that with 401
--      before the function's own auth check (index.ts) ever runs, and every
--      reminder silently fails. Confirmed August 2026: the live deployment had
--      verify_jwt=true because this line was missing the flag, which is why no
--      reminder had ever been delivered. Verify after deploying with
--      `supabase functions list` — this slug must show "verify_jwt":false.
--   2. supabase secrets set "REMINDER_CRON_SECRET=<a random string>"
--      (reuses the same FCM_SERVICE_ACCOUNT_JSON_B64 secret already set
--      up for send-event-notification — no separate Firebase credential
--      needed)
--   3. Run this once in the SQL Editor, using the *same* random string as
--      step 2 (confirmed on hosted Supabase: `alter database ... set
--      app.foo = ...` is blocked with "permission denied to set
--      parameter", even for the postgres role — Vault is the actual
--      supported way to hand a cron job a secret):
--        select vault.create_secret('<the same random string from step 2>', 'reminder_cron_secret');
--      Only run this once — `name` is unique, so calling it again raises
--      a duplicate-key error. To rotate the value later, use
--      `select vault.update_secret(id, new_secret)` (look up id via
--      `select id from vault.decrypted_secrets where name = 'reminder_cron_secret'`)
--      instead of calling create_secret again.
--
-- IMPORTANT: found via code review (July 2026) that this cron job was
-- documented here as a manual step but NEVER ACTUALLY CREATED — nothing
-- in this repo or the live project was invoking send-event-reminders on
-- any schedule, so reminders have never been sent. The cron.schedule call
-- below fixes that; it's idempotent (cron.schedule with an existing job
-- name updates it in place) and safe to re-run.
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'send-event-reminders',
  '*/15 * * * *',
  $cron$
  select net.http_post(
    url := 'https://xuxnoydakqembrytdbyz.supabase.co/functions/v1/send-event-reminders',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets where name = 'reminder_cron_secret'
      )
    )
  );
  $cron$
);

alter table public.profiles add column if not exists reminder_preference text not null default 'off';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_reminder_preference_check') then
    alter table public.profiles add constraint profiles_reminder_preference_check
      check (reminder_preference in ('off', '1h', '1d'));
  end if;
end $$;

-- Makes delivery idempotent: the cron job's lookahead window is
-- deliberately wider than its own run interval (so a slow/delayed run
-- never skips an event), which means consecutive runs' windows overlap
-- and would otherwise re-notify the same person twice for the same
-- event. Recording what's already been sent — and having
-- list_due_event_reminders below exclude it — closes that gap. Not
-- exposed to the app/PostgREST at all: no select/insert policy means no
-- access under RLS for ordinary users; only the Edge Function's
-- service-role client ever touches this table.
create table if not exists public.event_reminders_sent (
  event_id text not null references public.barangay_events(id) on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  reminder_window text not null,
  sent_at timestamptz not null default now(),
  primary key (event_id, user_id, reminder_window)
);
alter table public.event_reminders_sent enable row level security;

-- Service-role only (see the table comment above) — revoked from every
-- ordinary Postgres role so it can't be called via the public REST API,
-- where it would otherwise leak every user's reminder_preference and
-- upcoming-event visibility to any authenticated caller.
create or replace function public.list_due_event_reminders(p_window text)
returns table(
  user_id uuid, event_id text, event_title text, event_start timestamptz,
  event_location text, event_type text, group_name text
)
language plpgsql security definer set search_path = public as $$
declare
  window_start timestamptz;
  window_end timestamptz;
begin
  -- `barangay_events.start_time` is stored the same "naive local wall-clock
  -- value, mislabeled as UTC" way the whole app already treats it (see
  -- BarangayEvent.startTime / event_store.dart — never .toUtc()'d before
  -- being written). Comparing it against plain now() would silently be off
  -- by the Philippines' UTC+8 offset — `now() at time zone 'Asia/Manila'`
  -- re-labels the current real moment using that exact same convention
  -- (a naive PHT wall-clock value, then reinterpreted as if it were UTC),
  -- so both sides of the comparison agree on what "the same convention"
  -- means, rather than introducing real timezone-awareness for the first
  -- time just in this one function.
  if p_window = '1h' then
    window_start := (now() at time zone 'Asia/Manila') + interval '50 minutes';
    window_end := (now() at time zone 'Asia/Manila') + interval '70 minutes';
  elsif p_window = '1d' then
    window_start := (now() at time zone 'Asia/Manila') + interval '23 hours';
    window_end := (now() at time zone 'Asia/Manila') + interval '25 hours';
  else
    raise exception 'Invalid window: %', p_window;
  end if;

  return query
    select p.id, e.id, e.title, e.start_time, e.location, e.event_type, e.group_name
    from barangay_events e
    join profiles p on p.reminder_preference = p_window
    where e.start_time between window_start and window_end
      and (
        e.event_type = 'public'
        or (e.event_type = 'personal' and e.created_by_id = p.id)
        or (e.event_type = 'shared' and e.group_id is not null and exists (
              select 1 from group_members gm where gm.group_id = e.group_id and gm.user_id = p.id))
      )
      and not exists (
        select 1 from event_reminders_sent ers
        where ers.event_id = e.id and ers.user_id = p.id and ers.reminder_window = p_window
      );
end $$;

revoke all on function public.list_due_event_reminders(text) from public, anon, authenticated;

-- ============================================================
-- App store reviews (July 2026) — backs docs/store/index.html, the
-- Play-Store-style hub listing eCalendar (and, as "Coming Soon" cards
-- with no data behind them yet, the rest of the eBongabong app family).
-- The store page is a plain static site with no sign-in, so this table
-- is intentionally readable AND insertable by anyone (`anon` role) —
-- same trust model already used by docs/lgu-admin/index.html talking to
-- Supabase directly with the public anon key. There is no update/delete
-- policy for anon at all, so a review, once posted, can't be edited or
-- removed by the person who left it (or anyone else) short of an admin
-- acting directly in the Supabase dashboard — deliberately simple for a
-- v1 with no accounts to tie edit-rights to.
--
-- Not linked to `profiles`/`auth.users` at all — reviewers are always
-- anonymous site visitors, not signed-in app users, so `reviewer_name`
-- is free-text the visitor optionally types in, not a real identity.
create table if not exists public.app_reviews (
  id uuid primary key default gen_random_uuid(),
  app_id text not null,
  rating smallint not null check (rating between 1 and 5),
  reviewer_name text,
  comment text,
  created_at timestamptz not null default now()
);
alter table public.app_reviews enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'app_reviews' and policyname = 'Anyone can read reviews') then
    create policy "Anyone can read reviews" on public.app_reviews for select using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'app_reviews' and policyname = 'Anyone can post a review') then
    create policy "Anyone can post a review" on public.app_reviews for insert with check (true);
  end if;
end $$;

-- ============================================================
-- Auto-delete empty groups (July 2026). A group that loses its last
-- member (via leaveGroup/removeMember, both plain client-side deletes
-- against group_members — no single RPC choke point to hang a
-- client-side "check count then delete" off) is orphaned: nobody left who
-- could ever open it, rename it, or clean it up. Delete it automatically
-- instead, the same way guard_profile_role_columns (above) uses a plain
-- trigger rather than relying on every call site to remember a follow-up
-- step. The pending-join-request guard matters: group_join_requests rows
-- are never deleted on their own (status just becomes accepted/declined),
-- and cascade from groups — without the guard, the last member leaving
-- while someone's request is still pending would silently destroy that
-- request instead of leaving it to be declined normally.
-- ============================================================

create or replace function public.delete_group_if_empty()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from group_members where group_id = old.group_id)
     and not exists (
       select 1 from group_join_requests
       where group_id = old.group_id and status = 'pending'
     )
  then
    delete from groups where id = old.group_id;
  end if;
  return old;
end $$;

drop trigger if exists delete_group_if_empty on public.group_members;
create trigger delete_group_if_empty
  after delete on public.group_members
  for each row execute function public.delete_group_if_empty();

-- ============================================================
-- Group filter (calendar) preference (July 2026). Which of a signed-in
-- member's groups show as "Shared" events on the Calendar tab, persisted
-- per-account like theme/language already are (see profiles.theme_mode
-- etc. above) — synced across devices instead of a device-local setting.
-- Kept as its own column (not folded into the existing theme/appearance
-- preferences) since filter taps happen far more often than appearance
-- changes and are conceptually unrelated to them.
-- ============================================================

alter table public.profiles
  add column if not exists calendar_group_filter_ids jsonb not null default '[]'::jsonb;

-- The Flutter client now also watches its own group_members rows in
-- realtime (to notice "I was just added to a group" and reopen the event
-- stream — see main.dart's _listenToGroupMemberships) — barangay_events
-- was the only table already in this publication (line ~57).
alter publication supabase_realtime add table public.group_members;

-- ============================================================
-- Kiosk exit passcode (July 2026). Exiting kiosk mode now needs a 4-digit
-- passcode (see _buildKioskScaffold's exit button in main.dart), not just
-- a tap — a bit of friction so a passerby at an unattended public kiosk
-- can't casually back out of it. The passcode itself is never sent to the
-- client outside these RPCs: verify_kiosk_passcode returns only a
-- boolean, never the stored value. A lightweight lockout (5 wrong
-- attempts -> 60s cooldown) guards the obvious "mash all 10,000
-- combinations" attack without building a full audit/rate-limit system —
-- proportional to what this actually protects (a shared-device exit
-- gate), not a financial system.
-- ============================================================

alter table public.profiles
  add column if not exists kiosk_passcode text not null default '0000',
  add column if not exists kiosk_passcode_fail_count int not null default 0,
  add column if not exists kiosk_passcode_locked_until timestamptz;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_kiosk_passcode_check') then
    alter table public.profiles add constraint profiles_kiosk_passcode_check
      check (kiosk_passcode ~ '^[0-9]{4}$');
  end if;
end $$;

-- Callable by the signed-in kiosk account itself to confirm the passcode
-- typed on the exit dialog. Returns false (not an exception) on a simple
-- mismatch so the caller can show an inline "wrong passcode" error rather
-- than catching a thrown error for an expected, ordinary case; still
-- raises for the locked-out case since that's more of an exceptional
-- state worth distinguishing in the UI.
create or replace function public.verify_kiosk_passcode(p_passcode text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  row_locked_until timestamptz;
  row_passcode text;
begin
  select kiosk_passcode, kiosk_passcode_locked_until
    into row_passcode, row_locked_until
    from profiles where id = auth.uid();

  if row_locked_until is not null and row_locked_until > now() then
    raise exception 'Too many wrong attempts. Try again in a moment.';
  end if;

  if row_passcode = p_passcode then
    update profiles
      set kiosk_passcode_fail_count = 0, kiosk_passcode_locked_until = null
      where id = auth.uid();
    return true;
  end if;

  update profiles set kiosk_passcode_fail_count = kiosk_passcode_fail_count + 1,
    kiosk_passcode_locked_until = case
      when kiosk_passcode_fail_count + 1 >= 5 then now() + interval '60 seconds'
      else kiosk_passcode_locked_until
    end
    where id = auth.uid();
  return false;
end $$;

-- Self-service passcode change from the Security page — verifies the
-- current passcode server-side first (unlike a real password change,
-- which trusts the already-active Supabase session; a 4-digit passcode
-- has no such session-based guarantee of its own).
create or replace function public.set_own_kiosk_passcode(p_current text, p_new text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_new !~ '^[0-9]{4}$' then
    raise exception 'Passcode must be exactly 4 digits';
  end if;
  if not exists (select 1 from profiles where id = auth.uid() and kiosk_passcode = p_current) then
    raise exception 'Current passcode is incorrect';
  end if;
  update profiles
    set kiosk_passcode = p_new, kiosk_passcode_fail_count = 0, kiosk_passcode_locked_until = null
    where id = auth.uid();
end $$;

-- Superadmin-only reset (LGU-admin portal), mirroring admin_set_kiosk_account's
-- exact structure above — e.g. a kiosk device's staff forgot the passcode.
create or replace function public.admin_reset_kiosk_passcode(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'superadmin') then
    raise exception 'Only a superadmin can reset a kiosk passcode';
  end if;
  update profiles
    set kiosk_passcode = '0000', kiosk_passcode_fail_count = 0, kiosk_passcode_locked_until = null
    where id = p_user_id;
end $$;

-- ============================================================
-- Event color labels (July 2026). An optional, user-chosen color for an
-- event card (like Google Calendar) — distinct from the existing
-- keyword-guessed tint (_getEventTint in main.dart) and the event-type
-- badge color (_eventTypeTint/_buildEventTypePill, Public/Group/Personal —
-- unrelated to this and left untouched). Stored as a short lookup key
-- (not a raw hex string) so the actual color values live in one place in
-- the Dart client (lib/event_colors.dart) and can be retuned later
-- without a data migration. Null means "no color chosen" — falls back to
-- the existing keyword-based tint for full backward compatibility with
-- every event created before this shipped.
-- ============================================================

alter table public.barangay_events add column if not exists color_key text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'barangay_events_color_key_check') then
    alter table public.barangay_events add constraint barangay_events_color_key_check
      check (color_key is null or color_key in
        ('tomato', 'tangerine', 'banana', 'basil', 'peacock', 'blueberry', 'grape', 'graphite'));
  end if;
end $$;

-- ============================================================
-- LGU locations (July 2026). A superadmin-curated list of common venues
-- ("Barangay Hall", "Covered Court", ...) offered as quick picks in Add
-- Event's Location field, so most events don't need free-text typing —
-- picking "Other" (or there being no locations yet at all) still falls
-- back to the existing plain text field. Anyone signed in can read the
-- list (they need it to see the dropdown); only a superadmin can add or
-- remove entries — managed from either the LGU admin web portal or the
-- in-app "Manage Locations" screen (Profile tab, superadmin-only), both
-- thin CRUD UIs over this same table.
-- ============================================================

create table if not exists public.lgu_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id)
);
alter table public.lgu_locations enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'lgu_locations' and policyname = 'Anyone signed in can read lgu_locations') then
    create policy "Anyone signed in can read lgu_locations" on public.lgu_locations
      for select using (auth.uid() is not null);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'lgu_locations' and policyname = 'Superadmin can manage lgu_locations') then
    create policy "Superadmin can manage lgu_locations" on public.lgu_locations
      for all using (
        exists (select 1 from profiles where id = auth.uid() and role = 'superadmin')
      ) with check (
        exists (select 1 from profiles where id = auth.uid() and role = 'superadmin')
      );
  end if;
end $$;

-- ============================================================
-- Event contact number (July 2026). An optional phone number shown
-- alongside "Posted By" on an event's detail page, with a Call button
-- (see lib/main.dart's _DetailInfoRow trailing slot). Pre-filled from the
-- poster's own profile.phone_number in Add Event, but stored per-event
-- (not read live off the profile) so it can be edited/cleared for a
-- specific event without touching the poster's actual profile.
-- ============================================================

alter table public.barangay_events add column if not exists contact_number text;

-- ============================================================
-- Event attachments (July 2026). Multiple files per event (pubmats,
-- photos, PDFs, etc.), replacing the old hasAttachment/attachmentType
-- columns on barangay_events, which the Flutter client never actually had
-- a real upload path for (every event ever created hard-coded
-- has_attachment = false) — see lib/event_store.dart's removal of those
-- two fields. has_attachment/attachment_type are left in place here
-- (dropping columns is a data-loss-risk step outside what this migration
-- should do unprompted) but are no longer read or written by the app;
-- drop them yourself later if you want.
--
-- Visibility piggybacks on barangay_events' own RLS: the exists()
-- subquery below runs under the calling role, so it only matches if that
-- role could already see the event itself (public/own-group/own-personal)
-- — no separate visibility rules to keep in sync as barangay_events'
-- own policies evolve.
-- ============================================================

insert into storage.buckets (id, name, public)
  values ('event-attachments', 'event-attachments', false)
  on conflict (id) do nothing;

create table if not exists public.event_attachments (
  id uuid primary key default gen_random_uuid(),
  event_id text not null references public.barangay_events(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.event_attachments enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'event_attachments' and policyname = 'read attachments for visible events') then
    create policy "read attachments for visible events" on public.event_attachments for select
      using (exists (select 1 from barangay_events be where be.id = event_attachments.event_id));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'event_attachments' and policyname = 'creator can add attachments') then
    create policy "creator can add attachments" on public.event_attachments for insert
      with check (exists (select 1 from barangay_events be where be.id = event_attachments.event_id and be.created_by_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'event_attachments' and policyname = 'creator can delete their attachments') then
    create policy "creator can delete their attachments" on public.event_attachments for delete
      using (exists (select 1 from barangay_events be where be.id = event_attachments.event_id and be.created_by_id = auth.uid()));
  end if;
end $$;

-- storage.objects policies for the bucket itself — path convention is
-- '<event_id>/<uuid>-<filename>'.
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'objects' and schemaname = 'storage' and policyname = 'read event attachment files') then
    create policy "read event attachment files" on storage.objects for select
      using (bucket_id = 'event-attachments' and exists (
        select 1 from public.event_attachments ea where ea.storage_path = storage.objects.name
      ));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'objects' and schemaname = 'storage' and policyname = 'upload event attachment files') then
    create policy "upload event attachment files" on storage.objects for insert
      with check (bucket_id = 'event-attachments' and auth.uid() is not null);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'objects' and schemaname = 'storage' and policyname = 'delete own event attachment files') then
    create policy "delete own event attachment files" on storage.objects for delete
      using (bucket_id = 'event-attachments' and owner = auth.uid());
  end if;
end $$;
