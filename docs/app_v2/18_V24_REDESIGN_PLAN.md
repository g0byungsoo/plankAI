# 18 — v2.4 redesign plan: implemented + scoped

Date: 2026-07-03. Verdicts from 17_FEATURE_EVALUATION; this doc is
the build ledger for the product pass.

## Implemented this pass (all build-verified; suite green)

1. **Breathwork → the craving-reset system.** Doorways renamed from
   feelings to MOMENTS ("a craving wave" / "the day went sideways" /
   "food noise is loud" / "begin again"); occasion lines rewritten to
   urge-surfing + begin-again mechanics ("cravings crest and pass
   like a wave… the long exhale is how you ride it instead of feeding
   it"); the intro question became "what are we resetting?". Raw enum
   values untouched — quick-start prefs persist. Session mechanics
   untouched (69% completion says don't).
2. **Workouts → the five-minute floor.** Every workout brief carries
   the second door: "make it 5 minutes" (JFContinueButton secondary)
   → TodayModuleState.shrinkWorkoutToFloor() regenerates today's
   preset at 5 min from remembered tier/focus. No guilt gradient.
   Hidden when already ≤5 min or in hosts without the hook.
3. **Method → read-becomes-a-rep.** Lesson completion sets a one-shot
   chain on Today ("put it to work → sixty seconds of *breath*")
   routed through AppRouter; cleared on tap. The lesson stops being
   a dead-end read.
4. **Jeni knows the brake + the floor.** Persona additions (server
   file, NOT yet deployed → zero prod risk): craving/food-noise
   language routes to the sixty-second reset via start_breathwork;
   low-energy days get the five-minute frame. 13_DEPLOY_SAFETY
   verdict unchanged (the EF remains undeployed; same custody, same
   caps; delta = prompt text only).

## Verified

- Build + full unit suite green after all changes.
- testLivedDay walker leg added (real mutations: sheet-confirm beat
  marking, weigh-sheet save path) — passed; en route it captured the
  lesson reader page 1 at full quality for the ledger (kicker /
  serif punch / CBT body / photo / act footer — meets the bar).
- Breath doorway copy is exercised by the existing rest-day leg on
  the next full ledger run.

## Scoped next (concrete, not parking-lot)

- **Method content pass** (founder-present): re-author slot copy for
  deficit/protein/GLP-1 realities. 84 slots × 4 pages of authored
  voice — the founder owns the voice sign-off. Gate: a shared doc of
  10 rewritten sample slots first.
- **Journal day-receipt line** ("84g protein · 3 plates · fits") +
  "ask jeni about this day" — package-side, batch with the sweep.
- **Post-weigh interpretation whisper** in LogWeightSheet — batch
  with the notification orchestrator (same copy engine).
- **Program setup ritual** (content + flow order) — founder-present,
  same gate pattern as Method.
- **Steps/water/measurement prescriptions** stay unscheduled until a
  cohort needs them (provenance rule).

## Success metrics to watch post-release

Workout completion rate (floor-exposed vs not) · breath starts from
craving doorway + chat routing · lesson→action-within-1h rate ·
paid D7 (the fire) · protein-days-hit per week.
