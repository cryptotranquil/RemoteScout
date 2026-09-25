# RemoteScout — Product Requirements Document (PRD)

## 1. Overview

**RemoteScout** is a personal remote-job discovery and application assistant, built as a Flutter mobile app. It is not a job board. It answers one question every day: *"Which remote jobs are worth my time, and what should I do next?"*

The app collects listings from a small number of trusted remote-job sources, filters and scores them against the user's own profile, and delivers a short, high-confidence daily shortlist instead of an endless feed.

## 2. Problem Statement

Junior/entry-level candidates job-hunting remotely face three recurring problems:

1. **Noise** — generic job boards return hundreds of loosely-relevant listings per search.
2. **Eligibility ambiguity** — "remote" often hides country or region restrictions that only become clear after clicking through.
3. **No tracking** — saved jobs, applications, and follow-ups end up scattered across browser tabs, spreadsheets, and email.

RemoteScout solves this for one user (you) first, with a design that could scale later.

## 3. Target User

| Attribute | Value |
|---|---|
| Primary user | You (single-user MVP; architecture allows multi-user later) |
| Target roles | Junior Data Analyst, Data Analyst Intern/Analytics Intern, Junior Business Analyst, Junior BI Analyst, Reporting Analyst, Data Technician/Data Assistant, Junior Marketing/Sales Analyst, Junior Operations Analyst |
| Core skills | SQL, Excel/Google Sheets, a BI tool (Tableau, Power BI, or Looker), basic Python/R, data cleaning, basic statistics |
| Experience level | Junior / entry-level |
| Location eligibility | Worldwide-remote roles only (no fixed country/region restriction) |
| Industry preference | Open to any industry |

## 4. Goals

- Surface 3–5 genuinely high-match remote jobs per day, not hundreds of loosely-relevant ones.
- Make location eligibility (worldwide vs. region-restricted) explicit on every job card.
- Give a transparent, explainable match score — never a black-box number.
- Track the full lifecycle of an application: New → Saved → Plan to apply → Applied → Interview → Rejected → Offer → Closed.
- Prevent duplicate listings and repeat notifications for jobs already seen.
- Never auto-apply on the user's behalf — the human stays in the loop for every submission.

## 5. Non-Goals (MVP)

- Not a public job board or multi-tenant SaaS product (single user only, for now).
- Not scraping arbitrary company career pages (only two vetted API sources at launch: Remotive and Remote OK).
- Not an AI auto-apply tool.
- Not building native web/desktop clients — Flutter mobile only.
- Not handling paid job promotions or employer-facing features.

## 6. Core Features (MVP / V1)

### 6.1 Personal Profile
Stores: target roles, skills, experience level, minimum salary, preferred time zones, allowed countries (worldwide), portfolio link, CV file/link.

### 6.2 Job Feed ("Today's Recommendations")
A short, ranked list of jobs (not a full search results page) showing title, company, salary (if available), location eligibility, employment type, required skills, posted date, source, apply link, and match score with a plain-language explanation.

### 6.3 Match Scoring
A transparent, rule-based score (skills 40%, title 25%, location eligibility 20%, experience 10%, freshness 5%) with a human-readable breakdown of why a job scored the way it did.

### 6.4 Application Tracker
Status pipeline (New → Saved → Plan to apply → Applied → Interview → Rejected → Offer → Closed) plus application date, follow-up date, CV version used, cover letter, notes, and interview details.

### 6.5 Notifications
One daily digest (not per-job alerts), with user-configurable minimum match score, max jobs per day, digest time, and weekend on/off toggle.

### 6.6 Saved / Rejected Jobs
Explicit save/reject actions that permanently remove a job from future recommendation lists (feeds the "don't show again" and dedup logic).

## 7. User Stories

- As the user, I want to fill in my skills and target roles once, so the app can score jobs for me automatically.
- As the user, I want to see *why* a job matched, so I can trust the score instead of guessing.
- As the user, I want location eligibility flagged clearly, so I don't waste time on jobs I can't legally take.
- As the user, I want one daily digest instead of constant pings, so the app doesn't become noise itself.
- As the user, I want to track every job I've applied to in one place, so I never lose track of follow-ups.
- As the user, I want every "Apply" action to open the original source listing, so I know exactly where my application goes.

## 8. Success Metrics (personal-use MVP)

- App surfaces at least 3 jobs scoring ≥70% match on most active days.
- Zero duplicate job cards shown across sessions.
- 100% of job cards link back to the original source listing (no dead/ambiguous apply links).
- User actually opens the app daily and it replaces manual job-board browsing within the first month of real use.

## 9. Constraints & Safeguards

- Always link to the original job listing; never claim a listing is open without verifying against `collected_at`/`expires_at`.
- Respect each source's terms of use (Remotive and Remote OK both require attribution and a link back to the original listing).
- No automatic application submission — the user always makes the final decision and click.
- No storage of third-party job-site passwords.
- No uploading the user's CV to unvetted third-party services.
- Manual "report expired job" action available on every job card.

## 10. Release Phasing (high-level — see Implementation Plan for detail)

1. **Phase 1 — Flutter foundation**: onboarding, profile form, mock job data, job card UI, save/reject.
2. **Phase 2 — Local tracker**: local persistence, application statuses, search/filter, dedup logic.
3. **Phase 3 — Real backend**: Supabase schema, job-fetch worker, Remotive integration, real scoring against the live profile.
4. **Phase 4 — Notifications & polish**: daily digest, follow-up reminders, statistics, Remote OK as second source, refinement from real usage.

## 11. Open Questions / Future Considerations

- Should Remote OK or a third source (e.g. Arbeitnow) be added before or after the first real-usage cycle?
- Should AI-assisted skill extraction / cover-letter drafting be scoped for a v2, kept strictly human-controlled?
- At what point (if ever) does this become multi-user?
