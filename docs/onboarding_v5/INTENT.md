# Onboarding v5 — Intent (the anchor doc)

Started 2026-07-02. Branch `feat/onboarding-v5`. Founder brief: complete
ground-up redesign + rebuild of onboarding. Goal = maximize subscription
conversion at the hard paywall AND collect the data that makes the
in-app program genuinely custom. Design bar: "top 1% of human designers,
instantly eligible for an Apple Design Award" — her75 editorial luxury,
Gen-Z feminine, zero AI-slop tells, every transition intentional.

## Why a rebuild when v4.5 just shipped

v4.5 (~53 screens) carries 8 months of conversion science but its
presentation layer is a 9,645-line switch-on-Int monolith
(`OnboardingView.swift`) grown case-by-case. Screens are structurally
same-y (header + option list + CTA), transitions are one global
cross-dissolve, inputs are stock (pickers/steppers), and the flow has
zero product-magic preview (the #1 gap vs Cal AI, which demos scan
during onboarding). The founder wants the her75 FEEL — tactile ruler
sliders, cross-off selections, editorial photo cutouts, collage
moments, matched-geometry continuity — at 100x polish, with a fake-but-
convincing calorie snap demo as a centerpiece.

## What is LOAD-BEARING (preserve, do not regress)

1. **The data contract.** Downstream consumers read these AppStorage
   keys (writers may move screens; keys must still be written):
   - `onboarding_glp1_status` (`none/considering/past/current/prefer_not_say`) → `Glp1Cohort` everywhere
   - `onboarding_glp1_phase` (`just_started/few_months/established/prefer_not`) → early-GLP-1 pace floor
   - `onboardingSleepHours` (`under5/five6/six7/seven8/eightPlus`) → short-sleep pace penalty
   - `onboardingHormonalStage` (`perimenopause/...`) → peri floor
   - `onboarding_weight_trend` (`climbing/stable/declining/cycling`) → regain-risk pace notch
   - `onboarding_goal_direction` + `program_mode` (`loss/maintenance`)
   - `onboarding_medication_status` → safety gate `.clinicianFirst`
   - gender/age/height/weight/goal-weight numeric keys (see DATA_CONTRACT.md)
   - `onboardingPickedTier` (`gentle/medium/strong` → pace)
   - `onboardingNsvPriority`, `onboardingPriorAttempts`, `onboardingPriorWin`,
     `onboardingFoodRelationship`, `onboardingEatingCadence`,
     `onboardingCuisinePreference`, `onboarding_dietary`,
     `onb_fear_*` triplet, `onb_consent_*` pair, `onboardingStressLevel`,
     `onb_v4_movement_baseline`, name, attribution.
   - `hasCompletedOnboarding` terminal flag.
2. **Safety architecture (medical-grade v1.2).** SCOFF screen, BMI
   floor, pregnancy gate, medication/hypoglycemia intake, SafetyGate
   pre-paywall (`SafetyGatePresentation`), rapid-loss tripwire. These are
   partnership-grade credibility; v5 re-skins, never removes.
3. **Conversion beats proven in v4.5** (each traces to a teardown):
   anti-shame anchor early; food wedge before biometrics; cohort
   credibility slot; reciprocity beat after vulnerability cluster;
   psychometric Yes/No fears (Bem self-perception); "why it came back"
   conviction beat; realistic-target reframe; NSV outcome cards;
   consent checkboxes; HK ask mid-flow so projection can cite steps;
   notification ask as reveal's last pre-paywall beat; rating ask
   post-paywall. Long quiz is a FEATURE for this market (Cal AI 43,
   BetterMe 33+) — restructure for felt-pace, don't naively shorten.
4. **Compliance floors.** No drug brand names, no drug-equivalence, no
   "GLP-1 alternative" framing, no first-party numeric WL claims, no
   "AI" word, no em-dashes, hearts terminal-only, lowercase casual.
   ACSM pace bounds. Data provenance: every number shown traces to a
   collected field.
5. **Design system.** 8 locked palette tokens, cream `bgPrimary` only
   background, JeniHeroSerif/Fraunces/DMSans ladder, motion tokens,
   scatter only on welcome/plan-reveal/graduation, real-photo ≥40% +
   stickers ≤10% guardrails, Grok pipeline w/ no-hands + face-from-
   behind rules.

## What LEAPS (the 100x)

1. **Architecture**: `PlankApp/Views/OnboardingV5/` — typed step enum
   state machine (no Int cases), one file per screen family, shared
   scaffold, testable pure `OV5Flow` router with cohort branching.
2. **Tactility**: her75 tick-ruler slider (weight/goal/height/age) with
   haptic detents + pill readout; cross-off strikethrough on selects;
   press-scale on every touchable; drag-to-commit moments.
3. **Continuity**: persistent atmosphere layer; per-element staggered
   fade-rise (founder-approved luxury transition); matched-geometry
   handoffs (chosen pace card → plan card; snapped food → plate card;
   goal number rides from slider → projection).
4. **Snap demo (NEW hero beat)**: 3 hardcoded gorgeous meals; she picks
   one, the REAL Metal `snapSweep` scan pass runs over it, plate card
   pops with count-up kcal + protein + confidence语 — the product magic
   pre-paywall, no API.
5. **Editorial collage moments**: welcome "become her" collage
   (Grok transparent cutouts, her75 IMG_6256 register), reveal scatter.
6. **Plan-build ritual**: personalizing checklist rebuilt as a slow
   luxury sequence which VISIBLY consumes her answers (each line cites
   her actual inputs), then matched-geometry into the projection.
7. **Structure**: 5 acts with chapter covers as micro-dwells; insight
   interstitials that GIVE value back after each ask cluster.

## Non-goals

- Paywall internals (v1.0.7 single-screen paywall is solid; we polish
  the seam INTO it, not the wall itself).
- Post-purchase flow, program engine math, sync schema: untouched.
- Localization: English only (matches app).

## Rollout

`OnboardingView` call sites in `RootView` swap to `OnboardingV5Flow`.
v4.5 code stays on disk this branch (deleted only after founder signs
off on device) but is unreachable except via `--onboarding-v4` launch
arg debug escape. `hasCompletedOnboarding` semantics unchanged.

## File map (planned)

```
PlankApp/Views/OnboardingV5/
  OV5Flow.swift            // step enum + router + answer store
  OV5Screens.swift         // screen registry: step → view builder
  OV5Scaffold.swift        // chrome: progress, back, CTA dock, atmosphere
  OV5Components.swift      // option cards, chips, pills, headers
  OV5Ruler.swift           // tick-ruler slider (weight/height/age/goal)
  OV5Collage.swift         // welcome collage + scatter moments
  OV5SnapDemo.swift        // fake-but-real calorie snap demo
  OV5Interstitials.swift   // chapter covers, insight beats, teach screens
  OV5PlanBuild.swift       // building ritual → projection handoff
  (reveal continues to reuse OnboardingRevealView presentations where
   they already carry the science: SafetyGate, Projection, PacePicker,
   FirstWeek, NudgePermission — re-skinned to v5 chrome.)
```

## Verification bar

Every screen screenshotted in sim (light mode, iPhone 16 Pro), every
branch walked (generalWL / current / past / considering GLP-1,
maintenance mode, safety-gate trips), reduce-motion pass, Dynamic Type
sanity at XL, no layout overflow at iPhone SE width if cheap. Transition
frame-feel checked via recorded video where practical.
