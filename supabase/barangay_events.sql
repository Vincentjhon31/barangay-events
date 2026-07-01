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
