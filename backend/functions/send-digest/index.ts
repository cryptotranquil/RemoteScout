// Scheduled every five minutes. Each profile is checked against its local
// digest time so daylight-saving changes do not require schedule changes.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT } from "https://esm.sh/jose@5";
import {
  isDigestDue,
  isWeekend,
  localDateTime,
} from "../_shared/digest_schedule.ts";
import { handlePostRequest, jsonResponse } from "../_shared/http.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

function firstRelated<T>(value: T | T[] | null | undefined): T | undefined {
  if (Array.isArray(value)) return value[0];
  return value ?? undefined;
}

function decodePrivateKey(pem: string): ArrayBuffer {
  const encoded = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function fcmAccessToken(): Promise<string | null> {
  const projectId = Deno.env.get("FCM_PROJECT_ID");
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FCM_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  if (!projectId || !clientEmail || !privateKey) return null;

  const now = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({ scope: FCM_SCOPE })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(
      await crypto.subtle.importKey(
        "pkcs8",
        decodePrivateKey(privateKey),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      ),
    );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await response.json();
  if (!response.ok || typeof data.access_token !== "string") {
    throw new Error(`FCM OAuth token request failed: HTTP ${response.status}`);
  }
  return data.access_token;
}

async function sendPush(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  title: string,
  body: string,
  route: string,
): Promise<{ ok: boolean; invalidToken: boolean; error?: string }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          data: { route },
          android: { priority: "high" },
        },
      }),
    },
  );
  const result = await response.json().catch(() => ({}));
  if (response.ok) return { ok: true, invalidToken: false };
  const details = JSON.stringify(result);
  const invalidToken = details.includes("UNREGISTERED");
  return {
    ok: false,
    invalidToken,
    error: `FCM HTTP ${response.status}`,
  };
}

