# Phase 1a — "The Honest Arrival" Activation Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every new payer get an instant, *realistic* read of their plan (payoff before task), make one near-zero-effort promise that schedules a Day-1 return, and return to a kept-promise win — on a forgiving, habit-based (never weight-based) arrival horizon with clinical safety brakes enforced.

**Architecture:** Logic-first, UI-second. Tasks 1–6 verify/enforce the safety + data substrate (the "brakes") and add the schedulers/counters; Tasks 7–11 build the reveal/home/notification surfaces (the "amplifiers") on top. SwiftUI surfaces are verified by build + simulator screenshot; pure logic is verified by XCTest (`plankAITests`).

**Tech Stack:** SwiftUI, SwiftData (`@Model`, `@Query`), `@AppStorage`/UserDefaults, UserNotifications, XCTest. Existing types: `ProgramGoalCalculator`, `ProgramPlanRecord`, `UserRecord` (PlankSync package), `NotificationPermission`, `Glp1Cohort`.

## Global Constraints

- **No first-party numeric/speed weight-loss claim** on any surface. "On-track" = on-track-with-HABITS (behavior completion), NEVER on-track-to-a-weight or a predicted number.
- **The date is a forgiving horizon**, shown as `~[date]`; it recomputes on a miss; it **never turns red, never says "behind," never a countdown.** Miss copy = *"your timeline is yours."*
- **Pace clamp:** implied loss ≤ **1%/wk** (Hard ceiling) and ≥ the cohort floor (0.3–0.5%/wk). If a desired date implies faster, **move the date out, not the deficit up.**
- **BMI floor:** never ship a goal weight implying BMI < **18.5**.
- **Copy bans:** no red bars, no "behind"/deficit/"you're down"/"on pace to lose", no streak-loss threats, no good/bad food, no drug names, no drug-equivalence/"GLP-1 alternative". Provenance rule: every number traces to a collected field.
- **Voice/design:** dual register on shared surfaces — warm identity line in JeniHeroSerif + a quiet data line in DMSans; keep `bgPrimary` cream; no hospital aesthetic. Lead with the word **"realistic."**
- **Notifications:** D0–D3 capped at **3 total**, each in her words/data, activation-state-keyed, suppressed if she already acted that day.
- **After any SwiftUI change, capture a simulator screenshot in the same step** (founder rule) on `iPhone 16 Pro`.
- **Build/test command:**
  `xcodebuild -project plankAI.xcodeproj -scheme plankAITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`
- Spec: `docs/superpowers/specs/2026-06-28-phase1a-dated-arrival-activation-design.md`.

---

### Task 1: Regression-lock the pace-clamp safety envelope

**Files:**
- Modify (only if a gap is found): `PlankApp/Program/ProgramGoalCalculator.swift:139-183` (`compute(_:)`)
- Test: `plankAITests/ProgramGoalCalculatorSafetyTests.swift` (create)

**Interfaces:**
- Consumes: `ProgramGoalCalculator.compute(_ inputs: ProgramGoalCalculator.Inputs) -> ProgramGoalCalculator.Window` where `Window` exposes `minWeeks`, `maxWeeks`, `lossRateFloor`, `isMaintenance`.
- Produces: a verified invariant relied on by Tasks 2/8/9 — the implied weekly loss rate is always within `[cohortFloor, 0.01]` of body weight.

- [ ] **Step 1: Read the real signatures first.** Open `ProgramGoalCalculator.swift` and confirm the exact field names of `Inputs` and `Window` (the grounding pass reported `currentWeightKg, goalWeightKg, sex, age, isGLP1User, isPerimenopausal, isShortSleeper` and `minWeeks, maxWeeks, lossRateFloor, isMaintenance`). Adjust the test below to the actual names if they differ.

- [ ] **Step 2: Write the failing test** — asserts the fastest plan never exceeds 1%/wk and the slowest respects the cohort floor.

