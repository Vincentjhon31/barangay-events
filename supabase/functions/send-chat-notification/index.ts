// Supabase Edge Function: pushes a notification for a new event chat
// message. Called by the notify_event_comment trigger on
// public.event_comments (see the "Event chat push notifications" block at
// the end of supabase/barangay_events.sql) through pg_net — not a
// dashboard webhook — with the recipients already worked out in SQL:
//   * a group event's chat  -> every member of that group;
//   * a public event's chat -> the event's creator + everyone who has
//                              written in that chat;
//   * never the sender, never a personal event.
//
// Each recipient is pushed on their own user-<uid> FCM topic (see
// push_notifications.dart's userTopic), on the app's "Event chat" Android
// notification channel, with a per-chat tag so a busy chat shows as one
// tray entry with its latest message instead of a stack of them.
//
// Reuses the existing secrets — nothing new to set up:
//   * FCM_SERVICE_ACCOUNT_JSON_B64 — same Firebase credential as
//     send-event-notification / send-event-reminders;
//   * REMINDER_CRON_SECRET — the shared internal bearer secret the
//     database already sends (vault secret 'reminder_cron_secret').
//
// Deploy with --no-verify-jwt (REQUIRED — the bearer token is that random
// secret, not a JWT, so the gateway would otherwise 401 it before this
// code runs):
//   supabase functions deploy send-chat-notification --use-api --no-verify-jwt

import { initializeApp, cert } from "npm:firebase-admin@^13/app";
import { getMessaging, type Message } from "npm:firebase-admin@^13/messaging";

interface ChatNotificationPayload {
  comment_id: string;
  event_id: string;
  event_title: string;
  event_type: "public" | "shared" | "personal";
  group_name: string | null;
  author_id: string;
  author_name: string | null;
  body: string;
  recipients: string[];
}

// Long messages are cut for the notification; the whole thing is one tap
// away in the chat.
const PREVIEW_MAX_CHARS = 140;

// FCM's sendEach accepts at most 500 messages per call.
const FCM_BATCH_SIZE = 500;

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
      "send-chat-notification",
    );
  } catch (error) {
    console.error("Failed to parse FCM_SERVICE_ACCOUNT_JSON_B64:", error);
  }
}

function preview(body: string): string {
  const text = body.replace(/\s+/g, " ").trim();
  // Array.from splits by code point, so an emoji is never cut in half.
  const chars = Array.from(text);
  return chars.length <= PREVIEW_MAX_CHARS ? text : `${chars.slice(0, PREVIEW_MAX_CHARS).join("")}…`;
}

function buildMessages(payload: ChatNotificationPayload): Message[] {
  const author = payload.author_name?.trim() || "Someone";
  const text = preview(payload.body);
  const title = payload.event_type === "shared" && payload.group_name
    ? `${payload.event_title} · ${payload.group_name}`
    : payload.event_title;

  return payload.recipients.map((userId) => ({
    topic: `user-${userId}`,
    notification: { title, body: `${author}: ${text}` },
    data: {
      type: "chat_message",
      eventId: payload.event_id,
      commentId: payload.comment_id,
      authorId: payload.author_id,
      authorName: author,
      preview: text,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "event_chat",
        tag: `chat-${payload.event_id}`,
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

  let payload: ChatNotificationPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (!payload.event_id || !payload.body || !Array.isArray(payload.recipients)) {
    return new Response("Invalid payload", { status: 400 });
  }
  if (payload.event_type === "personal") {
    return new Response("Ignored: personal event", { status: 200 });
  }
  // Defense in depth — the SQL already leaves the sender out.
  payload.recipients = [...new Set(payload.recipients)].filter((id) => id && id !== payload.author_id);
  if (payload.recipients.length === 0) {
    return new Response("Ignored: no recipients", { status: 200 });
  }

  const messages = buildMessages(payload);
  let sent = 0;
  let failed = 0;
  try {
    const messaging = getMessaging(firebaseApp);
    for (let i = 0; i < messages.length; i += FCM_BATCH_SIZE) {
      const result = await messaging.sendEach(messages.slice(i, i + FCM_BATCH_SIZE));
      sent += result.successCount;
      failed += result.failureCount;
      result.responses.forEach((response, index) => {
        if (!response.success) {
          console.error(`FCM send to ${messages[i + index].topic} failed:`, response.error);
        }
      });
    }
  } catch (error) {
    console.error("FCM send failed:", error);
    return new Response(`FCM send failed: ${error}`, { status: 502 });
  }

  return Response.json({ sent, failed });
});
