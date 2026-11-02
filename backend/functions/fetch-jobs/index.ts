// fetch-jobs — scheduled Edge Function (TRD §5.1, Backend Schema §5).
//
// Pulls listings from supported public feeds, normalizes them into the shared
// `jobs` shape, and upserts with deterministic dedup. The Flutter app never
// calls job-source APIs directly.
//
// Deploy: supabase functions deploy fetch-jobs
// Secrets:  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-injected)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  crossSourceKey,
  isHimalayasJob,
  isWorldwideAdzunaJob,
  isWorldwideArbeitnowJob,
  isWorldwideFindworkJob,
  isWorldwideJobicyJob,
  isWorldwideJoobleJob,
  isWorldwideLocation,
  isWorldwideRemoteOkJob,
  isWorldwideRemotiveJob,
  isWorldwideTheMuseJob,
  normalizeAdzuna,
  normalizeArbeitnow,
  type NormalizedJob,
  normalizeFindwork,
  normalizeHimalayas,
  normalizeJobicy,
  normalizeJooble,
  normalizeRemoteOk,
  normalizeRemotive,
  normalizeTheMuse,
  normalizeWeWorkRemotely,
} from "../_shared/normalizers.ts";
import { handlePostRequest, jsonResponse } from "../_shared/http.ts";
import { parseWeWorkRemotelyRss } from "../_shared/rss.ts";

const REMOTIVE_URL = "https://remotive.com/api/remote-jobs?limit=100";
const REMOTEOK_URL = "https://remoteok.com/api";
const HIMALAYAS_URL = "https://himalayas.app/jobs/api";
const HIMALAYAS_PAGE_SIZE = 20;
const HIMALAYAS_MAX_PAGES = 5;
const JOBICY_URL = "https://jobicy.com/api/v2/remote-jobs";
const JOBICY_PAGE_SIZE = 100;
const JOBICY_MAX_PAGES = 5;
const ARBEITNOW_URL = "https://www.arbeitnow.com/api/job-board-api";
const ARBEITNOW_MAX_PAGES = 5;
const ADZUNA_COUNTRIES = ["gb", "us", "ca", "au", "de"];
const THEMUSE_URL = "https://www.themuse.com/api/public/jobs";
const THEMUSE_MAX_PAGES = 3;
const FINDWORK_URL = "https://findwork.dev/api/jobs/";
const JOOBLE_URL = "https://jooble.org/api";
const WEWORKREMOTELY_RSS_URL = "https://weworkremotely.com/remote-jobs.rss";
const WEWORKREMOTELY_USER_AGENT =
  "RemoteScout/1.0 (+https://github.com/cryptotranquil/RemoteScout)";