```swift
import XCTest
@testable import plankAI

final class ProgramGoalCalculatorSafetyTests: XCTestCase {
    // 80kg -> 70kg (10kg, 12.5% of body weight) must take >= 13 weeks at the
    // 1%/wk ceiling. A faster plan would be a clinical defect.
    func testFastestPlanNeverExceedsOnePercentPerWeek() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            isGLP1User: false, isPerimenopausal: false, isShortSleeper: false))
        // minWeeks is the fastest (Hard) plan. 10kg / (80kg * 0.01) = 12.5 -> >=13 wks.
        XCTAssertGreaterThanOrEqual(w.minWeeks, 13)
    }

    func testGLP1CohortFloorsAtGentlerPace() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            isGLP1User: true, isPerimenopausal: false, isShortSleeper: false))
        // GLP-1 floor is 0.3%/wk -> 10kg / (80*0.003) = ~41.7 -> maxWeeks >= 41.
        XCTAssertGreaterThanOrEqual(w.maxWeeks, 41)
    }

    func testClampedToProgramBounds() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 60, goalWeightKg: 59, sex: .female, age: 28,
            isGLP1User: false, isPerimenopausal: false, isShortSleeper: false))
        XCTAssertGreaterThanOrEqual(w.minWeeks, 4)
        XCTAssertLessThanOrEqual(w.maxWeeks, 52)
    }
}
```

- [ ] **Step 3: Run the test.** `xcodebuild ... -scheme plankAITests ... test` (filter to `ProgramGoalCalculatorSafetyTests`). Expected: PASS if the clamp already exists (regression lock). If any FAIL, the clamp has a gap.

- [ ] **Step 4: Only if a test failed**, fix the clamp in `compute(_:)` (the grounding pass located the rate math near lines 170–174): ensure the weekly rate used for `minWeeks` is `min(rate, 0.01)` and for `maxWeeks` uses the cohort floor, and weeks are clamped to `4...52`. Re-run until green.

- [ ] **Step 5: Commit.**
```bash
git add plankAITests/ProgramGoalCalculatorSafetyTests.swift PlankApp/Program/ProgramGoalCalculator.swift
git commit -m "test(program): lock pace-clamp safety envelope (0.3-1%/wk)"
```

---

### Task 2: Enforce the BMI floor on goal-weight selection

**Files:**
- Modify: `PlankApp/Program/ProgramGoalCalculator.swift` (expose a public floor helper if `weightForBMI` is private)
- Modify: the goal-weight input view in `PlankApp/Views/Onboarding/` (search for where `onboardingGoalWeightKg` is written — likely a goal-weight picker/slider)
- Test: `plankAITests/GoalWeightFloorTests.swift` (create)

**Interfaces:**
- Consumes: existing `weightForBMI(_ bmi: Double, _ heightCm: Double) -> Double` (grounding pass: used at line ~294 in `safetyAssessment`). If private, add `static func minimumGoalWeightKg(heightCm: Double) -> Double { weightForBMI(18.5, heightCm) }`.
- Produces: `ProgramGoalCalculator.minimumGoalWeightKg(heightCm:)` — consumed by the picker and by Task 8's assessment copy.

- [ ] **Step 1: Write the failing test.**
```swift
import XCTest
@testable import plankAI

final class GoalWeightFloorTests: XCTestCase {
    func testMinimumGoalWeightMatchesBMI185() {
        // 165cm -> BMI 18.5 floor = 18.5 * 1.65^2 = ~50.4kg
        let floor = ProgramGoalCalculator.minimumGoalWeightKg(heightCm: 165)
        XCTAssertEqual(floor, 18.5 * 1.65 * 1.65, accuracy: 0.5)
    }
    func testZeroHeightDoesNotCrashAndReturnsNonPositiveGuard() {
        // height 0 (default before capture) must not produce a usable floor.
        XCTAssertLessThanOrEqual(ProgramGoalCalculator.minimumGoalWeightKg(heightCm: 0), 0.0001 + 0)
    }
}
```

- [ ] **Step 2: Run → FAIL** (`minimumGoalWeightKg` undefined).

