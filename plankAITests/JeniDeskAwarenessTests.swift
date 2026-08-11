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

    func testAnEmptyDayFallsBackToTheClaimAndNeverInventsProof() {
        let l = JeniDeskAwareness.compose(.init())
        XCTAssertEqual(l.text, "your coach, day to day.")
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

    // MARK: register

    func testTheLineIsAlwaysLowercaseAndCarriesNoBannedMarks() {
        let cases: [JeniDeskAwareness.Input] = [
            .init(), .init(plates: 2, proteinEatenG: 40),
            .init(weighedToday: true), .init(daysSinceLastOpen: 3),
            .init(isCareConnected: true), .init(plates: 1),
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
