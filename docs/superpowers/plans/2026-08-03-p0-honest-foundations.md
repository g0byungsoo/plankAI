# P0 — Honest Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair passive weight, add HealthKit background delivery, align requested scope with the permission story and rendered surfaces, land the `BodyStateService` aggregate + dormant `MovementService` — v9's foundation phase per `docs/app_v9/02_PLAN.md` §P0.

**Architecture:** Additive only. One new pure aggregate (`BodyStateService`, enum) over existing stores; `TodayStateService` delegates its weight derivations to it with pinned equivalence. `BodyMassImportService` gains launch wiring + an HK observer + background delivery; onboarding's bodyMass grant finally sets its flag. `VitalsService` prunes five dead reads. All permission strings rewritten honestly (D10 drafts, founder voice review in the phase record).

**Tech Stack:** SwiftUI/SwiftData iOS app (`plankAI.xcodeproj`, target PlankApp), HealthKit, XCTest (`plankAITests`, shared `TestModelContainer`).

## Global Constraints

- Laws L1-L7 (`docs/app_v9/00_MISSION.md`, `04_DESIGN.md`); decisions D5 + D10 (`03_DECISIONS.md`).
- Additive changes only; no schema or route-machine changes; 407-unit suite must stay green.
- House gotchas: ONE in-memory ModelContainer per test process (use `TestModelContainer.shared`, distinct userIds); app-target singleton services stay `@MainActor` (`@Observable` class for HK services, enum for program services); UI legs run solo; ONE xcodebuild per commit batch.
- No new user-scoped `@AppStorage` keys (nothing to add to the sign-out sweep; `bodyMassImportRequested` is device-level HK state and correctly survives sign-out).
- Commit style: per-feature commits, `Co-Authored-By: Claude Fable 5` + `Claude-Session` trailers.

---

### Task 1: BodyStateService (pure aggregate) + tests

**Files:**
- Create: `PlankApp/Program/BodyStateService.swift`
- Test: `plankAITests/BodyStateServiceTests.swift`

**Interfaces:**
- Consumes: `WeightTrendChart.computeEMA(logs:)`, `TodayStateService.emaDelta7d(_:)` math (reimplemented as the canonical copy HERE; Task 2 re-points TodayStateService), `WeightAnalytics.isStalled/weeklyLossRate/isLosingTooFast`, `VitalsService.Read`, `StepsService.shared.weeklyCounts`, `MovementService` reads (Task 5; until then the movement inputs are plain parameters).
- Produces: `BodyState` value + `BodyStateService.current(userId:in:)`, `BodyStateService.weightRead(logs:today:)`, `.compositionRead(from:)`, `.movementRead(weeklySteps:strengthSessionsLast7:activeEnergyTodayKcal:distanceTodayKm:)` — Task 2 and later phases consume exactly these names.

- [ ] **Step 1: Write the failing tests** — `plankAITests/BodyStateServiceTests.swift`:

