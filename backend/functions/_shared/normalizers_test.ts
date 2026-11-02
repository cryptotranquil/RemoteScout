import {
  isHimalayasJob,
  isWorldwideAdzunaJob,
  isWorldwideArbeitnowJob,
  isWorldwideFindworkJob,
  isWorldwideJobicyJob,
  isWorldwideJoobleJob,
  isWorldwideRemoteOkJob,
  isWorldwideRemotiveJob,
  isWorldwideTheMuseJob,
  normalizeAdzuna,
  normalizeArbeitnow,
  normalizeFindwork,
  normalizeHimalayas,
  normalizeJobicy,
  normalizeJooble,
  normalizeRemoteOk,
  normalizeRemotive,
  normalizeTheMuse,
  normalizeWeWorkRemotely,
} from "./normalizers.ts";
import { parseWeWorkRemotelyRss } from "./rss.ts";

Deno.test("Himalayas normalizer preserves the application link and expiry", () => {
  const collectedAt = new Date("2026-11-01T00:00:00.000Z");
  const applicationLink =
    "https://himalayas.app/companies/example/jobs/role?utm_source=api";
  const job = normalizeHimalayas({
    guid: "https://himalayas.app/companies/example/jobs/role",
    title: "Data Analyst",
    companyName: "Example",
    applicationLink,
    locationRestrictions: [],
    timezoneRestrictions: [],
    minSalary: 70000,
    maxSalary: 90000,
    currency: "USD",
    salaryPeriod: "annual",
    employmentType: "Full Time",
    pubDate: 1793491200,
    expiryDate: 1796083200,
  }, collectedAt);

  if (job.source !== "himalayas") throw new Error("Wrong source");
  if (job.apply_url !== applicationLink) {
    throw new Error("Application link must remain unchanged");
  }
  if (job.source_url !== "https://himalayas.app/companies/example/jobs/role") {
    throw new Error("Source link should point to the Himalayas job page");
  }
  if (job.location_scope !== "worldwide") {
    throw new Error("Jobs without restrictions should be marked worldwide");
  }
  if (job.salary_min !== 70000 || job.salary_max !== 90000) {
    throw new Error("Annual salary should be retained");
  }
  if (job.expires_at !== new Date(1796083200 * 1000).toISOString()) {
    throw new Error("Expiry timestamp should be normalized");
  }
});

Deno.test("Himalayas normalizer omits salary with a non-annual period", () => {
  const job = normalizeHimalayas({
    guid: "https://himalayas.app/companies/example/jobs/role",
    title: "Data Analyst",
    companyName: "Example",
    applicationLink: "https://example.com/apply",
    minSalary: 50,
    maxSalary: 75,
    salaryPeriod: "hourly",
    employmentType: "Contractor",
    pubDate: 1793491200,
    expiryDate: 1796083200,
  }, new Date("2026-11-01T00:00:00.000Z"));

  if (job.salary_min !== null || job.salary_max !== null) {
    throw new Error("Non-annual salary must not be shown as an annual salary");
  }
  if (job.employment_type !== "contract") {
    throw new Error("Contractor should be normalized as contract");
  }
});

Deno.test("Himalayas job guard rejects incomplete entries", () => {
  if (isHimalayasJob({ title: "Missing application link" })) {
    throw new Error("Incomplete jobs must be skipped");
  }
});

Deno.test("Jobicy normalizer preserves source link and maps worldwide jobs", () => {
  const collectedAt = new Date("2026-11-01T00:00:00.000Z");
  const job = {
    id: 154189,
    url: "https://jobicy.com/jobs/154189-director-of-creative-strategy",
    jobTitle: "Director of Creative Strategy",
    companyName: "Superside",
    jobGeo: "Anywhere",
    jobType: ["Full-Time"],
    jobExcerpt: "A role summary.",
    jobDescription: "<p>Full role description.</p>",
    pubDate: "2026-10-30T03:25:26+00:00",
    salaryMin: 70000,
    salaryMax: 90000,
    salaryCurrency: "USD",
    salaryPeriod: "yearly",
  };

  if (!isWorldwideJobicyJob(job)) {
    throw new Error("Anywhere listings should be accepted");
  }
  const normalized = normalizeJobicy(job, collectedAt);
  if (normalized.source !== "jobicy") throw new Error("Wrong source");
  if (normalized.apply_url !== job.url || normalized.source_url !== job.url) {
    throw new Error("Jobicy listing link must remain intact for attribution");
  }
  if (normalized.location_scope !== "worldwide") {
    throw new Error("Anywhere listings should be marked worldwide");
  }
  if (normalized.employment_type !== "full_time") {
    throw new Error("Full-time employment type should be normalized");
  }
  if (normalized.salary_min !== 70000 || normalized.salary_max !== 90000) {
    throw new Error("Yearly salary should be retained");
  }
  if (normalized.published_at !== new Date(job.pubDate).toISOString()) {
    throw new Error("Publication date should be normalized");
  }
});