- [ ] **Step 3: Add the helper** in `ProgramGoalCalculator.swift`:
```swift
/// Lowest goal weight we will ever let a user select: BMI 18.5 for their height.
/// Returns 0 when height is unknown (0) so callers can skip the clamp safely.
public static func minimumGoalWeightKg(heightCm: Double) -> Double {
    guard heightCm > 0 else { return 0 }
    let m = heightCm / 100.0
    return 18.5 * m * m
}
```

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Wire the floor into the goal-weight input.** In the goal-weight view, clamp the selectable/persisted value: `let floored = max(selected, ProgramGoalCalculator.minimumGoalWeightKg(heightCm: heightCm)); onboardingGoalWeightKg = (floor > 0 ? floored : selected)`. When the floor bites, show the quiet line: `"we won't set a goal below what's healthy for your height."` Build + screenshot the goal-weight screen:
```bash
xcodebuild -project plankAI.xcodeproj -scheme plankAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcrun simctl io booted screenshot /tmp/goalweight_floor.png
```

- [ ] **Step 6: Commit.**
```bash
git add PlankApp/Program/ProgramGoalCalculator.swift plankAITests/GoalWeightFloorTests.swift PlankApp/Views/Onboarding/
git commit -m "feat(safety): floor goal weight at BMI 18.5 in onboarding"
```

---

### Task 3: Persist the clinical baseline (computed BMI + target rate) + disclaimer ack

**Files:**
- Modify: `Packages/PlankSync/Sources/PlankSync/Models.swift:7-124` (`UserRecord`) — add fields
- Modify: onboarding-complete handler `PlankApp/PlankAIApp.swift:2730-2819` (`handleOnboardingComplete`) — compute + persist
- Test: `plankAITests/ClinicalBaselineTests.swift` (create)

**Interfaces:**
- Produces: `UserRecord.computedStartBMI: Double?`, `UserRecord.targetRatePctPerWeek: Double?`, `UserRecord.medicalDisclaimerAckAt: Date?` — consumed by Task 8 (assessment copy) and future partner export.

- [ ] **Step 1: Write the failing test** for a pure BMI helper (so the value persisted is correct and testable).
```swift
import XCTest
@testable import plankAI

final class ClinicalBaselineTests: XCTestCase {
    func testBMIComputation() {
        // 70kg, 170cm -> 24.22
        XCTAssertEqual(ClinicalBaseline.bmi(weightKg: 70, heightCm: 170), 24.22, accuracy: 0.05)
    }
    func testBMINilWhenHeightMissing() {
        XCTAssertNil(ClinicalBaseline.bmi(weightKg: 70, heightCm: 0))
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Add the helper** in a new small file `PlankApp/Program/ClinicalBaseline.swift`:
```swift
import Foundation

/// Pure helpers for the clinical baseline record. Keep math here so it is testable
/// and the persisted numbers always trace to a collected field (provenance rule).
enum ClinicalBaseline {
    static func bmi(weightKg: Double, heightCm: Double) -> Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let m = heightCm / 100.0
        return weightKg / (m * m)
    }
}
```

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Add the `UserRecord` fields** (SwiftData `@Model`, all optional for migration safety):
```swift
public var computedStartBMI: Double?
public var targetRatePctPerWeek: Double?
public var medicalDisclaimerAckAt: Date?
```
Then in `handleOnboardingComplete`, after the plan is derived, set them on the user record:
```swift
user.computedStartBMI = ClinicalBaseline.bmi(weightKg: currentWeightKg, heightCm: heightCm)
user.targetRatePctPerWeek = window.lossRateFloor * 100   // trace to the derived plan
user.pendingUpsert = true
```
(Use the real local variable names present in `handleOnboardingComplete`; the grounding pass confirms weight/height/glp1 fields are already collected.)

- [ ] **Step 6: Build the app** (no UI), confirm SwiftData migration doesn't crash on launch (optional fields = lightweight migration). Run `plankAITests`. Expected: PASS.

- [ ] **Step 7: Commit.**
```bash
git add Packages/PlankSync/Sources/PlankSync/Models.swift PlankApp/Program/ClinicalBaseline.swift plankAITests/ClinicalBaselineTests.swift PlankApp/PlankAIApp.swift
git commit -m "feat(clinical): persist start BMI, target rate, disclaimer ack on UserRecord"
```

---

### Task 4: Rapid-loss tripwire (pure function + gentle surface)

**Files:**
- Create: `PlankApp/Program/RapidLossTripwire.swift`
- Test: `plankAITests/RapidLossTripwireTests.swift`
- Modify (surface): the weight-log write path / Becoming view (search for `weight_logged` emit and the EMA/trend computation)

**Interfaces:**
- Produces: `RapidLossTripwire.evaluate(trendKgPerWeek: Double, currentWeightKg: Double, safeCeilingPctPerWeek: Double = 0.01) -> RapidLossTripwire.Result` where `Result` has `isTooFast: Bool` and `careMessage: String?`.

- [ ] **Step 1: Write the failing test.**
```swift
import XCTest
@testable import plankAI