```swift
import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// BodyStateService (docs/app_v9/02_PLAN.md P0, W7) — ONE typed read
// of "is her body changing" composed from stores that already exist.
// Pinned laws: floors match the shipped ones exactly (trend floor =
// 3+ logs spanning 5+ days; stall/rate floors = WeightAnalytics);
// composition only from real sources with provenance (L3); movement
// nil when nothing flows (renders nothing downstream).

@MainActor
final class BodyStateServiceTests: XCTestCase {

    private func log(_ kg: Double, daysAgo: Int, source: String = "manual",
                     userId: String = "bs-test") -> WeightLogRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return WeightLogRecord(userId: userId, weightKg: kg, loggedAt: date, source: source)
    }

    // — weight

    func testEmptyLogsYieldNilWeight() {
        XCTAssertNil(BodyStateService.weightRead(logs: []))
    }

    func testSingleLogHasLatestButNoTrend() {
        let read = BodyStateService.weightRead(logs: [log(82.0, daysAgo: 0)])
        XCTAssertEqual(read?.latestKg, 82.0)
        XCTAssertNil(read?.emaDelta7dKg)
        XCTAssertEqual(read?.trendEstablished, false)
        XCTAssertEqual(read?.lastWeighInDaysAgo, 0)
    }

    func testThreeLogsOverFiveDaysEstablishTrend() {
        let logs = [log(81.0, daysAgo: 0), log(81.6, daysAgo: 3), log(82.2, daysAgo: 6)]
        XCTAssertEqual(BodyStateService.weightRead(logs: logs)?.trendEstablished, true)
    }

    func testThreeLogsInsideTwoDaysDoNotEstablishTrend() {
        let logs = [log(81.0, daysAgo: 0), log(81.2, daysAgo: 1), log(81.4, daysAgo: 2)]
        XCTAssertEqual(BodyStateService.weightRead(logs: logs)?.trendEstablished, false)
    }

    func testEmaDeltaMatchesCanonicalMath() {
        let logs = (0..<14).map { log(82.0 - Double($0) * 0.1, daysAgo: $0) }
        let expectedSeries = WeightTrendChart.computeEMA(logs: logs)
        let read = BodyStateService.weightRead(logs: logs)
        XCTAssertEqual(read?.emaSeries, expectedSeries)
        XCTAssertEqual(read?.emaDelta7dKg, TodayStateService.emaDelta7d(expectedSeries))
    }

    func testFloorsDelegateToWeightAnalytics() {
        let stalled = [log(81.0, daysAgo: 1), log(81.1, daysAgo: 6), log(80.9, daysAgo: 12)]
        XCTAssertEqual(BodyStateService.weightRead(logs: stalled)?.isStalled,
                       WeightAnalytics.isStalled(logs: stalled))
        let fast = [log(78.0, daysAgo: 0), log(79.5, daysAgo: 7), log(81.0, daysAgo: 14)]
        XCTAssertEqual(BodyStateService.weightRead(logs: fast)?.isLosingTooFast,
                       WeightAnalytics.isLosingTooFast(logs: fast))
        XCTAssertEqual(BodyStateService.weightRead(logs: fast)?.weeklyLossRate,
                       WeightAnalytics.weeklyLossRate(logs: fast))
    }

    func testLatestIsNewestByDate() {
        let logs = [log(80.5, daysAgo: 0, source: "healthkit"), log(81.0, daysAgo: 2)]
        let read = BodyStateService.weightRead(logs: logs)
        XCTAssertEqual(read?.latestKg, 80.5)
        XCTAssertEqual(read?.latestSource, "healthkit")
    }

    // — composition (L3: real sources only, provenance carried)

    func testCompositionNilWhenVitalsEmpty() {
        XCTAssertNil(BodyStateService.compositionRead(from: VitalsService.Read()))
    }

    func testCompositionCarriesProvenance() {
        var vitals = VitalsService.Read()
        vitals.bodyFatPct = 31.2
        vitals.leanMassKg = 48.9
        let comp = BodyStateService.compositionRead(from: vitals)
        XCTAssertEqual(comp?.bodyFatPct, 31.2)
        XCTAssertEqual(comp?.leanMassKg, 48.9)
        XCTAssertEqual(comp?.provenance, "apple health")
    }

    // — movement (nil when nothing flows)

    func testMovementNilWhenNothingFlows() {
        XCTAssertNil(BodyStateService.movementRead(
            weeklySteps: Array(repeating: 0, count: 7),
            strengthSessionsLast7: 0, activeEnergyTodayKcal: nil, distanceTodayKm: nil))
    }

    func testMovementAveragesActiveDaysOnly() {
        let read = BodyStateService.movementRead(
            weeklySteps: [0, 8000, 6000, 0, 10000, 0, 4000],
            strengthSessionsLast7: 2, activeEnergyTodayKcal: nil, distanceTodayKm: nil)
        XCTAssertEqual(read?.stepsWeekAvg, 7000)   // mean over the 4 active days
        XCTAssertEqual(read?.activeDaysLast7, 4)
        XCTAssertEqual(read?.strengthSessionsLast7, 2)
    }

    // — the composed read (SwiftData path, shared container law)

    func testCurrentComposesFromStore() throws {
        let context = ModelContext(TestModelContainer.shared)
        let uid = "bs-current-\(UUID().uuidString.prefix(8))"
        for l in [log(81.0, daysAgo: 0, userId: uid),
                  log(81.5, daysAgo: 3, userId: uid),
                  log(82.0, daysAgo: 6, userId: uid)] { context.insert(l) }
        try context.save()
        let state = BodyStateService.current(userId: uid, in: context)
        XCTAssertEqual(state.weight?.latestKg, 81.0)
        XCTAssertEqual(state.weight?.trendEstablished, true)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `xcodebuild test -scheme plankAI -only-testing plankAITests/BodyStateServiceTests` → FAIL: `cannot find 'BodyStateService'`.

- [ ] **Step 3: Implement** — `PlankApp/Program/BodyStateService.swift`:

```swift
import Foundation
import SwiftData
import PlankSync

