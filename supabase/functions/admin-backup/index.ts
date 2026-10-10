// Supabase Edge Function: the server side of the superadmin's Backups page
// in the LGU-admin portal (docs/lgu-admin/index.html). The portal builds
// the backup ZIP and drives restores itself; this function does only the
// parts that need the service role key:
//
//   { action: "export" }
//     Every row of every app table (profiles, events, groups, members,
//     join requests, chat, attachments, calendars and their handlers,
//     locations, settings,
//     reviews, reminder log), the login accounts WITHOUT passwords (id,
//     email, created/confirmed dates — restored accounts use "Forgot
//     password"), and short-lived signed download links for every event
//     attachment file. Row-level security would hide most of this from a
//     normal session (other people's profiles and personal events), which
//     is why it's done here.
//
//   { action: "restore-users", users: [{ id, email, ... }] }
//     Recreates any login account that doesn't exist anymore, with the
//     SAME id (so every profile/event/group reference still lines up) and
//     a random password, already email-confirmed. Existing accounts are
//     left alone. Needed before profiles can be restored (profiles.id
//     references auth.users).
//
//   { action: "signed-upload", paths: ["<event_id>/<file>", ...] }
//     Signed upload links (overwrite allowed) so the portal can put
//     attachment files back into the event-attachments bucket.
//
// Table rows themselves are restored by the admin_restore_table SQL
// function (called by the portal with the superadmin's own session), not
// here — see the "Database monitoring + backup & restore" block in
// supabase/barangay_events.sql.
//
// Deployed with the DEFAULT jwt verification on, like the other admin-*
// functions (it's called from a signed-in browser session):
//   supabase functions deploy admin-backup --use-api

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: BodyInit | null, init?: ResponseInit) {
  return new Response(body, {
    ...init,
    headers: { ...corsHeaders, ...(init?.headers ?? {}) },
  });
}

function json(data: unknown, status = 200) {
  return response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Bump when the backup layout changes in a way restore has to know about.
const BACKUP_FORMAT_VERSION = 1;

// Every app table, parents before children — the order a restore must
// follow. A table missing on this database (e.g. before the calendars
// block was run) is skipped, not an error.
const TABLES = [
  "profiles",
  "app_settings",
  "event_calendars",
  "event_calendar_handlers",
  "lgu_locations",
  "groups",
  "group_members",
  "group_join_requests",
  "barangay_events",
  "event_attachments",
  "event_comments",
  "event_reminders_sent",
  "app_reviews",
];

const ATTACHMENTS_BUCKET = "event-attachments";
const PAGE_SIZE = 1000;
const SIGNED_URL_SECONDS = 60 * 60;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

async function readTable(admin: SupabaseClient, table: string) {
  const rows: Record<string, unknown>[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await admin.from(table).select("*").range(from, from + PAGE_SIZE - 1);
    if (error) {
      // 42P01 = undefined table; PGRST205 = table not in the schema cache.
      if (error.code === "42P01" || error.code === "PGRST205") return null;
      throw new Error(`${table}: ${error.message}`);
    }
    rows.push(...(data ?? []));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

async function readAuthUsers(admin: SupabaseClient) {
  const users: Record<string, unknown>[] = [];
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: PAGE_SIZE });
    if (error) throw new Error(`auth users: ${error.message}`);
    for (const u of data.users) {
      users.push({
        id: u.id,
        email: u.email ?? null,
        phone: u.phone ?? null,
        created_at: u.created_at,
        email_confirmed_at: u.email_confirmed_at ?? null,
        last_sign_in_at: u.last_sign_in_at ?? null,
        user_metadata: u.user_metadata ?? {},
      });
    }
    if (data.users.length < PAGE_SIZE) return users;
  }
}

