import XCTest
@testable import plankAI

// MARK: - JeniDeskAwarenessTests (v25 E6 — THE DESK)
//
// The desk's resting line is the first thing a person reads before
// deciding whether jeni is worth talking to. This table is what she is
// allowed to say there.

final class JeniDeskAwarenessTests: XCTestCase {

    // MARK: proof

    func testPlatesAndProteinLeadWhenBothAreOnFile() {
        let l = JeniDeskAwareness.compose(.init(plates: 3, proteinEatenG: 76))
        XCTAssertEqual(l.text, "3 plates and 76 g of protein, on file.")
        XCTAssertTrue(l.isProof)
    }

    func testOnePlateIsSingular() {
        let l = JeniDeskAwareness.compose(.init(plates: 1, proteinEatenG: 24))
        XCTAssertEqual(l.text, "1 plate and 24 g of protein, on file.")
    }

    func testAPlateWithNoMacroDetailNeverRendersZeroGrams() {
        // A relogged or text-logged plate can carry no protein reading.
        // "2 plates and 0 g of protein" is the kind of true-but-useless
        // number the provenance law exists to stop.
        let l = JeniDeskAwareness.compose(.init(plates: 2, proteinEatenG: 0))
        XCTAssertEqual(l.text, "2 plates on file today.")
        XCTAssertFalse(l.text.contains("0 g"))
    }

    func testAWeighInAloneIsStillSomethingTrue() {
        let l = JeniDeskAwareness.compose(.init(weighedToday: true))
        XCTAssertEqual(l.text, "your weigh-in is on file today.")
        XCTAssertTrue(l.isProof)
    }

    // MARK: the empty day

    func testAnEmptyDayFallsBackToTheTeachingLineAndNeverInventsProof() {
        // Pass 52 — the empty desk teaches the one thing a first-day
        // payer cannot know: jeni can READ the record.
        let l = JeniDeskAwareness.compose(.init())
        XCTAssertEqual(l.text, "ask me anything about your record. i can read it.")
        XCTAssertFalse(l.isProof)
    }

    func testTheCareGateSurvives() {
        // E4 G9: "between visits" implies clinician visits, which is
        // true only for a connected patient.
        let l = JeniDeskAwareness.compose(.init(isCareConnected: true))
        XCTAssertEqual(l.text, "your coach between visits.")
        XCTAssertFalse(l.isProof)
    }

    // MARK: the gap

    func testAReturnAfterAGapIsStatedWarmlyAndNeverAsAReprimand() {
        let l = JeniDeskAwareness.compose(.init(daysSinceLastOpen: 4))
        XCTAssertEqual(l.text, "it's been 4 days. your record is where you left it.")
        XCTAssertTrue(l.isProof)
    }

    func testAGapNeverScoldsAcrossItsWholeRange() {
        // Guilt re-engagement is a named banned anti-loop
        // (00_THE_SYSTEM §12). These are the words that would make the
        // line a reprimand.
        let banned = ["missed", "lost", "failed", "back on track", "again?",
                      "you should", "slipped", "broke", "streak", "sorry"]
        for days in 2...60 {
            let l = JeniDeskAwareness.compose(.init(daysSinceLastOpen: days))
            for word in banned {
                XCTAssertFalse(l.text.lowercased().contains(word),
                               "\"\(word)\" surfaced at a \(days)-day gap")
            }
        }
    }

    func testTodaysRecordOutranksTheGap() {
        // She was away, but she has already logged. Lead with what she
        // just did, not with where she was.
        let l = JeniDeskAwareness.compose(
            .init(plates: 1, proteinEatenG: 30, daysSinceLastOpen: 9)
        )
        XCTAssertEqual(l.text, "1 plate and 30 g of protein, on file.")
    }

    // MARK: the record outlives the day