// MARK: - BodyStateService
//
// app v9 P0 (docs/app_v9/02_PLAN.md, closes W7): ONE typed read of
// "is her body changing" composed from the stores that already
// exist — weight logs (SwiftData), body composition (VitalsService,
// only when her scale writes it), movement (steps + workouts).
// Scans join in P1+.
//
// Laws carried: every floor is the shipped floor (trend = 3+ logs
// spanning 5+ days, the v5 trust floor; stall/rate = WeightAnalytics);
// composition numbers only from real sources with provenance (L3);
// a section with no data is nil — downstream renders nothing, never
// a fabricated state. Pure static core; `current` is the only
// store-touching entry.

struct BodyState {
    struct Weight: Equatable {
        let latestKg: Double
        let latestAt: Date
        let latestSource: String
        let lastWeighInDaysAgo: Int
        let emaSeries: [WeightTrendChart.EMAPoint]
        let emaDelta7dKg: Double?
        /// v5 trust floor: 3+ weigh-ins spanning 5+ days.
        let trendEstablished: Bool
        let isStalled: Bool
        let weeklyLossRate: Double?
        let isLosingTooFast: Bool
    }

    struct Composition: Equatable {
        let bodyFatPct: Double?
        let leanMassKg: Double?
        /// L3 — a composition number never renders without its source.
        let provenance: String
    }

    struct Movement: Equatable {
        /// Mean steps across the days that recorded any (0-days are
        /// absence, not zeros — the anti-shame floor).
        let stepsWeekAvg: Int
        let activeDaysLast7: Int
        let strengthSessionsLast7: Int
        let activeEnergyTodayKcal: Int?
        let distanceTodayKm: Double?
    }

    let weight: Weight?
    let composition: Composition?
    let movement: Movement?
}

enum BodyStateService {

    /// The composed read. Fetches weight logs (desc), reads the live
    /// vitals + movement services. MainActor because the services are.
    @MainActor
    static func current(userId: String, in context: ModelContext) -> BodyState {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return BodyState(
            weight: weightRead(logs: logs),
            composition: compositionRead(from: VitalsService.shared.read),
            movement: movementRead(
                weeklySteps: StepsService.shared.weeklyCounts,
                strengthSessionsLast7: MovementService.shared.strengthSessionsLast7,
                activeEnergyTodayKcal: MovementService.shared.activeEnergyTodayKcal,
                distanceTodayKm: MovementService.shared.distanceTodayKm
            )
        )
    }

