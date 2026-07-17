// Supabase Edge Function: lets the superadmin create a brand-new account
// (LGU member or another superadmin) directly from the LGU-admin portal
// (docs/lgu-admin/index.html's "Add account" card), instead of the account
// having to self-register and wait for approval.
//
// Deployed with the DEFAULT jwt verification on (do NOT pass
// --no-verify-jwt like send-app-update-notification does) — this is called
// by a real signed-in browser session, and Supabase should reject anything
// without a valid user JWT before this code ever runs:
//   supabase functions deploy admin-create-account --use-api
//
// Creating a real login-capable account needs the service role key, which
// must never reach any client (including the static admin portal page) —
// that's why this exists as a server-side function instead of a plain SQL
// RPC. No new secrets to configure: SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY are already auto-injected into every Edge
// Function's environment.
//
// Security boundary is entirely step 1 below: the caller's own JWT is
// resolved and their *own* profiles.role is checked. Nothing privileged
// happens unless that's 'superadmin'. The profiles insert afterwards
// bypasses guard_profile_role_columns "for free" — that trigger only fires
// on UPDATE (see supabase/barangay_events.sql), so inserting a brand-new
// row with role already set was never subject to it in the first place.
//
// Unlike the other two Edge Functions in this repo (both called
// server-to-server — GitHub Actions, Supabase's own webhook dispatcher),
// this one is called directly from a browser tab, so it needs to handle
// CORS itself: the preflight OPTIONS request, and Access-Control-Allow-*
// headers on every response. This isn't a security boundary (that's the
// JWT + role check above) — it's purely what lets the calling page's JS
// read the response at all, regardless of which domain/localhost it's
// served from (the admin portal, GitHub Pages, a future municipal
// subdomain, or a local dev server while testing).

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

interface CreateAccountPayload {
  email: string;
  password: string;
  displayName: string;
  role: "lgu_member" | "superadmin";
  department?: string;
}

function isValidPayload(body: unknown): body is CreateAccountPayload {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  if (typeof b.email !== "string" || !b.email.trim()) return false;
  if (typeof b.password !== "string" || b.password.length < 6) return false;
  if (typeof b.displayName !== "string" || !b.displayName.trim()) return false;
  if (b.role !== "lgu_member" && b.role !== "superadmin") return false;
  if (b.role === "lgu_member" && (typeof b.department !== "string" || !b.department.trim())) {
    return false;
  }
  return true;
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

  // Scoped to the caller's own session — used only to find out who's
  // asking, never for the privileged work below.
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
    return response("Only a superadmin can create accounts", { status: 403 });
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return response("Invalid JSON body", { status: 400 });
  }

  if (!isValidPayload(payload)) {
    return response(
      "Missing/invalid fields — need email, password (6+ chars), displayName, role ('lgu_member'|'superadmin'), and department if role is lgu_member",
      { status: 400 },
    );
  }

  const email = payload.email.trim();
  const displayName = payload.displayName.trim();
  const department = payload.role === "lgu_member" ? payload.department!.trim() : null;

  // Separate client: only this one ever uses the service role key, and
  // only for the two privileged calls below.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password: payload.password,
    email_confirm: true,
    user_metadata: { display_name: displayName },
  });

  if (createError || !created.user) {
    return response(createError?.message ?? "Could not create the account", { status: 400 });
  }

  const { error: insertError } = await adminClient.from("profiles").insert({
    id: created.user.id,
    email,
    display_name: displayName,
    department,
    role: payload.role,
    lgu_request_status: payload.role === "lgu_member" ? "approved" : null,
  });

  if (insertError) {
    // The auth user now exists without a matching profile row — surface
    // this clearly rather than silently leaving a half-created account.
    return response(
      `Account created but profile setup failed: ${insertError.message}. ` +
        `The auth user (${email}) may need manual cleanup.`,
      { status: 500 },
    );
  }

  return response(
    JSON.stringify({ id: created.user.id, email }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
