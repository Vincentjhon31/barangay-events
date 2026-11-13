// Tests for the "Calendar API for other LGU systems" block at the end of
// supabase/barangay_events.sql. Runs the block (twice) in PGlite, a real
// Postgres in WebAssembly, on top of a minimal stand-in for the project's
// schema, then checks keys, scopes, times, paging, errors, and grants.
// Doesn't touch Supabase. Setup once, in any scratch folder:
//   npm install --ignore-scripts @electric-sql/pglite@0.3.7
// Run from the repository:
//   node supabase/tests/calendar_api.test.mjs <that folder>/node_modules/@electric-sql/pglite/dist/index.js supabase/barangay_events.sql
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const [pglitePath, sqlPath] = process.argv.slice(2);
const { PGlite } = await import(pathToFileURL(pglitePath).href);

const sql = readFileSync(sqlPath, 'utf8');
const start = sql.indexOf('-- Calendar API for other LGU systems');
if (start < 0) throw new Error('API block not found');
// Back up to the "-- ====" line above the title.
const blockStart = sql.lastIndexOf('-- ====', start);
const block = sql.slice(blockStart);

const db = new PGlite();
let failures = 0;
let passes = 0;
function check(name, cond, detail) {
  if (cond) { passes++; console.log('PASS ' + name); }
  else { failures++; console.log('FAIL ' + name + (detail !== undefined ? '  -> ' + JSON.stringify(detail) : '')); }
}
async function one(text, params) {
  const r = await db.query(text, params || []);
  return r.rows[0] ? Object.values(r.rows[0])[0] : undefined;
}
async function err(text, params) {
  try { await db.query(text, params || []); return null; }
  catch (e) { return { code: e.code, message: e.message, detail: e.detail, hint: e.hint }; }
}
async function as(uid) {
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [uid || '']);
}

const SUPER = '00000000-0000-4000-8000-000000000001';
const ADMIN = '00000000-0000-4000-8000-000000000002';
const CITIZEN = '00000000-0000-4000-8000-000000000003';
const SPORTS = '10000000-0000-4000-8000-000000000001';
const MAYOR = '10000000-0000-4000-8000-000000000002';
const OLD = '10000000-0000-4000-8000-000000000003';
const GROUP = '20000000-0000-4000-8000-000000000001';

// ---- Minimal stand-in for the Supabase project ----
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create schema auth;
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated;
  grant execute on function auth.uid() to anon, authenticated;
  -- Supabase gives anon/authenticated everything on new public objects;
  -- the block's revokes have to undo that.
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

  create table public.profiles (
    id uuid primary key, email text not null, display_name text, department text,
    role text not null default 'citizen'
  );
  create table public.groups (id uuid primary key, name text, is_private boolean not null default false);
  create table public.group_members (group_id uuid references public.groups(id), user_id uuid);
  -- Supabase Vault, minus the encryption.
  create schema vault;
  create table vault.secrets (id uuid primary key default gen_random_uuid(), name text unique, description text, secret text);
  create function vault.create_secret(new_secret text, new_name text, new_description text) returns uuid
    language sql as $$ insert into vault.secrets (name, description, secret) values (new_name, new_description, new_secret) returning id $$;
  create view vault.decrypted_secrets as select id, name, description, secret, secret as decrypted_secret from vault.secrets;
  create table public.event_calendars (
    id uuid primary key default gen_random_uuid(),
    name text not null, icon text not null default 'tag', color_key text,
    sort_order integer not null default 0, archived_at timestamptz,
    created_at timestamptz not null default now(), created_by uuid
  );
  create table public.barangay_events (
    id text primary key, title text not null, location text not null,
    start_time timestamptz not null, end_time timestamptz not null, day_key timestamptz not null,
    description text not null default '', has_attachment boolean not null default false,
    attachment_type text, attendance_status text,
    created_at timestamptz not null default now(),
    created_by_name text, created_by_department text, event_type text not null default 'public',
    created_by_id uuid, group_id uuid references public.groups(id), group_name text,
    daily_overrides jsonb not null default '[]'::jsonb, color_key text, contact_number text,
    created_by_avatar_url text, calendar_id uuid references public.event_calendars(id),
    calendar_name text, series_id text
  );
