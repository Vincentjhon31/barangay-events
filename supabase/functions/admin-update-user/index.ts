// Supabase Edge Function: lets a superadmin edit another account's details
// (name, email, office/department, contact number) from the LGU-admin
// portal (docs/lgu-admin/index.html's "All users" → Details → Edit details).
//
// Deployed with the DEFAULT jwt verification on, same as admin-create-account
// (do NOT pass --no-verify-jwt):
//   supabase functions deploy admin-update-user --use-api
//
// A plain SQL RPC could update the profiles row, but changing the sign-in
// email means updating auth.users too, which needs the service role key —
// so both live here, behind the same caller-is-superadmin check as the
// other admin-* functions. Role and kiosk status are NOT editable here;
// they keep their own RPCs (admin_set_user_role, admin_set_kiosk_account)
// and those RPCs' safeguards.

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

interface UpdateUserPayload {
  userId: string;
  email: string;
  displayName: string;
  department?: string | null;
  phoneNumber?: string | null;
}

function isOptionalString(v: unknown) {
  return v === undefined || v === null || typeof v === "string";
}

function isValidPayload(body: unknown): body is UpdateUserPayload {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  if (typeof b.userId !== "string" || !b.userId.trim()) return false;
  if (typeof b.email !== "string" || !/^[^\s@]+@[^\s@]+$/.test(b.email.trim())) return false;
  if (typeof b.displayName !== "string" || !b.displayName.trim()) return false;
  return isOptionalString(b.department) && isOptionalString(b.phoneNumber);
}

function blankToNull(v: string | null | undefined) {
  const t = (v ?? "").trim();
  return t ? t : null;
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
    return response("Only a superadmin can edit other accounts", { status: 403 });
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return response("Invalid JSON body", { status: 400 });
  }

  if (!isValidPayload(payload)) {
    return response("Missing/invalid fields — need userId, a valid email, and displayName", { status: 400 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: target, error: targetError } = await adminClient
    .from("profiles")
    .select("email")
    .eq("id", payload.userId)
    .maybeSingle();
  if (targetError) {
    return response(targetError.message, { status: 500 });
  }
  if (!target) {
    return response("User not found", { status: 404 });
  }

  const email = payload.email.trim();
  const emailChanged = email.toLowerCase() !== (target.email ?? "").toLowerCase();

  // Auth first: if the new email is already taken there, nothing has been
  // changed yet. email_confirm skips the confirmation mail — the admin is
  // vouching for it, same as admin-create-account.
  if (emailChanged) {
    const { error: authError } = await adminClient.auth.admin.updateUserById(payload.userId, {
      email,
      email_confirm: true,
    });
    if (authError) {
      return response(authError.message, { status: 400 });
    }
  }

  const { error: updateError } = await adminClient
    .from("profiles")
    .update({
      email,
      display_name: payload.displayName.trim(),
      department: blankToNull(payload.department),
      phone_number: blankToNull(payload.phoneNumber),
      updated_at: new Date().toISOString(),
    })
    .eq("id", payload.userId);

  if (updateError) {
    // Keep auth.users and profiles agreeing on the sign-in email.
    if (emailChanged) {
      await adminClient.auth.admin.updateUserById(payload.userId, { email: target.email, email_confirm: true });
    }
    return response(updateError.message, { status: 400 });
  }

  return response(
    JSON.stringify({ id: payload.userId, email }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
