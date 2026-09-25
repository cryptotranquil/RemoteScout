# RemoteScout — App Flow

## 1. Navigation Structure

Bottom navigation, four tabs:

```text
Discover | Saved | Applications | Profile
```

Plus a Statistics screen reachable from Profile, and a Job Details screen reachable from any job card.

## 2. First-Run Flow (Onboarding)

```text
Splash
  → Welcome screen ("RemoteScout finds jobs worth your time")
  → Onboarding — Profile Setup (multi-step)
      Step 1: Target roles (e.g. Junior Data Analyst, BI Analyst, Reporting Analyst...)
      Step 2: Skills (SQL, Excel, Tableau/Power BI/Looker, Python/R, etc.)
      Step 3: Experience level (Junior / Entry-level)
      Step 4: Location eligibility (Worldwide-remote — confirmed default)
      Step 5: Minimum salary + preferred time zones (optional)
      Step 6: Portfolio link + CV upload/link (optional)
  → Notification preferences (digest time, min match score, max jobs/day, weekend on/off)
  → Home (Discover tab), empty state until first fetch cycle completes
```

Onboarding can be revisited any time from Profile → Edit Profile.

## 3. Discover Tab (Home) — "Today's Recommendations"

```text
Discover
  → Header: "Today's best opportunities" + date
  → Short ranked list (3–5 job cards, not a full feed)
      Each card: title, company, match %, location, posted date, source badge
      Tap card → Job Details
      Swipe/inline actions → Save, Reject
  → Empty state: "No more high-match jobs today" (not an infinite generic list)
  → Pull-to-refresh triggers a manual re-check against latest cached matches
```

## 4. Job Details Flow

```text
Job Details
  → Full job title, company, salary (if available), employment type
  → Location eligibility badge (Worldwide / Restricted — with detail)
  → Match score with expandable breakdown ("Why this matched")
      ✓ Matches SQL, Excel
      ✓ Junior-friendly
      ✓ Worldwide eligible
      ✓ Posted 2 days ago
  → Required skills list (matched vs. missing, visually distinguished)
  → Source + "Posted on [Source]" attribution + collected date
  → Actions: [View Original Listing] (external link) · [Save] · [Reject] · [Report Expired]
  → If moving toward applying: [Plan to Apply] → routes into Application Tracker with this job pre-filled
```

## 5. Saved Tab

```text
Saved
  → List of jobs the user explicitly saved (not rejected, not yet applied)
  → Filter/search by title, company, or match score
  → Tap → Job Details
  → Swipe → Move to "Plan to apply" or Reject
```

## 6. Applications Tab (Tracker)

```text
Applications
  → Grouped/filterable by status:
      New → Saved → Plan to apply → Applied → Interview → Rejected → Offer → Closed
  → Tap an application → Application Detail
      Application date, follow-up date, CV version used, cover letter, notes, interview details
      Status change control (dropdown/stepper)
  → "+ Add manually" for jobs found outside the app, so tracking stays centralized
  → Calendar/follow-up view: upcoming follow-up dates surfaced as a simple list or calendar
```

## 7. Profile Tab

```text
Profile
  → View/edit: skills, target roles, experience, location eligibility, salary floor, time zones
  → Portfolio link, CV file/link
  → Notification preferences (digest time, min match score, max jobs/day, weekend toggle)
  → Statistics (fl_chart): applications over time, match-score distribution, status funnel
  → App settings (data source status, manual "force refresh", about/attribution info)
```

## 8. Notification Flow

```text
Backend worker completes daily fetch + scoring cycle
  → Compiles digest: top N jobs ≥ user's minimum match score (cap: max jobs/day)
  → Sends push via FCM at the user's configured digest time
  → (Optional) sends email via Resend/SendGrid
  → Tapping the push deep-links into Discover, pre-scrolled to the new jobs
```

## 9. Save / Reject / Dedup Flow (system-level, not user-visible screens)

```text
New job fetched
  → Normalized into shared schema
  → Checked against existing jobs (source + company + title + apply_url)
      → Duplicate found → discard/merge, do not create a new card
      → Not a duplicate → scored against profile → inserted with is_seen = false
  → Once shown in Discover and acted on (saved/rejected) → is_seen = true, excluded from future "Today" lists
```

## 10. End-to-End Example Path

```text
Onboarding complete
  → Overnight: worker fetches Remotive + Remote OK, normalizes, dedups, scores
  → 08:00 digest push: "You have 4 new remote jobs today. Top match: Junior Data Analyst — 88%"
  → User taps push → Discover tab, sees ranked list
  → Taps top card → Job Details → sees why it matched → taps [View Original Listing]
  → Applies externally on the source site → returns to app → sets status to "Applied", adds notes
  → Job now appears in Applications tab under "Applied", with a follow-up date set
```