    /// Pure. `logs` newest-first (the fetch order everywhere).
    static func weightRead(logs: [WeightLogRecord], today: Date = .now) -> BodyState.Weight? {
        guard let newest = logs.first else { return nil }
        let cal = Calendar.current
        let daysAgo = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: newest.loggedAt),
            to: cal.startOfDay(for: today)
        ).day ?? 0
        let ema = WeightTrendChart.computeEMA(logs: logs)
        let established: Bool = {
            guard logs.count >= 3, let oldest = logs.last?.loggedAt else { return false }
            let span = cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: oldest),
                to: cal.startOfDay(for: newest.loggedAt)
            ).day ?? 0
            return span >= 5
        }()
        return .init(
            latestKg: newest.weightKg,
            latestAt: newest.loggedAt,
            latestSource: newest.source,
            lastWeighInDaysAgo: daysAgo,
            emaSeries: ema,
            emaDelta7dKg: emaDelta7d(ema),
            trendEstablished: established,
            isStalled: WeightAnalytics.isStalled(logs: logs, today: today),
            weeklyLossRate: WeightAnalytics.weeklyLossRate(logs: logs, today: today),
            isLosingTooFast: WeightAnalytics.isLosingTooFast(logs: logs, today: today)
        )
    }

    /// 7-day EMA delta (today's EMA minus the EMA 7 points back) —
    /// the canonical copy; TodayStateService delegates here.
    static func emaDelta7d(_ ema: [WeightTrendChart.EMAPoint]) -> Double? {
        guard ema.count >= 8 else { return nil }
        return ema[ema.count - 1].emaKg - ema[ema.count - 8].emaKg
    }

    static func compositionRead(from vitals: VitalsService.Read) -> BodyState.Composition? {
        guard vitals.bodyFatPct != nil || vitals.leanMassKg != nil else { return nil }
        return .init(bodyFatPct: vitals.bodyFatPct,
                     leanMassKg: vitals.leanMassKg,
                     provenance: "apple health")
    }

    static func movementRead(
        weeklySteps: [Int],
        strengthSessionsLast7: Int,
        activeEnergyTodayKcal: Int?,
        distanceTodayKm: Double?
    ) -> BodyState.Movement? {
        let active = weeklySteps.filter { $0 > 0 }
        let hasAny = !active.isEmpty || strengthSessionsLast7 > 0
            || activeEnergyTodayKcal != nil || distanceTodayKm != nil
        guard hasAny else { return nil }
        let avg = active.isEmpty ? 0 : active.reduce(0, +) / active.count
        return .init(stepsWeekAvg: avg,
                     activeDaysLast7: active.count,
                     strengthSessionsLast7: strengthSessionsLast7,
                     activeEnergyTodayKcal: activeEnergyTodayKcal,
                     distanceTodayKm: distanceTodayKm)
    }
}
```

Note: `MovementService` does not exist until Task 5. To keep Task 1 self-contained and the build green, Task 1 ships `current` reading movement as `movementRead(weeklySteps: StepsService.shared.weeklyCounts, strengthSessionsLast7: 0, activeEnergyTodayKcal: nil, distanceTodayKm: nil)` with a `// P0 Task 5 wires MovementService here` comment; Task 5 swaps the three literals for the service reads. (`EMAPoint` is `Hashable`, hence `Equatable` — the series equality in tests compiles.)

- [ ] **Step 4: Run tests** — same command → PASS (all).
- [ ] **Step 5: Commit** — `git add PlankApp/Program/BodyStateService.swift plankAITests/BodyStateServiceTests.swift && git commit -m "feat(v9-p0): BodyStateService — one typed body-state read (W7)"` (+ trailers).

---

### Task 2: TodayStateService delegates weight state (equivalence hold)

**Files:**
- Modify: `PlankApp/Program/TodayStateService.swift:116-126` (weight block), `:239-249` (trust floor), `:435-437` (snapshot init unchanged fields), `:453-460` (drop `fetchWeightLogs`), `:502-508` (delegate `emaDelta7d`)

