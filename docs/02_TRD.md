# RemoteScout — Technical Requirements Document (TRD)

## 1. Purpose

Defines the technical architecture, stack, and non-functional requirements needed to build RemoteScout as described in the PRD.

## 2. Architecture Overview

```text
Job APIs (Remotive, Remote OK)
        ↓
Backend worker (Supabase Edge Function / Python worker)
        ↓
Normalize + deduplicate
        ↓
Match against user profile (rule-based scoring)
        ↓
Supabase PostgreSQL database
        ↓
Flutter app (reads via Supabase client, real-time or polling)
        ↓
Notifications (Firebase Cloud Messaging) / Email (Resend or SendGrid)
```

Key principle: **the Flutter app never calls job-source APIs directly.** All fetching, key handling, normalization, deduplication, and scoring happen server-side. This avoids leaking API keys in a client binary and keeps scoring logic consistent and centrally updatable.

## 3. Technology Stack

| Layer | Choice | Notes |
|---|---|---|
| Mobile framework | Flutter | Single codebase, targeting Android first (per user's own device use), iOS later if needed |
| State management | Riverpod | Testable, compile-safe providers |
| Routing | go_router | Declarative routing, deep-linking for job detail/notification taps |
| Backend / database | Supabase | Postgres + Auth + Edge Functions + Storage, confirmed by user |
| Scheduled jobs | Supabase Edge Functions (cron) or a small Python worker | Fetch/normalize/score on a schedule (e.g. every few hours) |
| Push notifications | Firebase Cloud Messaging (FCM) | Daily digest push |
| Email digest (optional channel) | Resend or SendGrid | Optional secondary channel for the daily digest |
| Charts | fl_chart | Statistics screen (applications over time, match score distribution) |
| Local cache | Drift or Hive (Flutter local DB) | Offline-first list caching, faster cold start |

## 4. Job Sources (MVP)

| Source | Notes |
|---|---|
| Remotive API | Requires attribution and a link back to the original Remotive listing |
| Remote OK API | Requires attribution and a link back to the original listing |

**Excluded at MVP:** We Work Remotely (routes applications through its own site and restricts copying/storing data — evaluate terms before adding), Adzuna (requires separate API key — evaluate later), direct company career-page scraping (out of scope until sources above are proven).

## 5. Backend Responsibilities

1. **Fetch** — pull listings from each source on a schedule.
2. **Normalize** — map each source's schema into the shared `jobs` table shape (see Backend Schema doc).
3. **Deduplicate** — compare `source` + `company` + `title` + `apply_url` to avoid duplicate cards.
4. **Score** — run the rule-based matcher against the stored profile, write results to `job_matches`.
5. **Expire** — flag jobs past a reasonable freshness window; never claim a stale listing is open without the user manually reporting/confirming.
6. **Notify** — once per day, compile the digest (top N jobs above the user's minimum score threshold) and push via FCM and/or trigger an email via Resend/SendGrid.

## 6. Matching Engine (rule-based, MVP — no AI)

```text
score = skill_score (0–40)
      + title_score (0–25)
      + location_score (0–20)
      + experience_score (0–10)
      + freshness_score (0–5)
```

- **Skill score** — overlap between the job's extracted/keyword-matched skills and the user's stored skills list.
- **Title score** — fuzzy match between job title and the user's target roles list.
- **Location score** — full points if the listing is worldwide-eligible; partial/zero if restricted to a region the user isn't in.
- **Experience score** — match against stated seniority level (junior-friendly keywords).
- **Freshness score** — decays the longer since `published_at`.

Every score must be paired with a human-readable `match_reason` (e.g. "Matches SQL and Excel · Worldwide eligible · Posted 2 days ago") — the scoring logic must never be a black box to the user.

**Future (explicitly deferred, not MVP):** AI-assisted skill extraction from unstructured job descriptions, AI summarization, AI-drafted cover letters. AI must never auto-submit an application; the human always makes the final "Apply" click.

## 7. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Security | No API secrets in the Flutter client; all third-party API calls happen server-side. Supabase Row Level Security (RLS) enabled on all user-data tables. |
| Privacy | No storage of third-party job-site passwords. CV files stored only in Supabase Storage (or a link the user controls) — never uploaded to unvetted third-party services. |
| Reliability | Deduplication must be deterministic — same job never appears twice across fetch cycles. |
| Performance | Job feed screen should render the day's shortlist from cache/local DB in well under 1s on a typical Android device; network fetch happens in the background worker, not on app open. |
| Offline support | Previously fetched jobs and application-tracker data remain viewable offline via local cache (Drift/Hive). |
| Attribution compliance | Every job card must display source + link back to the original listing, satisfying Remotive/Remote OK terms. |
| Extensibility | Adding a third job source should require only a new normalizer function, not a schema or scoring-engine change. |

## 8. Environments

- **Local/dev** — Supabase local dev stack or a dedicated dev project; mock job data for early UI work (Phase 1 of the PRD's phasing).
- **Production** — single Supabase project, single user (RLS still enabled as good practice for future multi-user support).

## 9. Testing Requirements

- Unit tests for the normalizer (each source → shared schema) and the scoring function (given a profile + job, expect a specific score and reason string).
- Deduplication tests using near-identical listings from the same and different sources.
- Widget tests for the job card, application-status transitions, and the profile form.
- Manual end-to-end pass each phase: real Remotive data → real score → real notification.

## 10. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Source API terms change or rate-limit | Keep fetch logic isolated per-source; degrade gracefully to fewer sources rather than failing the whole pipeline |
| Over-notification becomes noise | Hard cap on jobs/day in the digest; minimum score threshold configurable by the user |
| Stale/expired listings shown as open | `expires_at` field + manual "report expired" action + conservative freshness scoring |
| Duplicate listings across sources | Composite-key dedup (source + company + title + apply_url) enforced at write time, not just at read time |
