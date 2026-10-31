// report-expired — invoked from the app (Backend Schema §5).
//
// Sets jobs.is_expired_reported = true for a user-flagged listing so it is
// kept out of future recommendations. Delegates to the `report_expired_job`
// security-definer RPC so `jobs` stays service-role-write-only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePostRequest, jsonResponse } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const response = handlePostRequest(req);
  if (response) return response;

  try {
    const { job_id } = await req.json();
    if (!job_id) {
      return jsonResponse({ error: "job_id required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error } = await supabase.rpc("report_expired_job", {
      p_job_id: job_id,
    });
    if (error) throw error;

    return jsonResponse({ ok: true, job_id });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
