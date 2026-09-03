import XCTest
@testable import plankAI

// Pass 74 — BECOMING'S JOB. Pins on the pure progress reads:
//
//  · a window claim requires the record to actually cover the window
//    (a 30-day sentence from 12 days of weigh-ins is a guess);
//  · the "flat week inside a moving month" reassurance speaks only
//    when both halves are separately honest, and never under a
//    falling week (there is nothing to reassure about);
//  · a dose era younger than 4 weeks NEVER carries a weight rate —
//    "early to read" is the sentence (the titration-interval floor);
//  · numeric suppression strips every era numeral.
final class BecomingStoryTests: XCTestCase {

    private let cal = Calendar.current
    private var now: Date { cal.startOfDay(for: .now) }

    /// Daily samples for the trailing `days`, kg = make(daysAgo).
    private func samples(
        days: Int, make: (Int) -> Double?
    ) -> [WeightWeekReadEngine.Sample] {
        (0...days).reversed().compactMap { ago in
            guard let kg = make(ago),
                  let day = cal.date(byAdding: .day, value: -ago, to: now)
            else { return nil }
            return .init(day: day, kg: kg)
        }
    }

    // MARK: window reads

    func testMonthLensSpeaksItsOwnWindowWithRate() {
        // Steady loss ~0.09 kg/day over 60 days — a clear month story.
        let s = samples(days: 60) { ago in 84.0 + Double(ago) * 0.09 }
        let read = BecomingStory.windowRead(
            samples: s, scope: .month, unit: .lb, now: now, calendar: cal
        )
        XCTAssertNotNil(read.periodLine)
        XCTAssertTrue(read.periodLine!.hasPrefix("down "), read.periodLine!)
        XCTAssertTrue(read.periodLine!.hasSuffix("this month."), read.periodLine!)
        XCTAssertNotNil(read.rateLine)
        XCTAssertTrue(read.rateLine!.contains("a week"), read.rateLine!)
    }

    func testWindowClaimRequiresCoverage() {
        // Only 10 days of record — the month may not speak.
        let s = samples(days: 10) { ago in 84.0 + Double(ago) * 0.1 }
        let read = BecomingStory.windowRead(
            samples: s, scope: .month, unit: .lb, now: now, calendar: cal
        )
        XCTAssertNil(read.periodLine)
        XCTAssertNil(read.rateLine)
    }

    func testFlatMonthSaysSteadyAndCarriesNoRate() {
        let s = samples(days: 60) { _ in 84.0 }
        let read = BecomingStory.windowRead(
            samples: s, scope: .month, unit: .lb, now: now, calendar: cal
        )
        XCTAssertEqual(read.periodLine, "held about steady this month.")
        XCTAssertNil(read.rateLine)
    }

    func testAnUpMonthIsNeverScoldedAndCarriesNoRate() {
        let s = samples(days: 60) { ago in 84.0 - Double(ago) * 0.05 }
        let read = BecomingStory.windowRead(
            samples: s, scope: .month, unit: .lb, now: now, calendar: cal
        )
        XCTAssertNotNil(read.periodLine)
        XCTAssertTrue(read.periodLine!.hasPrefix("up about "), read.periodLine!)
        XCTAssertNil(read.rateLine)
    }

    func testWeekAndYearLensesStayWithTheirStandingReads() {
        let s = samples(days: 120) { ago in 84.0 + Double(ago) * 0.06 }
        for scope in [JeniScope.week, .year, .all] {
            let read = BecomingStory.windowRead(
                samples: s, scope: scope, unit: .lb, now: now, calendar: cal
            )
            XCTAssertNil(read.periodLine, "\(scope) must not mint a window line")
        }
    }

    // MARK: the flat-week reassurance

    func testFlatWeekInsideAMovingMonthSpeaks() {
        // A fall, then flat long enough for the τ-EMA itself to go
        // flat (a 10-day tail left the smoothed week still falling —
        // the engine was right and the first fixture was wrong).
        let s = samples(days: 60) { ago in
            ago >= 16 ? 84.0 + Double(ago - 16) * 0.09 : 84.0
        }
        let context = BecomingStory.steadyContext(
            samples: s, unit: .lb, now: now, calendar: cal
        )
        XCTAssertNotNil(context)
        XCTAssertTrue(context!.line.hasPrefix("this week reads flat. the month is still down "),
                      context!.line)
    }

