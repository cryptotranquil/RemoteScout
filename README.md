# RemoteScout

**A personal remote-job discovery and application assistant.** Not a job
board — RemoteScout answers one question every day: *“Which remote jobs are
worth my time, and what should I do next?”*

Built as a Flutter mobile app (Android-first) with a LUNA neomorphic (Soft UI)
design, transparent rule-based match scoring, and a full application tracker.

| Spec | Doc |
|---|---|
| Product requirements | [`docs/01_PRD.md`](docs/01_PRD.md) |
| Technical requirements | [`docs/02_TRD.md`](docs/02_TRD.md) |
| App flow | [`docs/03_App_Flow.md`](docs/03_App_Flow.md) |
| UI/UX design (LUNA) | [`docs/04_UIUX_Design.md`](docs/04_UIUX_Design.md) |
| Backend schema | [`docs/05_Backend_Schema.md`](docs/05_Backend_Schema.md) |
| Implementation plan | [`docs/06_Implementation_Plan.md`](docs/06_Implementation_Plan.md) |

Open `preview/mockups.html` for a visual walkthrough of the key screens.

## What is implemented

### Phase 1 — Flutter foundation ✅ (runnable)

- LUNA neomorphic theme: soft raised/inset surfaces, dual-direction shadows,
  light **and** dark palettes, Poppins/Inter type, tabular figures.
- Onboarding: 6-step profile setup (roles → skills → experience → worldwide
  location → salary/time zones → portfolio/CV) with soft-inset progress dots.
- Notification preferences step (digest time, min match score, max jobs/day,
  weekend toggle) with soft toggles + inset time picker.
- `Job` model + configurable listing UI backed by live or locally cached jobs.
- Neomorphic job card + Discover (“Today’s Recommendations”) screen.
- Save / Reject actions with the seen/don’t-show-again semantics.
- Saved screen with search + sort.

### Phase 2 — local job tracker ✅ (runnable)

- Hive-backed local persistence (models stored as JSON maps — zero codegen)
  so everything survives restarts; `watch()` streams drive Riverpod rebuilds.
- Job Details: match breakdown ("Why this matched" ✓ checklist), matched vs
  missing skills, source attribution, sticky action bar with **View Original
  Listing**, Save / Reject / Report Expired, Plan to Apply.
- Application tracker: full status pipeline
  (`New → Saved → Plan to apply → Applied → Interview → Rejected → Offer → Closed`),
  horizontal soft status stepper, applied/follow-up dates, CV version,
  cover letter, notes & interview details.
- "+ Add manually" for jobs found outside the app.
- Follow-ups view with overdue highlighting.
- Search/filter on Saved and Applications.
- Deterministic dedup: `(source, external_id)` + cross-source
  `(company, title, apply_url)` — ready to reuse against real data in Phase 3.
- Rule-based match scorer (skills 40 · title 25 · location 20 · experience 10 ·
  freshness 5) with human-readable `match_reason` — never a black box.

### Phase 3 — backend & real jobs ✅ (code complete — needs a Supabase project)

- `backend/supabase/schema.sql` + `rls.sql` — full schema per 05 with RLS on
  every user-scoped table.
- `backend/functions/fetch-jobs` — Remotive + Remote OK → normalizer → dedup →
  upsert (one failing source degrades gracefully).
- `backend/functions/score-jobs` — server-side mirror of the Dart scorer,
  writes `job_matches` with the reason string.
- `backend/functions/report-expired` — user-flagged stale listings.
- See [`backend/README.md`](backend/README.md) for deploy steps.

**App wiring is done.** Screens talk to an `AppStore` interface with two
implementations:

- `LocalStore` — Hive persistence (local-only mode when no backend is
  configured; no bundled demo listings).
- `SyncedStore` — Supabase as remote truth with the local store as the
  offline-first cache (TRD §7: <1s render from cache, offline viewing).
  Anonymous auth gives RLS an `auth.uid()` subject; every mutation updates
  the cache first, then pushes under RLS; pulls converge in the background.
  Pull-to-refresh and "Force refresh from sources" invoke the `fetch-jobs` /
  `score-jobs` workers.

Row ↔ model mapping lives in `lib/data/supabase/mappers.dart` (pure, unit-
tested against `schema.sql`). The one documented bridge: `job_matches`
stores the "Why this matched" checklist as extra lines inside `match_reason`
(the SQL table has no `breakdown` column).

Enable live mode at run/build time — nothing is hardcoded:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

### Phase 4 — notifications & polish 🧩 (implemented; needs project setup)

