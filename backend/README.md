# RemoteScout — Backend (Supabase)

Server-side pipeline from 02_TRD.md and 05_Backend_Schema.md. The Flutter app
never calls job-source APIs directly — all fetching, normalization, dedup,
and scoring happen here.

## Layout

```
backend/
  supabase/
    schema.sql        tables, indexes, triggers, RPC, cv-files bucket
    rls.sql           Row Level Security policies (every user-scoped table)
  functions/
    _shared/
      normalizers.ts  Remotive + Remote OK → shared jobs shape, dedup keys
      scoring.ts      rule-based scorer (mirror of lib/core/scoring/match_scorer.dart)
    fetch-jobs/       cron: pull sources → normalize → dedup → upsert
    score-jobs/       cron: score against profiles → upsert job_matches
    send-digest/      cron: daily digest via FCM push + optional Resend email
    report-expired/   app-invoked: flag a stale listing
```

## Setup

1. Create a Supabase project and run in the SQL editor:
   - `supabase/schema.sql`
   - `supabase/rls.sql`
2. Enable the `pg_cron` and `pg_net` extensions (Dashboard → Extensions).
3. Deploy functions:

   ```bash
   supabase functions deploy fetch-jobs
   supabase functions deploy score-jobs
   supabase functions deploy send-digest
   supabase functions deploy report-expired
   ```

4. Set secrets:

   ```bash
   supabase secrets set FCM_PROJECT_ID=... FCM_CLIENT_EMAIL=... FCM_PRIVATE_KEY=...
   supabase secrets set RESEND_API_KEY=...   # optional email channel
   ```

5. Schedule (Dashboard → Edge Functions → Schedules, or `pg_cron`):
   - `fetch-jobs` every 3 hours (e.g. `15 */3 * * *`)
   - `score-jobs` 10 minutes later (e.g. `25 */3 * * *`)
   - `send-digest` daily at the user's digest time (default `0 8 * * *`)

## App wiring (Phase 3)

The Flutter app talks to this backend through `lib/data/supabase/synced_store.dart`
(pass `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`):

- Anonymous sign-in gives RLS policies an `auth.uid()` subject.
- Reads: `profiles`, `jobs`, `job_matches`, `applications` — pulled into the
  local Hive cache at startup and after every mutation (offline-first).
- Writes: profile upsert (with `notification_prefs` JSONB), match flags,
  application rows, `source = 'manual'` job inserts, and the
  `report_expired_job` RPC.
- "Force refresh from sources" (Profile tab) and pull-to-refresh (Discover)
  invoke the `fetch-jobs` + `score-jobs` functions, then pull results.

Enable **anonymous sign-ins** in Dashboard → Authentication → Providers for
the single-user MVP (or swap `ensureSignedIn()` for your preferred method).

## Attribution compliance

`jobs.source_url` and `jobs.apply_url` are kept separately so every card can
link back to the original listing — Remotive and Remote OK both require
attribution and a link back. Never drop `source_url` from card payloads.

## Schema deviations (documented)

- `profiles.notification_prefs jsonb` — the source schema doc has no
  preferences table; the digest worker needs one query to read them.
- Manual entries insert a `jobs` row with `source = 'manual'` (RLS allows
  authenticated inserts only for that source) so tracker rows can keep a
  strict `job_id` FK while supporting "Add manually".
- `job_matches.match_reason` carries the summary line plus the
  "Why this matched" checklist as extra lines.

## Safeguards (apply at every phase)

- No automatic application submission — ever.
- No storage of third-party job-site passwords.
- CV files live only in the private `cv-files` bucket (RLS-scoped) or a
  user-controlled external link.
- `is_expired_reported` + `expires_at` gate every "still open" claim.
