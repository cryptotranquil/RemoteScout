// fetch-jobs — scheduled Edge Function (TRD §5.1, Backend Schema §5).
//
// Pulls listings from Remotive and Remote OK, normalizes them into the shared
// `jobs` shape, and upserts with deterministic dedup. The Flutter app never
// calls job-source APIs directly.
//
// Deploy: supabase functions deploy fetch-jobs
// Secrets:  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-injected)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  crossSourceKey,
  type NormalizedJob,
  normalizeRemoteOk,
  normalizeRemotive,
} from "../_shared/normalizers.ts";
import { handlePostRequest, jsonResponse } from "../_shared/http.ts";

const REMOTIVE_URL = "https://remotive.com/api/remote-jobs?limit=100";
const REMOTEOK_URL = "https://remoteok.com/api";

Deno.serve(async (req) => {
  const response = handlePostRequest(req);
  if (response) return response;

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const collectedAt = new Date();
    const candidates: NormalizedJob[] = [];
    const errors: string[] = [];

    // Degrade gracefully: one failing source must not fail the pipeline.
    try {
      const res = await fetch(REMOTIVE_URL, {
        headers: { "User-Agent": "RemoteScout/1.0 (personal job tracker)" },
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status} ${res.statusText}`);
      }
      const data: unknown = await res.json();
      if (
        typeof data !== "object" || data === null || !("jobs" in data) ||
        !Array.isArray(data.jobs)
      ) {
        throw new Error("Invalid response: expected a jobs array");
      }
      for (const raw of data.jobs) {
        candidates.push(
          normalizeRemotive(
            raw as Parameters<typeof normalizeRemotive>[0],
            collectedAt,
          ),
        );
      }
    } catch (e) {
      errors.push(`remotive: ${e}`);
    }

    try {
      const res = await fetch(REMOTEOK_URL, {
        headers: { "User-Agent": "RemoteScout/1.0 (personal job tracker)" },
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status} ${res.statusText}`);
      }
      const data: unknown = await res.json();
      if (!Array.isArray(data)) {
        throw new Error("Invalid response: expected an array");
      }
      // First element is Remote OK's legal notice, not a job.
      for (const raw of data.slice(1)) {
        if (!raw.id || !(raw.position ?? raw.title)) continue;
        candidates.push(normalizeRemoteOk(raw, collectedAt));
      }
    } catch (e) {
      errors.push(`remoteok: ${e}`);
    }

    // Deterministic dedup: (source, external_id) via upsert conflict target,
    // plus a cross-source pass against what is already stored.
    const { data: existing, error: existingError } = await supabase
      .from("jobs")
      .select("id, source, external_id, company, title, apply_url");
    if (existingError) throw existingError;

    const ingestSeen = new Set<string>();
    const crossSeen = new Set(
      (existing ?? []).map((j) =>
        crossSourceKey(
          j as { company: string; title: string; apply_url: string },
        )
      ),
    );

    const fresh: NormalizedJob[] = [];
    for (const job of candidates) {
      const ingest = `${job.source}|${job.external_id}`;
      const cross = crossSourceKey(job);
      if (ingestSeen.has(ingest) || crossSeen.has(cross)) continue;
      ingestSeen.add(ingest);
      crossSeen.add(cross);
      fresh.push(job);
    }

    let inserted = 0;
    if (fresh.length > 0) {
      const { data: upserted, error: upsertError } = await supabase
        .from("jobs")
        .upsert(
          fresh.map((j) => ({
            external_id: j.external_id,
            source: j.source,
            title: j.title,
            company: j.company,
            description: j.description,
            apply_url: j.apply_url,
            source_url: j.source_url,
            location_text: j.location_text,
            location_scope: j.location_scope,
            salary_min: j.salary_min,
            salary_max: j.salary_max,
            currency: j.currency,
            employment_type: j.employment_type,
            published_at: j.published_at,
            collected_at: j.collected_at,
            expires_at: j.expires_at,
          })),
          { onConflict: "source,external_id", ignoreDuplicates: true },
        )
        .select("id");
      if (upsertError) throw upsertError;
      inserted = upserted?.length ?? 0;
    }

    return jsonResponse({
      fetched: candidates.length,
      inserted,
      duplicatesDiscarded: candidates.length - fresh.length,
      errors,
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
