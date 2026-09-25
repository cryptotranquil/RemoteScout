// report-expired — invoked from the app (Backend Schema §5).
//
// Sets jobs.is_expired_reported = true for a user-flagged listing so it is
// kept out of future recommendations. Delegates to the `report_expired_job`
// security-definer RPC so `jobs` stays service-role-write-only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const { job_id } = await req.json();
    if (!job_id) {
      return new Response(JSON.stringify({ error: "job_id required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error } = await supabase.rpc("report_expired_job", {
      p_job_id: job_id,
    });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, job_id }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
