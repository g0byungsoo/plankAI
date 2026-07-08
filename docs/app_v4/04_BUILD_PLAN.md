# app v4 — build plan

Date: 2026-07-06. Phases = commit batches; ONE build per batch;
evidence (stills/recordings) before any phase is called done.
Production fences: no schema/EF/payment/gating changes; SwiftData
untouched (new persistence = device-local JSONL); notification ids
follow the 4-site protocol; the three Today hooks survive; pace
floors + goal math untouched; pbxproj edits last in each batch.

## Phase 1 — the spine (pure logic + seams)
- `Program/ProgramArc.swift`: Phase model + per-chapter skeletons
  (losing 7-phase, on-med rolling blocks, keeping settle/kept) —
  pure math over (programDay, totalDays, chapter, flags).
- `Program/WeekIntent.swift`: named weeks + intent sentence + beat
  bias, deterministic (seeded by week-Monday dayKey).
- `Program/WeeklyReview.swift` + JSONL store: week receipt assembly
  (from WeekState), ≤1 proposal from the closed set, consent
  application through EXISTING setting knobs, signed record.
- DailyBriefEngine + InsightEngine: arc context + week-story mode.
- Fix: userId-scoped snap completion (todayKcalTotal seam) + pin.
- Unit tests: phase math across plan lengths (56/84/105/140), intent
  determinism, proposal rules (incl. numeric-suppression + tier
  bounds), consent writes, week-story provenance.

## Phase 2 — the journey (becoming rebuild)
- JKArcRibbon (phase segments + today tick, draw-in motion).
- BecomingView torn down to the trend canvas; rebuilt: masthead/arc
  → the line (ONE window story; band y-domain fix) → this week →
  week ledger (receipt cards + adaptation stamps + quiet seams +
  break rows) → future shape card → archive doors.
- Week page + day receipt (grown from ProgramDayReviewSheet: adds
  weigh-in, steps-vs-typical, jeni's reconstructed line, plate
  photos).
- THE RE-SIGNING: full-screen received page (cascade + consent
  doors) + Sunday-evening trigger + record + journey stamp.
- DELETE: legacy AnalyticsView/BecomingDashboard/BecomingV2Atoms +
  `--legacy-becoming`.

## Phase 3 — today threads
- Week ribbon under the masthead (dots + week name → journey);
  day-pill sheet door dies (HerDaysSheet, ProgramDayPeekSheet
  DELETE).
- THE PLATE STORY: filmstrip-led module (protein arc single hero,
  kcal sentence + day answer, steps to its own quiet row).
- Evening order fix (receipt above still-open rows, never hiding
  the hero); tonight-plan door in the close.
- Walker updates for the new stops.

## Phase 4 — breath (the marquee interior)
- `DesignSystem/Kit/JKBreathField.swift`: generative petal bloom
  (TimelineView+Canvas; SE 60fps target), breath-shaped asymmetric
  curves, hold micro-drift.
- `Health/BreathHaptics.swift`: CoreHaptics continuous curve engine
  (swell/fade/still), pulse fallback, reduce-motion off.
- Session: numerals die → cycle dot ring; softened phase words;
  full-bleed presentation; receipt/occasions kept.

## Phase 5 — method + completions + food archive
- Rep: post-door self-referential line; tonight-plan chip builder
  (15s, kept-plan renders on tomorrow's reading).
- Reader: one-idea tap-pacing + embedded micro-choices (manifest
  unchanged).
- Urge tool: before/after feeling dial → honest receipt line.
- Workout completion: kept-receipt grammar (PostRoutineView DELETE;
  stars die).
- Her plates archive page (v1 journal interior DELETE); journey
  method layer (acts + kept reps).

## Phase 6 — cohesion + hygiene
- Chat context: arc fields + re-signing seed door + day-receipt ask.
- Notifications: anchor week-intent bodies + Sunday knock (ids per
  protocol).
- Settings "your plan" row; CFBundleURLTypes for jenifit://;
  remaining legacy sweep (Views/Plan atoms, method ritual pair,
  `--legacy-today`).

## Phase 7 — the premium evidence pass
- Recordings: today morning/evening, ribbon→journey, week→day
  receipt, re-signing, snap→plate story, breath session (full),
  rep→tonight plan, workout completion, weight ritual→canvas.
- Frame dumps on every transition; fix pops/clipping/easing.
- iPhone SE full pass + Dynamic Type XL on new surfaces.
- Walker suite green; unit suite green.

## Evidence discipline
Every phase lands with: build green, tests green, stills in
`docs/app_v4/evidence/`, and (phases 2-7) recordings. No adjectives
without artifacts.
