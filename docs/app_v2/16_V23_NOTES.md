# 16 — v2.3: the gap-closing pass

Date: 2026-07-03. Rule for this pass: "fixed or intentionally
retained for a concrete reason" — documentation alone doesn't count.

## Legacy sweep — the decision, executed

**Deleted this pass (12 files, ~4,300 lines, all proven
zero-instantiation by reference count before removal, build-verified
after):** BreathworkHomeCard, StepsPulseTile→(restored, see below),
TrendHeroCard, WeekProgressStrip, HomeView(+StatCard),
PremiumWelcomeScreen, BreathLibraryView, **MainTabView** (the old
shell itself), SessionView, PreSessionView, PostSessionView (the
legacy single-plank trio), JeniMethodTodayCard, JeniMethodJourneyCard.
`scripts/remove_swift_file.rb` added as the inverse of the add script.

**Retained, each with its reason:**
- `PlanView` + Plan/ chrome — `--legacy-today` founder comparison;
  the device pass IS the concrete gate (comparing old vs new Today
  requires the old Today to run).
- `AnalyticsView` + the v1 atoms only it consumes + `FutureRailCard`
  + `StepsPulseTile` (compile deps of the kept file: FutureRail type,
  StepsDetailSheet harness) — `--legacy-becoming` comparison; one
  cluster, dies as one cluster.
- `JeniMethodRitual*` — LIVE (CBT manifest fallback + settings
  re-read), not legacy.
- `OnboardingView` v4.5 — separate founder sign-off predating this
  branch.

## The three embarrassments — fixed, not deferred

1. **Workout content**: the sentence-case template ("Builds the
   muscles in your…") is gone. The brief's line is now short,
   lowercase, cohort-aware, and ends in permission: GLP-1 current →
   "…kept strong while the weight moves. muscle is the part you
   keep ♥"; post-GLP-1 → "…steady. this is how the routine outlives
   the loss."; general → "…built gently. showing up small still
   counts ♥". The redundant preset description left the header.
2. **Program setup subflow**: staged-safe chrome unification — every
   scrapbook card (accent border + paper shadow, 4 sites) now wears
   the hairline register, the progress bar joined the onboarding's
   2pt grammar, the back arrow became the thin chevron. Zero bindings
   or writes touched (goalInputs/commit()/safety caps byte-identical);
   build + unit suite green. Deeper content redesign remains scoped
   for its own pass WITH founder present — this flow writes the plan.
3. **Journal header**: masthead register (tracked "her food story"
   eyebrow over full-serif "your *plates*"), ringed close circle →
   quiet thin mark.

## What the ledger caught that eyes missed

The walker's capture leg surfaced TWO real defects in the consent
sheet: its hearts were raw U+2665 without the FE0E variation selector
(iOS falls back to the RED EMOJI heart — the exact regression the
onboarding memory warns about), and the dismiss vocabulary said "not
now" while the walker knew "not today". Both fixed. This is the
argument for the walker as a permanent asset: it reads surfaces
literally.

## Walker v2.3

Three legs, one PNG ledger (`INVENTORY_DIR`, default
/tmp/jenifit_inventory):
- `testWalkEveryReachableSurface` — today (top/band), steps sheet,
  day peek, mark-as-done, lesson reader, workout brief, snap consent
  + camera, settings hub + 5 sub-screens, jeni (chips/stream/answer/
  tool card), becoming (top/journey/wins), journal + meal detail.
- `testStatesLedger` — wall fresh, wall expired, migration moment,
  workout completion (--debug-post-routine harness), program setup p1.
- `testRestDayBreath` — rest-day today, breath intro, live session,
  completion receipt (rides out the real 60s session).
Deterministic seeds added: `--uitest-seed-day N` (12 protein / 14
rest), two seeded plates via FoodLogPersister.mergeRemote (unlocks
journal/detail/protein/kcal/wins/insights in the ledger),
`--uitest-force-expired`, `--debug-post-routine`.

## Production safety delta

No server artifacts touched this pass (client-only + UITest + copy).
The 13_DEPLOY_SAFETY audit stands unchanged. Gating logic untouched;
AppPhase table tests still green.
