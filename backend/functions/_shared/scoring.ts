// Shared rule-based scorer — exact mirror of
// lib/core/scoring/match_scorer.dart (TRD §6).
//
// score = skill (0–40) + title (0–25) + location (0–20)
//       + experience (0–10) + freshness (0–5)

export interface ProfileLike {
  skills: string[];
  target_roles: string[];
  preferred_countries: string[];
}

export interface JobLike {
  title: string;
  description: string;
  location_text: string;
  location_scope: "worldwide" | "region_restricted" | "country_restricted";
  published_at: string;
}

export interface ScoreBreakdown {
  skill: number;
  title: number;
  location: number;
  experience: number;
  freshness: number;
}

export interface MatchResult {
  score: number;
  matchedSkills: string[];
  missingSkills: string[];
  matchReason: string;
  breakdown: ScoreBreakdown;
  reasons: string[];
}

export const SKILL_ALIASES: Record<string, string[]> = {
  SQL: ["sql", "postgres", "postgresql", "mysql", "bigquery", "t-sql", "tsql"],
  Excel: ["excel", "vlookup", "pivot table", "pivot tables", "spreadsheets"],
  "Google Sheets": ["google sheets", "gsheets"],
  Tableau: ["tableau"],
  "Power BI": ["power bi", "powerbi", "dax"],
  Looker: ["looker", "looker studio", "lookml"],
  Python: ["python", "pandas", "numpy"],
  R: ["tidyverse", "ggplot", "shiny", "r language"],
  Statistics: ["statistics", "statistical", "hypothesis testing", "regression", "a/b testing"],
  "Data Cleaning": ["data cleaning", "data wrangling", "data quality", "data entry", "etl"],
  "Data Visualization": ["data visualization", "data visualisation", "dashboards", "dashboarding", "charting"],
  Reporting: ["reporting", "weekly reports", "monthly reports", "kpi reports"],
  Communication: ["stakeholder", "cross-functional", "communication skills"],
};

const JUNIOR_KEYWORDS = [
  "junior", "jr", "entry", "entry-level", "entry level", "intern", "internship",
  "graduate", "graduation", "trainee", "associate", "assistant", "new grad",
  "0-2 years", "0 to 2 years", "1+ year", "1 year of",
];

const SENIOR_KEYWORDS = [
  "senior", "sr", "lead", "principal", "staff", "head of",
  "5+ years", "5+ year", "7+ years", "10+ years",
];

const MID_KEYWORDS = [
  "mid-level", "mid level", "2+ years", "2+ year", "3+ years",
  "3 years of", "experienced analyst",
];

const TITLE_STOPWORDS = new Set([
  "a", "an", "the", "of", "for", "and", "to", "at", "in", "on", "with",
  "remote", "wfh", "position", "role", "i", "ii", "iii",
]);

export function canonicalSkill(input: string): string {
  const lower = input.toLowerCase().trim();
  for (const [skill, aliases] of Object.entries(SKILL_ALIASES)) {
    if (skill.toLowerCase() === lower || aliases.includes(lower)) return skill;
  }
  return input.trim();
}

export function canonicalSkills(inputs: string[]): Set<string> {
  return new Set(inputs.map(canonicalSkill));
}

function containsPhrase(text: string, phrase: string): boolean {
  if (phrase.length <= 3 || !phrase.includes(" ")) {
    const re = new RegExp(`(?<![a-z])${phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![a-z])`);
    return re.test(text);
  }
  return text.includes(phrase);
}

export function detectJobSkills(job: JobLike): Set<string> {
  const text = `${job.title} ${job.description}`.toLowerCase();
  const found = new Set<string>();
  for (const [skill, aliases] of Object.entries(SKILL_ALIASES)) {
    if (aliases.some((a) => containsPhrase(text, a))) found.add(skill);
  }
  if (!found.has("R") && /(?<![a-z])r(?![a-z])/.test(text)) {
    if (text.includes("statistic") || text.includes("analysis") || text.includes("tidy")) {
      found.add("R");
    }
  }
  return found;
}

function titleTokens(input: string): Set<string> {
  return new Set(
    input
      .toLowerCase()
      .replace(/[^a-z0-9 ]+/g, " ")
      .split(/\s+/)
      .filter((t) => t.length > 0 && !TITLE_STOPWORDS.has(t)),
  );
}

function skillScore(required: Set<string>, matched: Set<string>): number {
  if (required.size === 0) return 20;
  return Math.round((40 * matched.size) / required.size);
}

