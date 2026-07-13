// Supabase Edge Function: sends a push notification whenever a new row is
// inserted into public.barangay_events. Triggered by a Database Webhook
// (Database > Webhooks in the Supabase dashboard) — see the setup steps in
// README.md's "Push Notifications" section.
//
// Visibility mirrors the app's own event RLS rules exactly:
//   - event_type = 'public'  -> FCM topic "public-events" (everyone)
//   - event_type = 'shared'  -> FCM topic "group-<group_id>" (that group's members)
//   - event_type = 'personal' or a 'shared' row with no group_id -> no push
//
// Needs one secret, set once via:
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<firebase service-account JSON>'
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
  record: BarangayEventRow;
}

const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
if (!serviceAccountJson) {
  console.error("FCM_SERVICE_ACCOUNT_JSON secret is not set.");
}

const firebaseApp = serviceAccountJson
  ? initializeApp({ credential: cert(JSON.parse(serviceAccountJson)) })
  : null;

function resolveTopic(event: BarangayEventRow): string | null {
  if (event.event_type === "public") return "public-events";
  if (event.event_type === "shared" && event.group_id) {
    return `group-${event.group_id}`;
  }
  // 'personal' events, or a malformed 'shared' row with no group — no push.
  return null;
}

function buildMessage(event: BarangayEventRow): { title: string; body: string } {
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
    return new Response("Server misconfigured: missing FCM_SERVICE_ACCOUNT_JSON", {
      status: 500,
    });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (payload.type !== "INSERT" || payload.table !== "barangay_events") {
    return new Response("Ignored: not a barangay_events insert", { status: 200 });
  }

  const event = payload.record;
  const topic = resolveTopic(event);
  if (!topic) {
    return new Response("Ignored: personal event, no push needed", { status: 200 });
  }

  const { title, body } = buildMessage(event);

  try {
    await getMessaging(firebaseApp).send({
      topic,
      notification: { title, body },
      data: { eventId: event.id },
    });
  } catch (error) {
    console.error("FCM send failed:", error);
    return new Response(`FCM send failed: ${error}`, { status: 502 });
  }

  return new Response("OK", { status: 200 });
});
