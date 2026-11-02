// Per-source normalizers (TRD §5.2): map each source's schema into the shared
// `jobs` table shape. New sources also need a matching database constraint.

export type LocationScope =
  | "worldwide"
  | "region_restricted"
  | "country_restricted";

export interface NormalizedJob {
  external_id: string;
  source:
    | "remotive"
    | "remoteok"
    | "himalayas"
    | "jobicy"
    | "arbeitnow"
    | "adzuna"
    | "jooble"
    | "themuse"
    | "findwork"
    | "weworkremotely";
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
  "worldwide",
  "anywhere",
  "any country",
  "any location",
  "world-wide",
  "work from anywhere",
  "remote globally",
  "global remote",
];

const REGION_MARKERS = [
  "europe",
  "emea",
  "americas",
  "apac",
  "latam",
  "africa",
  "asia",
  "uk ",
  "united kingdom",
  "cet",
  "gmt",
  "est ",
  "pst ",
];

const COUNTRY_MARKERS = [
  "united states",
  "usa",
  "us only",
  "u.s.",
  "canada",
  "germany",
  "netherlands",
  "india",
  "philippines",
  "south africa",
  "australia",
];

export function classifyLocation(text: string): LocationScope {
  const lower = text.toLowerCase();
  if (REGION_MARKERS.some((m) => lower.includes(m))) return "region_restricted";
  if (COUNTRY_MARKERS.some((m) => lower.includes(m))) {
    return "country_restricted";
  }
  if (isWorldwideLocation(text)) return "worldwide";
  // Conservative default: never claim worldwide without evidence.
  return "region_restricted";
}

export function isWorldwideLocation(text: string): boolean {
  const lower = text.toLowerCase().trim();
  const isRestricted =
    REGION_MARKERS.some((marker) => lower.includes(marker)) ||
    COUNTRY_MARKERS.some((marker) => lower.includes(marker));
  return !isRestricted &&
    (WORLDWIDE_MARKERS.some((marker) => lower.includes(marker)) ||
      lower === "global remote" || lower === "fully remote worldwide");
}

function normalizeType(raw: string | undefined | null): string {
  const t = (raw ?? "").toLowerCase().replace(/\s+/g, "_");
  if (t.includes("full")) return "full_time";
  if (t.includes("part")) return "part_time";
  if (t.includes("intern")) return "internship";
  if (t.includes("free")) return "freelance";
  if (t.includes("contract")) return "contract";
  if (t.includes("temp")) return "contract";
  return "full_time";
}

function normalizeJobicyType(raw: string | string[] | undefined): string {
  return normalizeType(Array.isArray(raw) ? raw.join(" ") : raw);
}

// ----------------------------------------------------------------- Remotive
// https://remotive.com/api/remote-jobs?limit=100

interface RemotiveJob {
  id: number;
  url: string;
  title: string;
  company_name: string;
  description?: string;
  location?: string;
  salary?: string;
  job_type?: string;
  publication_date: string;
  candidate_required_location?: string;
}

export function isWorldwideRemotiveJob(raw: unknown): raw is RemotiveJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  const location = typeof job.candidate_required_location === "string"
    ? job.candidate_required_location
    : typeof job.location === "string"
    ? job.location
    : "";
  return typeof job.id === "number" &&
    typeof job.url === "string" &&
    typeof job.title === "string" &&
    typeof job.company_name === "string" &&
    typeof job.publication_date === "string" &&
    Number.isFinite(Date.parse(job.publication_date)) &&
    (job.location === undefined || typeof job.location === "string") &&
    (job.candidate_required_location === undefined ||
      typeof job.candidate_required_location === "string") &&
    (job.description === undefined || typeof job.description === "string") &&
    (job.salary === undefined || typeof job.salary === "string") &&
    (job.job_type === undefined || typeof job.job_type === "string") &&
    isWorldwideLocation(location);
}

