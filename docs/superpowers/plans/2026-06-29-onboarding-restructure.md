# JeniFit Onboarding Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Tasks are SEQUENTIAL — the files heavily overlap (`OnboardingView.swift`, `OnboardingRevealView.swift`, `ProgramGoalCalculator.swift`). Never run two implementers in parallel.

**Goal:** Cut the redundancy, fix the sequencing, harden the medical-grade safety screening, and reconcile the plan math across JeniFit's onboarding so it builds one ascending value arc to a single climax at the hard paywall — without losing any collected signal.

**Architecture:** Two systems drive the flow: `OnboardingView.v2FlowOrder` (the her75 question cases) and `OnboardingRevealView`'s step machine (the post-questions reveal sequence). The restructure collapses 4 projection charts → 2, 4-6 goal-date prints → 2, and 2 pace pickers → 1; runs `build → one reveal → wall` with the safety gate moved pre-paywall and admin friction (rating/camera/sign-in) moved post-paywall; and wires (or honestly removes) the intake signals that currently say "that shapes your plan" while nothing reads them. Logic changes land first (unit-testable, in `ProgramGoalCalculator`), then the UI/flow changes (sim-verified).

**Tech Stack:** Swift / SwiftUI, Xcode 26.3, iPhone 17 Pro simulator, scheme `plankAI`, bundle `com.bk.plankAI`. Unit tests in `plankAITests` (XCTest). Design system in `PlankApp/DesignSystem/Tokens.swift`. Premium components in `PlankApp/Views/Activation/Design/`.

## Global Constraints

- NO em-dashes or double-hyphens between words, in copy AND comments (use `-`). The glyph `—` is OK only as a no-data placeholder.
- NO the word "AI" in any user-facing copy.
- Only the 8 locked color tokens; `Palette.bgPrimary` cream is the ONLY background; no new colors; NO red.
- Data provenance: every number shown in UI must trace to a real collected field. No fabricated/estimated/placeholder numbers.
- No hardcoded prices anywhere user-facing; prices read from RevenueCat `localizedPriceString` (Apple 3.1.2c).
- Compliance floors: no drug brand names on app surfaces (Apple 5.2.1), no drug-equivalence/"alternative" claims (FTC NextMed / FDA Feb 2026), no first-party numeric weight-loss claims.
- All animated components gate on `@Environment(\.accessibilityReduceMotion)`. No force-unwraps that can crash.
- The hard-paywall free-access invariant MUST hold: the paywall `fullScreenCover` is bound to `!effectiveHasProAccess`; nothing in this restructure may grant app access without purchase/restore.
- Lowercase casual copy; JeniHeroSerif on heroes; italic-Fraunces on punch words; hearts terminal-only.
- Build number / version: this branch ships as **1.1.3 build 23** (already bumped on `main`; the branch will fast-forward). Do not re-bump.
- Branch: `feat/onboarding-polish` (off `main`). The 4 screen redesigns are already done here (nudge `c462820`, disclaimer+commitment `0e1f623`, paywall `a3038b6`) — do NOT redo them.
- NEVER stage `scripts/asc_create_subscriptions.py` or `scripts/__pycache__/` (intentionally uncommitted live-pricing edits).

## File map

- `PlankApp/Program/ProgramGoalCalculator.swift` — pure pacing + safety logic. T1 (calorie), T2 (trend/phase pacing), T3 (safety upgrades).
- `plankAITests/ProgramGoalCalculatorSafetyTests.swift` (+ a new `ProgramGoalCalculatorPacingTests.swift`) — unit tests for T1-T3.
- `PlankApp/Views/Onboarding/OnboardingRevealView.swift` — the reveal step machine + `estimatedCalorieTarget` + Projection / PacePicker / GoalDateReveal / Assessment presentations. T1 (calorie consumer), T5 (de-dupe), T6 (resequence), T7 (safety gate placement).
- `PlankApp/Views/Onboarding/OnboardingView.swift` — `v2FlowOrder` + question cases (167, 21, 215, 23, 26, 250, 161, 136, 155, 157, 1320, 1641). T2/T5/T6/T8/T9.
- `PlankApp/Views/Onboarding/OnboardingComponents.swift` — `SCOFFScreenView`, `SafetyRecoveryView`, `SafetyConsentView`. T3/T4/T7.
- `PlankApp/Views/Program/ProgramSetupSubflow.swift` — current post-paywall `safetyPhase`. T7 (move it pre-paywall).
- `PlankApp/PlankAIApp.swift` — hard paywall cover (~L2391) + post-purchase routing + `--debug-*` harnesses. T6/T7/T8.
- `PlankApp/Views/Analytics/AnalyticsView.swift` (Becoming) — T9 (surface NSV priorities).