Deno.test("Jobicy rejects invalid records and non-worldwide listings", () => {
  if (isWorldwideJobicyJob({ id: 1, jobGeo: "Anywhere" })) {
    throw new Error("Incomplete listings should be rejected");
  }

  const restricted = {
    id: 2,
    url: "https://jobicy.com/jobs/2",
    jobTitle: "Restricted role",
    companyName: "Example",
    jobGeo: "United States",
    pubDate: "2026-10-30T03:25:26+00:00",
  };
  if (isWorldwideJobicyJob(restricted)) {
    throw new Error("Location-restricted listings should be excluded");
  }
});

Deno.test("Remotive only accepts complete worldwide jobs", () => {
  const raw = {
    id: 1,
    title: "Analyst",
    company_name: "Example",
    url: "https://remotive.com/remote-jobs/1",
    publication_date: "2026-10-30T00:00:00Z",
    candidate_required_location: "Worldwide",
  };
  if (!isWorldwideRemotiveJob(raw)) {
    throw new Error("Worldwide Remotive job should pass");
  }
  const job = normalizeRemotive(raw, new Date("2026-11-01T00:00:00Z"));
  if (job.location_scope !== "worldwide" || job.source_url !== raw.url) {
    throw new Error("Remotive worldwide scope and attribution should be kept");
  }
  if (
    isWorldwideRemotiveJob({
      ...raw,
      candidate_required_location: "United States",
    })
  ) {
    throw new Error("Country-restricted Remotive job should be excluded");
  }
});

Deno.test("Remote OK only accepts explicitly worldwide jobs", () => {
  const raw = {
    id: 42,
    position: "Analyst",
    company: "Example",
    url: "https://remoteok.com/remote-jobs/42",
    location: "Anywhere",
  };
  if (!isWorldwideRemoteOkJob(raw)) {
    throw new Error("Worldwide Remote OK job should pass");
  }
  const job = normalizeRemoteOk(raw, new Date("2026-11-01T00:00:00Z"));
  if (job.location_scope !== "worldwide" || job.source_url !== raw.url) {
    throw new Error("Remote OK worldwide scope and attribution should be kept");
  }
  if (isWorldwideRemoteOkJob({ ...raw, location: "Germany" })) {
    throw new Error("Country-restricted Remote OK job should be excluded");
  }
});

Deno.test("Arbeitnow requires the remote flag and worldwide location", () => {
  const raw = {
    slug: "worldwide-analyst",
    company_name: "Example",
    title: "Analyst",
    remote: true,
    url: "https://example.com/jobs/worldwide-analyst",
    job_types: ["Full-time"],
    location: "Worldwide",
    created_at: 1793491200,
  };
  if (!isWorldwideArbeitnowJob(raw)) {
    throw new Error("Worldwide Arbeitnow job should pass");
  }
  const job = normalizeArbeitnow(raw, new Date("2026-11-01T00:00:00Z"));
  if (job.source !== "arbeitnow" || job.location_scope !== "worldwide") {
    throw new Error("Arbeitnow source and location scope should be normalized");
  }
  if (isWorldwideArbeitnowJob({ ...raw, location: "Berlin", remote: true })) {
    throw new Error("Remote-only Berlin job should be excluded");
  }
});

Deno.test("Adzuna requires explicit worldwide eligibility", () => {
  const raw = {
    id: "adzuna-1",
    title: "Worldwide Analyst",
    description: "This position is available anywhere.",
    redirect_url: "https://example.com/jobs/adzuna-1",
    created: "2026-10-30T00:00:00Z",
    location: { display_name: "Remote" },
    company: { display_name: "Example" },
    salary_min: 70000,
  };
  if (!isWorldwideAdzunaJob(raw)) {
    throw new Error("Worldwide Adzuna job should pass");
  }
  const job = normalizeAdzuna(raw, new Date("2026-11-01T00:00:00Z"));
  if (
    job.location_scope !== "worldwide" || job.source_url !== raw.redirect_url
  ) {
    throw new Error("Adzuna scope and attribution should be normalized");
  }
  if (
    isWorldwideAdzunaJob({
      ...raw,
      title: "Analyst",
      description: "Remote in the United States.",
    })
  ) {
    throw new Error("Country-restricted Adzuna job should be excluded");
  }
});

