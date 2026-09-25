// Per-source normalizers (TRD §5.2): map each source's schema into the shared
// `jobs` table shape. Adding a third source means adding one function here —
// no schema or scoring-engine change.

export type LocationScope = "worldwide" | "region_restricted" | "country_restricted";

export interface NormalizedJob {
  external_id: string;
  source: "remotive" | "remoteok";
  title: string;
  company: string;
  description: string;
  apply_url: string;
  source_url: string;
  location_text: string;
  location_scope: LocationScope;
  salary_min: number | null;
  salary_max: number | null;
  currency: string | null;
  employment_type: string;
  published_at: string;
  collected_at: string;
  expires_at: string | null;
}

const WORLDWIDE_MARKERS = [
  "worldwide", "anywhere", "any country", "global", "any location", "world-wide",
];

const REGION_MARKERS = [
  "europe", "emea", "americas", "apac", "latam", "africa", "asia",
  "uk ", "united kingdom", "cet", "gmt", "est ", "pst ",
];

const COUNTRY_MARKERS = [
  "united states", "usa", "us only", "u.s.", "canada", "germany",
  "netherlands", "india", "philippines", "south africa", "australia",
];

export function classifyLocation(text: string): LocationScope {
  const lower = text.toLowerCase();
  if (WORLDWIDE_MARKERS.some((m) => lower.includes(m))) return "worldwide";
  if (REGION_MARKERS.some((m) => lower.includes(m))) return "region_restricted";
  if (COUNTRY_MARKERS.some((m) => lower.includes(m))) return "country_restricted";
  // Conservative default: never claim worldwide without evidence.
  return "region_restricted";
}

function normalizeType(raw: string | undefined | null): string {
  const t = (raw ?? "").toLowerCase().replace(/\s+/g, "_");
  if (t.includes("full")) return "full_time";
  if (t.includes("part")) return "part_time";
  if (t.includes("intern")) return "internship";
  if (t.includes("free")) return "freelance";
  if (t.includes("contract")) return "contract";
  return "full_time";
}

// ----------------------------------------------------------------- Remotive
// https://remotive.com/api/remote-jobs?limit=100

interface RemotiveJob {
  id: number;
  url: string;
  title: string;
  company_name: string;
  description: string;
  location: string;
  salary?: string;
  job_type?: string;
  publication_date: string;
  candidate_required_location?: string;
}

export function normalizeRemotive(raw: RemotiveJob, collectedAt: Date): NormalizedJob {
  const locationText = raw.candidate_required_location?.trim() || raw.location || "Unspecified";
  // Remotive carries salary as free text; parse simple "USD 28,000 - 38,000".
  let salaryMin: number | null = null;
  let salaryMax: number | null = null;
  let currency: string | null = null;
  const salaryText = raw.salary ?? "";
  const match = salaryText.match(/([A-Z]{3})?\s*([\d,.]+)\s*(?:-|–|to)\s*([\d,.]+)/i);
  if (match) {
    currency = match[1]?.toUpperCase() ?? "USD";
    salaryMin = Number(match[2].replace(/[,.]/g, ""));
    salaryMax = Number(match[3].replace(/[,.]/g, ""));
  }
  return {
    external_id: String(raw.id),
    source: "remotive",
    title: raw.title.trim(),
    company: raw.company_name.trim(),
    description: raw.description,
    apply_url: raw.url,
    source_url: raw.url,
    location_text: locationText,
    location_scope: classifyLocation(locationText),
    salary_min: salaryMin,
    salary_max: salaryMax,
    currency,
    employment_type: normalizeType(raw.job_type),
    published_at: new Date(raw.publication_date).toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// ----------------------------------------------------------------- Remote OK
// https://remoteok.com/api  (first element is a legal notice — skip non-jobs)

interface RemoteOkJob {
  id: number | string;
  url?: string;
  apply_url?: string;
  position?: string;
  title?: string;
  company?: string;
  description?: string;
  location?: string;
  salary_min?: number;
  salary_max?: number;
  date?: string;
  tags?: string[];
}

export function normalizeRemoteOk(raw: RemoteOkJob, collectedAt: Date): NormalizedJob {
  const title = (raw.position ?? raw.title ?? "").trim();
  const locationText = (raw.location ?? "Unspecified").trim();
  const url = raw.url ?? raw.apply_url ?? `https://remoteok.com/remote-jobs/${raw.id}`;
  const tags = raw.tags ?? [];
  const description = [raw.description ?? "", tags.map((t) => `#${t}`).join(" ")].join("\n");
  return {
    external_id: String(raw.id),
    source: "remoteok",
    title,
    company: (raw.company ?? "Unknown").trim(),
    description,
    apply_url: raw.apply_url ?? url,
    source_url: url,
    location_text: locationText,
    location_scope: classifyLocation(locationText),
    salary_min: raw.salary_min ?? null,
    salary_max: raw.salary_max ?? null,
    currency: raw.salary_min || raw.salary_max ? "USD" : null,
    employment_type: "full_time",
    published_at: new Date(raw.date ?? collectedAt).toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// ------------------------------------------------------------------- dedup
// Mirrors lib/core/utils/dedup.dart: (source, external_id) unique plus a
// cross-source (company, title, apply_url) pass at write time.

export function crossSourceKey(job: {
  company: string;
  title: string;
  apply_url: string;
}): string {
  const company = job.company.toLowerCase().trim();
  const title = job.title.toLowerCase().trim();
  const url = job.apply_url.toLowerCase().replace(/\/+$/, "").trim();
  return `${company}|${title}|${url}`;
}
