// Supabase Edge Function: sends "this event starts soon" push reminders to
// users who opted into them (Settings > Notifications > Remind me about
// events). Unlike send-event-notification, this isn't triggered by a
// Database Webhook — "an event is about to start" is a time-based
// condition, not a row change — so it must instead be invoked periodically
// by a cron job. See the setup steps in supabase/barangay_events.sql's
// "Event reminders" comment block.
//
// Reuses the same FCM_SERVICE_ACCOUNT_JSON_B64 secret already set up for
// send-event-notification — no separate Firebase credential needed.
//
// Deployed with --no-verify-jwt (called by pg_cron via net.http_post, not
// by a signed-in user) and instead requires its own bearer secret:
//   supabase secrets set "REMINDER_CRON_SECRET=<a random string>"
// which must match the Authorization header the cron job sends.
//
// For each of the two reminder windows ('1h' before, '1d' before), calls
// the list_due_event_reminders SQL function (service-role only — see
// barangay_events.sql) to find every (user, event) pair that's due and
// hasn't already been sent one, pushes a notification to that user's own
// FCM topic (see push_notifications.dart's userTopic — reminders are
// per-user opt-in, so they can't ride the broadcast public-events/group
// topics), then records the send in event_reminders_sent so a later,
// overlapping cron run never double-sends it.

import { createClient } from "npm:@supabase/supabase-js@2";
import { initializeApp, cert } from "npm:firebase-admin@^13/app";
import { getMessaging } from "npm:firebase-admin@^13/messaging";

interface DueReminderRow {
  user_id: string;
  event_id: string;
  event_title: string;
  event_start: string;
  event_location: string | null;
  event_type: string;
  group_name: string | null;
}

const REMINDER_WINDOWS = ["1h", "1d"] as const;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const serviceAccountJsonB64 = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON_B64");
if (!serviceAccountJsonB64) {
  console.error("FCM_SERVICE_ACCOUNT_JSON_B64 secret is not set.");
}

const reminderCronSecret = Deno.env.get("REMINDER_CRON_SECRET");
if (!reminderCronSecret) {
  console.error("REMINDER_CRON_SECRET secret is not set.");
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

function buildMessage(row: DueReminderRow, window: "1h" | "1d"): { title: string; body: string } {
  const when = window === "1h" ? "in about an hour" : "tomorrow";
  const title = row.event_type === "shared" ? (row.group_name ?? "Upcoming event") : "Upcoming event";
  const where = row.event_location ? ` at ${row.event_location}` : "";
  return {
    title,
    body: `"${row.event_title}" is happening ${when}${where}.`,
  };
}

Deno.serve(async (req) => {
  if (!reminderCronSecret) {
    return new Response("Server misconfigured: missing REMINDER_CRON_SECRET", { status: 500 });
  }

  const provided = req.headers.get("authorization");
  if (provided !== `Bearer ${reminderCronSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  if (!firebaseApp) {
    return new Response("Server misconfigured: missing or invalid FCM_SERVICE_ACCOUNT_JSON_B64", {
      status: 500,
    });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response("Server misconfigured: missing Supabase env vars", { status: 500 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const messaging = getMessaging(firebaseApp);

  let totalSent = 0;
  const errors: string[] = [];

  for (const window of REMINDER_WINDOWS) {
    const { data, error } = await adminClient.rpc("list_due_event_reminders", { p_window: window });
    if (error) {
      errors.push(`list_due_event_reminders(${window}): ${error.message}`);
      continue;
    }

    const rows = (data ?? []) as DueReminderRow[];
    for (const row of rows) {
      const { title, body } = buildMessage(row, window);
      try {
        await messaging.send({
          topic: `user-${row.user_id}`,
          notification: { title, body },
          data: { type: "event_reminder", eventId: row.event_id, window },
        });
      } catch (sendError) {
        errors.push(`FCM send failed for user ${row.user_id}/event ${row.event_id}: ${sendError}`);
        continue;
      }

      const { error: markError } = await adminClient
        .from("event_reminders_sent")
        .upsert(
          { event_id: row.event_id, user_id: row.user_id, reminder_window: window },
          { onConflict: "event_id,user_id,reminder_window", ignoreDuplicates: true },
        );
      if (markError) {
        errors.push(`Failed to record sent reminder (${row.event_id}/${row.user_id}): ${markError.message}`);
        continue;
      }

      totalSent++;
    }
  }

  return new Response(JSON.stringify({ sent: totalSent, errors }), {
    status: errors.length > 0 && totalSent === 0 ? 502 : 200,
    headers: { "Content-Type": "application/json" },
  });
});
