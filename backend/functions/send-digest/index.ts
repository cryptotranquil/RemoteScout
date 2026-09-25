// send-digest — daily digest at the user's configured time (PRD §6.5).
//
// Compiles top N matches ≥ the user's minimum score (capped at max-jobs-per-day,
// weekend toggle respected), records `notifications` rows, then delivers:
//   1. push via Firebase Cloud Messaging (HTTP v1)
//   2. optional email via Resend
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FCM_PROJECT_ID,
//          FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY, (optional) RESEND_API_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT } from "https://esm.sh/jose@5";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

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
        new TextEncoder().encode(privateKey),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      ),
    );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  return data.access_token ?? null;
}

Deno.serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const now = new Date();
    const isWeekend = now.getDay() === 0 || now.getDay() === 6;

    const { data: profiles, error: profilesError } = await supabase
      .from("profiles")
      .select("id, name, email, notification_prefs");
    if (profilesError) throw profilesError;

    const reports: unknown[] = [];

    for (const profile of profiles ?? []) {
      const prefs = profile.notification_prefs ?? {};
      if (isWeekend && prefs.weekend_enabled === false) continue;

      const minScore = prefs.min_match_score ?? 70;
      const maxJobs = prefs.max_jobs_per_day ?? 5;

      const { data: matches, error: matchError } = await supabase
        .from("job_matches")
        .select("id, job_id, match_score, match_reason, jobs (title, company, source_url, apply_url)")
        .eq("user_id", profile.id)
        .eq("is_seen", false)
        .eq("is_rejected", false)
        .gte("match_score", minScore)
        .order("match_score", { ascending: false })
        .limit(maxJobs);
      if (matchError) throw matchError;

      if (!matches || matches.length === 0) {
        reports.push({ user: profile.id, skipped: "no qualifying matches" });
        continue;
      }

      const top = matches[0];
      const title = `You have ${matches.length} new remote job${matches.length === 1 ? "" : "s"} today.`;
      const body = `Top match: ${top.jobs?.title} — ${top.match_score}%`;

      // Record the digest (job_id null = digest-level summary row).
      await supabase.from("notifications").insert([
        { user_id: profile.id, job_id: null, channel: "push", sent_at: now.toISOString() },
      ]);

      // 1) Push via FCM (deep link into Discover).
      const token = await fcmAccessToken();
      let push: string | null = null;
      if (token) {
        const fcmRes = await fetch(
          `https://fcm.googleapis.com/v1/projects/${Deno.env.get("FCM_PROJECT_ID")}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                topic: "daily-digest",
                notification: { title, body },
                data: { route: "/discover" },
                android: { priority: "high" },
              },
            }),
          },
        );
        push = (await fcmRes.json()).name ?? `error: ${fcmRes.status}`;
      }

      // 2) Optional email via Resend.
      let email: string | null = null;
      const resendKey = Deno.env.get("RESEND_API_KEY");
      if (resendKey && profile.email) {
        const list = matches
          .map((m) => `• ${m.jobs?.title} — ${m.jobs?.company} (${m.match_score}%)`)
          .join("\n");
        const resendRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "RemoteScout <digest@remotescout.app>",
            to: [profile.email],
            subject: title,
            text: `${body}\n\n${list}\n\nOpen RemoteScout for the full breakdowns.`,
          }),
        });
        email = resendRes.ok ? "sent" : `error: ${resendRes.status}`;
        if (resendRes.ok) {
          await supabase.from("notifications").insert([
            { user_id: profile.id, job_id: null, channel: "email", sent_at: now.toISOString() },
          ]);
        }
      }

      reports.push({ user: profile.id, jobs: matches.length, push, email });
    }

    return new Response(JSON.stringify({ reports }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
