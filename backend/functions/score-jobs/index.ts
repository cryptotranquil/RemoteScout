// score-jobs — runs right after fetch-jobs (TRD §5.4, Backend Schema §5).
//
// Runs the rule-based scorer for each profile against newly-inserted jobs and
// upserts `job_matches` with a human-readable match_reason. Seen/saved/rejected
// flags are always preserved.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { scoreJob } from "../_shared/scoring.ts";
import { handlePostRequest, jsonResponse } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const response = handlePostRequest(req);
  if (response) return response;

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profiles, error: profilesError } = await supabase
      .from("profiles")
      .select("id, skills, target_roles, preferred_countries");
    if (profilesError) throw profilesError;

    const { data: jobs, error: jobsError } = await supabase
      .from("jobs")
      .select("*")
      .eq("is_expired_reported", false);
    if (jobsError) throw jobsError;

    const now = new Date();
    let scored = 0;

    for (const profile of profiles ?? []) {
      const { data: existing, error: matchError } = await supabase
        .from("job_matches")
        .select("id, job_id, is_seen, is_saved, is_rejected")
        .eq("user_id", profile.id);
      if (matchError) throw matchError;

      const existingByJob = new Map((existing ?? []).map((m) => [m.job_id, m]));

      for (const job of jobs ?? []) {
        const result = scoreJob(
          {
            title: job.title,
            description: job.description ?? "",
            location_text: job.location_text ?? "Unspecified",
            location_scope: job.location_scope,
            published_at: job.published_at,
          },
          {
            skills: profile.skills ?? [],
            target_roles: profile.target_roles ?? [],
            preferred_countries: profile.preferred_countries ?? ["worldwide"],
          },
          now,
        );

        const previous = existingByJob.get(job.id);
        // match_reason carries the summary; one "Why this matched" line per row.
        const matchReason = [
          result.matchReason,
          "",
          ...result.reasons,
        ].join("\n");

        const row = {
          user_id: profile.id,
          job_id: job.id,
          match_score: result.score,
          matched_skills: result.matchedSkills,
          missing_skills: result.missingSkills,
          match_reason: matchReason,
          is_seen: previous?.is_seen ?? false,
          is_saved: previous?.is_saved ?? false,
          is_rejected: previous?.is_rejected ?? false,
        };

        const { error: upsertError } = previous
          ? await supabase.from("job_matches").update({
            match_score: row.match_score,
            matched_skills: row.matched_skills,
            missing_skills: row.missing_skills,
            match_reason: row.match_reason,
          }).eq("id", previous.id)
          : await supabase.from("job_matches").upsert(row, {
            onConflict: "user_id,job_id",
            ignoreDuplicates: true,
          });
        if (upsertError) throw upsertError;
        scored++;
      }
    }

    return jsonResponse({ scored });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