export function normalizeRemotive(
  raw: RemotiveJob,
  collectedAt: Date,
): NormalizedJob {
  const locationText = raw.candidate_required_location?.trim() ||
    raw.location || "Unspecified";
  // Remotive carries salary as free text; parse simple "USD 28,000 - 38,000".
  let salaryMin: number | null = null;
  let salaryMax: number | null = null;
  let currency: string | null = null;
  const salaryText = raw.salary ?? "";
  const match = salaryText.match(
    /([A-Z]{3})?\s*([\d,.]+)\s*(?:-|–|to)\s*([\d,.]+)/i,
  );
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
    description: raw.description ?? "",
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

export function isWorldwideRemoteOkJob(raw: unknown): raw is RemoteOkJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  const location = typeof job.location === "string" ? job.location : "";
  return (typeof job.id === "number" || typeof job.id === "string") &&
    typeof (job.position ?? job.title) === "string" &&
    typeof job.url === "string" &&
    (job.apply_url === undefined || typeof job.apply_url === "string") &&
    (job.company === undefined || typeof job.company === "string") &&
    (job.description === undefined || typeof job.description === "string") &&
    (job.salary_min === undefined ||
      (typeof job.salary_min === "number" &&
        Number.isFinite(job.salary_min))) &&
    (job.salary_max === undefined ||
      (typeof job.salary_max === "number" &&
        Number.isFinite(job.salary_max))) &&
    (job.date === undefined ||
      (typeof job.date === "string" &&
        Number.isFinite(Date.parse(job.date)))) &&
    (job.tags === undefined ||
      (Array.isArray(job.tags) &&
        job.tags.every((value) => typeof value === "string"))) &&
    isWorldwideLocation(location);
}

export function normalizeRemoteOk(
  raw: RemoteOkJob,
  collectedAt: Date,
): NormalizedJob {
  const title = (raw.position ?? raw.title ?? "").trim();
  const locationText = (raw.location ?? "Unspecified").trim();
  const url = raw.url ?? raw.apply_url ??
    `https://remoteok.com/remote-jobs/${raw.id}`;
  const tags = raw.tags ?? [];
  const description = [
    raw.description ?? "",
    tags.map((t) => `#${t}`).join(" "),
  ].join("\n");
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

// --------------------------------------------------------------- Himalayas
// https://himalayas.app/jobs/api

interface HimalayasJob {
  guid: string;
  title: string;
  companyName: string;
  description?: string;
  applicationLink: string;
  locationRestrictions?: string[];
  timezoneRestrictions?: number[];
  minSalary?: number | null;
  maxSalary?: number | null;
  salaryPeriod?: string;
  currency?: string | null;
  employmentType?: string;
  pubDate: number;
  expiryDate: number;
}

export function isHimalayasJob(raw: unknown): raw is HimalayasJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  return typeof job.guid === "string" &&
    typeof job.title === "string" &&
    typeof job.companyName === "string" &&
    typeof job.applicationLink === "string" &&
    typeof job.pubDate === "number" &&
    Number.isFinite(job.pubDate) &&
    Number.isFinite(new Date(job.pubDate * 1000).getTime()) &&
    typeof job.expiryDate === "number" &&
    Number.isFinite(job.expiryDate) &&
    Number.isFinite(new Date(job.expiryDate * 1000).getTime()) &&
    (job.description === undefined || typeof job.description === "string") &&
    (job.locationRestrictions === undefined ||
      (Array.isArray(job.locationRestrictions) &&
        job.locationRestrictions.every((value) =>
          typeof value === "string"
        ))) &&
    (job.timezoneRestrictions === undefined ||
      (Array.isArray(job.timezoneRestrictions) &&
        job.timezoneRestrictions.every((value) =>
          typeof value === "number"
        ))) &&
    (job.minSalary === undefined || job.minSalary === null ||
      (typeof job.minSalary === "number" &&
        Number.isFinite(job.minSalary))) &&
    (job.maxSalary === undefined || job.maxSalary === null ||
      (typeof job.maxSalary === "number" &&
        Number.isFinite(job.maxSalary))) &&
    (job.salaryPeriod === undefined || typeof job.salaryPeriod === "string") &&
    (job.currency === undefined || job.currency === null ||
      typeof job.currency === "string") &&
    (job.employmentType === undefined ||
      typeof job.employmentType === "string");
}