Deno.serve(async (req) => {
  const response = handlePostRequest(req);
  if (response) return response;

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const now = new Date();
    const { data: profiles, error: profilesError } = await supabase
      .from("profiles")
      .select("id, name, email, notification_prefs");
    if (profilesError) throw profilesError;

    const reports: unknown[] = [];
    for (const profile of profiles ?? []) {
      try {
        const prefs = profile.notification_prefs ?? {};
        const timeZone = prefs.time_zone ?? "UTC";
        const localNow = localDateTime(now, timeZone);
        const digestTime = prefs.digest_time ?? "08:00";

        if (!isDigestDue(now, timeZone, digestTime)) {
          reports.push({ user: profile.id, skipped: "outside digest time" });
          continue;
        }
        if (isWeekend(now, timeZone) && prefs.weekend_enabled !== true) {
          reports.push({
            user: profile.id,
            skipped: "weekend digests disabled",
          });
          continue;
        }

        const { data: recentNotifications, error: recentError } = await supabase
          .from("notifications")
          .select("channel, sent_at")
          .eq("user_id", profile.id)
          .in("channel", ["push", "email"])
          .gte(
            "sent_at",
            new Date(now.getTime() - 36 * 60 * 60 * 1000).toISOString(),
          )
          .order("sent_at", { ascending: false });
        if (recentError) throw recentError;
        const alreadySent = (recentNotifications ?? []).some((notification) =>
          localDateTime(new Date(notification.sent_at), timeZone).date ===
            localNow.date
        );
        if (alreadySent) {
          reports.push({
            user: profile.id,
            skipped: "digest already sent today",
          });
          continue;
        }

        const minScore = Number(prefs.min_match_score ?? 70);
        const maxJobs = Number(prefs.max_jobs_per_day ?? 5);
        const { data: matches, error: matchError } = await supabase
          .from("job_matches")
          .select(
            "id, job_id, match_score, jobs (title, company, source_url, apply_url)",
          )
          .eq("user_id", profile.id)
          .eq("is_seen", false)
          .eq("is_rejected", false)
          .gte("match_score", minScore)
          .order("match_score", { ascending: false })
          .limit(maxJobs);
        if (matchError) throw matchError;

        const { data: followUps, error: followUpError } = await supabase
          .from("applications")
          .select("id, follow_up_at, jobs (title, company)")
          .eq("user_id", profile.id)
          .in("status", ["applied", "interview", "offer"])
          .not("follow_up_at", "is", null)
          .lte(
            "follow_up_at",
            new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(),
          );
        if (followUpError) throw followUpError;

        const hasMatches = (matches?.length ?? 0) > 0;
        const hasFollowUps = (followUps?.length ?? 0) > 0;
        if (!hasMatches && !hasFollowUps) {
          reports.push({
            user: profile.id,
            skipped: "no qualifying matches or follow-ups",
          });
          continue;
        }

        const top = matches?.[0];
        const topJob = firstRelated(top?.jobs);
        const title = hasMatches
          ? `You have ${matches!.length} new remote job${
            matches!.length === 1 ? "" : "s"
          } today.`
          : "You have application follow-ups due.";
        const reminders = hasFollowUps
          ? ` ${followUps!.length} application follow-up${
            followUps!.length === 1 ? " is" : "s are"
          } due soon.`
          : "";
        const body = hasMatches
          ? `Top match: ${topJob?.title ?? "New listing"} — ${
            top!.match_score
          }%.${reminders}`
          : `${followUps!.length} application follow-up${
            followUps!.length === 1 ? " is" : "s are"
          } due soon.`;
        const route = hasMatches ? "/discover" : "/applications";

        const { data: devices, error: devicesError } = await supabase
          .from("push_tokens")
          .select("token")
          .eq("user_id", profile.id);
        if (devicesError) throw devicesError;

        let pushSent = 0;
        const deliveryErrors: string[] = [];
        const projectId = Deno.env.get("FCM_PROJECT_ID");
        if ((devices?.length ?? 0) > 0 && projectId) {
          const accessToken = await fcmAccessToken();
          if (!accessToken) {
            deliveryErrors.push("FCM credentials are incomplete");
          } else {
            for (const device of devices ?? []) {
              const result = await sendPush(
                projectId,
                accessToken,
                device.token,
                title,
                body,
                route,
              );
              if (result.ok) {
                pushSent++;
              } else {
                deliveryErrors.push(result.error ?? "FCM delivery failed");
                if (result.invalidToken) {
                  const { error } = await supabase
                    .from("push_tokens")
                    .delete()
                    .eq("token", device.token);
                  if (error) throw error;
                }
              }
            }
          }
        } else if ((devices?.length ?? 0) > 0) {
          deliveryErrors.push(
            "FCM_PROJECT_ID is required to send push notifications",
          );
        }

        let emailSent = false;
        const resendKey = Deno.env.get("RESEND_API_KEY");
        if (resendKey && profile.email) {
          const from = Deno.env.get("RESEND_FROM_EMAIL");
          if (!from) {
            deliveryErrors.push(
              "RESEND_FROM_EMAIL is required when email is enabled",
            );
          } else {
            const jobList = (matches ?? [])
              .map((match) => {
                const job = firstRelated(match.jobs);
                return `${job?.title ?? "New listing"} — ${
                  job?.company ?? "Unknown company"
                } (${match.match_score}%)`;
              })
              .join("\n");
            const followUpList = (followUps ?? [])
              .map((application) => {
                const job = firstRelated(application.jobs);
                return `${job?.title ?? "Application"} — ${
                  job?.company ?? "Unknown company"
                } (${application.follow_up_at})`;
              })
              .join("\n");
            const sections = [
              body,
              jobList ? `\nJobs:\n${jobList}` : "",
              followUpList ? `\nFollow-ups:\n${followUpList}` : "",
              "\n\nOpen RemoteScout for the full details.",
            ].join("");
            const response = await fetch("https://api.resend.com/emails", {
              method: "POST",
              headers: {
                Authorization: `Bearer ${resendKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                from,
                to: [profile.email],
                subject: title,
                text: sections,
              }),
            });
            if (response.ok) {
              emailSent = true;
            } else {
              deliveryErrors.push(`Resend HTTP ${response.status}`);
            }
          }
        }

        if (pushSent > 0) {
          const { error } = await supabase.from("notifications").insert({
            user_id: profile.id,
            job_id: null,
            channel: "push",
            sent_at: now.toISOString(),
          });
          if (error) throw error;
        }
        if (emailSent) {
          const { error } = await supabase.from("notifications").insert({
            user_id: profile.id,
            job_id: null,
            channel: "email",
            sent_at: now.toISOString(),
          });
          if (error) throw error;
        }

        reports.push({
          user: profile.id,
          jobs: matches?.length ?? 0,
          followUps: followUps?.length ?? 0,
          devicesSent: pushSent,
          emailSent,
          errors: deliveryErrors,
          skipped: pushSent === 0 && !emailSent && deliveryErrors.length === 0
            ? "no registered push token or email channel"
            : undefined,
        });
      } catch (error) {
        reports.push({ user: profile.id, error: String(error) });
      }
    }

    return jsonResponse({ reports });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
});