- Timezone-aware daily digest worker — per-user local time and weekend toggle,
  top-N threshold and cap, registered-device FCM push with app deep links,
  optional Resend email, and follow-up reminders.
- Flutter FCM registration and notification-tap routing are implemented.
  Firebase/Supabase credentials and platform app registrations are still
  required to deliver notifications.
- Statistics screen (fl_chart): applications over time, status funnel,
  match-score distribution.
- Second source (Remote OK) already normalized in `_shared/normalizers.ts`.

## Getting started

```bash
cd remotescout

# Platform folders (android/) are generated on demand:
flutter create --platforms=android .

flutter pub get
flutter run          # Local-only mode; no backend or bundled demo data
flutter test         # 32 unit + widget tests
flutter analyze

# Phase 3 mode: live Supabase backend (see backend/README.md first)
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY \
  --dart-define=FIREBASE_API_KEY=YOUR-FIREBASE-API-KEY \
  --dart-define=FIREBASE_APP_ID=YOUR-FIREBASE-APP-ID \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR-SENDER-ID \
  --dart-define=FIREBASE_PROJECT_ID=YOUR-FIREBASE-PROJECT-ID
```

Firebase client configuration is not a server secret. Keep the Supabase
service-role key and Firebase service-account private key on the backend only.
See [`backend/README.md`](backend/README.md) for deployment and scheduling.

## Project layout

```
lib/
  main.dart                 boot: Hive init → optional Supabase sync → runApp
  app.dart                  MaterialApp.router (light/dark LUNA themes)
  router.dart               go_router: shell tabs + detail routes
  shell.dart                soft raised bottom nav (Discover|Saved|Applications|Profile)
  core/
    theme/                  luna_colors, neumorphic kit, typography, app_theme
    scoring/match_scorer.dart  transparent rule-based matcher (+ test)
    utils/                  dedup keys, date/format helpers
  models/models.dart        Profile, Job, JobMatch, Application, NotificationPrefs
  data/
    app_store.dart          storage interface (local + Supabase both conform)
    local_store.dart        Hive persistence + streams + dedup + actions
    mock_data.dart          5 realistic junior-analytics listings
    providers.dart          Riverpod streams + Today/Saved/Tracker projections
    supabase/
      mappers.dart          pure row ↔ model mapping (SQL contract tests)
      synced_store.dart     Supabase remote truth + local offline cache
    push_notifications.dart Firebase Messaging token registration and routing
  config/env.dart           --dart-define backend configuration
  features/
    onboarding/             welcome, 6-step setup, notification prefs, form
    discover/               Today's Recommendations, job card, shared bits
    job_details/            full detail + why-it-matched breakdown
    saved/                  saved list with search/sort
    applications/           tracker, filters, follow-ups, detail/manual form
    profile/                profile, edit profile, statistics (fl_chart)
test/                       scorer, dedup, models, job card, status, chips
backend/                    Supabase schema + RLS + Edge Functions (see above)
preview/mockups.html        LUNA neomorphic screen mockups
```

## Design system (summary)

Neomorphism with the **LUNA** palette — flat base surface + two same-hue
shadows per brightness (light base `#EAF7F9`, dark base `#011C40`). Buttons
invert raised → inset on press instead of changing color. Match-score bands:
low `luna-300` → mid/high `luna-500` (≥80% gets a subtle glow). Monochrome
blue throughout — contrast/weight does the signaling. State is never signaled
by shadow depth alone (labels/icons accompany every pressed state), tap
targets stay ≥ 44dp.

## Safeguards (from day one)

- Every job card links to the **original source listing** (Remotive/Remote OK
  attribution terms satisfied).
- Never claims a listing is open without `expires_at` /
  `is_expired_reported` checks + manual "report expired" on every card.
- **No automatic application submission** — the human always clicks Apply.
- No third-party job-site passwords. CV stays local/Supabase-private only.
- Dedup is deterministic: the same job never appears twice.

## Testing

```bash
flutter test
```

- `match_scorer_test` — exact weighted scores, reason strings, all five bands.
- `dedup_test` — near-identical listings, same & different sources.
- `models_test` — JSON round-trips + wire names matching the SQL schema.
- `mappers_test` — Supabase row ↔ model contract (matches `schema.sql`).
- `job_card_test` — card content + Save/Reject callbacks.
- `application_status_test` — pipeline stepper transitions, manual-add form.
- `chips_field_test` — profile form interactions.
- `app_smoke_test` — boots the real app: welcome flow + scored Discover.