export function normalizeHimalayas(
  raw: HimalayasJob,
  collectedAt: Date,
): NormalizedJob {
  const locations = raw.locationRestrictions ?? [];
  const timezones = raw.timezoneRestrictions ?? [];
  const timezoneText = timezones.length > 0
    ? `UTC ${
      timezones.map((offset) => offset >= 0 ? "+" + offset : offset).join(", ")
    }`
    : null;
  const locationText = locations.length > 0
    ? [locations.join(", "), timezoneText].filter(Boolean).join(" · ")
    : timezoneText
    ? `Time-zone restricted (${timezoneText})`
    : "Worldwide";
  const annualSalary = !raw.salaryPeriod || raw.salaryPeriod === "annual";
  const publishedAt = new Date(raw.pubDate * 1000);
  const expiresAt = new Date(raw.expiryDate * 1000);

  return {
    external_id: raw.guid,
    source: "himalayas",
    title: raw.title.trim(),
    company: raw.companyName.trim(),
    description: raw.description ?? "",
    // Himalayas requires applicationLink to be used unchanged.
    apply_url: raw.applicationLink,
    source_url: raw.guid,
    location_text: locationText,
    location_scope: classifyLocation(locationText),
    salary_min: annualSalary ? raw.minSalary ?? null : null,
    salary_max: annualSalary ? raw.maxSalary ?? null : null,
    currency: annualSalary ? raw.currency ?? null : null,
    employment_type: normalizeType(raw.employmentType),
    published_at: publishedAt.toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: expiresAt.toISOString(),
  };
}

// ------------------------------------------------------------------- Jobicy
// https://jobicy.com/api/v2/remote-jobs

interface JobicyJob {
  id: number | string;
  url: string;
  jobTitle: string;
  companyName: string;
  jobGeo: string;
  jobType?: string | string[];
  jobDescription?: string;
  jobExcerpt?: string;
  pubDate: string;
  salaryMin?: number | null;
  salaryMax?: number | null;
  salaryCurrency?: string | null;
  salaryPeriod?: string;
}

export function isJobicyJob(raw: unknown): raw is JobicyJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  return (typeof job.id === "number" || typeof job.id === "string") &&
    typeof job.url === "string" &&
    typeof job.jobTitle === "string" &&
    typeof job.companyName === "string" &&
    typeof job.jobGeo === "string" &&
    typeof job.pubDate === "string" &&
    Number.isFinite(Date.parse(job.pubDate)) &&
    (job.jobType === undefined || typeof job.jobType === "string" ||
      (Array.isArray(job.jobType) &&
        job.jobType.every((value) => typeof value === "string"))) &&
    (job.jobDescription === undefined ||
      typeof job.jobDescription === "string") &&
    (job.jobExcerpt === undefined || typeof job.jobExcerpt === "string") &&
    (job.salaryMin === undefined || job.salaryMin === null ||
      (typeof job.salaryMin === "number" &&
        Number.isFinite(job.salaryMin))) &&
    (job.salaryMax === undefined || job.salaryMax === null ||
      (typeof job.salaryMax === "number" &&
        Number.isFinite(job.salaryMax))) &&
    (job.salaryCurrency === undefined || job.salaryCurrency === null ||
      typeof job.salaryCurrency === "string") &&
    (job.salaryPeriod === undefined ||
      typeof job.salaryPeriod === "string");
}

export function isWorldwideJobicyJob(raw: unknown): raw is JobicyJob {
  return isJobicyJob(raw) &&
    ["anywhere", "worldwide"].includes(raw.jobGeo.trim().toLowerCase());
}

