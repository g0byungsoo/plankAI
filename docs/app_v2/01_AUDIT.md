# 01 — Current app audit (2026-07-03)

Six parallel deep-reads of the working tree (shell/home/notifications,
program engine, analytics+food, method/workout/breath, payment/gating,
auth/sync/data-contract), plus first-hand reads of `RootView`,
`PaymentService`, `Tokens.swift`, the OV5 module, and the edge
functions. Citations are file:line in the pre-v2 tree.

## A. What the app is today

**Root flow.** `RootView` (PlankAIApp.swift:2703) switches on
`hasCompletedOnboarding`; completed users wait on
`auth.isReady && payment.isEntitlementReady && loaderMinHoldDone`,
then get `MainTabView` with the hard paywall as a
`.fullScreenCover(isPresented: .constant(!effectiveHasProAccess && !isInAuthTransition))`.
Exit intent → downsell (once/install) → winback (once/session).
Post-purchase → `PostPurchaseFlowView` (forging → coach intro →
breath primer/session → promise confirmation). Trials are gated off
(v1.1.3 pay-upfront) while paywall analytics still emit
`has_trial:true` — drift.

**Tabs.** Two native tabs — today (`PlanView` when `programEraEnabled`,
else `ProgramOnrampView`) and becoming (`AnalyticsView`) — plus a
cocoa camera FAB. Settings reachable only from Today's eyebrow
ellipsis. No `NavigationStack` at either root; depth is ~11 ad-hoc
sheets/covers on Becoming alone.

**Program.** `ProgramGoalCalculator` (cohort pace floors: GLP-1/peri
0.3%/wk, short-sleep 0.4, regain notch, safety caps) → weeks →
`ProgramPlanRecord`. `programDay` derived from calendar. 4 day
archetypes (protein/movement/balanced/rest) on a 7-day rotation
(docs claiming "7 archetypes" are wrong). Every day renders the same
6 rows — lesson, snap, workout, steps, weigh-in, breath — the
archetype only reorders one row to the top and tints copy.

**Food.** Snap camera → `food-vision` EF (JWT-auth, caps, gpt-4o
default) → 3-slide result carousel over the full-bleed photo →
`FoodLogPersister` JSONL (device-local) + plate-level `food_logs`
sync. Journal = ledger rows with monospaced macro footnotes.

**Method.** Manifest CBT curriculum (84 lessons, 6 pillars, 4 acts)
via `LessonReaderView`; legacy 14-day ritual survives as fallback +
settings re-read with a separate, non-reconciling progress ledger.

**Workouts.** Full interval player (`RoutineSessionView` + 1,105
baked voice clips across 3 coach voices) with 70% completion
threshold → `SessionLogRecord`. Post-session star rating collected
then **discarded**.

**Breathwork.** 4 evidence-cited protocols; completions counted in
UserDefaults only.

**Becoming.** Up to 11 stacked modules (diary hero, week dots,
energy+protein tiles, macro row, trend canvas, plate timeline, moved
strip, deeds counter, lighter-days, NSV echo, insight line).

**Payment.** `PaymentService` is genuinely solid: cache-seeded
`hasProAccess`, `customerInfoStream`, 3s safety timeout with forced
refresh, auth-transition suppression, per-emit analytics transitions.

**Auth/sync.** Anonymous-first bootstrap with timeout/retry +
fail-soft cached sessions. Typed upserts for users / session_logs /
day_progress / weight_logs / program_plans / program_day_checks /
food_logs. RLS policies exist as SQL runbooks.

## B. Defect register (things that are simply wrong)

1. **Three protein targets coexist.** 1.0 g/kg (SnapResultView:984),
   1.2 g/kg (AnalyticsView:330), 1.6 g/kg (OnboardingRevealView:1349),
   each with different clamps. A user can see contradictory targets
   the same afternoon. Violates data provenance.
2. **CBT cohort personalization is silently dead.**
   `CohortFlags.fromAppStorage` (CBTCurriculumTypes.swift:118) reads
   `onb_glp1_status` / `onb_stress_level` / `onb_prior_attempts_count`
   / `onb_restrictive_food` / `onb_food_noise` / `onb_perimenopausal`
   / `onb_pcos` — **zero writers exist for any of them** (canonical
   keys are named differently). The curriculum always runs on
   defaults; "archetype-aware pillar affinity" is aspiration.
3. **Session ratings thrown away.** PostRoutineView collects 5-star +
   effort + tags; `onRate` discards the star; `SessionRatingRecord`
   is never constructed; `session_ratings` sync (claimed in
   CLAUDE.md) does not exist; the Becoming rating stat is forever
   empty.
4. **No calorie target in-app.** `CalorieTargetCalculator` runs once
   at the reveal, stamps `foodDailyTarget`, and is never recomputed —
   not on weight change, not on plan change. Snap-meal embed uses
   hardcoded 100/200/70g macro targets (PlanRowEmbeds.swift:91).