async function fetchArbeitnow(
  collectedAt: Date,
  candidates: NormalizedJob[],
): Promise<number> {
  let url: URL | null = new URL(ARBEITNOW_URL);
  let skipped = 0;
  for (let page = 0; page < ARBEITNOW_MAX_PAGES && url != null; page++) {
    const res = await fetch(url, {
      headers: { "User-Agent": WEWORKREMOTELY_USER_AGENT },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
    const payload: unknown = await res.json();
    if (
      typeof payload !== "object" || payload === null ||
      !("data" in payload) || !Array.isArray(payload.data)
    ) {
      throw new Error("Invalid response: expected a data array");
    }
    for (const raw of payload.data) {
      if (!isWorldwideArbeitnowJob(raw)) {
        skipped++;
        continue;
      }
      candidates.push(normalizeArbeitnow(raw, collectedAt));
    }
    const next = "links" in payload && typeof payload.links === "object" &&
        payload.links !== null && "next" in payload.links &&
        typeof payload.links.next === "string"
      ? payload.links.next
      : null;
    url = next ? new URL(next) : null;
  }
  return skipped;
}

async function fetchAdzuna(
  collectedAt: Date,
  candidates: NormalizedJob[],
): Promise<number> {
  const appId = Deno.env.get("ADZUNA_APP_ID");
  const appKey = Deno.env.get("ADZUNA_APP_KEY");
  if (!appId || !appKey) {
    throw new Error(
      "missing Supabase secrets ADZUNA_APP_ID and ADZUNA_APP_KEY",
    );
  }
  let skipped = 0;
  for (const country of ADZUNA_COUNTRIES) {
    const url = new URL(
      `https://api.adzuna.com/v1/api/jobs/${country}/search/1`,
    );
    url.searchParams.set("app_id", appId);
    url.searchParams.set("app_key", appKey);
    url.searchParams.set("results_per_page", "50");
    url.searchParams.set("what", "remote worldwide anywhere");
    url.searchParams.set("content-type", "application/json");
    const res = await fetch(url, {
      headers: { "User-Agent": WEWORKREMOTELY_USER_AGENT },
    });
    if (!res.ok) throw new Error(`${country}: HTTP ${res.status}`);
    const payload: unknown = await res.json();
    if (
      typeof payload !== "object" || payload === null ||
      !("results" in payload) || !Array.isArray(payload.results)
    ) {
      throw new Error(`${country}: invalid response, expected results array`);
    }
    for (const raw of payload.results) {
      if (!isWorldwideAdzunaJob(raw)) {
        skipped++;
        continue;
      }
      candidates.push(normalizeAdzuna(raw, collectedAt));
    }
  }
  return skipped;
}

async function fetchJooble(
  collectedAt: Date,
  candidates: NormalizedJob[],
): Promise<number> {
  const apiKey = Deno.env.get("JOOBLE_API_KEY");
  if (!apiKey) throw new Error("missing Supabase secret JOOBLE_API_KEY");
  const res = await fetch(`${JOOBLE_URL}/${encodeURIComponent(apiKey)}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": WEWORKREMOTELY_USER_AGENT,
    },
    body: JSON.stringify({
      keywords: "remote worldwide work from anywhere",
      location: "Worldwide",
      page: 1,
    }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
  const payload: unknown = await res.json();
  if (
    typeof payload !== "object" || payload === null ||
    !("jobs" in payload) || !Array.isArray(payload.jobs)
  ) {
    throw new Error("Invalid response: expected a jobs array");
  }
  let skipped = 0;
  for (const raw of payload.jobs) {
    if (!isWorldwideJoobleJob(raw)) {
      skipped++;
      continue;
    }
    candidates.push(normalizeJooble(raw, collectedAt));
  }
  return skipped;
}

async function fetchTheMuse(
  collectedAt: Date,
  candidates: NormalizedJob[],
): Promise<number> {
  let skipped = 0;
  for (let page = 0; page < THEMUSE_MAX_PAGES; page++) {
    const url = new URL(THEMUSE_URL);
    url.searchParams.set("page", String(page));
    url.searchParams.set("location", "Worldwide Remote");
    const res = await fetch(url, {
      headers: { "User-Agent": WEWORKREMOTELY_USER_AGENT },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
    const payload: unknown = await res.json();
    if (
      typeof payload !== "object" || payload === null ||
      !("results" in payload) || !Array.isArray(payload.results)
    ) {
      throw new Error("Invalid response: expected a results array");
    }
    if (payload.results.length === 0) break;
    for (const raw of payload.results) {
      if (!isWorldwideTheMuseJob(raw)) {
        skipped++;
        continue;
      }
      candidates.push(normalizeTheMuse(raw, collectedAt));
    }
  }
  return skipped;
}

async function fetchFindwork(
  collectedAt: Date,
  candidates: NormalizedJob[],
): Promise<number> {
  const apiKey = Deno.env.get("FINDWORK_API_KEY");
  if (!apiKey) throw new Error("missing Supabase secret FINDWORK_API_KEY");
  const url = new URL(FINDWORK_URL);
  url.searchParams.set("remote", "true");
  const res = await fetch(url, {
    headers: {
      "Authorization": `Token ${apiKey}`,
      "User-Agent": WEWORKREMOTELY_USER_AGENT,
    },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
  const payload: unknown = await res.json();
  if (
    typeof payload !== "object" || payload === null ||
    !("results" in payload) || !Array.isArray(payload.results)
  ) {
    throw new Error("Invalid response: expected a results array");
  }
  let skipped = 0;
  for (const raw of payload.results) {
    if (!isWorldwideFindworkJob(raw)) {
      skipped++;
      continue;
    }
    candidates.push(normalizeFindwork(raw, collectedAt));
  }
  return skipped;
}

async function fetchWeWorkRemotely(
  collectedAt: Date,
  candidates: NormalizedJob[],
): Promise<number> {
  const res = await fetch(WEWORKREMOTELY_RSS_URL, {
    headers: { "User-Agent": WEWORKREMOTELY_USER_AGENT },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
  const items = parseWeWorkRemotelyRss(await res.text());
  let skipped = 0;
  for (const item of items) {
    if (!isWorldwideLocation(item.location)) {
      skipped++;
      continue;
    }
    candidates.push(normalizeWeWorkRemotely(item, collectedAt));
  }
  return skipped;
}

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
      let skippedListings = 0;
      for (const raw of data.jobs) {
        if (!isWorldwideRemotiveJob(raw)) {
          skippedListings++;
          continue;
        }
        candidates.push(normalizeRemotive(raw, collectedAt));
      }
      if (skippedListings > 0) {
        errors.push(
          `remotive: skipped ${skippedListings} invalid or restricted listings`,
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
      let skippedListings = 0;
      for (const raw of data.slice(1)) {
        if (!isWorldwideRemoteOkJob(raw)) {
          skippedListings++;
          continue;
        }
        candidates.push(normalizeRemoteOk(raw, collectedAt));
      }
      if (skippedListings > 0) {
        errors.push(
          `remoteok: skipped ${skippedListings} invalid or restricted listings`,
        );
      }
    } catch (e) {
      errors.push(`remoteok: ${e}`);
    }

    try {
      let cursor: string | null = null;
      let malformedJobs = 0;
      let restrictedJobs = 0;
      for (let page = 0; page < HIMALAYAS_MAX_PAGES; page++) {
        const url = new URL(HIMALAYAS_URL);
        url.searchParams.set("limit", String(HIMALAYAS_PAGE_SIZE));
        if (cursor != null) url.searchParams.set("cursor", cursor);
        const res = await fetch(url, {
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
          if (!isHimalayasJob(raw)) {
            malformedJobs++;
            continue;
          }
          const job = normalizeHimalayas(raw, collectedAt);
          if (raw.expiryDate * 1000 <= collectedAt.getTime()) {
            continue;
          }
          if (job.location_scope !== "worldwide") {
            restrictedJobs++;
            continue;
          }
          candidates.push(job);
        }
        cursor = "nextCursor" in data && typeof data.nextCursor === "string"
          ? data.nextCursor
          : null;
        if (cursor == null || cursor.length === 0 || data.jobs.length === 0) {
          break;
        }
      }
      if (malformedJobs > 0) {
        errors.push(`himalayas: skipped ${malformedJobs} malformed listings`);
      }
      if (restrictedJobs > 0) {
        errors.push(
          `himalayas: skipped ${restrictedJobs} region-restricted listings`,
        );
      }
    } catch (e) {
      errors.push(`himalayas: ${e}`);
    }

    try {
      let cursor: string | null = null;
      let skippedListings = 0;
      for (let page = 0; page < JOBICY_MAX_PAGES; page++) {
        const url = new URL(JOBICY_URL);
        url.searchParams.set("count", String(JOBICY_PAGE_SIZE));
        url.searchParams.set("geo", "anywhere");
        if (cursor != null) url.searchParams.set("cursor", cursor);
        const res = await fetch(url, {
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
          if (!isWorldwideJobicyJob(raw)) {
            skippedListings++;
            continue;
          }
          candidates.push(normalizeJobicy(raw, collectedAt));
        }
        cursor = "nextCursor" in data && typeof data.nextCursor === "string"
          ? data.nextCursor
          : null;
        if (cursor == null || cursor.length === 0 || data.jobs.length === 0) {
          break;
        }
      }
      if (skippedListings > 0) {
        errors.push(
          `jobicy: skipped ${skippedListings} invalid or restricted listings`,
        );
      }
    } catch (e) {
      errors.push(`jobicy: ${e}`);
    }

    const runSource = async (
      name: string,
      fetchSource: () => Promise<number>,
    ) => {
      try {
        const skipped = await fetchSource();
        if (skipped > 0) {
          errors.push(
            `${name}: skipped ${skipped} non-worldwide or invalid listings`,
          );
        }
      } catch (e) {
        errors.push(`${name}: ${e}`);
      }
    };

    await runSource("arbeitnow", () => fetchArbeitnow(collectedAt, candidates));
    await runSource("adzuna", () => fetchAdzuna(collectedAt, candidates));
    await runSource("jooble", () => fetchJooble(collectedAt, candidates));
    await runSource("themuse", () => fetchTheMuse(collectedAt, candidates));
    await runSource("findwork", () => fetchFindwork(collectedAt, candidates));
    await runSource(
      "weworkremotely",
      () => fetchWeWorkRemotely(collectedAt, candidates),
    );

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