final class RapidLossTripwireTests: XCTestCase {
    func testFiresWhenLossExceedsCeiling() {
        // 80kg losing 1.2kg/wk = 1.5%/wk > 1% ceiling.
        let r = RapidLossTripwire.evaluate(trendKgPerWeek: 1.2, currentWeightKg: 80)
        XCTAssertTrue(r.isTooFast)
        XCTAssertNotNil(r.careMessage)
    }
    func testSilentWithinEnvelope() {
        // 80kg losing 0.6kg/wk = 0.75%/wk < 1%.
        let r = RapidLossTripwire.evaluate(trendKgPerWeek: 0.6, currentWeightKg: 80)
        XCTAssertFalse(r.isTooFast)
        XCTAssertNil(r.careMessage)
    }
    func testWeightGainNeverFires() {
        let r = RapidLossTripwire.evaluate(trendKgPerWeek: -0.5, currentWeightKg: 80)
        XCTAssertFalse(r.isTooFast)
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.**
```swift
import Foundation

enum RapidLossTripwire {
    struct Result { let isTooFast: Bool; let careMessage: String? }

    /// `trendKgPerWeek` > 0 means losing weight. Fires when the loss rate exceeds
    /// the safe ceiling (default 1%/wk of body weight). Care-framed, never shame.
    static func evaluate(trendKgPerWeek: Double,
                         currentWeightKg: Double,
                         safeCeilingPctPerWeek: Double = 0.01) -> Result {
        guard currentWeightKg > 0, trendKgPerWeek > 0 else {
            return Result(isTooFast: false, careMessage: nil)
        }
        let pct = trendKgPerWeek / currentWeightKg
        guard pct > safeCeilingPctPerWeek else {
            return Result(isTooFast: false, careMessage: nil)
        }
        return Result(isTooFast: true,
                      careMessage: "you're losing faster than we plan for. let's make sure you're eating enough \u{2665}")
    }
}
```

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Surface it** where the EMA/trend is already computed (Becoming/weight view): after a weight log, compute rolling trend (reuse existing EMA), call `evaluate`, and if `isTooFast`, present `careMessage` as a calm sheet/banner (cream, no red). Build + screenshot.

- [ ] **Step 6: Commit.**
```bash
git add PlankApp/Program/RapidLossTripwire.swift plankAITests/RapidLossTripwireTests.swift PlankApp/Views/Analytics/
git commit -m "feat(safety): rapid-loss tripwire with care-framed check-in"
```

---

### Task 5: Habit-based "on-track" + promises-kept counter

**Files:**
- Create: `PlankApp/Program/HabitProgress.swift`
- Modify: `Packages/PlankSync/Sources/PlankSync/Models.swift` (add `promisesKept: Int` to `UserRecord`, default 0)
- Test: `plankAITests/HabitProgressTests.swift`

**Interfaces:**
- Produces: `HabitProgress.weeklyStatus(actionsThisWeek: Int, target: Int) -> String` (habit copy, NEVER weight) and `UserRecord.promisesKept` — consumed by Task 9 (home hero) and Task 10 (kept-promise win).

- [ ] **Step 1: Write the failing test.**
```swift
import XCTest
@testable import plankAI

final class HabitProgressTests: XCTestCase {
    func testShowsUpCopy() {
        XCTAssertEqual(HabitProgress.weeklyStatus(actionsThisWeek: 4, target: 5),
                       "you're showing up \u{2014} 4 of 5 this week")
    }
    func testNeverMentionsWeightOrBehind() {
        let s = HabitProgress.weeklyStatus(actionsThisWeek: 0, target: 5)
        XCTAssertFalse(s.lowercased().contains("behind"))
        XCTAssertFalse(s.lowercased().contains("lb"))
        XCTAssertFalse(s.lowercased().contains("kg"))
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.**
```swift
import Foundation

/// Behaviour-completion status for the arrival hero. NEVER references weight or a
/// deadline — adherence is the metric, per the on-track-is-habits constraint.
enum HabitProgress {
    static func weeklyStatus(actionsThisWeek: Int, target: Int) -> String {
        "you're showing up \u{2014} \(actionsThisWeek) of \(max(target, 1)) this week"
    }
}
```
Add `public var promisesKept: Int = 0` to `UserRecord`.

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Commit.**
```bash
git add PlankApp/Program/HabitProgress.swift plankAITests/HabitProgressTests.swift Packages/PlankSync/Sources/PlankSync/Models.swift
git commit -m "feat(activation): habit-based on-track status + promises-kept counter"
```

---

### Task 6: `scheduleDay1Promise` notification + activation-state helpers

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingComponents.swift:235-336` (`NotificationPermission`)
- Test: `plankAITests/Day1PromiseBodyTests.swift`

**Interfaces:**
- Produces: `NotificationPermission.scheduleDay1Promise(at date: Date, body: String)` (one-shot, id `day1_promise`) and `NotificationPermission.day1PromiseBody(action: String, anchor: String, userName: String?) -> String` — consumed by Task 7 (ritual) and Task 10.

- [ ] **Step 1: Write the failing test** for the body builder (pure, testable; scheduling itself is verified by build).
```swift
import XCTest
@testable import plankAI

final class Day1PromiseBodyTests: XCTestCase {
    func testReplaysHerWordsWithName() {
        let b = NotificationPermission.day1PromiseBody(action: "log breakfast", anchor: "coffee", userName: "Jen")
        XCTAssertTrue(b.contains("coffee"))
        XCTAssertTrue(b.contains("Jen"))
        XCTAssertFalse(b.lowercased().contains("don't forget"))   // no nagging
    }
    func testNoNameStillReads() {
        let b = NotificationPermission.day1PromiseBody(action: "log breakfast", anchor: "coffee", userName: nil)
        XCTAssertFalse(b.isEmpty)
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** in `NotificationPermission`:
```swift
static let day1PromiseIdentifier = "day1_promise"

static func day1PromiseBody(action: String, anchor: String, userName: String?) -> String {
    let who = (userName?.isEmpty == false) ? "\(userName!), " : ""
    return "\(who)it's your \(anchor) moment \u{2014} you said you'd \(action). ready when you are \u{2665}"
}

/// One-shot Day-1 nudge in her own words, at the time she chose in the ritual.
static func scheduleDay1Promise(at date: Date, body: String) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [day1PromiseIdentifier])
    let content = UNMutableNotificationContent()
    content.title = "tomorrow, you begin."
    content.body = body
    content.sound = .default
    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    center.add(.init(identifier: day1PromiseIdentifier, content: content, trigger: trigger))
}
```

- [ ] **Step 4: Run → PASS.** Then build the app to confirm it compiles.

- [ ] **Step 5: Commit.**
```bash
git add PlankApp/Views/Onboarding/OnboardingComponents.swift plankAITests/Day1PromiseBodyTests.swift
git commit -m "feat(notify): scheduleDay1Promise one-shot in her own words"
```

---

### Task 7: Ritual-as-promise screen (replace `.trialPromise`)

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingRevealView.swift:64-81` (Step enum), `:90-139` (body switch), `:1253-1348` (`TrialPromisePresentation` → new `CommitmentRitualPresentation`)
- (No new test target — SwiftUI surface verified by build + screenshot. The scheduling logic it calls is already tested in Task 6.)