**Interfaces:**
- Consumes: `BodyStateService.current(userId:in:)` (Task 1).
- Produces: `TodaySnapshot` unchanged (same fields, same values); `TodayStateService.emaDelta7d(_:)` kept as a thin forwarding wrapper (existing callers + Task 1's parity test reference it).

- [ ] **Step 1: Replace the weight derivations.** In `snapshot(userId:in:)`:

```swift
// — weight (v9 P0: ONE aggregate; equivalence pinned by
//   BodyStateServiceTests + the full suite)
let body = BodyStateService.current(userId: userId, in: context)
let latestKg = body.weight?.latestKg
let lastWeighDaysAgo = body.weight?.lastWeighInDaysAgo
let ema = body.weight?.emaSeries ?? []
let emaDelta = body.weight?.emaDelta7dKg
```

Delete the old `fetchWeightLogs` call + local `weightLogs` uses: the `trendEstablished` block at `:239-249` becomes `let trendEstablished = body.weight?.trendEstablished ?? false`. Delete the now-unused `fetchWeightLogs` helper. `emaDelta7d` body becomes `BodyStateService.emaDelta7d(ema)` (one-line forward). All other uses (`bandZone` via `ema.last?.emaKg`, `sustainedLossRate(ema:weightKg:)`, `emaFlatWeeks(ema)`, `firstDownWeek`) read the same `ema`/`emaDelta`/`latestKg` locals — untouched.

- [ ] **Step 2: Build + run the full unit suite** — must stay green (407 + Task 1's).
- [ ] **Step 3: Commit** — `refactor(v9-p0): TodayStateService weight state delegates to BodyStateService`.

---

### Task 3: Passive weight repaired (W3) + background delivery (W4)

**Files:**
- Modify: `PlankApp/Health/BodyMassImportService.swift` (observer + note-ask + debug seeder), `PlankApp/PlankAIApp.swift:2574` region (launch wiring), `PlankApp/Health/StepsService.swift:301-317` (background delivery), `PlankApp/Views/OnboardingV5/OV5ScreensClose.swift:315-329` (grant honored), `plankAI.entitlements` (background-delivery key)

**Interfaces:**
- Consumes: `BodyMassImportService.importIfEnabled(userId:into:)` (exists).
- Produces: `BodyMassImportService.noteSystemAskIncludedBodyMass()`, `.startObservingIfEnabled(userId:into:)`, `#if DEBUG .debugWriteSample(kg:)`.

- [ ] **Step 1: BodyMassImportService additions** (below `requestAccessAndImport`):

```swift
    /// Another surface's system sheet included bodyMass (onboarding's
    /// connect-health ask does). Records that the ask happened so the
    /// silent import path activates — the grant stops being wasted
    /// (v9 P0, W3). Idempotent.
    func noteSystemAskIncludedBodyMass() {
        guard authStatus == .notDetermined else { return }
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
        authStatus = .requested
    }

    /// v9 P0 (W4): new scale samples land without an app open.
    /// Observer + background delivery — active only after the ask;
    /// never prompts. Safe to call every launch.
    func startObservingIfEnabled(userId: String, into context: ModelContext) {
        guard authStatus == .requested, observerQuery == nil,
              let type = bodyMassType, !userId.isEmpty else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) {
            [weak self] _, completion, error in
            defer { completion() }   // background-delivery contract
            guard error == nil, let self else { return }
            Task { @MainActor in
                await self.importIfEnabled(userId: userId, into: context)
            }
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }
```

plus `private var observerQuery: HKObserverQuery?` beside the other stored state, and:

```swift
    #if DEBUG
    /// QA-only (v9 P0 proof): writes one bodyMass sample so the sim —
    /// which has no scale — can exercise the full passive path:
    /// write → observer/import → trend. Requests write+read in one
    /// sheet. Never compiled into release.
    func debugWriteSample(kg: Double) async {
        guard let type = bodyMassType else { return }
        try? await healthStore.requestAuthorization(toShare: [type], read: [type])
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
        authStatus = .requested
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: .now, end: .now)
        try? await healthStore.save(sample)
    }
    #endif
```

- [ ] **Step 2: Launch wiring** — `PlankAIApp.swift`, directly after `await VitalsService.shared.bootstrap()` (:2574):

```swift
            // v9 P0 (W3): passive weight, actually passive. Silent —
            // imports only after the ask has ever been shown; the
            // observer keeps future scale samples flowing (background
            // delivery, entitlement-backed). Manual rows still win
            // their day (BodyMassImportService policy).
            if let uid = auth.currentUser?.id.uuidString, !uid.isEmpty {
                #if DEBUG
                if let kgArg = ProcessInfo.processInfo.arguments
                    .firstIndex(of: "--debug-hk-write-weight")
                    .flatMap({ i -> Double? in
                        let args = ProcessInfo.processInfo.arguments
                        return args.indices.contains(i + 1) ? Double(args[i + 1]) : nil
                    }) {
                    await BodyMassImportService.shared.debugWriteSample(kg: kgArg)
                }
                #endif
                await BodyMassImportService.shared.importIfEnabled(
                    userId: uid, into: modelContext)
                BodyMassImportService.shared.startObservingIfEnabled(
                    userId: uid, into: modelContext)
            }
```

- [ ] **Step 3: Onboarding grant honored** — `OV5ScreensClose.swift` `requestHealthKit()` completion, after the `healthKitStepsRequested` set:

```swift
                UserDefaults.standard.set(true, forKey: "healthKitStepsRequested")
                BodyMassImportService.shared.noteSystemAskIncludedBodyMass()
```

(the sheet at `:321` already includes bodyMass; import itself runs at next launch wiring — no context plumbing into the onboarding screen).

- [ ] **Step 4: Steps background delivery** — `StepsService.startObserving()`: call the observer's completion handler and enable delivery; update the stale "we deliberately skip" comment:

```swift
    /// Subscribes to step-count changes. v9 P0 (W4): background
    /// delivery joins (hourly — HK's floor for steps) so the week
    /// strip is warm before first open; the entitlement rides
    /// plankAI.entitlements.
    private func startObserving() {
        guard observerQuery == nil else { return }
        let stepType = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, error in
            defer { completion() }
            guard error == nil, let self else { return }
            Task { @MainActor in await self.refresh() }
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }
```

- [ ] **Step 5: Entitlement** — `plankAI.entitlements`, inside the dict:

```xml
	<key>com.apple.developer.healthkit.background-delivery</key>
	<true/>
```

- [ ] **Step 6: Build + full unit suite** → green (no behavior under test changed; HK paths are runtime).
- [ ] **Step 7: Commit** — `feat(v9-p0): passive weight repaired + HK background delivery (W3, W4)`.

---

### Task 4: HealthKit truth pass (W5, D5) + honest strings (D10 drafts)

**Files:**
- Modify: `PlankApp/Health/VitalsService.swift` (prune 5 dead reads), `PlankApp/Info.plist:48-54` (4 strings), comment touch-ups `PlankApp/Health/StepsService.swift:154-156`, `PlankApp/Health/SleepService.swift:119-121`

**Interfaces:**
- Produces: `VitalsService.Read` with exactly `restingHR7d/restingHRBaseline/bodyFatPct/leanMassKg`; `VitalsService.readTypes` = {restingHeartRate, bodyFatPercentage, leanBodyMass}. Consumers verified untouched: `TodayStateBand` (restingHR), `BecomingView:1254` (bodyFat/lean), `BodyStateService.compositionRead` (Task 1).

- [ ] **Step 1: Prune VitalsService.** Delete `hrvLatest`, `vo2Max`, `respiratoryRate`, `bpSystolic`, `bpDiastolic` from `Read` + their five refresh blocks + their identifiers in `readTypes`; `isEmpty` becomes `restingHR7d == nil && bodyFatPct == nil && leanMassKg == nil`. Header comment gains: `// v9 P0 truth pass (D5): HRV / VO2max / respiratory rate / blood pressure left the request set — read-but-never-rendered violates L5 (never request what nothing shows). HRV returns WITH its rendered recovery surface (P3).`
- [ ] **Step 2: Rewrite the four Info.plist strings** (D10 drafts — surfaced for founder voice review in the phase record):
  - `NSCameraUsageDescription` (`:48`): `Jeni uses your camera to scan your meals. One photo per scan goes to our private vision service for calorie and protein estimates — never used to train models. A small copy stays on your phone for your own food diary.`
  - `NSHealthShareUsageDescription` (`:50`): `Jeni reads a few quiet signals from Apple Health — steps, sleep, weigh-ins, resting heart rate, cycle timing, and body composition when your scale saves it — so your trend fills in without you typing a thing. These signals shape only your own plan and jeni's notes to you. Imported weigh-ins sync to your private Jeni account; nothing is sold, and nothing is shared unless you explicitly choose to share it.`
  - `NSHealthUpdateUsageDescription` (`:52`): `If you turn on the Apple Health write toggle in Jeni's food settings, your logged meal calories are saved to Apple Health as Dietary Energy. Off by default. You can change this anytime.`
  - `NSPhotoLibraryAddUsageDescription` (`:54`): `Jeni saves your shared moments (food plates, becoming snapshots, lesson quotes) to your Photos so you can post them to TikTok or Instagram later. Nothing is saved without you tapping save.`
- [ ] **Step 3: Comment touch-ups** where steps/sleep sheets union `VitalsService.readTypes` (still true, now three types; note the D5 prune).
- [ ] **Step 4: Build + full suite** (grep first: no test references the removed fields) → green.
- [ ] **Step 5: Commit** — `fix(v9-p0): HealthKit truth pass — scope == story == surfaces (W5, D5, D10 drafts)`.

---

### Task 5: MovementService (dormant plumbing, W6) + BodyState wiring + tests

**Files:**
- Create: `PlankApp/Health/MovementService.swift`
- Modify: `PlankApp/Program/BodyStateService.swift` (swap the three literals for service reads), `PlankApp/PlankAIApp.swift` (bootstrap beside vitals)
- Test: `plankAITests/MovementServiceTests.swift`

**Interfaces:**
- Produces: `MovementService.shared` with `strengthSessionsLast7: Int`, `activeEnergyTodayKcal: Int?`, `distanceTodayKm: Double?`, `bootstrap()`, `requestAccess()` (unused until P3 ships its surface — L5), pure `MovementService.strengthCount(_:)`.

- [ ] **Step 1: Failing test** — `plankAITests/MovementServiceTests.swift`:

```swift
import XCTest
import HealthKit
@testable import plankAI

// MovementService (v9 P0, W6) — dormant plumbing: silent probe only,
// no auth request until P3 renders its surface (L5). The pure part
// under test: which workout types count as strength (the
// muscle-preservation input, P3).

final class MovementServiceTests: XCTestCase {
    func testStrengthTypesCount() {
        XCTAssertEqual(MovementService.strengthCount(
            [.traditionalStrengthTraining, .functionalStrengthTraining, .walking, .yoga]), 2)
    }
    func testNoWorkoutsCountZero() {
        XCTAssertEqual(MovementService.strengthCount([]), 0)
        XCTAssertEqual(MovementService.strengthCount([.running, .cycling]), 0)
    }
}
```

- [ ] **Step 2: Run** → FAIL (`cannot find 'MovementService'`).
- [ ] **Step 3: Implement** — `PlankApp/Health/MovementService.swift` mirroring the VitalsService silent-probe shape: `@MainActor @Observable final class`, `readTypes` = {activeEnergyBurned, distanceWalkingRunning, HKWorkoutType.workoutType()}; `bootstrap()` (silent `refresh()`, never prompts); `refresh()` reads: workouts last 7d via `HKSampleQuery` on `HKWorkoutType.workoutType()` → `strengthSessionsLast7 = Self.strengthCount(workouts.map(\.workoutActivityType))`; today's active energy (`HKStatisticsQuery .cumulativeSum`, kcal) → `activeEnergyTodayKcal`; today's distance (same, `.meter()` → km ≥ 0.1 else nil) → `distanceTodayKm`; `requestAccess()` mirrors VitalsService's (P3's surface calls it). Pure:

```swift
    /// Strength = the muscle-preservation signal (P3). Walking/cardio
    /// never count — the read is about resistance, not effort.
    static func strengthCount(_ activities: [HKWorkoutActivityType]) -> Int {
        activities.filter {
            $0 == .traditionalStrengthTraining || $0 == .functionalStrengthTraining
        }.count
    }
```

- [ ] **Step 4: Wire** — `BodyStateService.current` movement literals → `MovementService.shared.strengthSessionsLast7 / .activeEnergyTodayKcal / .distanceTodayKm`; `PlankAIApp` launch task gains `await MovementService.shared.bootstrap()` beside the vitals bootstrap.
- [ ] **Step 5: Run full suite** → green. **Step 6: Commit** — `feat(v9-p0): MovementService plumbing — workouts/energy/distance probe (W6)`.

---

### Task 6: Verification ritual + phase record

- [ ] **Step 1: ONE release-shaped build + the full unit suite** on the dedicated sim (house batch-build law). Expected: 407 + ~17 new, all green.
- [ ] **Step 2: On-sim passive-weight proof (the P0 exit criterion):** erase the dedicated sim → install → launch with `--debug-hk-write-weight 71.5` → approve the HK sheet (one tap; walker-style springboard handling if scripted) → relaunch WITHOUT the arg → the trend surface shows the imported point with zero manual weigh-in. Capture: screenshot of the Becoming trend page + the Settings weight row no longer offering "connect". If sheet automation resists after 2-3 attempts, fall back to manual-tap proof + screenshots (do not rabbit-hole).
- [ ] **Step 3: Regression legs (solo):** onboarding v7 walker generalWL leg (the HK screen behavior gained only a flag set) + core-in-app leg. Expected green.
- [ ] **Step 4: Docs + record:** `docs/app_v9/05_BUILD.md` P0 shipped record (incl. design evidence block per L7 + the D10 string drafts verbatim for founder review + device-signing note: the new background-delivery entitlement needs the capability on the App ID at next archive) · STATE.md §-12 · CLAUDE.md status prepend · memory update.
- [ ] **Step 5: Final commit** — `docs(app_v9): P0 shipped record`.

## Self-review

Spec coverage: W3 (Task 3), W4 (Task 3), W5+D5+D10 (Task 4), W6 (Task 5), W7 (Tasks 1-2), P0 exit criteria (Task 6) — covered; waist deliberately deferred to P2/P3 per plan text (L5). Placeholders: none. Type consistency: `BodyState.Weight/Composition/Movement`, `noteSystemAskIncludedBodyMass`, `startObservingIfEnabled(userId:into:)`, `strengthCount(_:)` used consistently across tasks.
