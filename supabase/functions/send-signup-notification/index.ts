// Supabase Edge Function: tells the superadmin(s) someone new signed up in
// the app, so a staff member can be promoted to LGU member from the
// portal's Users -> New sign-ups tab. Called by the notify_new_signup
// trigger on public.profiles (see the "New sign-ups" block at the end of
// supabase/barangay_events.sql) through pg_net, with the recipients (every
// superadmin) already worked out in SQL. Accounts the portal creates
// already have a role, so they never reach this.
//
// Each superadmin is pushed on their own user-<uid> FCM topic; tapping it
// in the app opens the portal (push_notifications.dart, newSignupsPortalUrl).
//
// Reuses the existing secrets — nothing new to set up:
//   * FCM_SERVICE_ACCOUNT_JSON_B64 — same Firebase credential as the other
//     push functions;
//   * REMINDER_CRON_SECRET — the shared internal bearer secret the
//     database already sends (vault secret 'reminder_cron_secret').
//
// Deploy with --no-verify-jwt (REQUIRED — the bearer token is that random
// secret, not a JWT):
//   supabase functions deploy send-signup-notification --use-api --no-verify-jwt

import { initializeApp, cert } from "npm:firebase-admin@^13/app";
import { getMessaging, type Message } from "npm:firebase-admin@^13/messaging";

interface SignupNotificationPayload {
  user_id: string;
  display_name: string | null;
  email: string | null;
  recipients: string[];
}

const serviceAccountJsonB64 = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON_B64");
if (!serviceAccountJsonB64) {
  console.error("FCM_SERVICE_ACCOUNT_JSON_B64 secret is not set.");
}

const internalSecret = Deno.env.get("REMINDER_CRON_SECRET");
if (!internalSecret) {
  console.error("REMINDER_CRON_SECRET secret is not set.");
}

let firebaseApp: ReturnType<typeof initializeApp> | null = null;
if (serviceAccountJsonB64) {
  try {
    firebaseApp = initializeApp(
      { credential: cert(JSON.parse(atob(serviceAccountJsonB64))) },
      "send-signup-notification",
    );
  } catch (error) {
    console.error("Failed to parse FCM_SERVICE_ACCOUNT_JSON_B64:", error);
  }
}

function buildMessages(payload: SignupNotificationPayload): Message[] {
  const name = payload.display_name?.trim();
  const email = payload.email?.trim();
  const who = name && email ? `${name} (${email})` : name || email || "Someone";

  return payload.recipients.map((userId) => ({
    topic: `user-${userId}`,
    notification: {
      title: "New account",
      body: `${who} just signed up. Tap to review and promote staff to LGU member.`,
    },
    data: { type: "new_signup", userId: payload.user_id },
    android: {
      priority: "high",
      notification: {
        channelId: "event_updates_v2",
        sound: "in_app_notify",
        tag: `signup-${payload.user_id}`,
      },
    },
  }));
}

Deno.serve(async (req) => {
  if (!internalSecret) {
    return new Response("Server misconfigured: missing REMINDER_CRON_SECRET", { status: 500 });
  }
  if (req.headers.get("authorization") !== `Bearer ${internalSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!firebaseApp) {
    return new Response("Server misconfigured: missing or invalid FCM_SERVICE_ACCOUNT_JSON_B64", {
      status: 500,
    });
  }

  let payload: SignupNotificationPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (!payload.user_id || !Array.isArray(payload.recipients)) {
    return new Response("Invalid payload", { status: 400 });
  }
  payload.recipients = [...new Set(payload.recipients)].filter((id) => id && id !== payload.user_id);
  if (payload.recipients.length === 0) {
    return new Response("Ignored: no recipients", { status: 200 });
  }

  try {
    const result = await getMessaging(firebaseApp).sendEach(buildMessages(payload));
    result.responses.forEach((response, index) => {
      if (!response.success) {
        console.error(`FCM send to user-${payload.recipients[index]} failed:`, response.error);
      }
    });
    return Response.json({ sent: result.successCount, failed: result.failureCount });
  } catch (error) {
    console.error("FCM send failed:", error);
    return new Response(`FCM send failed: ${error}`, { status: 502 });
  }
});