function titleScore(title: string, targetRoles: string[]): number {
  if (targetRoles.length === 0) return 0;
  const titleSet = titleTokens(title);
  let best = 0;
  for (const role of targetRoles) {
    const roleSet = titleTokens(role);
    if (roleSet.size === 0 || titleSet.size === 0) continue;
    let intersection = 0;
    for (const t of roleSet) if (titleSet.has(t)) intersection++;
    const union = new Set([...roleSet, ...titleSet]).size;
    let sim = union === 0 ? 0 : intersection / union;
    const rolePhrase = role.toLowerCase().replace(/[^a-z0-9 ]+/g, " ").trim();
    const titleLower = title.toLowerCase();
    if (rolePhrase.length > 4 &&
        (titleLower.includes(rolePhrase) || rolePhrase.includes(titleLower.trim()))) {
      sim = Math.max(sim, 0.85);
    }
    best = Math.max(best, sim);
  }
  return Math.min(25, Math.round(25 * best));
}

function locationScore(job: JobLike, profile: ProfileLike): number {
  switch (job.location_scope) {
    case "worldwide":
      return 20;
    case "region_restricted":
      return 6;
    case "country_restricted": {
      const text = job.location_text.toLowerCase();
      for (const country of profile.preferred_countries) {
        if (country.toLowerCase() === "worldwide") continue;
        if (text.includes(country.toLowerCase())) return 12;
      }
      return 2;
    }
  }
}

function experienceScore(job: JobLike): number {
  const text = `${job.title} ${job.description}`.toLowerCase();
  const mentions = (words: string[]) => words.some((w) => text.includes(w));
  if (mentions(SENIOR_KEYWORDS) && !mentions(JUNIOR_KEYWORDS)) return 0;
  if (mentions(JUNIOR_KEYWORDS)) return 10;
  if (mentions(MID_KEYWORDS)) return 4;
  return 6;
}

function freshnessScore(publishedAt: Date, now: Date): number {
  const days = Math.floor((now.getTime() - publishedAt.getTime()) / 86400000);
  if (days <= 1) return 5;
  if (days <= 3) return 4;
  if (days <= 7) return 3;
  if (days <= 14) return 2;
  if (days <= 30) return 1;
  return 0;
}

function freshnessPhrase(publishedAt: Date, now: Date): string {
  const days = Math.floor((now.getTime() - publishedAt.getTime()) / 86400000);
  if (days <= 0) return "Posted today";
  if (days === 1) return "Posted yesterday";
  if (days < 30) return `Posted ${days} days ago`;
  return "Posted over a month ago";
}

function locationPhrase(job: JobLike): string {
  switch (job.location_scope) {
    case "worldwide": return "Worldwide eligible";
    case "region_restricted": return "Region-restricted";
    case "country_restricted": return "Country-restricted";
  }
}

function joinAnd(items: string[]): string {
  if (items.length === 0) return "";
  if (items.length === 1) return items[0];
  return `${items.slice(0, -1).join(", ")} and ${items[items.length - 1]}`;
}

export function scoreJob(job: JobLike, profile: ProfileLike, now = new Date()): MatchResult {
  const userSkills = canonicalSkills(profile.skills);
  const required = detectJobSkills(job);
  const matched = [...required].filter((s) => userSkills.has(s)).sort();
  const missing = [...required].filter((s) => !userSkills.has(s)).sort();

  const skill = skillScore(required, new Set(matched));
  const title = titleScore(job.title, profile.target_roles);
  const location = locationScore(job, profile);
  const experience = experienceScore(job);
  const freshness = freshnessScore(new Date(job.published_at), now);

  const breakdown: ScoreBreakdown = { skill, title, location, experience, freshness };
  const score = Math.max(0, Math.min(100, skill + title + location + experience + freshness));

  const clauses: string[] = [];
  if (matched.length > 0) clauses.push(`Matches ${joinAnd(matched)}`);
  if (experience === 10) clauses.push("Junior-friendly");
  clauses.push(locationPhrase(job));
  clauses.push(freshnessPhrase(new Date(job.published_at), now));

  const reasons: string[] = [];
  if (matched.length > 0) reasons.push(`✓ Matches ${matched.join(", ")}`);
  if (matched.length === 0 && required.size > 0) reasons.push("— None of your listed skills called out");
  if (required.size === 0) reasons.push("— Listing does not name specific tools");
  if (experience === 10) reasons.push("✓ Junior-friendly");
  else if (experience === 0) reasons.push("— Reads as senior-level");
  else reasons.push("— Experience level unclear");
  if (location === 20) reasons.push("✓ Worldwide eligible");
  else reasons.push(`— ${locationPhrase(job)} (${job.location_text})`);
  reasons.push(`✓ ${freshnessPhrase(new Date(job.published_at), now)}`);

  return {
    score,
    matchedSkills: matched,
    missingSkills: missing,
    matchReason: clauses.join(" · "),
    breakdown,
    reasons,
  };
}
