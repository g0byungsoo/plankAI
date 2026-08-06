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
        XCTAssertNotNil(read?.emaDelta7dKg)
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
                    log(81.5, daysAgo: 3, userId: uid),
                    log(82.0, daysAgo: 6, userId: uid)]
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
