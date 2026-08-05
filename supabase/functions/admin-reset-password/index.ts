// Supabase Edge Function: lets a superadmin force-reset another account's
// password directly from the LGU-admin portal (docs/lgu-admin/index.html's
// "All Users" table), for an account that used a made-up/inaccessible email
// and so can't complete the normal self-service "Forgot password?" flow
// (see lib/auth_service.dart's sendPasswordResetEmail). The new password is
// generated server-side and returned once, for the admin to relay to the
// user out-of-band and copy into the app themselves — never stored or
// logged anywhere after this response.
//
// Deployed with the DEFAULT jwt verification on, same as admin-create-account
// (do NOT pass --no-verify-jwt):
//   supabase functions deploy admin-reset-password --use-api
//
// Security boundary, identical shape to admin-create-account: resolve the
// caller's own JWT, check their own profiles.role is 'superadmin' before
// anything privileged happens. Nothing here is exposed to the anon/client
// role directly — force-resetting another user's password needs the
// service role key, which never leaves this function.

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

interface ResetPasswordPayload {
  userId: string;
}

function isValidPayload(body: unknown): body is ResetPasswordPayload {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return typeof b.userId === "string" && b.userId.trim().length > 0;
}

// 12 chars from a charset with no visually-ambiguous characters (no 0/O,
// 1/l/I) — this gets read aloud/typed by hand by whoever the admin relays
// it to.
function generatePassword(): string {
  const charset = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => charset[b % charset.length]).join("");
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
    return response("Only a superadmin can reset another account's password", { status: 403 });
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

  const newPassword = generatePassword();

  // Separate client: only this one ever uses the service role key, and
  // only for this one privileged call.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { error: updateError } = await adminClient.auth.admin.updateUserById(payload.userId, {
    password: newPassword,
  });

  if (updateError) {
    return response(updateError.message, { status: 400 });
  }

  return response(
    JSON.stringify({ newPassword }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
