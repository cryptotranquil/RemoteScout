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
      normalizers.ts  Source-specific job mapping and dedup keys
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
   - `supabase/push_tokens.sql` (for an existing deployment being upgraded)
2. Enable the `pg_cron` and `pg_net` extensions (Dashboard → Extensions).
3. Deploy all four Edge Functions from the repository root:

   ```bash
   npx supabase functions deploy fetch-jobs --project-ref YOUR_PROJECT_REF --workdir backend --use-api
   npx supabase functions deploy score-jobs --project-ref YOUR_PROJECT_REF --workdir backend --use-api
   npx supabase functions deploy send-digest --project-ref YOUR_PROJECT_REF --workdir backend --use-api
   npx supabase functions deploy report-expired --project-ref YOUR_PROJECT_REF --workdir backend --use-api
   ```

   The entries in `supabase/config.toml` map each function to its source under
   `backend/functions/`; all require JWT verification.
   The handlers answer browser `OPTIONS` preflights without running worker
   jobs, and include CORS headers on both success and error responses.

4. Configure backend secrets. Supabase supplies `SUPABASE_URL` and
   `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions. For push, create a Firebase
   service account with permission to send FCM messages and set:

   ```bash
   npx supabase secrets set FCM_PROJECT_ID=... FCM_CLIENT_EMAIL=... FCM_PRIVATE_KEY=... --project-ref YOUR_PROJECT_REF
   ```

   Keep the service-account private key out of source control. For optional
   email, configure a verified Resend sender and set
   `RESEND_API_KEY` and `RESEND_FROM_EMAIL`.

5. Schedule the workers. Enable `pg_cron`, `pg_net`, and Vault. In Dashboard →
   Database → Vault, create secrets named `remotescout_functions_url` (the
   project's `/functions/v1` URL) and `remotescout_service_role_key` (the
   service-role/secret API key). Then run `supabase/schedule.sql` once in the
   SQL editor. It runs fetch every three hours, scores ten minutes later, and
   checks each user's local digest time every five minutes. Keep the service
   role key in Vault only; never paste it into SQL or source control.

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

### Job sources

The fetch worker uses the Remotive and Remote OK feeds, the public Himalayas
Jobs API (`https://himalayas.app/jobs/api?limit=20`), Jobicy's public jobs API
(`https://jobicy.com/api/v2/remote-jobs`), Arbeitnow, Adzuna, Jooble, The Muse,
Findwork.dev, and the We Work Remotely RSS feed. Each source is fetched and
normalized independently; a failure is reported in the worker response and
does not stop other sources. New sources are filtered conservatively to jobs
explicitly marked worldwide/anywhere. It fetches up to five cursor pages per
run from the paginated sources.
Himalayas permits displaying its listings in apps under its API terms; the
app links to each Himalayas listing, keeps its `applicationLink` unchanged,
and excludes restricted or expired listings. Review the current
[Himalayas API documentation](https://himalayas.app/api) before deployment.
Jobicy is requested with `geo=anywhere`, and listings are checked for a
worldwide location before ingestion. The public API needs no key; its
[documentation](https://jobi.cy/apidocs) requires clear Jobicy credit and
linking to its listing, which the app displays and opens from job details.

Adzuna is queried across a fixed set of country endpoints and then filtered
for explicit worldwide eligibility; this may return few results. The Muse's
public API may be unavailable from some environments. If a provider rejects
its request, that source reports its own error and the other sources continue.

Set these as Supabase Edge Function secrets (never as GitHub APK-build
secrets or Flutter `--dart-define` values):

```bash
npx supabase secrets set ADZUNA_APP_ID=... ADZUNA_APP_KEY=... JOOBLE_API_KEY=... FINDWORK_API_KEY=... --project-ref YOUR_PROJECT_REF
```

Adzuna, Jooble, and Findwork.dev require credentials; Arbeitnow, The Muse,
Himalayas, Jobicy, Remotive, Remote OK, and We Work Remotely need no key.
Missing or rejected credentials only disable that source for the run.
We Work Remotely is fetched from its RSS feed with a named user agent and only
explicit worldwide listings are ingested.

Tier 3 crawling has not been enabled after checking each site's robots.txt,
terms, and public listing/sitemap format. The project owner reports written
permission for all four sites; keep that permission on file for deployment.

- [Remote4Africa](https://remote4africa.com/robots.txt) allows crawling in
  robots.txt, but its [terms](https://remote4africa.com/terms) prohibit
  copying or aggregating its content without express written consent.
- [RemoteJobs.io](https://www.remotejobs.io/robots.txt) exposes public pages,
  but its [terms](https://www.remotejobs.io/terms-of-service) limit job-seeker
  use to personal, non-commercial purposes and prohibit sharing, copying, or
  aggregating content without prior written consent.
- [Dynamite Jobs](https://www.dynamitejobs.com/robots.txt) publishes job
  sitemaps, but the inspected listing page had no `JobPosting` JSON-LD and
  the sitemap did not provide the required location field. Its general terms
  do not spell out a listing-republication license; the reported written
  permission is relied on for authorization.
- [JustRemote](https://justremote.co/robots.txt) allows public paths but
  disallows several private paths. The inspected listings had no
  `JobPosting` JSON-LD, the conventional sitemap URLs were unavailable, and
  its [terms](https://justremote.co/terms) grant limited access to protected
  materials; the reported written permission is relied on for authorization.

The Tier 3 implementation remains JSON-LD-only as requested. Do not infer
worldwide eligibility from a generic "remote" label; enable a source only
when its public structured data provides a `JobPosting` with the required
title, company, location, date, and link fields. If a structured feed becomes
available, keep each crawler isolated, limited to one request per second,
use a descriptive user agent, and retain only those fields with a link back
to the original listing.

Jobspresso is not ingested: its current terms prohibit copying, public display,
transfer, and mirroring without permission. The other requested sites that do
not have a verified public API/feed and redistribution permission remain
unfetched; do not scrape login-gated or anti-bot-protected pages. Google Jobs
is not an ingestible public API, and Kaggle Jobs has been discontinued.

When upgrading an existing Supabase project, run the migrations in order:
`supabase/migrations/20261101000000_add_himalayas_source.sql`,
`supabase/migrations/20261101093000_add_jobicy_source.sql`,
`supabase/migrations/20261101094500_add_tier1_sources.sql`, and
`supabase/migrations/20261101100000_add_weworkremotely_source.sql` before
deploying the updated fetch worker. New projects get all source constraints
from `supabase/schema.sql`.

For GitHub Actions release builds, add repository Actions secrets named
`SUPABASE_URL` and `SUPABASE_ANON_KEY`. The Android release workflow passes
these values into both APK and AAB builds and fails early if either is
missing, rather than silently producing a local-only release. The anon key is
intended for client builds and must remain protected by RLS; never use the
service-role key here.

## Mobile push setup

1. The Android package ID is `com.praisekajawa.remotescout` (lowercase form of
   the ID selected for this project). Verify availability in Google Play
   Console before publishing; Android IDs must be unique in the Play Store.
   The same ID is used for any Firebase Android app registration.
2. From the Firebase app configuration, pass the non-secret client values at
   build/run time: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
   `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID`. The Android app
   initializes Firebase from these values, so `google-services.json` is not
   required.
3. For iOS, register the iOS bundle ID and upload an APNs authentication key
   in Firebase. For both platforms, the app requests notification permission
   when notification preferences are saved and registers its FCM token under
   the signed-in Supabase user.
4. Test with a real device: emulator/simulator push delivery is not a
   substitute for configuring a Firebase project and APNs.

## Android release signing

Release APK/AAB tasks fail unless the Android package ID is valid and signing
keystore values are configured. Supply `APPLICATION_ID` (defaults to this
project's selected ID), `RELEASE_STORE_FILE`, `RELEASE_STORE_PASSWORD`,
`RELEASE_KEY_ALIAS`, and `RELEASE_KEY_PASSWORD` through Gradle properties or
environment variables. Keep the keystore outside source control; `.jks` and
`.keystore` files are ignored by Git. Never put passwords in this file.

Generate the upload key locally after installing JDK 17. `keytool` prompts for
the passwords interactively, so do not add them as command-line arguments:

```powershell
New-Item -ItemType Directory -Force "$HOME\.android" | Out-Null
keytool -genkeypair -v `
  -keystore "$HOME\.android\remotescout-upload-key.jks" `
  -alias remotescout -keyalg RSA -keysize 2048 -validity 10000
```

Back up the keystore and its passwords securely. Keep them private and never
send them in chat. For one local release build, set the passwords using secure
PowerShell prompts in that terminal session, then set the file path and alias:

```powershell
$env:APPLICATION_ID = "com.praisekajawa.remotescout"
$env:RELEASE_STORE_FILE = "$HOME\.android\remotescout-upload-key.jks"
$env:RELEASE_KEY_ALIAS = "remotescout"
$env:RELEASE_STORE_PASSWORD = [System.Net.NetworkCredential]::new("", (Read-Host "Keystore password" -AsSecureString)).Password
$env:RELEASE_KEY_PASSWORD = [System.Net.NetworkCredential]::new("", (Read-Host "Key password" -AsSecureString)).Password
```

### GitHub Actions Android build

`.github/workflows/android-release.yml` builds a signed Android App Bundle on
pushes to `main` or when manually started from the repository's Actions tab.
Add these repository Actions secrets under **Settings → Secrets and variables
→ Actions**:

- `KEYSTORE_BASE64` — create the value locally in PowerShell with:
  `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\.android\remotescout-upload-key.jks")) | Set-Clipboard`
- `RELEASE_STORE_PASSWORD` — the keystore password.
- `RELEASE_KEY_PASSWORD` — the key password.

The workflow uses the `remotescout` alias and this project's default package
ID. It uploads `remotescout-android-release` (AAB for Google Play) and
`remotescout-android-apk` (APK for direct phone installation) as separate
downloadable artifacts. Never put the keystore or passwords in the repository
or send them in chat.

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