5. **Weigh-in row daily while labeled weekly** (ProgramDayPrescription
   doc comment vs PlanView:1799 unconditional append).
6. **Gating fail-open offline-expired.** Cached `hasProAccess=true` +
   offline cold launch + failed 3s refresh → expired user enters the
   app until connectivity. Plus a ≤500ms auth-transition window with
   the cover suppressed, and MainTabView mounts/queries/tracks behind
   the cover for unpaid users.
7. **Cohort keys don't survive devices.** `program_mode`,
   `onboarding_medication_status`, `onboarding_goal_direction`,
   dietary, NSV, fears are AppStorage-only; sign-in on a new device
   restores none of them (safety gate + paywall + copy consumers all
   degrade). Sign-out sweeps them.
8. **Hydration is one-shot on empty-cache** (AppSync.swift:696) —
   cross-device profile edits silently diverge.
9. **`onboarding_dietary` → food-vision `dietary_profile` never
   wired** (FoodVisionService takes it; live source is FoodSettings).
10. **RapidLossTripwire unwired.** The >1%/wk care message exists,
    nothing calls it.
11. **Unconsumed collection:** `onb_v5_seen`,
    `onboarding_appetite_return`, `onb_v5_goal_legacy_mirror` have no
    readers (provenance-rule violations).
12. **Dormant engine capability:** `IntensityProfile.lessonCadence`
    and `.deficitKcalFloor` computed and never read;
    `sessionsPerWeek` never gates which days carry workouts;
    `.plank/.water/.measurements` prescriptions never scheduled.

## C. Design weaknesses (why it reads "indie")

- **Two apps in one.** Onboarding v5 speaks hairline-editorial,
  cross-off, serif punch, receipt rows; the in-app surfaces speak
  v1.0-era card stacks (LuxuryCard vs ScrapbookCard vs EditorialCard
  chrome coexist), sticker sticky-notes, emoji in PostRoutine
  (🔥/💪/👏 against the app-wide kill-list).
- **Density instead of hierarchy.** Becoming stacks ~11 modules;
  three near-duplicate "today's food" tiles read the same value.
  Founder QA comments in-file record repeated "too busy" verdicts.
- **The journal is a spreadsheet.** Ledger rows + monospaced
  `p·c·f` footnotes — exactly the MFP grammar the brand rejects,
  downstream of a genuinely beautiful capture flow.
- **Modules are dead-ends.** Lesson/workout/breath complete → return
  home; no chaining, no "what's next," no thread. Each celebrates in
  a different dialect.
- **Empty states are placeholders**, not invitations (trend canvas
  bare under 2 logs; plate timeline collapses to a dashed tile).
- **Navigation is sheet soup.** ~11 independent presenters on
  Becoming; no stack; no deep-link spine.
- **Dead weight.** ~2,300 lines of orphaned Home-era cards, ~1,500
  lines of the legacy plank session system, PremiumWelcomeScreen,
  BreathLibraryView; PlankAIApp.swift is a 3,874-line god-file (95%
  DEBUG harnesses); PlanView 2,574 and AnalyticsView 4,858 monoliths.

## D. Feature/program weaknesses (why it isn't yet a "program")

- The day is identical every day; archetypes are presentation, not
  programming. Rest days prescribe workouts.
- No daily calorie/protein guidance in the loop the user actually
  lives in (Today) — the program's numbers live only at the reveal.
- No coach presence in-app: CoachNote (a finished Claude client +
  locked voice contract) is shelved; "personalized coaching moments"
  today = string interpolation + cohort-variant selection.
- GLP-1 users get copy acknowledgment but no differentiated day
  (no protein-floor emphasis in the loop, no appetite-rhythm use).
- Post-GLP-1 maintenance mode exists as a flag, not an experience.
- Nothing closes the day: no evening beat, no tomorrow preview, no
  reflection — the retention ritual is one-shot (DailyReturnRitual)
  rather than a daily shape.

## E. What is world-class (keep, do not regress)

- `SnapResultView` carousel + `PlateEditSession` math (unit-tested
  Atwater coherence) + Metal `snapSweep` + `FoodResultExplosion`.
- `BecomingTrendCanvas` (EMA line, raw headline, scrub, windows) and
  the anti-shame weight grammar (7-day raw delta, never DoD).
- The workout player + 1,105-clip voice system + Lottie exercises.
- Breathwork protocols (citations, occasions, receipts).
- The CBT manifest (84 lessons, evidence anchors, cohort variants —
  once the flag bridge is fixed).
- `PaymentService` internals; `AuthService` bootstrap hardening;
  typed sync layer with UUID-case discipline.
- OV5 component language + `JFPageTransition` + haptic grammar.
- `ProgramGoalCalculator` science floors + safety-cap plumbing.

## F. Verdict

The domain layer is largely sound; the experience layer is what's
old. v2 therefore: keeps engines + capture flows + sync machinery,
rebuilds the shell / Today / Becoming / journal / module framing,
adds the missing organ (Jeni chat), fixes the defect register, and
unifies everything under one design language and one voice.
