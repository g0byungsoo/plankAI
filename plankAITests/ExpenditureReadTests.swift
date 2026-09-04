import XCTest
@testable import plankAI

// MARK: - ExpenditureReadTests (p79 — THE LEARNED BURN)
//
// Pins the laws from 79_evidence/r1: band output only · silence over
// guessing at every gate · the under-logging death spiral dies at the
// BMR rail · a fresh dose change holds the read · partial days are
// judged by HER OWN distribution · the arithmetic is exact.

final class ExpenditureReadTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private lazy var now: Date = {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 9))!
    }()
    private var today: Date { cal.startOfDay(for: now) }

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: today)!
    }

    /// Consecutive logged days ending today: offsets 0...(n-1) back.
    private func intakeDays(
        _ n: Int, kcal: Double, plates: Int = 3, skippingOffsets: Set<Int> = []
    ) -> [ExpenditureRead.DayIntake] {
        (0..<n).compactMap { back in
            skippingOffsets.contains(back) ? nil
                : ExpenditureRead.DayIntake(day: day(-back), kcal: kcal, plates: plates)
        }
    }

    /// Linear trend covering the trailing `spanDays` days ending
    /// today: startKg at the oldest point, slopeKgPerDay applied.
    private func linearTrend(
        spanDays: Int, startKg: Double, slopeKgPerDay: Double
    ) -> [WeightWeekReadEngine.TrendPoint] {
        (0..<spanDays).map { i in
            let d = day(-(spanDays - 1) + i)
            return WeightWeekReadEngine.TrendPoint(
                day: d, rawKg: nil, trendKg: startKg + slopeKgPerDay * Double(i)
            )
        }
    }

    private func inputs(
        days: [ExpenditureRead.DayIntake],
        trend: [WeightWeekReadEngine.TrendPoint],
        sufficiency: WeightWeekRead.Sufficiency = .established,
        weighIns: Int = 12,
        daysSinceDoseChange: Int? = nil,
        bmr: Int? = 1_400,
        suppressed: Bool = false
    ) -> ExpenditureRead.Inputs {
        ExpenditureRead.Inputs(
            days: days, trend: trend, sufficiency: sufficiency,
            weighInDaysInWindow: weighIns,
            daysSinceDoseChange: daysSinceDoseChange,
            bmrKcal: bmr, numericsSuppressed: suppressed,
            now: now, calendar: cal
        )
    }

    // MARK: - The arithmetic is exact

    func testSteadyLossReadsExpenditureAboveIntake() {
        // 1,800 kcal/day logged, trend losing 0.05 kg/day over the
        // window → storage −1.0 kg over 20 days → −385 kcal/day →
        // burn = 1,800 + 385 = 2,185 → rounds to 2,175.
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84.0, slopeKgPerDay: -0.05)
        ))
        guard case .read(let est) = read else {
            return XCTFail("expected a read, got \(read)")
        }
        XCTAssertEqual(est.centerKcal, 2_175)
        XCTAssertEqual(est.bandLowKcal, 2_025)     // −150, tight band
        XCTAssertEqual(est.bandHighKcal, 2_325)
        XCTAssertEqual(est.usableDays, 21)
        XCTAssertEqual(est.intakeMeanKcal, 1_800)
        XCTAssertEqual(est.weeklyMassDeltaKg, -0.35, accuracy: 0.001)
    }

    func testFlatTrendReadsExpenditureAtIntake() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 2_000),
            trend: linearTrend(spanDays: 40, startKg: 80, slopeKgPerDay: 0)
        ))
        guard case .read(let est) = read else {
            return XCTFail("expected a read, got \(read)")
        }
        XCTAssertEqual(est.centerKcal, 2_000)
    }

    func testGainingTrendReadsExpenditureBelowIntake() {
        // +0.03 kg/day → +0.6 kg over 20 d → +231/day → 1,769 → 1,775.
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 2_000),
            trend: linearTrend(spanDays: 40, startKg: 80, slopeKgPerDay: 0.03)
        ))
        guard case .read(let est) = read else {
            return XCTFail("expected a read, got \(read)")
        }
        XCTAssertEqual(est.centerKcal, 1_775)
    }

    // MARK: - The gates (silence over guessing)

    func testSuppressedIsSilent() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            suppressed: true
        ))
        XCTAssertEqual(read, .silent(.suppressed))
    }

    func testProvisionalTrendIsSilent() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            sufficiency: .provisional
        ))
        XCTAssertEqual(read, .silent(.trendNotEstablished))
    }

    func testStaleTrendHolds() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            sufficiency: .stale
        ))
        XCTAssertEqual(read, .holding(.trendStale))
    }

    func testFreshDoseChangeHolds() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            daysSinceDoseChange: 10
        ))
        XCTAssertEqual(read, .holding(.doseChangeFresh(daysAtDose: 10)))
        // At the titration floor the read speaks again.
        let after = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            daysSinceDoseChange: 14
        ))
        if case .read = after {} else { XCTFail("expected a read at day 14, got \(after)") }
    }

    func testSparseWeighInsAreSilent() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            weighIns: 8
        ))
        XCTAssertEqual(read, .silent(.weighInsTooSparse(count: 8)))
    }

    func testTrendMustCoverTheWholeWindow() {
        // A series that starts mid-window would read a shorter span
        // as if it were the whole — silence instead.
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800),
            trend: linearTrend(spanDays: 10, startKg: 84, slopeKgPerDay: -0.05)
        ))
        XCTAssertEqual(read, .silent(.trendNotEstablished))
    }

    func testTooFewUsableDaysIsSilent() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800,
                             skippingOffsets: [0, 2, 4, 6, 8, 10, 12, 14]),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05)
        ))
        guard case .silent(.loggingTooSparse) = read else {
            return XCTFail("expected loggingTooSparse, got \(read)")
        }
    }

    func testAGapWeekPoisonsTheWindowEvenWithEnoughTotalDays() {
        // 14 usable days in the two older weeks, but the freshest
        // rolling week holds only 3 — the mean would lean on stale
        // days while claiming the window (r1's ≤3-of-7 gate).
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 1_800,
                             skippingOffsets: [0, 1, 2, 3]),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05)
        ))
        guard case .silent(.loggingTooSparse) = read else {
            return XCTFail("expected loggingTooSparse, got \(read)")
        }
    }

    // MARK: - Partial days (her own distribution)

    func testFragmentDaysAreExcludedByHerOwnMedian() {
        // 18 real days at 1,800 + 3 fragments at 300 (median 1,800 →
        // floor 900): fragments leave BOTH the mean and the count.
        var days = intakeDays(28, kcal: 1_800, skippingOffsets: [2, 9, 16])
        for offset in [2, 9, 16] {
            days.append(.init(day: day(-offset), kcal: 300, plates: 1))
        }
        let read = ExpenditureRead.read(inputs(
            days: days,
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05)
        ))
        guard case .read(let est) = read else {
            return XCTFail("expected a read, got \(read)")
        }
        XCTAssertEqual(est.usableDays, 18)
        XCTAssertEqual(est.intakeMeanKcal, 1_800)   // fragments never dilute
        XCTAssertEqual(est.bandHighKcal - est.bandLowKcal, 300)  // tight band at 18
    }

    func testLooseBandUnderEighteenUsableDays() {
        var days = intakeDays(28, kcal: 1_800,
                              skippingOffsets: [2, 5, 9, 12, 16])
        days.append(.init(day: day(-2), kcal: 300, plates: 1))
        let read = ExpenditureRead.read(inputs(
            days: days,
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05)
        ))
        guard case .read(let est) = read else {
            return XCTFail("expected a read, got \(read)")
        }
        XCTAssertEqual(est.usableDays, 16)
        XCTAssertEqual(est.bandHighKcal - est.bandLowKcal, 400)  // loose band
    }

    // MARK: - The death-spiral rail

    func testUnderLoggedRecordGoesSilentNotConfidentlyLow() {
        // 700 kcal/day logged while losing 0.35 kg/wk computes a
        // ~1,085 burn — below 0.9 × BMR 1,400. The record is
        // contradicting the scale; the read says so instead of
        // handing back a number that would ratchet her downward.
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 700),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05),
            bmr: 1_400
        ))
        XCTAssertEqual(read, .silent(.intakeInconsistent))
    }

    func testImplausiblyHighBurnGoesSilent() {
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 4_800),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.02),
            bmr: 1_400
        ))
        XCTAssertEqual(read, .silent(.intakeInconsistent))
    }

    func testAbsoluteFragmentFloorProtectsThinRecords() {
        // Every logged day at 350 kcal: her median is 350, but a
        // 350-kcal "day" is a fragment by the absolute floor — the
        // whole window is fragments, so the read is honest silence.
        let read = ExpenditureRead.read(inputs(
            days: intakeDays(28, kcal: 350),
            trend: linearTrend(spanDays: 40, startKg: 84, slopeKgPerDay: -0.05)
        ))
        guard case .silent(.loggingTooSparse) = read else {
            return XCTFail("expected loggingTooSparse, got \(read)")
        }
    }
}