**Interfaces:**
- Consumes: `NotificationPermission.scheduleDay1Promise`, `day1PromiseBody` (Task 6); `@AppStorage` baseline keys (`onboardingSleepHours`, `userName`).
- Produces: persists `@AppStorage("day1PromiseAction")`, `("day1PromiseAnchor")`, `("day1PromiseTimeISO")` — consumed by Task 10 (Day-1 surfacing).

- [ ] **Step 1:** Rename the enum case `case trialPromise` → `case commitment` (update the `Int` raw ordering comment; it stays the final step). Update the body `switch` case to render `CommitmentRitualPresentation(onContinue: onRevealComplete)`.

- [ ] **Step 2:** Replace `TrialPromisePresentation` (1253–1348) with `CommitmentRitualPresentation`. Requirements (use existing design components — `LineCascadeText`, tokens, `JFContinueButton`):
  - **Pre-filled smart defaults** (confirm, not fill): default anchor from `onboardingSleepHours` (`under5`/`five6` → "after I wake up"; else "after coffee"); default action = "log breakfast"; default time = 8:00am. Offer 2–3 tappable chips each, not free-text.
  - **Replay-as-promise:** on confirm, render her composed sentence in JeniHeroSerif: *"tomorrow, after \(anchor), you'll \(action)."* Soft haptic (`UIImpactFeedbackGenerator(style: .soft)`).
  - On Continue: persist the three `@AppStorage` values; if notifications authorized, call `scheduleDay1Promise(at: chosenDate, body: day1PromiseBody(action:anchor:userName:))`; then `onContinue()`.
  - **GLP-1 thread (cheap):** if `onboarding_glp1_status == "current"`, change the default action to "get protein at breakfast" and the replay to *"tomorrow, after \(anchor), you'll protect your muscle."* (Phase-1b deepens this.)
  - **Copy ban check:** no "trial", no "free", no numbers/weight.

