import XCTest
@testable import plankAI

// MARK: - WeightWeekReadTests (v25 E2 — B7)
//
// Pins for the read's weight intelligence: bands are withheld below
// the data floors, a single weigh-in never speaks a direction, noise
// inside the ±0.25%-BM band reads "holding steady", gaps go stale
// instead of extrapolating, and probable unit errors never move the
// trend.

final class WeightWeekReadTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 8))!
    }

    private func read(
        _ samples: [(Date, Double)], now: Date
    ) -> WeightWeekRead {
        WeightWeekReadEngine.read(
            samples: samples.map { .init(day: $0.0, kg: $0.1) },
            now: now, calendar: cal
        )
    }

    func testEmptyRecordReadsSilence() {
        let r = read([], now: day(2026, 8, 10))
        XCTAssertEqual(r.sufficiency, .insufficient)
        XCTAssertNil(r.band)
        XCTAssertNil(r.trendKg)
    }

    func testASingleWeighInNeverSpeaksADirection() {
        let r = read([(day(2026, 8, 9), 74.2)], now: day(2026, 8, 10))
        XCTAssertEqual(r.sufficiency, .insufficient)
        XCTAssertNil(r.band)
        XCTAssertNotNil(r.trendKg)   // the number exists; the verdict doesn't
    }

    func testThreeSamplesInAWeekAreStillInsufficient() {
        let r = read([
            (day(2026, 8, 4), 75.0), (day(2026, 8, 7), 74.6),
            (day(2026, 8, 9), 74.9),
        ], now: day(2026, 8, 10))
        XCTAssertEqual(r.sufficiency, .insufficient)
        XCTAssertNil(r.band)
    }

    func testSteadyLossReadsTrendingDownAtProvisionalFloor() {
        // 5 obs over 16 days, ~0.6 kg/week down.
        let r = read([
            (day(2026, 7, 25), 76.0), (day(2026, 7, 29), 75.6),
            (day(2026, 8, 2), 75.2), (day(2026, 8, 6), 74.8),
            (day(2026, 8, 10), 74.4),
        ], now: day(2026, 8, 10))
        XCTAssertEqual(r.sufficiency, .provisional)
        XCTAssertEqual(r.band, .trendingDown)
        XCTAssertNotNil(r.weeklyDeltaKg)
        XCTAssertLessThan(r.weeklyDeltaKg ?? 0, 0)
    }

    func testWaterNoiseReadsHoldingSteady() {
        // Dense record oscillating ±0.4 kg around 75 — inside the
        // noise band; never "drifting up".
        var samples: [(Date, Double)] = []
        let weights = [75.0, 74.7, 75.3, 74.8, 75.2, 74.9, 75.1,
                       74.6, 75.4, 75.0, 74.8, 75.2]
        for (i, w) in weights.enumerated() {
            samples.append((cal.date(byAdding: .day, value: -33 + i * 3,
                                     to: day(2026, 8, 10))!, w))
        }
        let r = read(samples, now: day(2026, 8, 10))
        XCTAssertEqual(r.sufficiency, .established)
        XCTAssertEqual(r.band, .holdingSteady)
    }

    func testStaleRecordWithholdsTheBand() {
        // A good history whose last sample is 16 days old: no band,
        // no extrapolation.
        let r = read([
            (day(2026, 7, 1), 76.0), (day(2026, 7, 5), 75.6),
            (day(2026, 7, 9), 75.4), (day(2026, 7, 13), 75.1),
            (day(2026, 7, 17), 74.9), (day(2026, 7, 21), 74.6),
            (day(2026, 7, 25), 74.4),
        ], now: day(2026, 8, 10))
        XCTAssertEqual(r.sufficiency, .stale)
        XCTAssertNil(r.band)
        XCTAssertEqual(r.lastSampleDaysAgo, 16)
    }

    func testProbableUnitErrorNeverMovesTheTrend() {
        // 74-ish kg record with one 163 entry (her lb number typed
        // into a kg field, ratio ≈ 2.2): skipped, not smoothed in.
        let clean = read([
            (day(2026, 7, 25), 74.5), (day(2026, 7, 29), 74.3),
            (day(2026, 8, 2), 74.1), (day(2026, 8, 6), 74.0),
            (day(2026, 8, 9), 73.9),
        ], now: day(2026, 8, 10))
        let withError = read([
            (day(2026, 7, 25), 74.5), (day(2026, 7, 29), 74.3),
            (day(2026, 8, 2), 74.1), (day(2026, 8, 4), 163.0),
            (day(2026, 8, 6), 74.0), (day(2026, 8, 9), 73.9),
        ], now: day(2026, 8, 10))
        XCTAssertEqual(
            clean.trendKg ?? 0, withError.trendKg ?? 1, accuracy: 0.01
        )
    }

    func testASpikeIsClampedNotBelieved() {
        // A +3 kg sodium morning after a steady week moves the trend
        // by at most the clamped innovation, not the spike.
        let r = read([
            (day(2026, 7, 27), 75.0), (day(2026, 7, 30), 75.0),
            (day(2026, 8, 2), 75.0), (day(2026, 8, 5), 75.0),
            (day(2026, 8, 8), 75.0), (day(2026, 8, 10), 78.0),
        ], now: day(2026, 8, 10))
        // clamp = 1.6% × 75 × min(2,7) = 2.4 kg innovation cap,
        // k(2d) ≈ 0.19 → trend moves ≤ ~0.46 kg.
        XCTAssertLessThan(r.trendKg ?? 99, 75.6)
    }

    func testImplausibleValuesAreRejectedOutright() {
        let r = read([
            (day(2026, 8, 2), 12.0), (day(2026, 8, 5), 420.0),
        ], now: day(2026, 8, 10))
        XCTAssertEqual(r.sampleCount, 0)
        XCTAssertEqual(r.sufficiency, .insufficient)
    }

    // MARK: - p54 · one plateau arithmetic, one gated story

    /// The flat-weeks count is owned by the trend authority now (the
    /// Method counted the fast fold; the day composer read a raw
    /// span). Three flat canonical weeks count 3; a moving trend
    /// counts 0.
    func testFlatWeeksCountsTheCanonicalTrend() {
        let now = day(2026, 8, 18)
        var flat: [(Date, Double)] = []
        for ago in 0..<28 {
            flat.append((cal.date(byAdding: .day, value: -ago, to: now)!, 78.0))
        }
        let flatTrend = WeightWeekReadEngine.trendSeries(
            samples: flat.map { .init(day: $0.0, kg: $0.1) },
            now: now, calendar: cal
        )
        XCTAssertGreaterThanOrEqual(
            WeightWeekReadEngine.flatWeeks(trend: flatTrend, now: now, calendar: cal),
            3
        )

        var moving: [(Date, Double)] = []
        for ago in 0..<28 {
            moving.append((
                cal.date(byAdding: .day, value: -ago, to: now)!,
                78.0 + Double(ago) * 0.12
            ))
        }
        let movingTrend = WeightWeekReadEngine.trendSeries(
            samples: moving.map { .init(day: $0.0, kg: $0.1) },
            now: now, calendar: cal
        )
        XCTAssertEqual(
            WeightWeekReadEngine.flatWeeks(trend: movingTrend, now: now, calendar: cal),
            0
        )
    }

    /// Becoming's trend story was the last customer-legible weight
    /// sentence off the fast fold with no sufficiency gate: it could
    /// say "down about 1 lb this week" over a record the authority
    /// rated insufficient, one screen element above a tile that
    /// refused the same claim. The band decides now.
    func testTheTrendStorySpeaksOnlyWithTheBand() {
        let quietWeek = WeekState(days: [], proteinTargetG: nil)
        let insufficient = read(
            [(day(2026, 8, 17), 78.6), (day(2026, 8, 18), 78.0)],
            now: day(2026, 8, 18)
        )
        let forming = InsightEngine.trendStory(
            read: insufficient, week: quietWeek, numericsSuppressed: false
        )
        XCTAssertEqual(
            forming?.line, "a few more weigh-ins and your trend line starts.",
            "two weigh-ins have no direction; the story must not invent one"
        )

        var samples: [(Date, Double)] = []
        for ago in stride(from: 20, through: 0, by: -1) {
            samples.append((
                cal.date(byAdding: .day, value: -ago, to: day(2026, 8, 18))!,
                80.0 - Double(20 - ago) * 0.12
            ))
        }
        let established = read(samples, now: day(2026, 8, 18))
        XCTAssertNotNil(established.band)
        let story = InsightEngine.trendStory(
            read: established, week: quietWeek, numericsSuppressed: false
        )
        XCTAssertTrue(
            story?.line.hasPrefix("down ") ?? false,
            "an established falling band earns the direction word: \(story?.line ?? "nil")"
        )
    }

    func testOneSamplePerDayFirstWins() {
        let morning = day(2026, 8, 9)
        let evening = cal.date(byAdding: .hour, value: 12, to: morning)!
        let r = read([
            (morning, 74.0), (evening, 75.5),
        ], now: day(2026, 8, 10))
        XCTAssertEqual(r.sampleCount, 1)
        XCTAssertEqual(r.trendKg ?? 0, 74.0, accuracy: 0.001)
    }
}
