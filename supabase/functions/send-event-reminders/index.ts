// Supabase Edge Function: sends "this event starts soon" push reminders to
// users who opted into them (Settings > Notifications > Remind me about
// events — "1 hour before" by default). Unlike send-event-notification,
// this isn't triggered by a Database Webhook — "an event is about to
// start" is a time-based condition, not a row change — so it's invoked by
// a pg_cron job every minute, and only when has_due_event_reminders() says
// something is due. See the "Reminder timing fix" block at the end of
// supabase/barangay_events.sql.
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
// the list_due_event_reminders SQL function (service-role only) to find
// every (user, event) pair that's due and hasn't been sent one, claims it
// in event_reminders_sent, then pushes a notification to that user's own
// FCM topic (see push_notifications.dart's userTopic — reminders are
// per-user, so they can't ride the broadcast public-events/group topics).
// Claiming BEFORE sending means two overlapping runs can never both send
// the same reminder; a failed send releases its claim so the next run
// retries it.
//
// TIME CONVENTION: event times are stored as Philippine wall-clock time
// labeled as UTC — a 10:00 AM event comes back as "...T10:00:00+00:00".
// So its UTC fields ARE the Philippine clock time to show, and the real
// moment it happens is that value minus 8 hours.

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
  // Absent when running against the pre-September-2026 SQL.
  event_all_day?: boolean | null;
}

type ReminderWindow = "1h" | "1d";

const REMINDER_WINDOWS: readonly ReminderWindow[] = ["1h", "1d"];

const MANILA_OFFSET_MS = 8 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

// What an event's location is saved as when left blank in the app
// (event_store.dart's unspecifiedLocation) — not worth showing.
const UNSPECIFIED_LOCATION = "Other";

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

/** "10:00 AM" from a stored (wall-clock-labeled-UTC) timestamp. */
function formatClock(stored: Date): string {
  const hours = stored.getUTCHours();
  const minutes = stored.getUTCMinutes().toString().padStart(2, "0");
  const period = hours < 12 ? "AM" : "PM";
  const hour12 = hours % 12 === 0 ? 12 : hours % 12;
  return `${hour12}:${minutes} ${period}`;
}

/** "today" / "tomorrow" / "on Friday", relative to the current Philippine date. */
function dayWord(stored: Date, nowMs: number): string {
  const eventDay = Date.UTC(stored.getUTCFullYear(), stored.getUTCMonth(), stored.getUTCDate());
  const manilaNow = new Date(nowMs + MANILA_OFFSET_MS);
  const today = Date.UTC(manilaNow.getUTCFullYear(), manilaNow.getUTCMonth(), manilaNow.getUTCDate());
  const diffDays = Math.round((eventDay - today) / DAY_MS);
  if (diffDays === 0) return "today";
  if (diffDays === 1) return "tomorrow";
  const weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][
    stored.getUTCDay()
  ];
  return `on ${weekday}`;
}

function buildMessage(
  row: DueReminderRow,
  window: ReminderWindow,
  nowMs: number,
): { title: string; body: string } {
  const start = new Date(row.event_start);
  const title = row.event_type === "shared" ? (row.group_name ?? "Upcoming event") : "Upcoming event";
  const location = row.event_location?.trim();
  const where = location && location !== UNSPECIFIED_LOCATION ? ` · ${location}` : "";

  let when: string;
  if (row.event_all_day) {
    when = `is ${dayWord(start, nowMs)}, all day`;
  } else if (window === "1h") {
    when = `starts at ${formatClock(start)}`;
  } else {
    when = `is ${dayWord(start, nowMs)} at ${formatClock(start)}`;
  }
  return { title, body: `"${row.event_title}" ${when}${where}` };
}

/**
 * How long FCM should keep trying to deliver: until the event starts (a
 * reminder that arrives after that is useless), but at least a minute.
 * All-day events are reminded relative to 8:00 AM on their day.
 */
function ttlMs(row: DueReminderRow, nowMs: number): number {
  const storedStart = new Date(row.event_start).getTime();
  const anchorWallClock = row.event_all_day ? storedStart + 8 * 60 * 60 * 1000 : storedStart;
  const anchorRealMs = anchorWallClock - MANILA_OFFSET_MS;
  return Math.max(60_000, anchorRealMs - nowMs);
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
      const key = { event_id: row.event_id, user_id: row.user_id, reminder_window: window };

      // Claim first: with ignoreDuplicates, only the run that actually
      // inserts the row gets it back — any other overlapping run skips.
      const { data: claimed, error: claimError } = await adminClient
        .from("event_reminders_sent")
        .upsert(key, { onConflict: "event_id,user_id,reminder_window", ignoreDuplicates: true })
        .select("event_id");
      if (claimError) {
        errors.push(`Failed to claim reminder (${row.event_id}/${row.user_id}): ${claimError.message}`);
        continue;
      }
      if (!claimed || claimed.length === 0) continue;

      const nowMs = Date.now();
      const { title, body } = buildMessage(row, window, nowMs);
      try {
        await messaging.send({
          topic: `user-${row.user_id}`,
          notification: { title, body },
          data: { type: "event_reminder", eventId: row.event_id, window },
          android: { priority: "high", ttl: ttlMs(row, nowMs) },
        });
      } catch (sendError) {
        errors.push(`FCM send failed for user ${row.user_id}/event ${row.event_id}: ${sendError}`);
        // Release the claim so the next run retries this one.
        await adminClient.from("event_reminders_sent").delete().match(key);
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