- [ ] **Step 3:** Build + screenshot the new step (and the GLP-1 variant via launch arg or temp default):
```bash
xcodebuild -project plankAI.xcodeproj -scheme plankAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcrun simctl io booted screenshot /tmp/commitment_ritual.png
```
Verify: pre-filled chips, the serif replay line, no trial language.

- [ ] **Step 4: Commit.**
```bash
git add PlankApp/Views/Onboarding/OnboardingRevealView.swift
git commit -m "feat(onboarding): replace trial-promise with commitment ritual (promise + Day-1 schedule)"
```

---

### Task 8: Assessment-as-payoff at plan reveal

**Files:**
- Modify: `PlankApp/Views/Onboarding/OnboardingRevealView.swift` `.projection` step (`BecomingProjectionCard`, referenced ~line 90–139) — enrich, or add a dedicated `.assessment` step immediately after `.building`.

**Interfaces:**
- Consumes: derived `Window` (Task 1), `minimumGoalWeightKg` (Task 2), `ClinicalBaseline.bmi` (Task 3), `@AppStorage` inputs.
- Produces: the earned-progress label string used here is self-contained.

- [ ] **Step 1:** Build the dual-register assessment card. **Warm line (JeniHeroSerif):** an identity sentence, e.g. *"here's your realistic arc."* **Quiet data line (DMSans):** provenance-cited, e.g. `pace 0.5%/wk \u{00B7} arrival ~Sep 14 \u{00B7} set conservatively`. **Provenance microcopy:** one line tying a number to her input, e.g. *"because you sleep ~6h, we set a gentler pace."* **Credibility beat:** *"paced like a clinician would \u{2014} slower is what lasts."* All from real derived values; no projected weight figure.

- [ ] **Step 2: Earned-only endowed progress** on this card: render `"step 1 of your plan: complete \u{2014} you did the assessment"`. **Never** a naked percentage.

- [ ] **Step 3:** Apply microcopy pairs (one clinical line followed by one warm line), e.g. `"0.5% a week is the safe ceiling."` → `"slow is not behind. slow is how she arrives."` Keep cream; a single thin rule as the only "clinical" accent.

