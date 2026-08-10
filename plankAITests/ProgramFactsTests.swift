import XCTest
@testable import plankAI

// E1 THE SPINE — pure program-fact semantics (docs/app_v25/05_E1_SPINE.md §1).
// Adversarial by brief: competing authorities, revocation resume,
// clamps per authority, vocabulary validation, tiebreaks.

final class ProgramFactsTests: XCTestCase {

    private func fact(
        _ kind: ProgramFactKind,
        _ value: ProgramFactValue,
        _ authority: ProgramFactAuthority,
        ended: Date? = nil,
        accepted: Date? = nil,
        created: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> ProgramFacts.Row {
        ProgramFacts.Row(
            kind: kind, value: value, authority: authority,
            endedAt: ended, acceptedAt: accepted, createdAt: created
        )
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    // MARK: - Resolution / precedence

    func testPrecedenceOrderPrescribedOverAll() {
        let rows = [
            fact(.stepGoal, .int(6_000), .defaulted),
            fact(.stepGoal, .int(7_000), .recommended, accepted: t0),
            fact(.stepGoal, .int(9_000), .preferred),
            fact(.stepGoal, .int(10_000), .prescribed),
        ]
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .stepGoal)?.value, .int(10_000))
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .stepGoal)?.authority, .prescribed)
    }

    func testPreferredBeatsAcceptedRecommendation() {
        let rows = [
            fact(.stepGoal, .int(7_000), .recommended, accepted: t0),
            fact(.stepGoal, .int(9_000), .preferred),
        ]
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .stepGoal)?.authority, .preferred)
    }

    func testPrescriptionEndResumesPreferred() {
        // The no-silent-overwrite law: ending the prescription
        // RESUMES her preference — it was never destroyed.
        let rows = [
            fact(.stepGoal, .int(9_000), .preferred),
            fact(.stepGoal, .int(10_000), .prescribed, ended: at(60)),
        ]
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .stepGoal)?.value, .int(9_000))
    }

    func testRecommendedWithoutAcceptanceNeverResolves() {
        let rows = [fact(.stepGoal, .int(7_000), .recommended, accepted: nil)]
        XCTAssertNil(ProgramFacts.head(of: rows, kind: .stepGoal))
    }

    func testAcceptedRecommendationResolvesWhenAlone() {
        let rows = [fact(.stepGoal, .int(7_000), .recommended, accepted: t0)]
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .stepGoal)?.value, .int(7_000))
    }

    func testEndedRowsExcluded() {
        let rows = [fact(.stepGoal, .int(7_000), .preferred, ended: at(1))]
        XCTAssertNil(ProgramFacts.head(of: rows, kind: .stepGoal))
    }

    func testHeadNilWhenNoRowsForKind() {
        let rows = [fact(.stepGoal, .int(7_000), .preferred)]
        XCTAssertNil(ProgramFacts.head(of: rows, kind: .weighCadence))
    }

    func testLatestCreatedAtWinsWithinAuthority() {
        // Two active rows in one (kind, authority) chain is a data
        // anomaly (coalescing should prevent it) — resolution stays
        // deterministic: latest createdAt wins.
        let rows = [
            fact(.stepGoal, .int(5_000), .preferred, created: at(0)),
            fact(.stepGoal, .int(5_500), .preferred, created: at(60)),
        ]
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .stepGoal)?.value, .int(5_500))
    }

    func testHeadIgnoresOtherKinds() {
        let rows = [
            fact(.proteinAdjust, .int(5), .preferred),
            fact(.stepGoal, .int(6_000), .defaulted),
        ]
        XCTAssertEqual(ProgramFacts.head(of: rows, kind: .proteinAdjust)?.value, .int(5))
    }

    // MARK: - Clamps (per kind × authority)

    func testStepGoalRecommendedClampsToSafeBand() {
        XCTAssertEqual(
            ProgramFacts.clamped(.int(12_000), kind: .stepGoal, authority: .recommended),
            .int(8_000)
        )
        XCTAssertEqual(
            ProgramFacts.clamped(.int(1_200), kind: .stepGoal, authority: .recommended),
            .int(2_500)
        )
    }

    func testStepGoalRecommendedRoundsToFifty() {
        XCTAssertEqual(
            ProgramFacts.clamped(.int(5_163), kind: .stepGoal, authority: .recommended),
            .int(5_150)
        )
    }

    func testStepGoalPreferredMayExceedRecommendedBand() {
        XCTAssertEqual(
            ProgramFacts.clamped(.int(12_000), kind: .stepGoal, authority: .preferred),
            .int(12_000)
        )
        // Sanity ceiling still applies.
        XCTAssertEqual(
            ProgramFacts.clamped(.int(80_000), kind: .stepGoal, authority: .preferred),
            .int(30_000)
        )
    }

    func testStepGoalPrescribedPassesThroughWithSanityFloor() {
        XCTAssertEqual(
            ProgramFacts.clamped(.int(10_000), kind: .stepGoal, authority: .prescribed),
            .int(10_000)
        )
        XCTAssertEqual(
            ProgramFacts.clamped(.int(100), kind: .stepGoal, authority: .prescribed),
            .int(500)
        )
    }

    func testProteinAdjustClampsAllAuthorities() {
        // The advisory band is a safety law — no authority rides
        // outside ±10g (the v4 clamp, now structural).
        for authority in ProgramFactAuthority.allCases {
            XCTAssertEqual(
                ProgramFacts.clamped(.int(25), kind: .proteinAdjust, authority: authority),
                .int(10), "authority \(authority)"
            )
            XCTAssertEqual(
                ProgramFacts.clamped(.int(-25), kind: .proteinAdjust, authority: authority),
                .int(-10), "authority \(authority)"
            )
        }
    }

    func testMovesAdjustClamp() {
        XCTAssertEqual(
            ProgramFacts.clamped(.int(3), kind: .movesAdjust, authority: .recommended),
            .int(1)
        )
        XCTAssertEqual(
            ProgramFacts.clamped(.int(-4), kind: .movesAdjust, authority: .preferred),
            .int(-1)
        )
    }

    // MARK: - Word vocabulary

    func testWordVocabularyPerKind() {
        XCTAssertTrue(ProgramFacts.isValidWord("softened", kind: .weighCadence))
        XCTAssertTrue(ProgramFacts.isValidWord("standard", kind: .weighCadence))
        XCTAssertFalse(ProgramFacts.isValidWord("sometimes", kind: .weighCadence))

        XCTAssertTrue(ProgramFacts.isValidWord("lighter", kind: .loggingMode))
        XCTAssertFalse(ProgramFacts.isValidWord("off", kind: .loggingMode))

        XCTAssertTrue(ProgramFacts.isValidWord("afterMeals", kind: .walkTiming))
        XCTAssertTrue(ProgramFacts.isValidWord("off", kind: .walkTiming))
        XCTAssertFalse(ProgramFacts.isValidWord("mornings", kind: .walkTiming))

        XCTAssertTrue(ProgramFacts.isValidWord("quieter", kind: .notificationPosture))
        XCTAssertFalse(ProgramFacts.isValidWord("silent", kind: .notificationPosture))
    }

    func testReadAnchorVocabulary() {
        XCTAssertTrue(ProgramFacts.isValidWord("auto", kind: .readAnchor))
        XCTAssertTrue(ProgramFacts.isValidWord("weekday:3", kind: .readAnchor))
        XCTAssertFalse(ProgramFacts.isValidWord("weekday:9", kind: .readAnchor))
        XCTAssertFalse(ProgramFacts.isValidWord("weekday:", kind: .readAnchor))
        XCTAssertFalse(ProgramFacts.isValidWord("monday", kind: .readAnchor))
    }

    func testIntKindsRejectWords() {
        XCTAssertFalse(ProgramFacts.isValidWord("softened", kind: .stepGoal))
    }

    // MARK: - Value encoding

    func testValueEncodingRoundTrip() {
        XCTAssertEqual(ProgramFactValue.decode(ProgramFactValue.int(5_150).encoded), .int(5_150))
        XCTAssertEqual(ProgramFactValue.decode(ProgramFactValue.int(-10).encoded), .int(-10))
        XCTAssertEqual(
            ProgramFactValue.decode(ProgramFactValue.word("softened").encoded),
            .word("softened")
        )
    }

    func testValueDecodeRejectsGarbage() {
        XCTAssertNil(ProgramFactValue.decode(""))
        XCTAssertNil(ProgramFactValue.decode("i:"))
        XCTAssertNil(ProgramFactValue.decode("i:abc"))
        XCTAssertNil(ProgramFactValue.decode("x:5"))
        XCTAssertNil(ProgramFactValue.decode("banana"))
    }
}