---

### Task 1: Reconcile the calorie target with the pace math

**Problem:** `estimatedCalorieTarget` (in `OnboardingRevealView.swift`) is `currentWeightKg * 22` clamped 1300-2000, computed independently of the picked pace and goal date. The calorie hero and the goal date are unrelated formulas wearing a matching card. A post-Cal-AI cohort notices.

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingRevealView.swift` (the `estimatedCalorieTarget` computed var — grep for `estimatedCalorieTarget` and `* 22`).
- Create: `PlankApp/Program/CalorieTargetCalculator.swift` (pure function, unit-testable).
- Test: `plankAITests/CalorieTargetCalculatorTests.swift`.

**Interfaces:**
- Produces: `CalorieTargetCalculator.dailyTarget(currentWeightKg:heightCm:age:sex:activityKey:lossRatePctPerWeek:) -> Int` and `tdee(...) -> Int`.

**Approach (the real reconciliation):**
1. TDEE = Mifflin-St Jeor BMR × activity factor. BMR (female) = `10*kg + 6.25*cm - 5*age - 161`; (male) `+5` instead of `-161`; unspecified = female formula (conservative). Activity factor from the onboarding activity key (sedentary 1.2 / light 1.375 / moderate 1.55 / active 1.725; map the project's actual activity option keys — grep the activity question case).
2. Daily deficit = `(lossRatePctPerWeek * currentWeightKg) kg/week * 7700 kcal/kg / 7 days`. (7700 kcal per kg is the standard energy-per-kg constant; cite Hall 2012 in a comment as the ramp caveat.)
3. `dailyTarget = round(TDEE - deficit)`, clamped to a safe floor of `max(1200, BMR)` (never below BMR or 1200) and the existing ceiling. The picked `lossRatePctPerWeek` comes from the selected tier: Hard=0.01, Medium=0.0075, Soft=floor (0.005, or 0.003/0.004 cohort floor — read the same floor `ProgramGoalCalculator.compute` used). So the calorie number now MOVES with the pace pill and DERIVES from the same rate that draws the goal date.

**Steps:**
- [ ] Step 1: Write `CalorieTargetCalculatorTests` — assert: (a) a 80kg/165cm/30/female/sedentary user at 0.005/wk gets a target between her BMR and her TDEE and below `80*22`-ish only when the deficit warrants; (b) Hard pace (0.01) yields a LOWER target than Soft (0.005) for the same person; (c) the target never drops below `max(1200, BMR)`; (d) target is deterministic.
- [ ] Step 2: Run tests, verify they fail (no `CalorieTargetCalculator`).
- [ ] Step 3: Implement `CalorieTargetCalculator` with the formulas above. Register the new file in `project.pbxproj` (non-synchronized project — add fileRef + build-file + Sources phase entry; `plutil -lint` after).
- [ ] Step 4: Run tests, verify they pass.
- [ ] Step 5: Replace `estimatedCalorieTarget` in `OnboardingRevealView` to call `CalorieTargetCalculator.dailyTarget(...)`, passing the picked tier's `lossRatePctPerWeek` (the same rate the projection/goal-date uses — read from the active plan record / picked tier already in scope). Keep the calorie hero's honesty caption ("a starting plan, we'll tune yours").
- [ ] Step 6: `xcodebuild ... build` -> BUILD SUCCEEDED. `xcrun simctl launch booted com.bk.plankAI --debug-assessment` (or the reveal-projection harness), screenshot `/tmp/t1_calorie.png`, confirm the calorie hero renders a sane number that reflects the pace.
- [ ] Step 7: Commit `feat(program): calorie target derives from TDEE minus pace-implied deficit`.

---

### Task 2: Wire weight-trend + GLP-1 phase into pacing (stop the "shapes your plan" lie)

**Problem:** case `1320` (weight trend: `cycling`/`gaining`/`losing`/`stable`) and case `1641` (GLP-1 phase: `just_started`/etc.) are collected, synced, and tell the user "got it, that shapes your plan" — but `ProgramGoalCalculator.compute` ignores them.

**Files:**
- Modify: `PlankApp/Program/ProgramGoalCalculator.swift` (`Inputs` + `compute`).
- Modify: the call sites that build `Inputs` (grep `ProgramGoalCalculator.compute(` and `Inputs(`).
- Test: `plankAITests/ProgramGoalCalculatorPacingTests.swift` (new).

**Interfaces:**
- Produces: `Inputs` gains `weightTrendKey: String = ""` and `glp1PhaseKey: String = ""`; new helpers `isRegainRisk(from:) -> Bool` and `isEarlyGLP1(from:) -> Bool`.

**Approach:** Keep changes inside the existing floor cascade so behavior for unset values is identical.
- `cycling` weight trend → regain-risk → widen the window one notch: nudge the effective floor down by one step (e.g. default 0.005 → 0.004), so the expected pace is GENTLER (longer maxWeeks). Document: regain history warrants a more sustainable glide (NWCR).
- GLP-1 phase `just_started` → apply the cautious 0.003 floor + set a `proteinEmphasis` flag the reveal copy can read (the inline copy already claims protein emphasis). `just_started` should also imply `isGLP1User`-equivalent caution even if `glp1_status` mapping lags.

**Steps:**
- [ ] Step 1: Write `ProgramGoalCalculatorPacingTests`: (a) `cycling` trend produces a `maxWeeks >= ` the same user's `maxWeeks` without it (gentler); (b) `just_started` GLP-1 phase forces the 0.003 floor; (c) unset values (`""`) reproduce the EXACT current window (regression lock).
- [ ] Step 2: Run, verify the new-behavior tests fail and the regression test passes.
- [ ] Step 3: Add `weightTrendKey`/`glp1PhaseKey` to `Inputs` (defaulted, so all existing call sites compile unchanged), add the helpers, fold them into the floor cascade in `compute`. Update the call sites that have the AppStorage values in scope to pass them (`onboarding_weight_trend`, `onboarding_glp1_phase`).
- [ ] Step 4: Run tests, verify pass.
- [ ] Step 5: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 6: Commit `feat(program): weight-trend + GLP-1-phase now move pacing (no more dead signals)`.

---

### Task 3: Safety upgrades — medication branch, GLP-1-aware SCOFF, ttc routing

**Problem:** `safetyAssessment` has no medication/hypoglycemia screen (the biggest real hazard for the GLP-1 cohort), SCOFF false-positives current-GLP-1 users (rapid loss + food-noise are expected drug effects), and `ttc` falls through to a loss deficit.

**Files:**
- Modify: `PlankApp/Program/ProgramGoalCalculator.swift` (`SafetyInputs`, `ProgramMode`, `safetyAssessment`, `scoffPositive`).
- Test: `plankAITests/ProgramGoalCalculatorSafetyTests.swift` (extend).

**Interfaces:**
- Produces: `ProgramMode` gains `.clinicianFirst`. `SafetyInputs` gains `medicationKey: String` (`none`/`insulin_or_sulfonylurea`/`other_glucose`/`prefer_not_say`/`""`), `glp1StatusKey: String`, `weightTrendKey: String`. `safetyAssessment` reads them.

**Approach (order stays most-protective-first):**
1. age `under18` → `.blocked` (unchanged).
2. medication: `insulin_or_sulfonylurea` → `.clinicianFirst` (reasonKey `"med_hypo"`, no deficit; copy: a deficit plan with these meds needs a clinician's input first — supportive, not scary). New branch ABOVE the ED branch (a real physiological hazard).
3. ED / SCOFF — make GLP-1-aware: when `glp1StatusKey == "current"`, do NOT auto-route a 2-yes to `recovery` if the only yes-items are the GLP-1-expected ones. Implement: keep `scoffPositive` for the general case, but add `scoffPositive(yesCount:glp1Current:rapidLossExpected:)` that requires `yesCount >= 3` for current-GLP-1 users (raise the threshold by 1 to absorb the two expected-effect items), OR accept a `coreYesCount` (yes-count excluding the rapid-loss + food-dominates items) and screen on that. Use the `coreYesCount` approach — cleaner and honest. `SCOFFScreenView` (T7) passes both counts.
4. pregnancy: add `case "ttc":` → `.maintenance` reasonKey `"ttc"` (no aggressive pre-conception deficit). `pregnant`/`breastfeeding` unchanged.
5. BMI floor unchanged.

**Steps:**
- [ ] Step 1: Extend `ProgramGoalCalculatorSafetyTests`: (a) `insulin_or_sulfonylurea` → `.clinicianFirst`; (b) current-GLP-1 user with 2 yes that are ONLY the expected-effect items → `.loss` not `.recovery`; (c) current-GLP-1 user with 2 CORE yes → still `.recovery`; (d) `ttc` → `.maintenance`; (e) all existing assertions still pass (regression).
- [ ] Step 2: Run, verify new fail / regression pass.
- [ ] Step 3: Implement. Add `.clinicianFirst` to `ProgramMode`, the new `SafetyInputs` fields (defaulted so call sites compile), the medication + ttc branches, the `coreYesCount` SCOFF path.
- [ ] Step 4: Run tests, verify pass.
- [ ] Step 5: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 6: Commit `feat(safety): medication/hypoglycemia branch + GLP-1-aware SCOFF + ttc routing`.

---

### Task 4: Medication / hypoglycemia intake screen

**Problem:** No screen asks about insulin / sulfonylurea — the single biggest deficit-safety hazard for the GLP-1-adjacent cohort.

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingView.swift` (add a new question case + add it to `v2FlowOrder` right after the GLP-1 question `164`/`1641`, in the medical-context cluster).
- Modify: `PlankApp/Views/Onboarding/OnboardingComponents.swift` if a shared option-card component is reused.
- New AppStorage key: `onboarding_medication_status` (value space matches `SafetyInputs.medicationKey`).

**Approach:** A her75-register single-select question, clinically framed, compliant (NO drug brand names — use the class/category language). Copy:
- Headline: "one quick health question." (JeniHeroSerif)
- Body: "are you taking any medication that lowers your blood sugar?"
- Options (tall pills): "insulin or a sulfonylurea" / "another glucose medication" / "no" / "prefer not to say".
- Sub/footnote (small, honest): "we ask because a calorie plan needs your clinician's input if you take these." NO drug brand names.
- Writes `onboarding_medication_status`.

**Steps:**
- [ ] Step 1: Add the case + AppStorage key + add to `v2FlowOrder` after the GLP-1 cluster. Wire its value into the `SafetyInputs` builder used by T7's gate.
- [ ] Step 2: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 3: Add `--debug-medication` harness (mirror existing `--debug-*`), launch, screenshot `/tmp/t4_medication.png`, confirm premium clinical look + tall pills + honest footnote, nothing clipped.
- [ ] Step 4: Commit `feat(onboarding): medication/hypoglycemia intake screen (compliant, no drug names)`.

---

### Task 5: De-dupe — cut duplicate pace picker, cut GoalDateReveal, merge assessment into projection

**Problem:** pace asked twice (`case 167` + reveal `PacePicker`), `GoalDateReveal` re-prints the date the assessment arc shows seconds later, and `Assessment`'s `ArcSparkline` is a 3rd projection curve.

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingView.swift` (`v2FlowOrder` — remove `167`).
- Modify: `PlankApp/Views/Onboarding/OnboardingRevealView.swift` (step machine ~L71-180 — remove `goalDate` and `assessment` steps; fold the assessment's UNIQUE payload into the `projection` step).

**Approach:**
- Keep the reveal `PacePicker` (better composed, sits next to the projection it recomputes). Remove `case 167` from `v2FlowOrder`. Verify nothing else reads case-167-only state (the pace key is written by both; PacePicker still writes it).
- Cut the `goalDate` reveal step entirely (its arrival date + 5-dot timeline is re-shown by the projection/assessment). The single date hero now lives ON the projection card.
- Cut the standalone `assessment` step. MERGE its two unique assets into the `projection` step: (a) the "paced like a clinician would. slower is what lasts." credibility line + the cohort-provenance line (e.g. "gentler because you sleep ~6h"), rendered as a `LabReadoutBlock`/hairline credibility strip UNDER the projection card; (b) keep ONLY the `BecomingProjectionCard` curve (drop the `ArcSparkline` duplicate). Net: ONE reveal curve + the pace + the calorie + the clinician credibility, all on one screen.

**Steps:**
- [ ] Step 1: Remove `167` from `v2FlowOrder`; confirm via grep no dangling references break navigation.
- [ ] Step 2: Remove `goalDate` + `assessment` from the reveal step enum + switch; fold the credibility lines into the `projection` presentation; delete the now-dead `GoalDateRevealPresentation` + `AssessmentPresentation` structs and any helpers only they used (dead-code rule).
- [ ] Step 3: `xcodebuild ... build` -> BUILD SUCCEEDED (grep the log to confirm OnboardingRevealView recompiled).
- [ ] Step 4: Launch the reveal harness, screenshot `/tmp/t5_projection.png`, confirm: one curve, the date once, the pace, the calorie, the clinician credibility strip; no clipping; the reveal flows projection -> firstWeek without the cut steps.
- [ ] Step 5: Commit `refactor(onboarding): one projection reveal - cut dup pace, GoalDateReveal, assessment curve`.

---

### Task 6: Resequence the climax — loader before "ready", build → one reveal → wall

**Problem:** `case 21` says "your plan is ready" BEFORE the `building` 25-35s loader says it's still "building" — a contradiction that reads fake. And the reveal is smeared across pre- and post-loader screens.

**Files:**
- Modify: `PlankApp/Views/Onboarding/BuildingPlanLoadingView.swift` (duration).
- Modify: `PlankApp/Views/Onboarding/OnboardingView.swift` (`v2FlowOrder` placement of `21` and the building/reveal handoff).
- Modify: `PlankApp/Views/Onboarding/OnboardingRevealView.swift` (step order).

**Approach:**
- Trim `BuildingPlanLoadingView` to ~8s total (read its current 25-35s timing — grep the duration constants ~L57-62 — and cut to a ~8s budget across its label beats).
- Ensure order is: `... questions ... → building loader (~8s) → projection reveal (climax) → firstWeek → commitment → permissions/nudge → paywall`. The premature `case 21` "your plan is ready" beat is REDUNDANT with the projection reveal: cut `case 21`'s standalone "ready" screen and let the projection reveal be the single "here it is" moment. If `case 21`'s day-one 5-rail card has unique content not in `firstWeek`, fold the unique rails into `firstWeek`; otherwise remove it.
- The disclaimer + safety gate placement is handled in T7; this task just gets the build → reveal → wall spine right.

**Steps:**
- [ ] Step 1: Trim the loader to ~8s; verify the label beats still read.
- [ ] Step 2: Remove/cut `case 21` (fold unique rails into `firstWeek` if any); set `v2FlowOrder` + reveal order to build → projection → firstWeek → commitment → permissions → paywall.
- [ ] Step 3: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 4: Walk the flow in sim from the building loader forward (use the reveal harness), screenshot `/tmp/t6_sequence_1.png` (loader) + `/tmp/t6_sequence_2.png` (projection). Confirm no "ready" claim precedes the loader, and the loader is ~8s.
- [ ] Step 5: Commit `refactor(onboarding): build then one reveal then wall - loader trimmed, no premature ready`.

---

### Task 7: Move the safety gate pre-paywall

**Problem:** the SCOFF + BMI + pregnancy gate runs in `ProgramSetupSubflow` AFTER the hard paywall (inside `MainTabView`). Charging a user, then routing a pregnant/under-18/ED/insulin user to a "this isn't for you" terminal is a medical + refund + App Review (5.1.1) risk.

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingRevealView.swift` (insert the safety screen as a reveal step right after `disclaimer`, before `building`).
- Modify: `PlankApp/Views/Onboarding/OnboardingComponents.swift` (`SCOFFScreenView` passes `coreYesCount` per T3; reuse `SafetyRecoveryView`/`SafetyConsentView` terminals).
- Modify: `PlankApp/Views/Program/ProgramSetupSubflow.swift` (remove the now-duplicated `safetyPhase`; it must NOT run twice).
- Modify: `PlankApp/PlankAIApp.swift` if routing to terminals needs a pre-paywall exit path.

**Approach:**
- Build the `SafetyInputs` (now incl. `medicationKey`, `glp1StatusKey`, `weightTrendKey`) from AppStorage at the end of the reveal, run `safetyAssessment`, and branch BEFORE the paywall:
  - `.blocked` (under 18) → supportive exit terminal, no paywall.
  - `.recovery` (ED) → `SafetyRecoveryView` (non-numeric, NEDA/988 resources), no paywall, no goal weight.
  - `.clinicianFirst` (insulin) → supportive "talk to your clinician first" terminal, no deficit paywall (offer a maintenance/non-deficit path or a soft exit — keep it supportive, compliant, no drug names).
  - `.maintenance` (pregnant/breastfeeding/ttc/low-BMI) → continue to a maintenance-framed reveal + paywall (no aggressive deficit copy).
  - `.loss` → continue normally; `softConfirm` (healthy BMI) softens + confirms.
- CRITICAL: ensure the gate runs EXACTLY ONCE. Remove/disable the post-paywall `safetyPhase` in `ProgramSetupSubflow` so it does not re-run. Verify the hard-paywall free-access invariant still holds (the terminals are pre-paywall exits, not app access).

**Steps:**
- [ ] Step 1: Insert the safety step after `disclaimer` in the reveal machine; build `SafetyInputs` from AppStorage; route per mode.
- [ ] Step 2: Remove the duplicate post-paywall `safetyPhase` from `ProgramSetupSubflow`; confirm no double-run.
- [ ] Step 3: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 4: Sim-verify each branch via a debug harness that seeds the inputs: screenshot `/tmp/t7_recovery.png` (SCOFF positive), `/tmp/t7_clinician.png` (insulin), `/tmp/t7_loss.png` (normal continues to paywall). Confirm none of the terminals grant app access.
- [ ] Step 5: Commit `feat(safety): run the safety gate pre-paywall (no charge-then-reject)`.

---

### Task 8: Move admin friction post-paywall

**Problem:** sign-in (`26`), App Store rating (`215`), and camera setup (`23`) sit between the plan reveal and the price, bleeding impulse intent.

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingView.swift` (`v2FlowOrder` — remove `215`, `23`; evaluate `26`).
- Modify: `PlankApp/PlankAIApp.swift` (post-purchase flow — present rating + camera setup after purchase; `presentPostPurchaseFlowIfEligible`).

**Approach:**
- Move `215` (App Store rating) and `23` (camera setup) into the post-purchase flow (after `onSubscribed`), where the user is already committed. Low risk.
- `case 26` (sign-in) is HIGHER risk: it ties to the anonymous-first Supabase model + RevenueCat `auth.currentUser` identity. Evaluate: if an anonymous user can purchase and the entitlement reliably transfers on later sign-in (the app already supports anonymous-first + restore + sign-in recovery), move sign-in post-paywall too. If verification shows ANY entitlement-stranding risk, LEAVE `26` pre-paywall and note it. Do not guess — verify the RevenueCat alias behavior in sim before moving it.

**Steps:**
- [ ] Step 1: Remove `215` + `23` from `v2FlowOrder`; add them to the post-purchase flow.
- [ ] Step 2: Evaluate `26`: verify (in sim) anonymous purchase → entitlement holds → later sign-in preserves it. If clean, move `26` post-paywall; else leave it and document why.
- [ ] Step 3: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 4: Sim-verify the pre-paywall flow ends at the paywall with no rating/camera in between; screenshot `/tmp/t8_flow.png`. Verify hard-paywall invariant holds.
- [ ] Step 5: Commit `refactor(onboarding): rating + camera setup move post-paywall (tighten run to the wall)`.

---

### Task 9: Honest signals — surface NSV, fix "still to sharpen", remove dead keys

**Problem:** `136` (NSV priorities) is collected + "we'll watch for these" but never shown again; `case 161`'s "still to sharpen" lists inputs (stress, eating) that don't move the math; `onb_v4_movement_baseline` is dead; some confirmations promise "shapes your plan" without wiring.

**Files:**
- Modify: `PlankApp/Views/Analytics/AnalyticsView.swift` (Becoming) — echo the user's chosen NSVs (read `nsvPriorityCSV`).
- Modify: `PlankApp/Views/Onboarding/OnboardingView.swift` — fix `case 161`'s "still to sharpen" list to name ONLY inputs that genuinely move the number (sleep, cycle/peri, GLP-1, weight-trend after T2); remove the dead `onb_v4_movement_baseline` key + any always-default `applyCadenceDerivations` branch; for `stress` (155) + `eating window` (157), remove the "that shapes your plan"-style confirmation promise OR (cheaper) leave the question but make the confirmation honest ("noted" not "that shapes your plan"). Decision: make the confirmations honest (do not over-promise); do NOT delete the questions (they have product value later).

**Steps:**
- [ ] Step 1: Add an NSV echo to the Becoming dashboard (reads the collected `nsvPriorityCSV`; if empty, render nothing - provenance rule).
- [ ] Step 2: Fix `case 161` copy + remove the dead movement key + correct any over-promising confirmations (155/157/136/1641/1320 where not wired by T2).
- [ ] Step 3: `xcodebuild ... build` -> BUILD SUCCEEDED.
- [ ] Step 4: Screenshot `/tmp/t9_becoming.png` (NSV echo) + `/tmp/t9_161.png` (corrected copy). Confirm provenance (NSV echo only shows real picks).
- [ ] Step 5: Commit `feat(onboarding): surface NSV picks on Becoming + honest confirmations (no dead promises)`.

---

## Self-Review

**Spec coverage:** (1) DE-DUPE → T5 (+ the chart reduction across T5/T6). (2) RESEQUENCE → T6 (loader + spine) + T8 (admin post-paywall). (3) MEDICAL → T3 (logic) + T4 (med screen) + T7 (gate pre-paywall). (4) CALORIE MATH → T1. (5) UNUSED SIGNALS → T2 (wire trend/phase) + T9 (NSV/copy/dead-key). All five workstreams covered.

**Placeholder scan:** Formulas (Mifflin-St Jeor, 7700 kcal/kg, deficit) and copy (medication screen) are concrete. The one deliberately open item is T8's sign-in move, which is gated on an in-sim entitlement-transfer verification (escalate if it strands entitlements) — that is a verification branch, not a placeholder.

**Type consistency:** `lossRatePctPerWeek` is the shared rate threaded from the picked tier through both the goal-date (existing) and the calorie target (T1). `ProgramMode.clinicianFirst` (T3) is consumed by T7's routing. `SafetyInputs` new fields (T3) are populated by T4's medication key + T7's builder. `coreYesCount` (T3) is produced by `SCOFFScreenView` (T7). Consistent.

**Risk ordering:** logic-first (T1-T3, unit-tested, no flow change) → new screen (T4) → de-dupe (T5) → resequence (T6) → the two riskiest reroutes last (T7 safety-gate move, T8 admin move), each isolated with its own sim verification and the hard-paywall invariant re-checked.