- [ ] **Step 4: Build + screenshot.**
```bash
xcrun simctl io booted screenshot /tmp/assessment_payoff.png
```
Verify: serif identity + quiet data line + provenance line + "step 1 complete" (no %); no weight number; no red.

- [ ] **Step 5: Commit.**
```bash
git add PlankApp/Views/Onboarding/OnboardingRevealView.swift
git commit -m "feat(onboarding): assessment-as-payoff plan reveal (dual register, earned progress)"
```

---

### Task 9: Forgiving habit-based arrival horizon (home hero)

**Files:**
- Modify: the Today/Plan home hero (search `PlankApp/Views/Plan/PlanView.swift` for the top hero slot) — read `ProgramPlanRecord.goalDate` + a weekly action count.

**Interfaces:**
- Consumes: `ProgramPlanRecord.goalDate`, `HabitProgress.weeklyStatus` (Task 5).

- [ ] **Step 1:** Render the hero: line 1 (JeniHeroSerif) `"~\(formatted(goalDate))"` using a `~`-prefixed medium date; line 2 (DMSans) = `HabitProgress.weeklyStatus(actionsThisWeek:target:)`. Compute `actionsThisWeek` from existing session/log records for the current week; `target` from the tier (reuse existing per-week expectation).

- [ ] **Step 2: Forgiving behavior:** if the week's actions are behind the implied schedule, **do not** color red or say "behind"; the date simply re-derives later and shows `"your timeline is yours"` as the subline that day. Verify no red/`behind`/countdown anywhere in the hero.

- [ ] **Step 3: Build + screenshot** the home hero.
```bash
xcrun simctl io booted screenshot /tmp/arrival_hero.png
```

- [ ] **Step 4: Commit.**
```bash
git add PlankApp/Views/Plan/PlanView.swift
git commit -m "feat(home): forgiving habit-based arrival horizon hero"
```

---

### Task 10: Payer routing (payoff→promise) + Day-1 kept-promise win

**Files:**
- Modify: `PlankApp/PlankAIApp.swift:2308-2426` (paywall `onSubscribed` / `presentPostPurchaseFlowIfEligible()` ~2343)
- Modify: the root/home appearance to surface the saved promise on Day 1

**Interfaces:**
- Consumes: `@AppStorage("day1PromiseAction"/"day1PromiseAnchor"/"day1PromiseTimeISO")` (Task 7), `UserRecord.promisesKept` (Task 5).

- [ ] **Step 1:** In `presentPostPurchaseFlowIfEligible()`, route a brand-new payer to the assessment-payoff + the saved promise summary (a `fullScreenCover`), **not** the root tab and **not** a forced log. (If the ritual already ran during reveal, show a one-screen "your promise is set for tomorrow" confirmation.)

- [ ] **Step 2:** On the first app open **on or after** the promise date, surface a top-of-home card replaying her promise sentence with a single primary action (the small thing she committed to). When she completes it that day, increment `UserRecord.promisesKept`, mark `pendingUpsert = true`, and animate the arrival hero "locking in" one notch (a subtle, non-numeric flourish). Track **promises kept**, never a streak; a miss never resets or threatens.

- [ ] **Step 3: Build + screenshot** the Day-1 promise card + the kept state.
```bash
xcrun simctl io booted screenshot /tmp/kept_promise.png
```

- [ ] **Step 4: Commit.**
```bash
git add PlankApp/PlankAIApp.swift PlankApp/Views/Plan/
git commit -m "feat(activation): payer routing payoff->promise + Day-1 kept-promise win"
```

---

### Task 11: D0–D3 activation-state notifications (cap 3, personalized, no deficit/scale/streak)

**Files:**
- Modify: `PlankApp/Notifications/RetentionNotifications.swift` (add an activation-state predicate to the D1/D2 scheduling)
- Test: `plankAITests/ActivationPushTests.swift`

**Interfaces:**
- Consumes: `Glp1Cohort.current`, existing `day1MorningContent`/`day1ContinueContent`. Adds a guard so pushes only fire for "onboarding complete && no core action yet" and are capped at 3 across 3 days.