    /// THE DEFECT THIS CLOSES. E6 replaced the tagline with proof and
    /// scoped the proof to TODAY — the one window most likely to be empty
    /// at the moment somebody opens the app. So a payer with a twelve-day
    /// record, opening at 9am, read the same sentence as a person who has
    /// never logged anything. The awareness reset every midnight.
    func testAFullRecordIsNeverDescribedAsAnEmptyOne() {
        let l = JeniDeskAwareness.compose(.init(
            yesterdayPlates: 4, yesterdayProteinG: 118, daysOnFile: 12
        ))
        XCTAssertEqual(l.text, "yesterday: 4 plates and 118 g of protein.")
        XCTAssertTrue(l.isProof)
        XCTAssertNotEqual(l.text, "ask me anything about your record. i can read it.")
    }

    func testYesterdayIsSingularAndNeverRendersZeroGrams() {
        let one = JeniDeskAwareness.compose(.init(yesterdayPlates: 1, daysOnFile: 3))
        XCTAssertEqual(one.text, "yesterday: 1 plate on file.")
        // A plate with no macro detail must not render "0 g" — the same
        // provenance rule the today branch already keeps.
        let noMacros = JeniDeskAwareness.compose(
            .init(yesterdayPlates: 2, yesterdayProteinG: 0, daysOnFile: 2)
        )
        XCTAssertEqual(noMacros.text, "yesterday: 2 plates on file.")
        XCTAssertFalse(noMacros.text.contains("0 g"))
    }

    func testTodayOutranksYesterdayWhichOutranksDepth() {
        let full = JeniDeskAwareness.Input(
            plates: 1, proteinEatenG: 30, weighedToday: true,
            yesterdayPlates: 4, yesterdayProteinG: 118, daysOnFile: 12
        )
        XCTAssertEqual(
            JeniDeskAwareness.compose(full).text,
            "1 plate and 30 g of protein, on file."
        )
        var noToday = full; noToday.plates = 0; noToday.proteinEatenG = 0
        XCTAssertEqual(
            JeniDeskAwareness.compose(noToday).text,
            "your weigh-in is on file today."
        )
        var noWeighIn = noToday; noWeighIn.weighedToday = false
        XCTAssertEqual(
            JeniDeskAwareness.compose(noWeighIn).text,
            "yesterday: 4 plates and 118 g of protein."
        )
        var noYesterday = noWeighIn; noYesterday.yesterdayPlates = 0
        XCTAssertEqual(
            JeniDeskAwareness.compose(noYesterday).text,
            "your record has 12 days in it."
        )
    }

    /// A single logged day is not depth. One day on file with nothing
    /// yesterday and nothing today has no proof to offer, so the claim
    /// stands — the engine still never invents.
    func testOneDayOnFileIsNotDepth() {
        let l = JeniDeskAwareness.compose(.init(daysOnFile: 1))
        XCTAssertEqual(l.text, "ask me anything about your record. i can read it.")
        XCTAssertFalse(l.isProof)
    }

    /// The gap line still outranks the record's depth: a return after
    /// days away is the most true thing about that moment.
    func testTheGapStillOutranksTheRecordsDepth() {
        let l = JeniDeskAwareness.compose(
            .init(daysSinceLastOpen: 5, yesterdayPlates: 0, daysOnFile: 12)
        )
        XCTAssertEqual(l.text, "it's been 5 days. your record is where you left it.")
    }

    // MARK: register

    func testTheLineIsAlwaysLowercaseAndCarriesNoBannedMarks() {
        let cases: [JeniDeskAwareness.Input] = [
            .init(), .init(plates: 2, proteinEatenG: 40),
            .init(weighedToday: true), .init(daysSinceLastOpen: 3),
            .init(isCareConnected: true), .init(plates: 1),
            .init(yesterdayPlates: 3, yesterdayProteinG: 90, daysOnFile: 8),
            .init(yesterdayPlates: 1, daysOnFile: 2),
            .init(daysOnFile: 14),
        ]
        for input in cases {
            let t = JeniDeskAwareness.compose(input).text
            XCTAssertFalse(t.first!.isUppercase, "\"\(t)\" opens with a capital")
            XCTAssertFalse(t.contains("—"), "em-dash in \"\(t)\"")
            XCTAssertFalse(t.contains("--"), "double hyphen in \"\(t)\"")
            XCTAssertFalse(t.contains("♥"), "heart in \"\(t)\"")
            XCTAssertFalse(t.contains("%"), "percentage in \"\(t)\"")
        }
    }
}