`);

await db.query(`insert into profiles (id, email, display_name, role) values
  ($1, 'super@example.test', 'Vincent', 'superadmin'),
  ($2, 'admin@example.test', 'Ana', 'admin'),
  ($3, 'citizen@example.test', 'Ben', 'citizen')`, [SUPER, ADMIN, CITIZEN]);
const GROUP2 = '20000000-0000-4000-8000-000000000002';
await db.query(`insert into groups (id, name) values ($1, 'MDRRMO staff'), ($2, 'Zumba club')`, [GROUP, GROUP2]);
await db.query(`insert into group_members values ($1, $2), ($1, $3)`, [GROUP, ADMIN, CITIZEN]);
await db.query(`insert into event_calendars (id, name, icon, color_key, sort_order, archived_at) values
  ($1, 'Sports', 'basketball', 'basil', 1, null),
  ($2, 'Mayor''s Office', 'briefcase', 'grape', 2, null),
  ($3, 'Old calendar', 'tag', null, 0, now())`, [SPORTS, MAYOR, OLD]);

// Times in the stored convention: Philippine wall clock labeled UTC.
const ev = (o) => db.query(
  `insert into barangay_events (id, title, location, start_time, end_time, day_key, description, created_at,
     created_by_name, created_by_department, created_by_id, event_type, group_id, group_name, daily_overrides,
     color_key, contact_number, calendar_id, calendar_name, series_id)
   values ($1, $2, $3, $4, $5, date_trunc('day', $4::timestamptz), $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)`,
  [o.id, o.title || o.id, o.location ?? 'Municipal Gym', o.start, o.end, o.description ?? '', o.created ?? '2026-11-01 09:30+00',
   o.by ?? 'Ana Cruz', o.office ?? 'MDRRMO', o.byId ?? ADMIN, o.type ?? 'public', o.group ?? null, o.group ? 'MDRRMO staff' : null,
   JSON.stringify(o.overrides ?? []), o.color ?? null, o.contact ?? null, o.cal ?? null, o.calName ?? null, o.series ?? null]);

await ev({ id: 'pub1', title: 'Foundation Day', start: '2026-11-07 10:00+00', end: '2026-11-07 12:00+00', contact: '0917 000 0000', description: 'Program at the plaza' });
await ev({ id: 'pub-allday', start: '2026-11-08 00:00+00', end: '2026-11-08 23:59+00', location: 'Other' });
await ev({ id: 'pub-multi', start: '2026-11-10 07:00+00', end: '2026-11-12 08:00+00',
  overrides: [{ day: '2026-11-11T00:00:00.000Z', start_minutes: 780, end_minutes: 1020 }] });
await ev({ id: 'pub-overnight', start: '2026-11-14 22:00+00', end: '2026-11-15 02:00+00' });
await ev({ id: 'cal-sports', type: 'calendar', cal: SPORTS, calName: 'Sports', start: '2026-11-09 15:00+00', end: '2026-11-09 17:00+00' });
await ev({ id: 'cal-mayor', type: 'calendar', cal: MAYOR, calName: "Mayor's Office", color: 'tomato', start: '2026-11-09 08:00+00', end: '2026-11-09 09:00+00' });
await ev({ id: 'cal-old', type: 'calendar', cal: OLD, calName: 'Old calendar', start: '2026-11-20 08:00+00', end: '2026-11-20 09:00+00' });
await ev({ id: 'grp1', type: 'shared', group: GROUP, start: '2026-11-07 09:00+00', end: '2026-11-07 10:00+00' });
await ev({ id: 'grp2', type: 'shared', group: GROUP2, start: '2026-11-07 15:00+00', end: '2026-11-07 16:00+00' });
await ev({ id: 'pers1', type: 'personal', byId: CITIZEN, start: '2026-11-07 13:00+00', end: '2026-11-07 14:00+00' });
await ev({ id: 'pub-past', start: '2026-10-01 10:00+00', end: '2026-10-01 11:00+00' });
await ev({ id: 'pub-edge-in', start: '2026-10-31 23:00+00', end: '2026-11-01 01:00+00' });
await ev({ id: 'pub-edge-out', start: '2026-12-01 00:00+00', end: '2026-12-01 01:00+00' });
await ev({ id: 's1', series: 's1', start: '2026-11-21 08:00+00', end: '2026-11-21 10:00+00' });
await ev({ id: 's2', series: 's1', start: '2026-11-22 08:00+00', end: '2026-11-22 10:00+00' });

// ---- Run the block, twice (it must be safe to re-run) ----
await db.exec(block);
await db.exec(block);
check('block runs twice without errors', true);

// ---- Key management (portal) ----
await as(CITIZEN);
let e = await err('select admin_create_api_key($1, true, null)', ['x']);
check('a citizen cannot make keys', e && /superadmin/.test(e.message), e);
await as(ADMIN);
e = await err('select admin_create_api_key($1, true, null)', ['x']);
check('an admin cannot make keys', e && /superadmin/.test(e.message), e);
e = await err('select admin_list_api_keys()');
check('an admin cannot list keys', e && /superadmin/.test(e.message), e);

await as(SUPER);
const k1 = await one('select admin_create_api_key($1, true, null)', ['  LGU intranet website  ']);
check('superadmin makes a key: ecal_ + 64 hex', /^ecal_[0-9a-f]{64}$/.test(k1.key), k1);
check('result has the 13-character prefix', k1.key_prefix === k1.key.slice(0, 13), k1);
const row1 = (await db.query('select * from api_keys where id = $1', [k1.id])).rows[0];
check('name is trimmed', row1.name === 'LGU intranet website', row1.name);
check('only the hash is stored', row1.key_hash === (await one("select encode(sha256(convert_to($1, 'UTF8')), 'hex')", [k1.key]))
  && !JSON.stringify(row1).includes(k1.key.slice(5)), row1);
check('all calendars = null', row1.calendar_ids === null, row1.calendar_ids);
const k1b = await one('select admin_create_api_key($1, true, null)', ['Second']);
check('two keys differ', k1b.key !== k1.key);

e = await err('select admin_create_api_key($1, true, null)', ['   ']);
check('a blank name is refused', e && /name/.test(e.message), e);
e = await err('select admin_create_api_key($1, true, null)', ['x'.repeat(81)]);
check('an 81-character name is refused', e && /80/.test(e.message), e);
e = await err("select admin_create_api_key($1, false, '{}'::uuid[])", ['Nothing']);
check('a key that reads nothing is refused', e && /at least one/.test(e.message), e);
e = await err('select admin_create_api_key($1, false, $2::uuid[])', ['Ghost', '{' + GROUP + '}']);
check('a calendar that does not exist is refused', e && /no longer exists/.test(e.message), e);
const k2 = await one('select admin_create_api_key($1, false, $2::uuid[])', ['Sports site', `{${SPORTS},${SPORTS}}`]);
const row2 = (await db.query('select calendar_ids from api_keys where id = $1', [k2.id])).rows[0];
check('chosen calendars are de-duplicated', JSON.stringify(row2.calendar_ids) === JSON.stringify([SPORTS]), row2);

const list = await one('select admin_list_api_keys()');
check('the key is kept in Vault', (await one('select count(*)::int from vault.secrets where secret = $1', [k1.key])) === 1);
check('superadmin can copy the key again', (await one('select admin_reveal_api_key($1)', [k1.id])) === k1.key);
const kOld = (await db.query(`insert into api_keys (name, key_prefix, key_hash) values ('Before copying', 'ecal_0000000', 'h0') returning id`)).rows[0].id;
check('a key made before keys were kept has no copy', (await one('select admin_reveal_api_key($1)', [kOld])) === null);
await db.query('delete from api_keys where id = $1', [kOld]);

// Groups
const groups = await one('select admin_list_groups()');
check('superadmin lists groups with member counts', JSON.stringify(groups.map((g) => [g.name, g.members])) === '[["MDRRMO staff",2],["Zumba club",0]]', groups);
e = await err("select admin_create_api_key($1, false, '{}'::uuid[], $2::uuid[])", ['Ghost group', '{' + SPORTS + '}']);
check('a group that does not exist is refused', e && /groups no longer exists/.test(e.message), e);
const kg = await one("select admin_create_api_key($1, false, '{}'::uuid[], $2::uuid[])", ['MDRRMO site', `{${GROUP},${GROUP}}`]);
check('a groups-only key is allowed, groups de-duplicated',
  JSON.stringify(await one('select group_ids from api_keys where id = $1', [kg.id])) === JSON.stringify([GROUP]));

await as(ADMIN);
e = await err('select admin_reveal_api_key($1)', [k1.id]);
check('an admin cannot copy a key', e && /superadmin/.test(e.message), e);
e = await err('select admin_list_groups()');
check('an admin cannot list all groups', e && /superadmin/.test(e.message), e);
await as(SUPER);

check('superadmin lists keys without hashes or keys', list.length === 3 && list.every((k) => !('key_hash' in k) && !('key' in k)), list);
check('list shows who made it', list[0].created_by_name === 'Vincent', list[0]);
check('list says the key can be copied', list.every((k) => k.can_copy === true && Array.isArray(k.group_ids)), list);

// ---- Reading events, the way api/events.php calls it (as anon) ----
await as(null);
await db.exec('set role anon');
let k1Served = 0;  // successful requests made with k1 (errors aren't counted)
const listEv = async (key, opts = {}) => { const r = await listEvRaw(key, opts); if (key === k1.key) k1Served++; return r; };
const listEvRaw = (key, opts = {}) => one(
  'select api_list_events(p_key => $1, p_from => $2, p_to => $3, p_type => $4, p_calendar_id => $5, p_event_id => $6, p_limit => $7, p_offset => $8)',
  [key, opts.from ?? null, opts.to ?? null, opts.type ?? null, opts.calendar ?? null, opts.id ?? null, opts.limit ?? null, opts.offset ?? null]);
const listErr = (key, opts = {}) => err(
  'select api_list_events(p_key => $1, p_from => $2, p_to => $3, p_type => $4, p_calendar_id => $5, p_event_id => $6, p_limit => $7, p_offset => $8)',
  [key, opts.from ?? null, opts.to ?? null, opts.type ?? null, opts.calendar ?? null, opts.id ?? null, opts.limit ?? null, opts.offset ?? null]);

const nov = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30' });
const ids = nov.events.map((x) => x.id);
check('November: public + calendar events in start order',
  JSON.stringify(ids) === JSON.stringify(['pub-edge-in', 'pub1', 'pub-allday', 'cal-mayor', 'cal-sports', 'pub-multi', 'pub-overnight', 'cal-old', 's1', 's2']), ids);
check('no Group events unless ticked, never Personal', !ids.includes('grp1') && !ids.includes('grp2') && !ids.includes('pers1'));
check('range ends on "to" (Dec 1 event excluded) and past events excluded', !ids.includes('pub-edge-out') && !ids.includes('pub-past'));
check('summary fields', nov.from === '2026-11-01' && nov.to === '2026-11-30' && nov.count === 10 && nov.has_more === false && nov.limit === 500 && nov.offset === 0, nov);

const byId = Object.fromEntries(nov.events.map((x) => [x.id, x]));
const p1 = byId.pub1;
check('times are real ISO 8601 with +08:00', p1.start === '2026-11-07T10:00:00+08:00' && p1.end === '2026-11-07T12:00:00+08:00', p1);
check('a one-day event has one day', p1.days.length === 1 && p1.days[0].date === '2026-11-07'
  && p1.days[0].start === p1.start && p1.days[0].end === p1.end && p1.days[0].all_day === false, p1.days);
check('event fields', p1.title === 'Foundation Day' && p1.location === 'Municipal Gym' && p1.type === 'public'
  && p1.calendar === null && p1.color === null && p1.contact_number === '0917 000 0000' && p1.description === 'Program at the plaza'
  && p1.posted_by.name === 'Ana Cruz' && p1.posted_by.office === 'MDRRMO' && p1.posted_at === '2026-11-01T09:30:00+08:00'
  && p1.series_id === null && p1.all_day === false, p1);
check('fields come out in a readable order', JSON.stringify(Object.keys(p1)) === JSON.stringify(['id', 'title', 'description', 'location',
  'start', 'end', 'all_day', 'days', 'type', 'calendar', 'group', 'color', 'contact_number', 'posted_by', 'posted_at', 'series_id']), Object.keys(p1));
check('summary fields come out in order', JSON.stringify(Object.keys(nov)) === JSON.stringify(['from', 'to', 'count', 'offset', 'limit', 'has_more', 'events']), Object.keys(nov));
check('no internal fields leak', !('created_by_id' in p1) && !('group_id' in p1) && !('daily_overrides' in p1) && !('created_by_avatar_url' in p1), Object.keys(p1));

const ad = byId['pub-allday'];
check('all-day event', ad.all_day === true && ad.location === null && ad.days.length === 1 && ad.days[0].all_day === true
  && ad.end === '2026-11-08T23:59:00+08:00', ad);

const mu = byId['pub-multi'];
check('multi-day: one entry per day, daily window + per-day hours',
  JSON.stringify(mu.days) === JSON.stringify([
    { date: '2026-11-10', start: '2026-11-10T07:00:00+08:00', end: '2026-11-10T08:00:00+08:00', all_day: false },
    { date: '2026-11-11', start: '2026-11-11T13:00:00+08:00', end: '2026-11-11T17:00:00+08:00', all_day: false },
    { date: '2026-11-12', start: '2026-11-12T07:00:00+08:00', end: '2026-11-12T08:00:00+08:00', all_day: false },
  ]) && mu.all_day === false, mu.days);

const on = byId['pub-overnight'];
check('overnight (end time before start time): one continuous stretch',
  JSON.stringify(on.days) === JSON.stringify([
    { date: '2026-11-14', start: '2026-11-14T22:00:00+08:00', end: '2026-11-14T23:59:00+08:00', all_day: false },
    { date: '2026-11-15', start: '2026-11-15T00:00:00+08:00', end: '2026-11-15T02:00:00+08:00', all_day: false },
  ]), on.days);

const sp = byId['cal-sports'];
check('calendar event: calendar + the calendar\'s color', sp.type === 'calendar' && sp.calendar.id === SPORTS
  && sp.calendar.name === 'Sports' && sp.color === '#2FA36B', sp);
check('own color wins over the calendar\'s', byId['cal-mayor'].color === '#E85D50', byId['cal-mayor']);
check('archived calendar\'s events still come through', ids.includes('cal-old'));
check('dates of one event share series_id', byId.s1.series_id === 's1' && byId.s2.series_id === 's1');

const edge = byId['pub-edge-in'];
check('an event that started before "from" but runs into it is included', edge.start === '2026-10-31T23:00:00+08:00', edge);

// Filters and scope
const onlyCal = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30', type: 'calendar' });
check('type=calendar', onlyCal.events.every((x) => x.type === 'calendar') && onlyCal.count === 3, onlyCal.events.map((x) => x.id));
const onlyPub = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30', type: 'public' });
check('type=public', onlyPub.events.every((x) => x.type === 'public') && onlyPub.count === 7, onlyPub.events.map((x) => x.id));
const mayor = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30', calendar: MAYOR });
check('one calendar', JSON.stringify(mayor.events.map((x) => x.id)) === '["cal-mayor"]', mayor.events.map((x) => x.id));
const grpOnly = await listEv(kg.key, { from: '2026-11-01', to: '2026-11-30' });
check('a key reads only its ticked group', JSON.stringify(grpOnly.events.map((x) => x.id)) === '["grp1"]', grpOnly.events.map((x) => x.id));
const g1 = grpOnly.events[0];
check('group event: type "group" + the group', g1.type === 'group' && g1.group.id === GROUP && g1.group.name === 'MDRRMO staff' && g1.calendar === null, g1);
check('type=group filter', (await listEv(kg.key, { from: '2026-11-01', to: '2026-11-30', type: 'group' })).count === 1);
check('non-group events have group null', p1.group === null);
check('one event of a ticked group by id', (await listEv(kg.key, { id: 'grp1' })).event.id === 'grp1');
e = await listErr(kg.key, { id: 'grp2' });
check('an event of an unticked group is not found', e && e.code === 'PT404', e);
const gcals = await one('select api_list_calendars($1)', [kg.key]);
check("calendars lists the key's groups", gcals.public_events === false && gcals.calendars.length === 0
  && JSON.stringify(gcals.groups) === JSON.stringify([{ id: GROUP, name: 'MDRRMO staff' }]), gcals);
const sportsOnly = await listEv(k2.key, { from: '2026-11-01', to: '2026-11-30' });
check('a Sports-only key sees only Sports', JSON.stringify(sportsOnly.events.map((x) => x.id)) === '["cal-sports"]', sportsOnly.events.map((x) => x.id));

// One event
const single = await listEv(k1.key, { id: 'pub1' });
check('one event by id', single.event && single.event.id === 'pub1' && single.event.start === '2026-11-07T10:00:00+08:00', single);
for (const hidden of ['grp1', 'pers1', 'missing']) {
  e = await listErr(k1.key, { id: hidden });
  check(`event ${hidden} by id is "not found" (404)`, e && e.code === 'PT404' && e.message === 'not_found', e);
}
e = await listErr(k2.key, { id: 'pub1' });
check('a key can\'t fetch an event outside its scope by id', e && e.code === 'PT404', e);

// Paging
const pg1 = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30', limit: 4 });
const pg2 = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30', limit: 4, offset: 4 });
const pg3 = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30', limit: 4, offset: 8 });
check('paging walks through every event once',
  JSON.stringify([...pg1.events, ...pg2.events, ...pg3.events].map((x) => x.id)) === JSON.stringify(ids)
  && pg1.has_more && pg2.has_more && !pg3.has_more && pg1.count === 4 && pg3.count === 2, [pg1.has_more, pg2.has_more, pg3.has_more]);

// Defaults
const def = await listEv(k1.key, {});
const today = await one("select to_char((now() at time zone 'Asia/Manila')::date::timestamp, 'YYYY-MM-DD')");
const plus30 = await one("select to_char(((now() at time zone 'Asia/Manila')::date + 30)::timestamp, 'YYYY-MM-DD')");
check('default range: today (Manila) to 30 days ahead', def.from === today && def.to === plus30, [def.from, def.to, today]);
const onlyFrom = await listEv(k1.key, { from: '2026-11-10' });
check('"to" defaults to "from" + 30', onlyFrom.to === '2026-12-10', onlyFrom.to);

// Bad parameters
for (const [label, opts, re] of [
  ['"to" before "from"', { from: '2026-11-30', to: '2026-11-01' }, /before/],
  ['more than 366 days', { from: '2026-01-01', to: '2027-01-03' }, /366/],
  ['type=shared', { type: 'shared' }, /type/],
  ['type=personal', { type: 'personal' }, /type/],
  ['limit 0', { limit: 0 }, /limit/],
  ['limit 1001', { limit: 1001 }, /limit/],
  ['offset -1', { offset: -1 }, /offset/],
]) {
  e = await listErr(k1.key, opts);
  check(`bad parameter: ${label} -> 400`, e && e.code === 'PT400' && e.message === 'invalid_parameter' && re.test(e.detail || ''), e);
}
const r366 = await listEv(k1.key, { from: '2026-01-01', to: '2027-01-02' });
check('exactly 366 days is allowed', r366.to === '2027-01-02');

// Bad keys
for (const [label, key] of [
  ['no key', null], ['junk', 'hello'], ['wrong prefix', 'xcal_' + 'a'.repeat(64)],
  ['upper-case hex', k1.key.toUpperCase().replace('ECAL_', 'ecal_')], ['unknown key', 'ecal_' + 'a'.repeat(64)],
  ['key with a space', ' ' + k1.key],
]) {
  e = await listErr(key, { from: '2026-11-01', to: '2026-11-30' });
  check(`bad key (${label}) -> 401`, e && e.code === 'PT401' && e.message === 'invalid_api_key', e);
}

// Calendars
const cals = await one('select api_list_calendars($1)', [k1.key]);
k1Served++;
check('calendars: what the key can read, archived last',
  cals.public_events === true && JSON.stringify(cals.calendars.map((c) => [c.name, c.archived, c.color, c.icon])) === JSON.stringify([
    ['Sports', false, '#2FA36B', 'basketball'], ["Mayor's Office", false, '#9B59B6', 'briefcase'], ['Old calendar', true, null, 'tag']]), cals);
const cals2 = await one('select api_list_calendars($1)', [k2.key]);
check('a Sports-only key lists only Sports', cals2.public_events === false && cals2.calendars.length === 1 && cals2.calendars[0].id === SPORTS, cals2);

// Locked down for anon
for (const [label, q] of [
  ['read api_keys', 'select * from api_keys'],
  ['call api_key_use', "select api_key_use('ecal_" + 'a'.repeat(64) + "')"],
  ['call api_event_json', "select api_event_json('{}'::jsonb, null)"],
  ['call admin_list_api_keys', 'select admin_list_api_keys()'],
  ['call admin_create_api_key', 'select admin_create_api_key(\'x\', true, null)'],
  ['read barangay_events through the key check helper', 'select api_key_can_read(null::api_keys, \'public\', null, null)'],
  ['copy a key', `select admin_reveal_api_key('${GROUP}')`],
  ['list all groups', 'select admin_list_groups()'],
  ['read the kept keys', 'select * from vault.secrets'],
]) {
  e = await err(q);
  check(`anon cannot ${label}`, e && e.code === '42501', e);
}
await db.exec('reset role');

// Signed-in users (authenticated) may also call the read API, nothing more.
await db.exec('set role authenticated');
await as(CITIZEN);
const asUser = await listEv(k1.key, { from: '2026-11-01', to: '2026-11-30' });
check('authenticated callers get the same result', asUser.count === 10);
e = await err('select * from api_keys');
check('authenticated cannot read api_keys', e && e.code === '42501', e);
await db.exec('reset role');

// ---- Usage counting and the rate limit ----
const before = (await db.query('select request_count, last_used_at from api_keys where id = $1', [k1.id])).rows[0];
check('successful requests are counted and last use is recorded', Number(before.request_count) === k1Served && before.last_used_at !== null, [before, k1Served]);
const unused = (await db.query('select request_count, last_used_at from api_keys where id = $1', [k1b.id])).rows[0];
check('an unused key stays at 0', Number(unused.request_count) === 0 && unused.last_used_at === null, unused);

await db.query("update api_keys set rate_window_start = now() - interval '10 seconds', rate_window_count = 300 where id = $1", [k1.id]);
await db.exec('set role anon');
e = await listErr(k1.key, {});
check('request 301 in a minute -> 429 with seconds to wait', e && e.code === 'PT429' && e.message === 'rate_limited'
  && Number(e.hint) >= 45 && Number(e.hint) <= 51, e);
await db.exec('reset role');
const limited = (await db.query('select rate_window_count, request_count from api_keys where id = $1', [k1.id])).rows[0];
check('a refused request isn\'t counted', limited.rate_window_count === 300 && Number(limited.request_count) === Number(before.request_count), limited);
await db.query("update api_keys set rate_window_start = now() - interval '61 seconds' where id = $1", [k1.id]);
await db.exec('set role anon');
const again = await listEv(k1.key, {});
await db.exec('reset role');
const reset = (await db.query('select rate_window_count from api_keys where id = $1', [k1.id])).rows[0];
check('a new minute starts a new count', again && reset.rate_window_count === 1, reset);

// ---- Changing, revoking, deleting ----
await as(SUPER);
await db.query('select admin_update_api_key($1, $2, true, $3::uuid[])', [k2.id, 'Sports + public', `{${SPORTS}}`]);
await db.exec('set role anon');
const k2now = await listEv(k2.key, { from: '2026-11-01', to: '2026-11-30' });
await db.exec('reset role');
check('changing what a key reads applies right away', k2now.count === 8 && k2now.events.some((x) => x.id === 'pub1')
  && !k2now.events.some((x) => x.id === 'cal-mayor'), k2now.events.map((x) => x.id));
e = await err('select admin_update_api_key($1, $2, true, null)', ['00000000-0000-4000-8000-00000000dead', 'x']);
check('updating a key that doesn\'t exist says so', e && /no longer exists/.test(e.message), e);

await db.query('select admin_revoke_api_key($1)', [k1.id]);
check('revoking drops the kept copy', (await one('select count(*)::int from vault.secrets where secret = $1', [k1.key])) === 0
  && (await one('select admin_reveal_api_key($1)', [k1.id])) === null);
await db.exec('set role anon');
e = await listErr(k1.key, {});
check('a revoked key stops working', e && e.code === 'PT401', e);
e = await err('select api_list_calendars($1)', [k1.key]);
check('…for calendars too', e && e.code === 'PT401', e);
await db.exec('reset role');
const revokedAt = await one('select revoked_at from api_keys where id = $1', [k1.id]);
await db.query('select admin_revoke_api_key($1)', [k1.id]);
check('revoking twice keeps the first time', (await one('select revoked_at from api_keys where id = $1', [k1.id])).getTime() === revokedAt.getTime());
const list2 = await one('select admin_list_api_keys()');
check('revoked keys are listed last', list2[list2.length - 1].id === k1.id && list2[list2.length - 1].revoked_at !== null, list2.map((k) => k.name));
await db.query('select admin_delete_api_key($1)', [k1.id]);
check('delete removes it', (await one('select count(*)::int from api_keys where id = $1', [k1.id])) === 0);
await db.query('select admin_delete_api_key($1)', [kg.id]);
check('delete removes the kept copy too', (await one('select count(*)::int from vault.secrets where secret = $1', [kg.key])) === 0);

// Re-running the block keeps the keys
await db.exec(block);
check('re-running the block keeps existing keys', (await one('select count(*)::int from api_keys')) === 2);
await db.exec('set role anon');
const stillWorks = await listEv(k2.key, { from: '2026-11-01', to: '2026-11-30' });
await db.exec('reset role');
check('…and they still work', stillWorks.count === 8);

console.log(`\n${passes} passed, ${failures} failed`);
process.exit(failures ? 1 : 0);
