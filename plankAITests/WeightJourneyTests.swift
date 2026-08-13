import XCTest
@testable import plankAI

// THE WHOLE DISTANCE — the arithmetic this app never performed.
//
// `weight_logged` is the second most-used action in the product (72
// users / 193 events over 90 days) and until this engine there was no
// "how much have I lost?" anywhere in the codebase. These tests pin
// the honesty rules, which are the whole point: a start anchor that
// does not shorten with the EMA window, a threshold that refuses to
// read daily noise as a journey, and a goal that never counts up at
// someone who already reached it.

final class WeightJourneyTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    private func day(_ ago: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -ago, to: .now)!)
    }

    /// An EMA series ending today, oldest first.
    private func ema(_ values: [(daysAgo: Int, kg: Double)])
    -> [WeightTrendChart.EMAPoint] {
        values
            .sorted { $0.daysAgo > $1.daysAgo }
            .map { .init(date: day($0.daysAgo), rawKg: $0.kg, emaKg: $0.kg) }
    }

    private func lb(_ kg: Double) -> Double { kg * 2.20462 }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("lb", forKey: "weightUnit")
    }

    // MARK: - Refusing to speak

    /// Two logs a day apart is water, not a journey. The threshold is
    /// BodyStateService's existing `trendEstablished`, not a second
    /// invented one.
    func testNoJourneyBeforeTheTrendIsEstablished() {
        XCTAssertNil(WeightJourney.from(
            startKg: 75, startedAt: day(1),
            ema: ema([(1, 75.0), (0, 74.4)]),
            trendEstablished: false, goalKg: 65, calendar: cal
        ))
    }

    func testNoJourneyWithoutAStartAnchor() {
        XCTAssertNil(WeightJourney.from(
            startKg: 0, startedAt: day(30),
            ema: ema([(30, 75.0), (0, 73.0)]),
            trendEstablished: true, goalKg: 65, calendar: cal
        ))
    }

    /// A record that starts and ends on the same day has no distance.
    func testSameDayRecordHasNoDistance() {
        XCTAssertNil(WeightJourney.from(
            startKg: 75, startedAt: day(0),
            ema: ema([(0, 75.0)]),
            trendEstablished: true, goalKg: 65, calendar: cal
        ))
    }

    // MARK: - The distance

    func testTotalChangeIsMeasuredFromHerEarliestWeighIn() {
        let j = WeightJourney.from(
            startKg: 78.0, startedAt: day(120),
            ema: ema([(60, 76.0), (0, 74.0)]),
            trendEstablished: true, goalKg: nil, calendar: cal
        )
        // 78.0 → 74.0 = 4.0 kg down, NOT the 2.0 kg the 60-day EMA
        // window would have reported. This is the bug the anchor
        // exists to prevent: computeEMA windows to 60 days, so its
        // first point means "sixty days ago", never "when you started".
        XCTAssertEqual(j?.changeKg ?? 0, -4.0, accuracy: 0.001)
        XCTAssertEqual(j?.days, 120)
        XCTAssertEqual(j?.changeLine(unit: .kg), "down 4 kg since you started")
    }

    func testTheLineDropsATrailingZero() {
        let j = WeightJourney.from(
            startKg: 80, startedAt: day(40),
            ema: ema([(40, 80.0), (0, 75.0)]),
            trendEstablished: true, goalKg: nil, calendar: cal
        )
        XCTAssertEqual(j?.changeLine(unit: .kg), "down 5 kg since you started")
    }

    /// A gain is stated as flatly as a loss — no scold, no colour.
    func testAGainIsStatedFlatly() {
        let j = WeightJourney.from(
            startKg: 70, startedAt: day(40),
            ema: ema([(40, 70.0), (0, 71.5)]),
            trendEstablished: true, goalKg: nil, calendar: cal
        )
        XCTAssertEqual(j?.isDown, false)
        XCTAssertTrue(j?.changeLine(unit: .kg).hasPrefix("up 1.5 kg") ?? false)
    }

    /// Movement under a tenth of a display unit is not a direction.
    func testNoiseReadsAsHolding() {
        let j = WeightJourney.from(
            startKg: 75.00, startedAt: day(40),
            ema: ema([(40, 75.0), (0, 75.01)]),
            trendEstablished: true, goalKg: nil, calendar: cal
        )
        XCTAssertEqual(j?.changeLine(unit: .kg), "holding where you started")
    }

    // MARK: - The goal she named

    func testGoalStillAheadCountsTheDistanceLeft() {
        let j = WeightJourney.from(
            startKg: 80, startedAt: day(60),
            ema: ema([(60, 80.0), (0, 75.0)]),
            trendEstablished: true, goalKg: 70, calendar: cal
        )
        XCTAssertEqual(j?.remainingKg ?? 0, 5.0, accuracy: 0.001)
        XCTAssertEqual(j?.goalLine(unit: .kg), "5 kg to go")
        XCTAssertEqual(j?.reachedGoal, false)
    }

    /// A remaining figure that counts up from a met goal is a scold.
    func testAReachedGoalNeverCountsUp() {
        let j = WeightJourney.from(
            startKg: 80, startedAt: day(60),
            ema: ema([(60, 80.0), (0, 69.0)]),
            trendEstablished: true, goalKg: 70, calendar: cal
        )
        XCTAssertEqual(j?.reachedGoal, true)
        XCTAssertNil(j?.remainingKg)
        XCTAssertEqual(j?.goalLine(unit: .kg), "you reached your goal")
    }

    /// A goal at or above where she started is not a loss goal, and
    /// this engine has nothing true to say about it.
    func testAGoalAboveTheStartIsNotClaimed() {
        let j = WeightJourney.from(
            startKg: 70, startedAt: day(60),
            ema: ema([(60, 70.0), (0, 69.0)]),
            trendEstablished: true, goalKg: 75, calendar: cal
        )
        XCTAssertNil(j?.goalKg)
        XCTAssertNil(j?.goalLine(unit: .kg))
    }

    func testNoGoalOnFileDrawsNothing() {
        let j = WeightJourney.from(
            startKg: 80, startedAt: day(60),
            ema: ema([(60, 80.0), (0, 75.0)]),
            trendEstablished: true, goalKg: nil, calendar: cal
        )
        XCTAssertNil(j?.goalLine(unit: .kg))
        XCTAssertNotNil(j?.changeLine(unit: .kg))
    }

    // MARK: - Her unit

    func testTheLineSpeaksHerUnit() {
        let j = WeightJourney.from(
            startKg: 80, startedAt: day(60),
            ema: ema([(60, 80.0), (0, 75.0)]),
            trendEstablished: true, goalKg: 70, calendar: cal
        )
        let line = j?.changeLine(unit: .lb) ?? ""
        XCTAssertTrue(line.hasSuffix("lb since you started"), line)
        // 5 kg = 11.0 lb, and the trailing zero is dropped.
        XCTAssertEqual(line, "down 11 lb since you started")
        XCTAssertEqual(j?.goalLine(unit: .lb), "11 lb to go")
    }

    func testVoiceOverCarriesBothFactsAsOneSentence() {
        let j = WeightJourney.from(
            startKg: 80, startedAt: day(60),
            ema: ema([(60, 80.0), (0, 75.0)]),
            trendEstablished: true, goalKg: 70, calendar: cal
        )
        let vo = j?.voiceOver(unit: .kg) ?? ""
        XCTAssertEqual(vo, "down 5 kg since you started, 5 kg to go.")
    }
}
