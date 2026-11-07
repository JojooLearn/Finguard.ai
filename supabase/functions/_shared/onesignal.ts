// supabase/functions/_shared/onesignal.ts
/**
 * Shared utility for sending push notifications via OneSignal REST API.
 * Uses OneSignal External ID (Supabase Auth UUID) to target specific user devices.
 */

interface PushPayloadData {
  screen?: string;
  symbol?: string;
  category_id?: string;
  month?: string;
  type?: string;
  [key: string]: unknown;
}

/**
 * Sends a targeted push notification to specific users by their Supabase UUID.
 */
export async function sendPushNotification(
  userIds: string[],
  heading: string,
  content: string,
  dataPayload?: PushPayloadData
) {
  const ONE_SIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID");
  const ONE_SIGNAL_REST_KEY = Deno.env.get("ONESIGNAL_REST_KEY");

  if (!ONE_SIGNAL_APP_ID || !ONE_SIGNAL_REST_KEY) {
    console.warn(
      "[OneSignal] ONESIGNAL_APP_ID or ONESIGNAL_REST_KEY is not set. Skipping push notification."
    );
    return { success: false, reason: "credentials_missing" };
  }

  if (!userIds || userIds.length === 0) {
    return { success: false, reason: "no_recipients" };
  }

  try {
    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Basic ${ONE_SIGNAL_REST_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONE_SIGNAL_APP_ID,
        include_aliases: {
          external_id: userIds, // Targets Supabase auth UUIDs
        },
        target_channel: "push",
        headings: {
          en: heading,
          id: heading,
        },
        contents: {
          en: content,
          id: content,
        },
        data: dataPayload,
      }),
    });

    const resJson = await response.json();
    console.log("[OneSignal] Push sent successfully:", resJson);
    return { success: true, result: resJson };
  } catch (error) {
    console.error("[OneSignal] Error sending push notification:", error);
    return { success: false, error };
  }
}

/**
 * Broadcasts a push notification to all subscribed users (e.g. for general stock alerts).
 */
export async function sendPushNotificationToAll(
  heading: string,
  content: string,
  dataPayload?: PushPayloadData
) {
  const ONE_SIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID");
  const ONE_SIGNAL_REST_KEY = Deno.env.get("ONESIGNAL_REST_KEY");

  if (!ONE_SIGNAL_APP_ID || !ONE_SIGNAL_REST_KEY) {
    console.warn(
      "[OneSignal] ONESIGNAL_APP_ID or ONESIGNAL_REST_KEY is not set. Skipping broadcast push."
    );
    return { success: false, reason: "credentials_missing" };
  }

  try {
    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Basic ${ONE_SIGNAL_REST_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONE_SIGNAL_APP_ID,
        included_segments: ["Subscribed Users"],
        target_channel: "push",
        headings: {
          en: heading,
          id: heading,
        },
        contents: {
          en: content,
          id: content,
        },
        data: dataPayload,
      }),
    });

    const resJson = await response.json();
    console.log("[OneSignal] Broadcast push sent successfully:", resJson);
    return { success: true, result: resJson };
  } catch (error) {
    console.error("[OneSignal] Error sending broadcast push notification:", error);
    return { success: false, error };
  }
}

