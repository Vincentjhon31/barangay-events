create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text not null unique,
  display_name text,
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
  created_at timestamptz not null default now()
);

alter table public.barangay_events enable row level security;

create policy "Public read access to barangay events"
  on public.barangay_events
  for select
  using (true);

create policy "Public insert access to barangay events"
  on public.barangay_events
  for insert
  with check (true);

create policy "Public update access to barangay events"
  on public.barangay_events
  for update
  using (true)
  with check (true);

alter publication supabase_realtime add table public.barangay_events;
