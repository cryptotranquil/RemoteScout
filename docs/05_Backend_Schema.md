# RemoteScout — Backend Schema (Supabase / PostgreSQL)

## 1. Design Principles

- One Supabase Postgres project; Row Level Security (RLS) enabled on every user-scoped table, even for a single-user MVP, so it's multi-user-ready later.
- `jobs` is source-of-truth normalized data, shared across users; `job_matches` and `applications` are per-user.
- Every job row keeps `source_url` and `apply_url` separately so the app always directs to the original listing (attribution compliance, per TRD §7).

## 2. Tables

### 2.1 `profiles`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, PK | matches `auth.users.id` |
| `name` | text | |
| `email` | text | |
| `skills` | text[] | e.g. `{sql, excel, tableau, python}` |
| `target_roles` | text[] | e.g. `{Junior Data Analyst, BI Analyst}` |
| `minimum_salary` | numeric, nullable | |
| `preferred_countries` | text[] | default `{worldwide}` per user's stated preference |
| `preferred_timezones` | text[], nullable | |
| `experience_level` | text | e.g. `junior` |
| `cv_url` | text, nullable | Supabase Storage path or external link |
| `portfolio_url` | text, nullable | |
| `created_at` | timestamptz | default `now()` |

The `notification_prefs` JSONB extension also stores the user's IANA `time_zone`
so daily digest time and weekend settings follow local time, including DST.

RLS: user can only `select`/`update` their own row (`id = auth.uid()`).

### 2.2 `jobs`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, PK | |
| `external_id` | text | source's own job ID |
| `source` | text | `remotive` \| `remoteok` |
| `title` | text | |
| `company` | text | |
| `description` | text | |
| `apply_url` | text | where the user actually applies |
| `source_url` | text | canonical listing on the source site (attribution) |
| `location_text` | text | raw location/eligibility string from the source |
| `location_scope` | text | normalized: `worldwide` \| `region_restricted` \| `country_restricted` |
| `salary_min` | numeric, nullable | |
| `salary_max` | numeric, nullable | |
| `currency` | text, nullable | |
| `employment_type` | text | e.g. `full_time`, `contract` |
| `published_at` | timestamptz | |
| `collected_at` | timestamptz | when RemoteScout's worker fetched it |
| `expires_at` | timestamptz, nullable | |
| `is_expired_reported` | boolean | default `false`, set via manual "report expired" action |

Unique constraint: `(source, external_id)` to prevent duplicate ingestion from the same source; additional dedup pass compares `(company, title, apply_url)` across sources at write time.

RLS: `jobs` is readable by any authenticated user (shared catalog); writes restricted to the service role (backend worker only).

### 2.3 `job_matches`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, PK | |
| `user_id` | uuid, FK → `profiles.id` | |
| `job_id` | uuid, FK → `jobs.id` | |
| `match_score` | integer | 0–100 |
| `matched_skills` | text[] | |
| `missing_skills` | text[] | |
| `match_reason` | text | human-readable explanation string |
| `is_seen` | boolean | default `false` |
| `is_saved` | boolean | default `false` |
| `is_rejected` | boolean | default `false` |
| `created_at` | timestamptz | default `now()` |

Unique constraint: `(user_id, job_id)`.

RLS: user can only `select`/`update` rows where `user_id = auth.uid()`.

### 2.4 `applications`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, PK | |
| `user_id` | uuid, FK → `profiles.id` | |
| `job_id` | uuid, FK → `jobs.id`, nullable | nullable to support "Add manually" entries not tied to a fetched job |
| `status` | text | `new` \| `saved` \| `plan_to_apply` \| `applied` \| `interview` \| `rejected` \| `offer` \| `closed` |
| `applied_at` | timestamptz, nullable | |
| `follow_up_at` | timestamptz, nullable | |
| `cv_version` | text, nullable | |
| `cover_letter` | text, nullable | |
| `notes` | text, nullable | |
| `created_at` | timestamptz | default `now()` |
| `updated_at` | timestamptz | default `now()`, updated via trigger on change |

RLS: user can only access rows where `user_id = auth.uid()`.

### 2.5 `notifications`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, PK | |
| `user_id` | uuid, FK → `profiles.id` | |
| `job_id` | uuid, FK → `jobs.id`, nullable | nullable for digest-level summary rows |
| `channel` | text | `push` \| `email` |
| `sent_at` | timestamptz | |
| `opened_at` | timestamptz, nullable | |

RLS: user can only `select` their own rows; writes restricted to the service role.

### 2.6 `push_tokens`

| Column | Type | Notes |
|---|---|---|
| `token` | text, PK | FCM registration token |
| `user_id` | uuid, FK → `profiles.id` | |
| `updated_at` | timestamptz | refreshed when the device token changes |

RLS: a user can register, refresh, and remove only their own device tokens;
the digest worker reads tokens with the service role.

## 3. Relationships (ER summary)

```text
profiles (1) ──< job_matches >── (1) jobs
profiles (1) ──< applications >── (0..1) jobs
profiles (1) ──< notifications >── (0..1) jobs
```

## 4. Indexes

- `jobs (source, external_id)` — unique, for idempotent ingestion.
- `jobs (published_at desc)` — for freshness sorting.
- `job_matches (user_id, match_score desc, is_seen)` — for building "Today's Recommendations" efficiently.
- `applications (user_id, status)` — for the tracker's grouped-by-status view.
- `applications (user_id, follow_up_at)` — for the follow-up/calendar view.

## 5. Server-Side Logic (Edge Functions)

| Function | Trigger | Responsibility |
|---|---|---|
| `fetch-jobs` | scheduled (cron, e.g. every few hours) | Pull from Remotive + Remote OK, normalize, upsert into `jobs` with dedup |
| `score-jobs` | after `fetch-jobs`, or scheduled shortly after | Run rule-based scorer for the profile against newly-inserted jobs, write `job_matches` |
| `send-digest` | scheduled daily at user's configured digest time | Compile top N `job_matches` above threshold, insert `notifications` rows, trigger FCM push and/or Resend/SendGrid email |
| `report-expired` | invoked from app | Sets `jobs.is_expired_reported = true` for user-flagged listings |

## 6. Storage

- Supabase Storage bucket `cv-files`, private, RLS-scoped so only the owning user can read/write their own CV file; `profiles.cv_url` stores the path (or an external link if the user prefers not to upload directly).
