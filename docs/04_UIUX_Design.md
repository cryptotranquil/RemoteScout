# RemoteScout — UI/UX Design

## 1. Design Direction

**Style:** Neomorphism (Soft UI) — soft extruded surfaces, dual-direction shadows (light + dark) on a flat-toned background, minimal borders, low-contrast depth instead of hard elevation.

**Palette:** LUNA

| Token | Hex | Role |
|---|---|---|
| `luna-100` | `#A7EBF2` | Lightest accent — highlights, success states, light-mode base surface tint |
| `luna-300` | `#54ACBF` | Secondary accent — active states, progress indicators, links |
| `luna-500` | `#26658C` | Primary brand color — primary buttons, selected nav item, match-score high band |
| `luna-700` | `#023859` | Deep surface — dark-mode base, headers, card backgrounds in dark mode |
| `luna-900` | `#011C40` | Deepest — dark-mode background, high-emphasis text on light surfaces |

Neomorphism depends on a **flat base surface color** with two shadow layers (a lighter "highlight" and a darker "shadow") of the *same hue family* as the base — so light and dark mode each get their own base + shadow pair rather than simply inverting.

- **Light mode base:** a very light tint derived from `luna-100` (e.g. `#EAF7F9`), shadows: highlight `#FFFFFF`, shadow `#B9D9DE`.
- **Dark mode base:** `luna-900` (`#011C40`) as the base surface, shadows: highlight a lightened `luna-700`, shadow near-black navy.

Text: `luna-900` on light backgrounds, `luna-100` on dark backgrounds. Match-score bands use the palette as a gradient (low → `luna-300`, mid → `luna-500`, high ≥80% → a warmer accent kept minimal, e.g. `luna-500` at full saturation with a subtle glow) — avoid introducing green/red outside this family; keep the whole app monochrome-blue with weight/contrast doing the signaling, consistent with Soft UI's low-saturation character.

## 2. Core Neomorphic Component Patterns

- **Cards (job cards, application cards):** raised soft surface — base color + soft highlight top-left, soft shadow bottom-right, large corner radius (~20–24px), no hard border.
- **Buttons (primary actions — Save, Apply, Plan to Apply):** raised pill-shaped soft buttons; pressed state inverts to an *inset* (pressed-in) shadow rather than a color change, which is the signature Soft UI interaction.
- **Inputs (profile form fields):** inset/concave fields (shadow direction reversed from cards) so they read as "pressed into" the surface — standard neomorphic convention for text fields.
- **Toggles/switches (notification prefs):** soft pill track, raised thumb; on-state shifts thumb color toward `luna-500`.
- **Bottom navigation:** soft raised bar, active tab shown as a subtly inset circular badge around the icon rather than a hard color fill.
- **Match score ring/badge:** circular soft-extruded badge with the percentage in the center, ring color mapped to the score band described above.

Because neomorphism relies on subtle contrast, keep depth effects restrained on small elements (avoid heavy shadows on dense list rows) and reserve the fuller raised/inset effect for cards, buttons, and primary inputs — this keeps the UI readable rather than visually noisy.

## 3. Typography

- Headings: a clean geometric sans-serif (e.g. Poppins or Inter, Semibold/Bold) — matches the confident, minimal "LUNA" wordmark style from the palette reference.
- Body: Inter or system default sans-serif, Regular/Medium, for readability in dense job-detail text.
- Numerals (match %, salary): tabular figures where possible so scores align cleanly in lists.

## 4. Screen-by-Screen Layout Notes

### 4.1 Onboarding / Profile Setup
Soft-inset stepper at the top (progress dots, inset track). Each step is a single card-surface with inset input fields. Primary CTA is a raised pill button anchored bottom, full-width with margin.

### 4.2 Discover (Home)
```
┌───────────────────────────────┐
│  Today's best opportunities   │  ← heading, luna-900/100 text
│  Fri, 25 Sep                  │  ← muted subtext
│                                │
│  ╭───────────────────────╮   │  ← raised soft card
│  │ Junior Data Analyst    │   │
│  │ Example Labs   ● 88%   │   │  ← score badge, soft-extruded circle
│  │ Worldwide · 2d ago     │   │
│  │ [Save]  [Reject]       │   │  ← raised pill buttons
│  ╰───────────────────────╯   │
│  ╭───────────────────────╮   │
│  │  ... next card ...     │   │
│  ╰───────────────────────╯   │
│                                │
│  "No more high-match jobs      │  ← empty-state, centered, muted
│   today."                      │
└───────────────────────────────┘
  Discover | Saved | Applications | Profile   ← soft nav bar
```

### 4.3 Job Details
Full-bleed soft card header (title/company/score), a scrollable body split into soft-separated sections (Why it matched / Required skills / Source & attribution), and a sticky bottom action bar (raised primary "View Original Listing" button + secondary icon buttons for Save/Reject/Report).

### 4.4 Saved / Applications
List of raised job/application cards; Applications adds a horizontally scrollable soft "status pill" filter row at the top (New, Saved, Plan to apply, Applied, Interview, Rejected, Offer, Closed), active pill shown inset.

### 4.5 Application Detail
Inset-style form fields for editable metadata (follow-up date, CV version, notes), with a horizontal soft-stepper for status progression across the pipeline.

### 4.6 Profile
Grouped soft cards per section (Skills & Roles, Location & Salary, Notifications, Statistics link, About/Attribution). Notification prefs use soft toggles + an inset time picker for digest time.

### 4.7 Statistics
fl_chart visualizations (applications-over-time line, status funnel bar, match-score distribution) rendered inside a raised soft card container so charts don't fight the neomorphic surface language — chart colors pulled from the LUNA palette bands.

## 5. Accessibility Notes

Neomorphism's low-contrast-by-design nature is a known accessibility risk — mitigate it deliberately:
- Never rely on shadow depth alone to indicate state; pair every raised/inset/pressed state with a text label or icon change.
- Maintain minimum 4.5:1 text contrast against the base surface in both light and dark mode even though shadows themselves are subtle (test `luna-900` text on the light-mode base, and `luna-100` text on the dark-mode base).
- Ensure tap targets (pill buttons, toggles) meet a 44x44dp minimum regardless of their soft visual footprint.

## 6. Motion

Minimal, physical-feeling transitions: card save/reject uses a soft slide+fade; button press uses a quick raised→inset shadow crossfade (~100–150ms) to reinforce the "pressed" metaphor; digest notification tap performs a shared-element transition from notification into the Discover list.