Deno.test("Jooble worldwide job keeps listing link as attribution", () => {
  const raw = {
    id: "jooble-1",
    title: "Analyst",
    location: "Worldwide",
    snippet: "Remote work available anywhere.",
    link: "https://example.com/jobs/jooble-1",
    company: "Example",
  };
  if (!isWorldwideJoobleJob(raw)) {
    throw new Error("Worldwide Jooble job should pass");
  }
  const job = normalizeJooble(raw, new Date("2026-11-01T00:00:00Z"));
  if (job.location_scope !== "worldwide" || job.source_url !== raw.link) {
    throw new Error("Jooble scope and attribution should be normalized");
  }
  if (isWorldwideJoobleJob({ ...raw, location: "Canada", snippet: "" })) {
    throw new Error("Country-restricted Jooble job should be excluded");
  }
});

Deno.test("The Muse accepts only a worldwide location", () => {
  const raw = {
    id: 23,
    name: "Analyst",
    company: { name: "Example" },
    locations: [{ name: "Worldwide" }],
    refs: { landing_page: "https://example.com/jobs/23" },
    publication_date: "2026-10-30T00:00:00Z",
  };
  if (!isWorldwideTheMuseJob(raw)) {
    throw new Error("Worldwide Muse job should pass");
  }
  const job = normalizeTheMuse(raw, new Date("2026-11-01T00:00:00Z"));
  if (
    job.location_scope !== "worldwide" ||
    job.source_url !== raw.refs.landing_page
  ) {
    throw new Error("The Muse scope and attribution should be normalized");
  }
  if (
    isWorldwideTheMuseJob({
      ...raw,
      locations: [{ name: "New York" }],
    })
  ) {
    throw new Error("Country-restricted Muse job should be excluded");
  }
});

Deno.test("Findwork requires remote=true and worldwide location", () => {
  const raw = {
    id: 3,
    role: "Analyst",
    company_name: "Example",
    location: "Anywhere",
    url: "https://example.com/jobs/findwork-3",
    remote: true,
  };
  if (!isWorldwideFindworkJob(raw)) {
    throw new Error("Worldwide Findwork job should pass");
  }
  const job = normalizeFindwork(raw, new Date("2026-11-01T00:00:00Z"));
  if (job.location_scope !== "worldwide" || job.source_url !== raw.url) {
    throw new Error("Findwork scope and attribution should be normalized");
  }
  if (isWorldwideFindworkJob({ ...raw, remote: false })) {
    throw new Error("Non-remote Findwork job should be excluded");
  }
});

Deno.test("We Work Remotely RSS parser and normalizer retain attribution", () => {
  const xml = `<?xml version="1.0"?>
    <rss><channel><item>
      <title>Example Co: Analyst</title>
      <link>https://weworkremotely.com/remote-jobs/1</link>
      <guid>https://weworkremotely.com/remote-jobs/1</guid>
      <region>Worldwide</region><country></country><state></state>
      <description>&lt;p&gt;Remote role&lt;/p&gt;</description>
      <type>Full-Time</type><pubDate>Fri, 30 Oct 2026 00:00:00 GMT</pubDate>
    </item></channel></rss>`;
  const [raw] = parseWeWorkRemotelyRss(xml);
  if (!raw || raw.company !== "Example Co" || raw.location !== "Worldwide") {
    throw new Error("RSS item fields should be parsed");
  }
  const job = normalizeWeWorkRemotely(raw, new Date("2026-11-01T00:00:00Z"));
  if (
    job.source !== "weworkremotely" ||
    job.source_url !== raw.link ||
    job.location_scope !== "worldwide"
  ) {
    throw new Error(
      "RSS job source, attribution, and scope should be normalized",
    );
  }
  const restrictedXml = xml.replace(
    "<region>Worldwide</region>",
    "<region>Canada</region>",
  );
  const [restricted] = parseWeWorkRemotelyRss(restrictedXml);
  if (restricted.location === "Worldwide") {
    throw new Error("RSS location should preserve its restricted region");
  }
});
