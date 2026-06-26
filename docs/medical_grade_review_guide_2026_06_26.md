# Medical-grade stack — review guide (2026-06-26)

Branch `feat/medical-grade-safety`, **13 commits**, **+1644 / −20**, 13 files.
Stacked on the unmerged **v1.1.2 PR #10** (merge #10 first, then this).
**72 unit tests green.** Builds clean.

## Trust-the-whole-thing-in-5-minutes

Verify these three load-bearing claims and the rest follows:

1. **Existing enrolled users are not disrupted.** The intake gate runs only
   for *new* enrollments — `ProgramSetupSubflow.onSetupAppear()` enters the
   safety flow only when `safety_screen_enabled && !safety_screen_completed`.
   Already-enrolled users re-derive straight to the program.
2. **The new clinical behavior is OFF by default.** Three flags, all
   `= false`: `protein_hero_enabled`, `rapid_loss_guard_enabled`,
   `adaptive_pacing_enabled`. Nothing changes for anyone until you flip them.
3. **Tests pass.** `xcodebuild test -only-testing:plankAITests` → 72 green
   (30 new: safety math, %TBWL, protein band, rapid-loss, adaptive status).

## What users actually see (the only always-on changes)

- **New users:** the safety screening flow (consent → pregnancy → SCOFF)
  before the program builds. This is the intended Phase 1 behavior. Kill
  switch: `safety_screen_enabled` (default true).
- **Existing enrolled users:** a **one-time, non-blocking** safety check-in
  (commit `be49281`), then never again.
- **Everyone (invisible):** energy floor raised to `max(1200, BMR)` (safer
  direction only); goal-weight clamped to BMI-18.5 (new builds only);
  GLP-1 copy drops one unshipped claim; %TBWL analytics events.
- **Phase 2 clinical engine:** nothing until you flip the 3 flags.

→ **Your main review focus = the safety screening flow** (new users see it).
Walk it on-device with the debug hooks below; the rest is low-risk.

## Review in 4 groups (not commit order)

### A — Intake safety gate (Phase 1) · highest review priority
`ff8912d 3925a53 1407c8d b711dd7 be49281 4d83535 d678f66`
- Files: `OnboardingComponents.swift` (+556, all the screens — housed here to
  avoid the non-synchronized pbxproj), `ProgramSetupSubflow.swift` (+121, the
  gate wiring), `ProgramGoalCalculator.swift` (+116, the assessment logic),
  `EnergyLedger.swift` (floor), `PlanView.swift` (existing-user check-in).
- Verify: the gate precedence (age<18 → ED/SCOFF → pregnancy → BMI), the
  crisis-resource routing, and that the copy reads right (it's clinical but
  must stay on-voice). The `4d83535` churn (+160/−139) is the tap/overlap
  fix you already saw on-device — same screens, re-laid-out.

### B — Compliance copy · 1 line
`87f1159` — drops "satiety-aware portions" (unshipped) from the on-GLP-1
confirmation. 30-second read.

### C — Evidence instrumentation (Phase 5) · invisible
`e4fbe4b` — `AnalyticsManager.swift` + `AnalyticsView.swift`. PostHog-only,
no UI, no schema. Verify the data-provenance choice: no weigh-in → no event
(we never invent a body weight).

### D — Clinical engine (Phase 2.3 + 2.2) · all flag-gated OFF
`b0870d0` protein floor · `4ce0ae6` rapid-loss · `872b158` adaptive pace.
- Files: `WeightAnalytics.swift` (+93 pure logic), `EnergyLedger.swift`
  (ClinicalTargets), `AnalyticsView.swift` (flag-gated wiring),
  `BecomingV2Atoms.swift` (tile note), `WeightTests.swift` (+234 tests).
- The engines are pure + unit-tested; the UI is what you'd review when you
  decide to flip each flag.

(`011859d` = the spec doc — context only, skim if useful.)

## On-device walkthrough (debug launch args)

| Arg | Screen |
|---|---|
| `--debug-safety-consent` | informed consent |
| `--debug-safety-pregnancy` | pregnancy/lactation |
| `--debug-safety-screen` | SCOFF ED screen |
| `--debug-safety-recovery` | ED-positive gentle path + crisis resources |
| `--debug-safety-checkin` | existing-user one-time check-in |
| `--debug-program-setup` | the real subflow (gate fires before build) |
| `--debug-protein-hero` | protein tile: baseline vs GLP-1 elevated |
| `--debug-rapid-loss` | rapid-loss guardrail insight |
| `--debug-adaptive-pace` | adaptive pace insights |

## Merge + enable

1. Merge **PR #10** (v1.1.2) → then this branch.
2. Merging changes nothing for users (gate is new-enroll; flags OFF).
3. Enable per-flag after on-device review, in whatever order you trust:
   `safety_screen_enabled` is already on; flip `protein_hero_enabled`,
   `rapid_loss_guard_enabled`, `adaptive_pacing_enabled` when ready.

## Explicitly NOT in this stack (your calls)

- **2.1 TDEE wiring** — changes the calorie target; needs your review.
- **2.3 resistance Rx / lean-mass proxy** — new logging surfaces.
- **3.1/3.2/4.x cohort substance + PHQ-9** — need onboarding capture.
- **3.4 post-GLP-1 default** — reverses a deliberate decision
  (`ProgramGoalCalculator.swift:249`); needs your bless.
- All **deferred non-engineering** (governance, FDA opinion, RWE study) —
  block the *"medical-grade" claim*, not these builds.
