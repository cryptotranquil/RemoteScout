# RemoteScout — Implementation Plan

No fixed calendar timeline is assumed — phases are sequential and each should be considered complete (and used for a while) before moving to the next, rather than scheduled by week.

## Phase 1 — Flutter Foundation

**Goal:** prove the core experience — seeing a relevant job and deciding what to do with it — before touching any backend.

- Create the Flutter project; set up Riverpod and go_router.
- Apply the LUNA neomorphic theme: base colors, soft shadow tokens (light + dark mode), typography.
- Build onboarding flow: target roles, skills, experience level, location (default worldwide), optional salary/time zone/portfolio/CV fields.
- Build the profile form (editable version of onboarding).
- Create a `Job` model and 5 mock jobs matching realistic junior data-analytics listings.
- Build the neomorphic job card component and the Discover screen layout.
- Add Save / Reject actions (local state only, no persistence yet).
- Build the Saved screen showing locally-saved mock jobs.

**Exit criteria:** the app is browsable end-to-end on mock data and *feels* like the intended product.

## Phase 2 — Local Job Tracker

**Goal:** make the tracking half of the app real, still without a live backend.

- Introduce local persistence (Drift or Hive) for jobs, matches, and applications.
- Implement Saved / Rejected states backed by local storage (survive app restarts).
- Build Job Details screen (full layout per App Flow §4).
- Implement the Application Tracker: status pipeline, status transitions, application detail fields (date, follow-up, CV version, cover letter, notes).
- Add search and filter on Saved and Applications screens.
- Implement duplicate-detection logic locally (source + company + title + apply_url) so it's ready to reuse against real data in Phase 3.

**Exit criteria:** the user can fully manage a job's lifecycle (save → apply → track → follow up) against mock data, with nothing lost between sessions.

## Phase 3 — Backend and Real Jobs

**Goal:** replace mock data with a real, scored, deduplicated feed.

- Stand up the Supabase project; create all tables per the Backend Schema doc, with RLS policies.
- Build the `fetch-jobs` Edge Function; connect Remotive first (single source, per TRD §4 sequencing).
- Implement the normalizer mapping Remotive's schema into the shared `jobs` table shape.
- Implement the rule-based `score-jobs` function (skills 40 / title 25 / location 20 / experience 10 / freshness 5) against the real stored profile, writing `job_matches` with a `match_reason` string.
- Wire the Flutter app to Supabase (auth, and reading `jobs`/`job_matches`/`applications` instead of local mocks).
- Verify attribution requirements are met on every real job card (source badge + link to `source_url`).

**Exit criteria:** the Discover tab shows real, scored Remotive listings with correct, explainable match scores and zero duplicates.

## Phase 4 — Notifications and Refinement

**Goal:** close the loop with the daily-digest experience and add the second source.

- Implement `send-digest` Edge Function: compile top N matches above the user's threshold, respect max-jobs-per-day and weekend toggle.
- Integrate Firebase Cloud Messaging for the push digest; wire the deep link from notification → Discover.
- (Optional secondary channel) integrate Resend or SendGrid for an email digest.
- Add follow-up reminders (surfaced from `applications.follow_up_at`).
- Add the Statistics screen (fl_chart: applications-over-time, status funnel, match-score distribution).
- Add Remote OK as the second job source, reusing the Phase 3 normalizer/scorer pipeline.
- Real-world dogfooding pass: use the app for actual job searching, tune the scoring weights and notification thresholds based on what turns out to matter in practice.

**Exit criteria:** the user gets a genuinely useful daily digest from two sources, with tracking and stats fully wired, and has adjusted scoring/notification settings based on real use.

## Backlog / Explicitly Deferred (not MVP)

- Additional sources (Arbeitnow, Adzuna, company career pages) — only after reviewing each source's terms.
- AI-assisted skill extraction, listing summarization, and cover-letter drafting — kept strictly human-controlled, never auto-submitting.
- Multi-user support (schema is RLS-ready for this, but no multi-tenant UI/billing work planned yet).
- iOS build (Android-first per current plan; revisit if needed).

## Cross-Phase Safeguards (apply from Phase 1 onward)

- Every job card always links to the original source listing.
- Never claim a listing is still open without checking `expires_at` / the manual "report expired" flag.
- No automatic application submission at any phase.
- No storage of third-party job-site passwords.
- CV files stored only in Supabase Storage (private, RLS-scoped) or as an external link — never pushed to an unvetted third-party service.
