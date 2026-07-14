// Supabase Edge Function: sends a push notification announcing a new app
// release. Unlike send-event-notification, this isn't triggered by a
// Database Webhook (there's no table row for "a release happened") — it's
// called directly, over plain HTTP, by the release GitHub Action right
// after it publishes a GitHub Release (see .github/workflows/release.yml).
// See the setup steps in README.md's "Push Notifications" section.
//
// Reuses the same FCM_SERVICE_ACCOUNT_JSON_B64 secret already set up for
// send-event-notification — no separate Firebase credential needed.
//
// Because this function is invoked directly rather than through Supabase's
// own webhook dispatcher (which auto-authenticates "Supabase Edge
// Functions"-type webhooks), it must be deployed with --no-verify-jwt and
// instead requires its own bearer secret:
//   supabase secrets set "RELEASE_NOTIFY_SECRET=<a random string>"
// The same value also needs to be set as a GitHub Actions repo secret named
// RELEASE_NOTIFY_SECRET so the release workflow can authenticate its call.

import { initializeApp, cert } from "npm:firebase-admin@^13/app";
import { getMessaging } from "npm:firebase-admin@^13/messaging";

interface NotifyPayload {
  version: string;
  releaseUrl: string;
}

const serviceAccountJsonB64 = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON_B64");
if (!serviceAccountJsonB64) {
  console.error("FCM_SERVICE_ACCOUNT_JSON_B64 secret is not set.");
}

const releaseNotifySecret = Deno.env.get("RELEASE_NOTIFY_SECRET");
if (!releaseNotifySecret) {
  console.error("RELEASE_NOTIFY_SECRET secret is not set.");
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

Deno.serve(async (req) => {
  if (!releaseNotifySecret) {
    return new Response("Server misconfigured: missing RELEASE_NOTIFY_SECRET", { status: 500 });
  }

  const provided = req.headers.get("authorization");
  if (provided !== `Bearer ${releaseNotifySecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  if (!firebaseApp) {
    return new Response("Server misconfigured: missing or invalid FCM_SERVICE_ACCOUNT_JSON_B64", {
      status: 500,
    });
  }

  let payload: NotifyPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (!payload.version) {
    return new Response("Missing version in request body", { status: 400 });
  }

  try {
    await getMessaging(firebaseApp).send({
      topic: "app-updates",
      notification: {
        title: "New version available",
        body: `v${payload.version} is ready — check the About page for what's new.`,
      },
      data: {
        type: "app_update",
        version: payload.version,
        releaseUrl: payload.releaseUrl ?? "",
      },
    });
  } catch (error) {
    console.error("FCM send failed:", error);
    return new Response(`FCM send failed: ${error}`, { status: 502 });
  }

  return new Response("OK", { status: 200 });
});
