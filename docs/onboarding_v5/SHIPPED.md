# Onboarding v5 — Shipped State + Final Audit

2026-07-02. Branch `feat/onboarding-v5`. Built end-to-end in one pass:
7-lens expert panel → synthesis → implementation → walker-verified in
the simulator (welcome → hard paywall, three cohort walks).

## What shipped

**Module** `PlankApp/Views/OnboardingV5/` (13 files):
`OV5Flow` (typed step enum + pure router + UserDefaults-backed store) ·
`OV5Scaffold` (5-act hairline progress, act eyebrows, two-beat entrance,
CTA dock) · `OV5Components` (cross-off select rows w/ auto-advance,
multi lists, statement yes/no w/ strike-the-fear, photo grid, teach +
receipt archetypes, trust lines, citation chips) · `OV5Ruler` (tick
ruler: haptic detents, digit-roll serif pill, rose delta band, live
weeks line) · act screen files · `OV5Collage` (welcome) · `OV5SnapDemo`
· `OV5FearResolution`.

**Flow** (~46 beats + cohort branches): arrival (collage → anti-shame →
outcome → attribution → credibility → name) → food story (GLP-1 status
fork w/ current: phase + appetite rhythm + muscle-math teach · past:
stop window + appetite return + regain-truth teach w/ JAMA chip ·
considering: agency teach; food relationship → cohort-routed food-noise
teach → pre-eat → SNAP DEMO → cadence → prior win → cuisine → dietary →
act receipt) → numbers (movement/sleep/stress/gender → age/height/
weight/goal rulers → trend → direction → reframe → NSV → care bridge →
medication → RELOCATED SAFETY GATE → receipt) → the part nobody asks
(identity → hormonal → started-over → data-mirror → fears ×3 → why it
came back w/ rebound curve → receipt) → almost hers (her-file dossier →
signature (consent + disclaimer fold) → HealthKit → hold-to-build) →
reveal (receipt-tape loader → pace → projection w/ causal receipts →
first week → fear resolution → commitment → nudge w/ trial promise) →
wall.

**Reveal surgery**: reveal starts at building for v5 (`skipsPreamble`);
ratingAsk slot → `OV5FearResolutionPresentation` (self-skips); loader
rewritten (dead-field narration bug fixed — it cited fields cut in v4
and derived "pace" from voice preference); nudge banner carries her
promise at her time + trial-reminder row; commitment pre-leads "snap
your first real meal" after a completed demo; projection: causal
receipts replace context chips, ♥ forced to text presentation.

**Entry**: `RootView` mounts `OnboardingV5Flow`; `--onboarding-v4`
launch arg keeps legacy reachable during burn-in.

**Verification**: `OnboardingV5WalkerUITests` walks the full flow with
a screenshot per beat (hittable-wait taps, marker-strict receipts,
SCOFF scroll-answer, springboard ATT/notification handling,
`TEST_RUNNER_GLP1_COHORT` env for branch walks). Screenshots land in
`screenshots/v5_qa/` (gitignored).

## Audit findings resolved during verification

- Building loader narrated dead fields (panel catch) → receipt tape.
- Pre-wall rating ask (intent bleed) → fear-resolution beat.
- Recap-before-name (dossier unaddressed) → name in Act I; the paywall
  now renders "maya, unlock *your* N-day plan" + identity word + fear
  echo + promise echo for every v5 user.
- "no counting" first-week rail contradicted the demo count-up →
  "read in seconds" / GLP-1 "protein is the number to watch".
- Promise-time vs nudge-time contradiction → single merged anchor.
- Red emoji hearts (font fallback on U+2665) → U+FE0E text presentation.
- Em-dashes in two new copy strings → removed (voice floor).
- Safety gate reads canonical weight/height/age keys → store mirrors
  them live (gate now runs mid-flow).
- PTY exhaustion blocking the test runner (Xcode leaked ~500) → quit
  Xcode; documented here for the next long session.

## Follow-ups (deliberate, not forgotten)

1. **v4.5 code sweep** — `OnboardingView.swift` (9.6k lines) +
   companions stay on disk behind `--onboarding-v4` until founder
   sign-off on device; then delete per the dead-code rule (also retire
   `RatingAskPresentation`, `FlowingChips`, unused welcome assets).
2. **Post-purchase bridge** ("first two things": breathe now + snap
   tonight) — lifecycle P1, post-paywall surface.
3. **Decline plan-preservation terminal** ("still here. still yours.").
4. ~~Day-1 push deep link~~ — DONE 2026-07-03: scheduleDay1Promise
   carries `deeplink: jenifit://snap` for snap/log/protein promises
   (app v2's AppRouter + NotificationDelegate cash it; queued until
   .main so unpaid users still hit the wall first).
5. **Analytics events** (`ov5_*` — demo_completed, promise_set,
   gate_outcome, act receipts) — wire into Analytics enum.
6. **Protein co-line on projection** (flip `protein_hero_enabled`,
   GLP-1 accent) — verify citation string first.
7. **"from your practice run" caption** on the prefilled promise chip.
8. **Collage art pass 2** — bespoke Grok set for the welcome (current
   build reuses the filler inventory; strong but can go further),
   day-one artifact card share button (ImageRenderer).
9. **Router unit test** asserting the no-repeated-archetype rule +
   branch reachability.
10. **Reduce-motion + Dynamic-Type XL pass** on the new screens
    (components gate motion; needs an explicit walkthrough).