export function normalizeJobicy(
  raw: JobicyJob,
  collectedAt: Date,
): NormalizedJob {
  const annualSalary = raw.salaryPeriod == null ||
    ["annual", "annually", "year", "yearly"].includes(
      raw.salaryPeriod.trim().toLowerCase(),
    );
  const jobDescription = raw.jobDescription?.trim() ||
    raw.jobExcerpt?.trim() || "";

  return {
    external_id: String(raw.id),
    source: "jobicy",
    title: raw.jobTitle.trim(),
    company: raw.companyName.trim(),
    description: jobDescription,
    // The public API returns the Jobicy listing URL as its application URL.
    apply_url: raw.url,
    source_url: raw.url,
    location_text: raw.jobGeo.trim(),
    location_scope: "worldwide",
    salary_min: annualSalary ? raw.salaryMin ?? null : null,
    salary_max: annualSalary ? raw.salaryMax ?? null : null,
    currency: annualSalary ? raw.salaryCurrency ?? null : null,
    employment_type: normalizeJobicyType(raw.jobType),
    published_at: new Date(raw.pubDate).toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// --------------------------------------------------------------- Arbeitnow

interface ArbeitnowJob {
  slug: string;
  company_name: string;
  title: string;
  description?: string;
  remote: boolean;
  url: string;
  job_types?: string[];
  location: string;
  created_at: number;
}

export function isWorldwideArbeitnowJob(raw: unknown): raw is ArbeitnowJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  return typeof job.slug === "string" &&
    typeof job.company_name === "string" &&
    typeof job.title === "string" &&
    job.remote === true &&
    typeof job.url === "string" &&
    typeof job.location === "string" &&
    isWorldwideLocation(job.location) &&
    typeof job.created_at === "number" &&
    Number.isFinite(job.created_at) &&
    Number.isFinite(new Date(job.created_at * 1000).getTime()) &&
    (job.description === undefined || typeof job.description === "string") &&
    (job.job_types === undefined ||
      (Array.isArray(job.job_types) &&
        job.job_types.every((value) => typeof value === "string")));
}

export function normalizeArbeitnow(
  raw: ArbeitnowJob,
  collectedAt: Date,
): NormalizedJob {
  return {
    external_id: raw.slug,
    source: "arbeitnow",
    title: raw.title.trim(),
    company: raw.company_name.trim(),
    description: raw.description ?? "",
    apply_url: raw.url,
    source_url: raw.url,
    location_text: raw.location.trim(),
    location_scope: "worldwide",
    salary_min: null,
    salary_max: null,
    currency: null,
    employment_type: normalizeType(raw.job_types?.join(" ")),
    published_at: new Date(raw.created_at * 1000).toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// ------------------------------------------------------------------- Adzuna

interface AdzunaJob {
  id: string | number;
  title: string;
  description?: string;
  redirect_url: string;
  created: string;
  location?: { display_name?: string };
  company?: { display_name?: string };
  salary_min?: number;
  salary_max?: number;
  contract_type?: string;
  contract_time?: string;
}

export function isWorldwideAdzunaJob(raw: unknown): raw is AdzunaJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  const location = typeof job.location === "object" && job.location !== null
    ? job.location as Record<string, unknown>
    : undefined;
  const company = typeof job.company === "object" && job.company !== null
    ? job.company as Record<string, unknown>
    : undefined;
  const validLocation = job.location === undefined || job.location === null ||
    (typeof job.location === "object" && !Array.isArray(job.location) &&
      (location?.display_name === undefined ||
        typeof location.display_name === "string"));
  const validCompany = job.company === undefined || job.company === null ||
    (typeof job.company === "object" && !Array.isArray(job.company) &&
      (company?.display_name === undefined ||
        typeof company.display_name === "string"));
  const worldwideText = [
    job.title,
    job.description,
    location?.display_name,
  ].filter((value): value is string => typeof value === "string").join(" ");
  return (typeof job.id === "number" || typeof job.id === "string") &&
    typeof job.title === "string" &&
    typeof job.redirect_url === "string" &&
    typeof job.created === "string" &&
    Number.isFinite(Date.parse(job.created)) &&
    (job.description === undefined || typeof job.description === "string") &&
    validLocation &&
    validCompany &&
    (job.salary_min === undefined ||
      (typeof job.salary_min === "number" &&
        Number.isFinite(job.salary_min))) &&
    (job.salary_max === undefined ||
      (typeof job.salary_max === "number" &&
        Number.isFinite(job.salary_max))) &&
    (job.contract_type === undefined ||
      typeof job.contract_type === "string") &&
    (job.contract_time === undefined ||
      typeof job.contract_time === "string") &&
    isWorldwideLocation(worldwideText);
}

export function normalizeAdzuna(
  raw: AdzunaJob,
  collectedAt: Date,
): NormalizedJob {
  const location = raw.location?.display_name?.trim() || "Worldwide remote";
  return {
    external_id: String(raw.id),
    source: "adzuna",
    title: raw.title.trim(),
    company: raw.company?.display_name?.trim() || "Unknown",
    description: raw.description ?? "",
    apply_url: raw.redirect_url,
    source_url: raw.redirect_url,
    location_text: location,
    location_scope: "worldwide",
    salary_min: raw.salary_min ?? null,
    salary_max: raw.salary_max ?? null,
    currency: null,
    employment_type: normalizeType(
      `${raw.contract_time ?? ""} ${raw.contract_type ?? ""}`,
    ),
    published_at: new Date(raw.created).toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// -------------------------------------------------------------------- Jooble

interface JoobleJob {
  id?: string | number;
  title: string;
  location?: string;
  snippet?: string;
  salary?: string;
  type?: string;
  link: string;
  updated?: string;
  company?: string;
}

export function isWorldwideJoobleJob(raw: unknown): raw is JoobleJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  const listingText = [job.title, job.location, job.snippet]
    .filter((value): value is string => typeof value === "string").join(" ");
  return typeof job.title === "string" &&
    typeof job.link === "string" &&
    (job.id === undefined || typeof job.id === "string") &&
    (job.location === undefined || typeof job.location === "string") &&
    (job.snippet === undefined || typeof job.snippet === "string") &&
    (job.company === undefined || typeof job.company === "string") &&
    (job.type === undefined || typeof job.type === "string") &&
    (job.updated === undefined || typeof job.updated === "string") &&
    isWorldwideLocation(listingText);
}

export function normalizeJooble(
  raw: JoobleJob,
  collectedAt: Date,
): NormalizedJob {
  return {
    external_id: String(raw.id ?? raw.link),
    source: "jooble",
    title: raw.title.trim(),
    company: raw.company?.trim() || "Unknown",
    description: raw.snippet ?? "",
    apply_url: raw.link,
    source_url: raw.link,
    location_text: raw.location?.trim() || "Worldwide remote",
    location_scope: "worldwide",
    salary_min: null,
    salary_max: null,
    currency: null,
    employment_type: normalizeType(raw.type),
    published_at: raw.updated && Number.isFinite(Date.parse(raw.updated))
      ? new Date(raw.updated).toISOString()
      : collectedAt.toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// ------------------------------------------------------------------ The Muse

interface TheMuseJob {
  id: number | string;
  name: string;
  contents?: string;
  company?: { name?: string };
  locations?: Array<{ name?: string }>;
  refs: { landing_page: string };
  publication_date?: string;
  levels?: Array<{ name?: string }>;
  type?: string;
}

export function isWorldwideTheMuseJob(raw: unknown): raw is TheMuseJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  const locations = Array.isArray(job.locations) ? job.locations : [];
  const locationText = locations.map((location) => {
    if (typeof location !== "object" || location === null) return "";
    const name = (location as Record<string, unknown>).name;
    return typeof name === "string" ? name : "";
  }).join(" ");
  return (typeof job.id === "number" || typeof job.id === "string") &&
    typeof job.name === "string" &&
    typeof job.refs === "object" &&
    job.refs !== null &&
    typeof (job.refs as Record<string, unknown>).landing_page === "string" &&
    (job.company === undefined ||
      (typeof job.company === "object" && job.company !== null &&
        ((job.company as Record<string, unknown>).name === undefined ||
          typeof (job.company as Record<string, unknown>).name ===
            "string"))) &&
    (job.locations === undefined ||
      (Array.isArray(job.locations) &&
        job.locations.every((location) =>
          typeof location === "object" && location !== null &&
          ((location as Record<string, unknown>).name === undefined ||
            typeof (location as Record<string, unknown>).name === "string")
        ))) &&
    (job.levels === undefined ||
      (Array.isArray(job.levels) &&
        job.levels.every((level) =>
          typeof level === "object" && level !== null &&
          ((level as Record<string, unknown>).name === undefined ||
            typeof (level as Record<string, unknown>).name === "string")
        ))) &&
    (job.contents === undefined || typeof job.contents === "string") &&
    (job.publication_date === undefined ||
      (typeof job.publication_date === "string" &&
        Number.isFinite(Date.parse(job.publication_date)))) &&
    (job.type === undefined || typeof job.type === "string") &&
    isWorldwideLocation(locationText);
}

export function normalizeTheMuse(
  raw: TheMuseJob,
  collectedAt: Date,
): NormalizedJob {
  const locations = (raw.locations ?? [])
    .map((location) => location.name)
    .filter((location): location is string => Boolean(location));
  const locationText = locations.join(", ") || "Worldwide remote";
  return {
    external_id: String(raw.id),
    source: "themuse",
    title: raw.name.trim(),
    company: raw.company?.name?.trim() || "Unknown",
    description: raw.contents ?? "",
    apply_url: raw.refs.landing_page,
    source_url: raw.refs.landing_page,
    location_text: locationText,
    location_scope: "worldwide",
    salary_min: null,
    salary_max: null,
    currency: null,
    employment_type: normalizeType(
      `${raw.type ?? ""} ${
        (raw.levels ?? []).map((level) => level.name ?? "").join(" ")
      }`,
    ),
    published_at: raw.publication_date &&
        Number.isFinite(Date.parse(raw.publication_date))
      ? new Date(raw.publication_date).toISOString()
      : collectedAt.toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// ----------------------------------------------------------------- Findwork

interface FindworkJob {
  id: string | number;
  role: string;
  company_name?: string;
  location?: string;
  url: string;
  text?: string;
  date_posted?: string;
  remote: boolean;
  employment_type?: string;
}

export function isWorldwideFindworkJob(raw: unknown): raw is FindworkJob {
  if (typeof raw !== "object" || raw === null) return false;
  const job = raw as Record<string, unknown>;
  const location = typeof job.location === "string" ? job.location : "";
  return (typeof job.id === "number" || typeof job.id === "string") &&
    typeof job.role === "string" &&
    typeof job.url === "string" &&
    typeof job.remote === "boolean" &&
    job.remote === true &&
    isWorldwideLocation(location) &&
    (job.company_name === undefined || typeof job.company_name === "string") &&
    (job.text === undefined || typeof job.text === "string") &&
    (job.date_posted === undefined || typeof job.date_posted === "string") &&
    (job.employment_type === undefined ||
      typeof job.employment_type === "string");
}

export function normalizeFindwork(
  raw: FindworkJob,
  collectedAt: Date,
): NormalizedJob {
  return {
    external_id: String(raw.id),
    source: "findwork",
    title: raw.role.trim(),
    company: raw.company_name?.trim() || "Unknown",
    description: raw.text ?? "",
    apply_url: raw.url,
    source_url: raw.url,
    location_text: raw.location?.trim() || "Worldwide remote",
    location_scope: "worldwide",
    salary_min: null,
    salary_max: null,
    currency: null,
    employment_type: normalizeType(raw.employment_type),
    published_at: raw.date_posted &&
        Number.isFinite(Date.parse(raw.date_posted))
      ? new Date(raw.date_posted).toISOString()
      : collectedAt.toISOString(),
    collected_at: collectedAt.toISOString(),
    expires_at: null,
  };
}

// --------------------------------------------------------- We Work Remotely

export interface WeWorkRemotelyJob {
  id: string;
  title: string;
  company: string;
  link: string;
  location: string;
  description?: string;
  type?: string;
  pubDate?: string;
}

export function normalizeWeWorkRemotely(
  raw: WeWorkRemotelyJob,
  collectedAt: Date,
): NormalizedJob {
  const separator = raw.title.indexOf(":");
  const titleCompany = separator > 0
    ? raw.title.slice(0, separator).trim()
    : raw.company;
  const title = separator > 0
    ? raw.title.slice(separator + 1).trim()
    : raw.title.trim();
  return {
    external_id: raw.id,
    source: "weworkremotely",
    title,
    company: raw.company || titleCompany || "Unknown",
    description: raw.description ?? "",
    apply_url: raw.link,
    source_url: raw.link,
    location_text: raw.location || "Worldwide remote",
    location_scope: "worldwide",
    salary_min: null,
    salary_max: null,
    currency: null,
    employment_type: normalizeType(raw.type),
    published_at: raw.pubDate && Number.isFinite(Date.parse(raw.pubDate))
      ? new Date(raw.pubDate).toISOString()
      : collectedAt.toISOString(),
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
