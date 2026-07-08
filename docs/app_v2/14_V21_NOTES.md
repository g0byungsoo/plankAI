# 14 — v2.1 pass: feature-by-feature status, usage data, verification

Date: 2026-07-03, second pass on feat/app-v2.

## Usage data (PostHog, 21 days, internal user excluded)

1,467 active · 1,105 onboarding completions · ~90 purchasers.
Food = the engagement engine (5 of top-6 day-2+ events; 10.5
plates/logger). Lessons = widest reach (89/90 purchasers viewed;
completion event only 19% — reader-length audit follow-up).
Workouts = minority behavior (26% ever complete). Breath completes
69%. Paid retention 44% D1 → 10% D7 (the fire this rebuild aims at).
Scan fallback fires on 26% of scans (deploy food-vision). Rage-clicks
cluster on sheets (621/222u) — screen attribution unwired (follow-up).

## Feature-by-feature status after v2.1

| Surface | Status |
|---|---|
| Today | v2 ritual + v2.1 day-complete silk sweep (jkSilk Metal shader, frame-verified) |
| Jeni chat | v2 letter-register UI; EF deploy-ready + safety-hardened (13_DEPLOY_SAFETY) |
| Becoming | v2.1 REBUILT as the insight layer (12_BECOMING_V2) |
| Method | Journey card in Becoming + cadence-aware ordinal; reader internals kept (already premium); reader-length audit = follow-up |
| Snap/result | Kept (world-class); dietary resolver + canonical protein target wired in v2 |
| Journal | v2 catalog rows (photo-forward 4:5, protein-only at rest) |
| Steps | Ring in Today band + beat row; detail sheet = follow-up |
| Weight log | LogWeightSheet kept (on-register); entry points: Today beat, Becoming empty state, jeni tool |
| Weight trend | Canvas kept + v2.1 coach-story layer above it |
| Breathwork | Flow kept (69% completion — it works); chrome audit clean |
| Workouts | Beats 3-5×/wk by tier (v2); v2.1 celebration de-emoji'd → typographic "kept. / strong. / showed up." |
| Program week | PrescriptionEngineV2 (v2) |
| Notifications | Delegate + deep links (v2); orchestrator consolidation per 09 spec = follow-up |
| Settings | ProfileHub reachable from both tabs; sub-screens already on-register (2026-06 memory) |
| Paywall / expired | WallView destinations (v2); paywall internals = founder-approved 2026-06-29 design |
| Migration | Single-beat moment (v2); three-beat enrichment on founder call |
| Onramp | v2.1 reskin: bordered scrapbook card → receipt grammar (first paid screen for new users) |
| Empty/loading/error | JKEmptyState grammar on new surfaces; chat failure copy designed; remaining legacy states die with the sweep |
| Deep links | jenifit:// grammar via AppRouter, queued until .main |

## Remaining dead/legacy surfaces (the sweep list, founder-gated)

- `PlanView` + Plan/ folder chrome (behind `--legacy-today`)
- `AnalyticsView` + Becoming v1 atoms it exclusively owns (behind
  `--legacy-becoming`; BecomingTrendCanvas is KEPT — it moved)
- `MainTabView` (replaced by MainShell; still compiled)
- `Views/Home/` orphans (~1,580 lines), `Views/Session/` +
  `PostSession/` legacy plank trio (~1,500), `PremiumWelcomeScreen`,
  `BreathLibraryView`
- Onboarding v4.5 (`OnboardingView.swift` + companions) — separate
  founder sign-off, predates this branch
- `--onboarding-v4`, `--legacy-today`, `--legacy-becoming` escapes

## Verification loop notes

- Unit tests: full suite green (incl. 10-case AppPhase table).
- Walkers: v5 onboarding walker green; settings walker updated to the
  masthead mark and green; legacy v4.5 walker failure predates branch.
- Frame-level: silk sweep verified via simctl recordVideo → ffmpeg
  10fps frames → PIL pixel-diff: two clean pulses on the 2s replay
  cadence (diff_sum 300k baseline → 3.5M crest → ease-out decay),
  text legible through the crest; lift tuned 0.38 → 0.30 after crest
  inspection. Harness: `--debug-jenikit --debug-silk-auto`.
- Sim QA args (full set): `--uitest-seed-program` (enrolled maya,
  day 12, weight series; hydration-proof), `--uitest-start-tab`,
  `--uitest-mock-chat`, `--uitest-chat-demo`,
  `--uitest-force-migration`, `--uitest-today-bottom`,
  `--debug-jenikit`, `--debug-silk-auto`, `--legacy-today`,
  `--legacy-becoming`.
- cfprefsd gotcha: `simctl spawn defaults write/delete` splits from
  the app sandbox plist — always use in-process launch args for QA
  state.