async function exportAll(admin: SupabaseClient) {
  const tables: Record<string, Record<string, unknown>[]> = {};
  for (const table of TABLES) {
    const rows = await readTable(admin, table);
    if (rows !== null) tables[table] = rows;
  }

  // Files are found through their event_attachments rows (the bucket's
  // own listing is per-folder only).
  const paths = (tables["event_attachments"] ?? [])
    .map((row) => row["storage_path"])
    .filter((p): p is string => typeof p === "string" && p.length > 0);
  const files: { path: string; url: string | null }[] = [];
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    const { data, error } = await admin.storage.from(ATTACHMENTS_BUCKET).createSignedUrls(batch, SIGNED_URL_SECONDS);
    if (error) throw new Error(`attachment links: ${error.message}`);
    for (const item of data ?? []) {
      files.push({ path: item.path ?? "", url: item.signedUrl ?? null });
    }
  }

  return {
    format: "ebongabong-calendar-backup",
    version: BACKUP_FORMAT_VERSION,
    created_at: new Date().toISOString(),
    source: supabaseUrl,
    table_order: TABLES.filter((t) => t in tables),
    tables,
    auth_users: await readAuthUsers(admin),
    files: { bucket: ATTACHMENTS_BUCKET, items: files },
  };
}

function randomPassword() {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes));
}

async function restoreUsers(admin: SupabaseClient, users: unknown[]) {
  let created = 0;
  let existing = 0;
  const failed: { id: string; email: string | null; error: string }[] = [];
  for (const raw of users) {
    if (typeof raw !== "object" || raw === null) continue;
    const u = raw as Record<string, unknown>;
    const id = typeof u.id === "string" ? u.id : null;
    const email = typeof u.email === "string" ? u.email : null;
    if (!id) continue;

    const { data: found } = await admin.auth.admin.getUserById(id);
    if (found?.user) {
      existing++;
      continue;
    }
    if (!email) {
      failed.push({ id, email, error: "No email in the backup" });
      continue;
    }
    const { error } = await admin.auth.admin.createUser({
      id,
      email,
      password: randomPassword(),
      email_confirm: true,
      user_metadata: (u.user_metadata as Record<string, unknown>) ?? {},
    });
    if (error) failed.push({ id, email, error: error.message });
    else created++;
  }
  return { created, existing, failed };
}

async function signedUploads(admin: SupabaseClient, paths: unknown[]) {
  const items: { path: string; token: string | null; error: string | null }[] = [];
  for (const p of paths) {
    if (typeof p !== "string" || !p) continue;
    const { data, error } = await admin.storage.from(ATTACHMENTS_BUCKET).createSignedUploadUrl(p, { upsert: true });
    items.push({ path: p, token: data?.token ?? null, error: error?.message ?? null });
  }
  return { bucket: ATTACHMENTS_BUCKET, items };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return response(null, { status: 204 });
  }
  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return response("Server misconfigured: missing Supabase env vars", { status: 500 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return response("Unauthorized", { status: 401 });
  }

  // Scoped to the caller's own session — only used to find out who's
  // asking, never for the privileged work.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return response("Unauthorized", { status: 401 });
  }
  const { data: callerProfile, error: profileError } = await callerClient
    .from("profiles")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (profileError) {
    return response(`Could not verify caller: ${profileError.message}`, { status: 500 });
  }
  if (!callerProfile || callerProfile.role !== "superadmin") {
    return response("Only a superadmin can back up or restore data", { status: 403 });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return response("Invalid JSON body", { status: 400 });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  try {
    switch (payload.action) {
      case "export":
        return json(await exportAll(admin));
      case "restore-users":
        if (!Array.isArray(payload.users)) return response("users must be a list", { status: 400 });
        return json(await restoreUsers(admin, payload.users));
      case "signed-upload":
        if (!Array.isArray(payload.paths)) return response("paths must be a list", { status: 400 });
        return json(await signedUploads(admin, payload.paths));
      default:
        return response("Unknown action — use export, restore-users, or signed-upload", { status: 400 });
    }
  } catch (error) {
    return response(error instanceof Error ? error.message : String(error), { status: 500 });
  }
});