    func testAFallingWeekNeedsNoReassurance() {
        let s = samples(days: 60) { ago in 84.0 + Double(ago) * 0.09 }
        XCTAssertNil(BecomingStory.steadyContext(
            samples: s, unit: .lb, now: now, calendar: cal
        ))
    }

    func testAFlatMonthOffersNoFalseComfort() {
        // Flat week AND flat month — "the month is still down" would
        // be a lie; silence is the read.
        let s = samples(days: 60) { _ in 84.0 }
        XCTAssertNil(BecomingStory.steadyContext(
            samples: s, unit: .lb, now: now, calendar: cal
        ))
    }

    // MARK: the dose seat

    private func era(_ startedDaysAgo: Int, _ endedDaysAgo: Int?, _ word: String?)
    -> BecomingStory.EraInput {
        .init(
            startedAt: cal.date(byAdding: .day, value: -startedDaysAgo, to: now)!,
            endedAt: endedDaysAgo.flatMap {
                cal.date(byAdding: .day, value: -$0, to: now)
            },
            doseWord: word
        )
    }

    func testDoseSeatReadsEachSettledEraFromTheTrend() {
        let s = samples(days: 180) { ago in 80.0 + Double(ago) * 0.06 }
        let seat = BecomingStory.doseSeat(
            eras: [
                era(180, 120, "0.25 mg"),
                era(120, 60, "0.5 mg"),
                era(60, nil, "1 mg"),
            ],
            samples: s, unit: .lb, now: now, calendar: cal
        )
        XCTAssertNotNil(seat)
        XCTAssertEqual(seat!.doseWord, "1 mg")
        XCTAssertFalse(seat!.tooEarly)
        XCTAssertNil(seat!.contextLine)
        XCTAssertEqual(seat!.eraRows.count, 3)
        // Newest first, every settled era speaks a direction + span.
        XCTAssertEqual(seat!.eraRows.first!.label, "on 1 mg")
        XCTAssertTrue(seat!.eraRows.first!.value.contains("down"),
                      seat!.eraRows.first!.value)
        XCTAssertTrue(seat!.eraRows.first!.value.contains("wks"),
                      seat!.eraRows.first!.value)
    }

    func testAYoungEraIsEarlyToReadNeverRated() {
        let s = samples(days: 120) { ago in 80.0 + Double(ago) * 0.06 }
        let seat = BecomingStory.doseSeat(
            eras: [era(120, 20, "0.5 mg"), era(20, nil, "1 mg")],
            samples: s, unit: .lb, now: now, calendar: cal
        )
        XCTAssertNotNil(seat)
        XCTAssertTrue(seat!.tooEarly)
        XCTAssertNotNil(seat!.contextLine)
        XCTAssertEqual(seat!.eraRows.first!.value, "week 3 · early to read")
        XCTAssertFalse(seat!.eraRows.first!.value.contains("lb"))
    }

    func testSuppressionStripsEveryEraNumeral() {
        let s = samples(days: 120) { ago in 80.0 + Double(ago) * 0.06 }
        let seat = BecomingStory.doseSeat(
            eras: [era(120, 60, "0.5 mg"), era(60, nil, "1 mg")],
            samples: s, unit: .lb, numericsSuppressed: true,
            now: now, calendar: cal
        )
        XCTAssertNotNil(seat)
        for row in seat!.eraRows {
            XCTAssertFalse(row.value.contains("lb"), row.value)
            XCTAssertFalse(row.value.contains("down"), row.value)
        }
    }

    func testNoRegimenNoSeat() {
        XCTAssertNil(BecomingStory.doseSeat(
            eras: [], samples: [], unit: .lb, now: now, calendar: cal
        ))
        // An era chain whose current era has no stated dose can't
        // name a seat either.
        XCTAssertNil(BecomingStory.doseSeat(
            eras: [era(60, nil, nil)], samples: [], unit: .lb,
            now: now, calendar: cal
        ))
    }
}
