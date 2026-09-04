import XCTest
@testable import plankAI

// Pass 77 — the morning verdict. The kept beat answers with HER
// trend (the same fold the pages draw), never a stock aphorism, and
// the scale-spike morning gets its answer at the moment it lands.
final class WeighInReceiptTests: XCTestCase {

    private func read(
        trendKg: Double? = 82.0,
        weeklyDeltaKg: Double? = -0.59,
        band: WeightWeekRead.Band? = .trendingDown,
        sufficiency: WeightWeekRead.Sufficiency = .established,
        sampleCount: Int = 17,
        lastSampleDaysAgo: Int? = 0
    ) -> WeightWeekRead {
        WeightWeekRead(
            trendKg: trendKg, weeklyDeltaKg: weeklyDeltaKg, band: band,
            sufficiency: sufficiency, sampleCount: sampleCount,
            lastSampleDaysAgo: lastSampleDaysAgo
        )
    }

    // MARK: - refusals

    func testSuppressionSilencesTheWhisperEvenOnAnEstablishedDownTrend() {
        XCTAssertNil(WeighInReceipt.whisper(
            read: read(), savedKg: 82.0, unit: .lb, numericsSuppressed: true
        ))
    }

    func testInsufficientAndStaleRecordsSpeakNoVerdict() {
        XCTAssertNil(WeighInReceipt.whisper(
            read: read(band: nil, sufficiency: .insufficient),
            savedKg: 82.0, unit: .lb
        ))
        XCTAssertNil(WeighInReceipt.whisper(
            read: read(band: nil, sufficiency: .stale, lastSampleDaysAgo: 21),
            savedKg: 82.0, unit: .lb
        ))
    }

    // MARK: - the established verdict

    func testEstablishedDownTrendSpeaksTheWeekDeltaInHerUnit() {
        let sub = WeighInReceipt.whisper(
            read: read(), savedKg: 82.0, unit: .lb
        )
        XCTAssertEqual(sub, "your trend reads down about 1.3 lb this week.")
    }

    func testKgUnitSpeaksKg() {
        let sub = WeighInReceipt.whisper(
            read: read(weeklyDeltaKg: -0.6), savedKg: 82.0, unit: .kg
        )
        XCTAssertEqual(sub, "your trend reads down about 0.6 kg this week.")
    }

    func testAMorningSpikeAboveTheLineLeadsWithTheReassurance() {
        let sub = WeighInReceipt.whisper(
            read: read(trendKg: 82.0), savedKg: 82.5, unit: .lb
        )
        XCTAssertEqual(
            sub,
            "this morning sits above your line. the trend still reads down about 1.3 lb this week."
        )
    }

    func testTheSpikeThresholdIsARealBoundary() {
        // 0.44 above the fold: an ordinary morning, no spike lead.
        XCTAssertEqual(
            WeighInReceipt.whisper(
                read: read(trendKg: 82.0), savedKg: 82.44, unit: .lb
            ),
            "your trend reads down about 1.3 lb this week."
        )
        // 0.46 above: the spike answer.
        XCTAssertTrue(
            WeighInReceipt.whisper(
                read: read(trendKg: 82.0), savedKg: 82.46, unit: .lb
            )!.hasPrefix("this morning sits above your line.")
        )
    }

    func testFlatWeekPassesThroughTheMonthContextWhenTheCallerHasOne() {
        let sub = WeighInReceipt.whisper(
            read: read(weeklyDeltaKg: 0.05, band: .holdingSteady),
            savedKg: 82.0, unit: .lb,
            steadyContextLine: "this week reads flat. the month is still down 4.1 lb."
        )
        XCTAssertEqual(
            sub, "this week reads flat. the month is still down 4.1 lb."
        )
    }

    func testFlatWeekWithoutMonthContextStatesTheHold() {
        XCTAssertEqual(
            WeighInReceipt.whisper(
                read: read(weeklyDeltaKg: 0.05, band: .holdingSteady),
                savedKg: 82.0, unit: .lb
            ),
            "your trend is holding steady this week."
        )
        XCTAssertEqual(
            WeighInReceipt.whisper(
                read: read(trendKg: 82.0, weeklyDeltaKg: 0.05, band: .holdingSteady),
                savedKg: 82.6, unit: .lb
            ),
            "this morning sits above your line. your trend is holding steady this week."
        )
    }

    func testAnUpTrendIsAPlainFactNeverScoldedNeverWaterExcused() {
        let sub = WeighInReceipt.whisper(
            read: read(weeklyDeltaKg: 0.41, band: .driftingUp),
            savedKg: 83.0, unit: .lb
        )
        XCTAssertEqual(sub, "your trend reads up about 0.9 lb this week.")
        for banned in ["water", "fault", "careful", "should", "bad"] {
            XCTAssertFalse(sub!.contains(banned), banned)
        }
    }

    // MARK: - the young trend

    func testProvisionalSpeaksDirectionWithoutNumerals() {
        let down = WeighInReceipt.whisper(
            read: read(sufficiency: .provisional, sampleCount: 5),
            savedKg: 82.0, unit: .lb
        )
        XCTAssertEqual(down, "an early read: trending down.")
        XCTAssertNil(down!.rangeOfCharacter(from: .decimalDigits))

        XCTAssertEqual(
            WeighInReceipt.whisper(
                read: read(band: .driftingUp, sufficiency: .provisional),
                savedKg: 82.0, unit: .lb
            ),
            "an early read. the line needs a few more days."
        )
    }

    // MARK: - the envelope's quotable form

    func testModelLineQuotesTheFoldWithItsBasis() {
        let line = WeighInReceipt.modelLine(read: read(), unit: .lb)
        XCTAssertEqual(
            line,
            "her smoothed weight trend reads down about 1.3 lb over the last week, resting on 17 weigh-ins. quote this fold for 'am i losing' and 'why is my weight up', never a single day's number."
        )
    }

    func testModelLineMarksAProvisionalReadAsEarly() {
        let line = WeighInReceipt.modelLine(
            read: read(sufficiency: .provisional, sampleCount: 5), unit: .lb
        )!
        XCTAssertTrue(line.contains("an early read"))
        XCTAssertTrue(line.contains("5 weigh-ins"))
    }

    func testModelLineNamesAStaleRecordInsteadOfADirection() {
        let line = WeighInReceipt.modelLine(
            read: read(band: nil, sufficiency: .stale, lastSampleDaysAgo: 21),
            unit: .lb
        )!
        XCTAssertTrue(line.contains("21 days ago"))
        XCTAssertTrue(line.contains("stale"))
        XCTAssertFalse(line.contains("down about"))
        XCTAssertNil(WeighInReceipt.modelLine(
            read: read(band: nil, sufficiency: .insufficient), unit: .lb
        ))
    }
}
