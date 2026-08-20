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

    // MARK: - Weight

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

    // p53 RE-PIN: establishment follows the CANONICAL gate now (the
    // engine's own band — ≥4 observations spanning ≥14 days before
    // any direction is spoken), so the brief cannot claim a trend
    // jeni's tool refuses. Three logs over five days was the old
    // ad-hoc rule; under the one gate it is honest insufficiency.
    func testThreeLogsOverFiveDaysAreNotYetATrend() {
        let logs = [log(81.0, daysAgo: 0), log(81.6, daysAgo: 3), log(82.2, daysAgo: 6)]
        XCTAssertEqual(BodyStateService.weightRead(logs: logs)?.trendEstablished, false)
    }

    func testAProvisionalSeriesEstablishesUnderTheCanonicalGate() {
        let logs = [
            log(81.0, daysAgo: 0), log(81.3, daysAgo: 4),
            log(81.6, daysAgo: 9), log(82.0, daysAgo: 15),
        ]
        XCTAssertEqual(BodyStateService.weightRead(logs: logs)?.trendEstablished, true)
    }

    func testThreeLogsInsideTwoDaysDoNotEstablishTrend() {
        let logs = [log(81.0, daysAgo: 0), log(81.2, daysAgo: 1), log(81.4, daysAgo: 2)]
        XCTAssertEqual(BodyStateService.weightRead(logs: logs)?.trendEstablished, false)
    }

    // p53 RE-PIN: the customer-legible delta is the canonical fold's
    // weekly delta (one number across the brief, the chat card, the
    // tile and jeni's tool); the fast series survives as trigger
    // input only and is still pinned here as such.
    func testEmaDeltaMatchesCanonicalMath() {
        let logs = (0..<14).map { log(82.0 - Double($0) * 0.1, daysAgo: $0) }
        let expectedSeries = WeightTrendChart.computeEMA(logs: logs)
        let read = BodyStateService.weightRead(logs: logs)
        XCTAssertEqual(read?.emaSeries, expectedSeries)
        let canonical = WeightWeekReadEngine.read(
            samples: WeightSeries.samples(from: logs), now: .now
        )
        XCTAssertEqual(read?.emaDelta7dKg, canonical.weeklyDeltaKg)
        XCTAssertNotNil(read?.emaDelta7dKg)
    }

    func testFloorsDelegateToWeightAnalytics() {
        // p54 re-pin: `isStalled` left the read — the day composer's
        // plateau now consumes the canonical flat-weeks arithmetic
        // (`WeightWeekReadEngine.flatWeeks`), so the raw-span answer
        // has no consumer and no seat on this struct.
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

    // MARK: - Composition (L3: real sources only, provenance carried)

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

    // MARK: - Movement (nil when nothing flows)

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

    // MARK: - The composed read (SwiftData path, shared container law)

    func testCurrentComposesFromStore() throws {
        let context = ModelContext(TestModelContainer.shared)
        let uid = "bs-current-\(UUID().uuidString.prefix(8))"
        let rows = [log(81.0, daysAgo: 0, userId: uid),
                    log(81.4, daysAgo: 4, userId: uid),
                    log(81.7, daysAgo: 9, userId: uid),
                    log(82.0, daysAgo: 15, userId: uid)]
        for l in rows { context.insert(l) }
        try context.save()
        let state = BodyStateService.current(userId: uid, in: context)
        XCTAssertEqual(state.weight?.latestKg, 81.0)
        XCTAssertEqual(state.weight?.trendEstablished, true)
        // Shared-container law: leave no rows behind (ReattributionTests
        // counts WeightLogRecord globally).
        for l in rows { context.delete(l) }
        try context.save()
    }
}