- [ ] **Step 1: Write the failing test** for the cap/guard logic (extract a pure decision function).
```swift
import XCTest
@testable import plankAI

final class ActivationPushTests: XCTestCase {
    func testSuppressedOnceUserActed() {
        XCTAssertFalse(ActivationPushPolicy.shouldSchedule(dayIndex: 1, hasActedToday: true, alreadyScheduled: 0))
    }
    func testCapsAtThree() {
        XCTAssertFalse(ActivationPushPolicy.shouldSchedule(dayIndex: 3, hasActedToday: false, alreadyScheduled: 3))
    }
    func testFiresWhenInactiveUnderCap() {
        XCTAssertTrue(ActivationPushPolicy.shouldSchedule(dayIndex: 1, hasActedToday: false, alreadyScheduled: 0))
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** `ActivationPushPolicy`:
```swift
enum ActivationPushPolicy {
    /// D0-D3 activation nudges: only for not-yet-activated users, hard cap 3.
    static func shouldSchedule(dayIndex: Int, hasActedToday: Bool, alreadyScheduled: Int) -> Bool {
        guard dayIndex >= 1, dayIndex <= 3 else { return false }
        guard !hasActedToday else { return false }
        return alreadyScheduled < 3
    }
}
```
Wire it into the D1/D2 scheduling path; bodies come from the existing cohort variants (already feature-only, no deficit/scale language). Confirm no body contains "lose"/"down"/"behind"/"streak".

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Commit.**
```bash
git add PlankApp/Notifications/RetentionNotifications.swift plankAITests/ActivationPushTests.swift
git commit -m "feat(notify): activation-state D0-D3 pushes, capped + suppressed-on-action"
```

---

## Self-Review

**Spec coverage:** §4.1 assessment-payoff → Task 8. §4.2 guardrails → Tasks 1 (pace), 2 (BMI floor), 3 (baseline+disclaimer), 4 (tripwire). §4.3 arrival horizon → Tasks 5+9. §4.4 ritual-as-promise → Tasks 6+7. §4.5 earned progress → Task 8 step 2. §4.6 payer routing → Task 10 step 1. §4.7 kept-promise win → Task 10 step 2. §4.8 D0–D3 pushes → Task 11. §5 compliance → Global Constraints + enforced in Tasks 8/9/11 copy checks. §6 data model → Tasks 3+5. **Gap noted:** §4.2 "logged disclaimer/pregnancy exclusion *acknowledgment screen*" — Task 3 persists `medicalDisclaimerAckAt` but does not add the screen UI; **add a short ack screen before plan reveal during Task 3 step 5, or fold into Task 8's pre-roll.** Implement as part of Task 3.

**Placeholder scan:** no "TBD"/"handle edge cases"; every logic step ships code; UI steps ship exact copy strings + screenshot verification (the correct SwiftUI verification). Steps that say "use the real local variable names" / "search for X" are *grounding instructions*, not placeholders — they point the implementer at a verified file:line.

**Type consistency:** `Window.lossRateFloor`, `minimumGoalWeightKg(heightCm:)`, `ClinicalBaseline.bmi`, `RapidLossTripwire.evaluate`, `HabitProgress.weeklyStatus`, `scheduleDay1Promise`/`day1PromiseBody`, `ActivationPushPolicy.shouldSchedule`, and the new `UserRecord` fields (`computedStartBMI`, `targetRatePctPerWeek`, `medicalDisclaimerAckAt`, `promisesKept`) and `@AppStorage` keys (`day1PromiseAction`/`Anchor`/`TimeISO`) are used consistently across tasks.

**Caveat for the implementer:** `ProgramGoalCalculator.Inputs`/`Window` field names and the exact `compute()` rate lines were reported by a read-only grounding pass, not a full file read — Task 1 Step 1 verifies them before writing code. Several existing components (`LineCascadeText`, `BecomingProjectionCard`, tokens) are referenced by name; read their current usage in `OnboardingRevealView.swift` before building Tasks 7–9.
