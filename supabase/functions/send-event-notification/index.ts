// Supabase Edge Function: sends a push notification whenever a row is
// inserted into, updated in, or deleted from public.barangay_events.
// Triggered by a Database Webhook (Database > Webhooks in the Supabase
// dashboard) — see the setup steps in README.md's "Push Notifications"
// section. The webhook must be configured to fire on Insert, Update, AND
// Delete (not just Insert) for the update/delete pushes below to ever
// reach this function.
//
// Visibility mirrors the app's own event RLS rules exactly:
//   - event_type = 'public'  -> FCM topic "public-events" (everyone)
//   - event_type = 'shared'  -> FCM topic "group-<group_id>" (that group's members)
//   - event_type = 'personal' or a 'shared' row with no group_id -> no push
//
// UPDATE and DELETE pushes exist so people who already saw an event don't
// silently miss a reschedule/relocation/cancellation — the exact case a
// notification system is for. They're deliberately terser than the
// INSERT message (no "posted by" line) since a reschedule ping doesn't
// need to re-introduce the event the way its original post did.
//
// Needs one secret, set once via (PowerShell):
//   $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Raw "path\to\service-account.json")))
//   supabase secrets set "FCM_SERVICE_ACCOUNT_JSON_B64=$b64"
// Base64 on purpose: the raw JSON is nothing but double-quoted text, and
// PowerShell's argument passing to native executables (like this CLI) does
// not reliably preserve embedded double-quotes — the secret silently got
// corrupted the first time this used plain JSON. Base64 has no characters
// a shell could mangle.
// Optionally also WEBHOOK_SECRET (see the auth check below).

import { initializeApp, cert } from "npm:firebase-admin@^13/app";
import { getMessaging } from "npm:firebase-admin@^13/messaging";

interface BarangayEventRow {
  id: string;
  title: string;
  event_type: "public" | "shared" | "personal";
  group_id: string | null;
  group_name: string | null;
  created_by_name: string | null;
  created_by_department: string | null;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  // Supabase's webhook payload only populates `record` for INSERT/UPDATE
  // and `old_record` for UPDATE/DELETE — a DELETE has no `record` at all,
  // so the deleted row's data (title, group, etc.) has to come from
  // `old_record` instead.
  record: BarangayEventRow | null;
  old_record: BarangayEventRow | null;
}

const serviceAccountJsonB64 = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON_B64");
if (!serviceAccountJsonB64) {
  console.error("FCM_SERVICE_ACCOUNT_JSON_B64 secret is not set.");
}

let firebaseApp: ReturnType<typeof initializeApp> | null = null;
if (serviceAccountJsonB64) {
  try {
    const decoded = atob(serviceAccountJsonB64);
    firebaseApp = initializeApp({ credential: cert(JSON.parse(decoded)) });
  } catch (error) {
    console.error("Failed to parse FCM_SERVICE_ACCOUNT_JSON_B64:", error);
  }
}

function resolveTopic(event: BarangayEventRow): string | null {
  if (event.event_type === "public") return "public-events";
  if (event.event_type === "shared" && event.group_id) {
    return `group-${event.group_id}`;
  }
  // 'personal' events, or a malformed 'shared' row with no group — no push.
  return null;
}

function buildMessage(
  event: BarangayEventRow,
  changeType: "INSERT" | "UPDATE" | "DELETE",
): { title: string; body: string } {
  if (changeType === "UPDATE") {
    return {
      title: event.event_type === "shared" ? (event.group_name ?? "Group update") : "Event updated",
      body: `"${event.title}" was updated — check the app for the latest details.`,
    };
  }
  if (changeType === "DELETE") {
    return {
      title: event.event_type === "shared" ? (event.group_name ?? "Group update") : "Event cancelled",
      body: `"${event.title}" was cancelled/removed.`,
    };
  }

  if (event.event_type === "shared") {
    return {
      title: event.group_name ?? "Group update",
      body: `New event: ${event.title}`,
    };
  }

  const author = [event.created_by_name, event.created_by_department]
    .filter((part) => part && part.trim().length > 0)
    .join(" • ");

  return {
    title: "New public event",
    body: author ? `${event.title} — posted by ${author}` : event.title,
  };
}

Deno.serve(async (req) => {
  const webhookSecret = Deno.env.get("WEBHOOK_SECRET");
  if (webhookSecret) {
    const provided = req.headers.get("authorization");
    if (provided !== `Bearer ${webhookSecret}`) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  if (!firebaseApp) {
    return new Response("Server misconfigured: missing or invalid FCM_SERVICE_ACCOUNT_JSON_B64", {
      status: 500,
    });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (payload.table !== "barangay_events") {
    return new Response("Ignored: not a barangay_events change", { status: 200 });
  }

  // DELETE rows have no `record` — the deleted data only ever lives in
  // `old_record`. INSERT/UPDATE always have `record`.
  const event = payload.record ?? payload.old_record;
  if (!event) {
    return new Response("Ignored: no row data in payload", { status: 200 });
  }

  const topic = resolveTopic(event);
  if (!topic) {
    return new Response("Ignored: personal event, no push needed", { status: 200 });
  }

  const { title, body } = buildMessage(event, payload.type);

  try {
    await getMessaging(firebaseApp).send({
      topic,
      notification: { title, body },
      data: { eventId: event.id, changeType: payload.type },
    });
  } catch (error) {
    console.error("FCM send failed:", error);
    return new Response(`FCM send failed: ${error}`, { status: 502 });
  }

  return new Response("OK", { status: 200 });
});
