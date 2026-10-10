// Supabase Edge Function: lets a superadmin permanently delete another
// account from the LGU-admin portal (docs/lgu-admin/index.html's
// "All users" → Details → Delete account).
//
// Deployed with the DEFAULT jwt verification on, same as admin-create-account
// (do NOT pass --no-verify-jwt):
//   supabase functions deploy admin-delete-user --use-api
//
// Deleting from auth.users needs the service role key, hence a function
// rather than an RPC. Everything keyed to auth.users / profiles with
// ON DELETE CASCADE goes with it (profile, preferences, group memberships,
// join requests, and groups they created). Their events stay —
// created_by_id has no foreign key — and keep the author name stored on
// the event itself.
//
// Two references have no ON DELETE rule and would block the delete, so they
// are cleared first: lgu_locations.created_by and
// event_attachments.uploaded_by (both just "who added this" bookkeeping).

import { createClient } from "npm:@supabase/supabase-js@2";

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

interface DeleteUserPayload {
  userId: string;
}

function isValidPayload(body: unknown): body is DeleteUserPayload {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return typeof b.userId === "string" && b.userId.trim().length > 0;
}

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

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
    return response("Only a superadmin can delete accounts", { status: 403 });
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return response("Invalid JSON body", { status: 400 });
  }

  if (!isValidPayload(payload)) {
    return response("Missing/invalid field — need userId", { status: 400 });
  }

  // Same reasoning as admin_set_user_role refusing your own role. And since
  // the caller is a superadmin who stays, at least one superadmin always
  // remains.
  if (payload.userId === userData.user.id) {
    return response("You can't delete your own account here", { status: 400 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  for (const [table, column] of [["lgu_locations", "created_by"], ["event_attachments", "uploaded_by"]]) {
    const { error } = await adminClient.from(table).update({ [column]: null }).eq(column, payload.userId);
    if (error) {
      return response(`Could not clear ${table}.${column}: ${error.message}`, { status: 500 });
    }
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(payload.userId);

  if (deleteError) {
    // A profile row whose auth user is already gone (e.g. removed by hand in
    // the Supabase dashboard) — delete the leftover row so it stops listing.
    if (deleteError.status !== 404) {
      return response(deleteError.message, { status: 400 });
    }
    const { error: rowError } = await adminClient.from("profiles").delete().eq("id", payload.userId);
    if (rowError) {
      return response(rowError.message, { status: 500 });
    }
  }

  return response(
    JSON.stringify({ id: payload.userId }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
