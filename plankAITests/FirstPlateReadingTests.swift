import XCTest
@testable import plankAI

// MARK: - FirstPlateReadingTests (v25 E5 — THE FIRST PLATE)
//
// The one true thing Jeni says about a stranger's first plate. This
// table is its honesty specification: what she may claim, what she must
// hedge, and what she must refuse to say when the record is thin.
//
// The register laws under test (docs/app_v9/00_MISSION.md L2 honesty ·
// 00_THE_SYSTEM §9 "protein floor leads, kcal quiet" · design law: no
// scores, no colour judgement):
//   · protein leads; kcal only speaks when protein cannot
//   · no floor without a weight on file — never a guessed target
//   · fractions render in coarse WORDS, never a percentage, because the
//     vision pipeline is ±30% and a percent implies precision it does
//     not have
//   · no praise, no blame, no verdict

final class FirstPlateReadingTests: XCTestCase {

    // MARK: the ordinary case

    func testProteinLeadsAndTheFloorGivesItMeaning() {
        let r = FirstPlateReadingEngine.compose(proteinG: 32, kcal: 480, floorG: 90)
        XCTAssertEqual(r.headline, "32 g of protein")
        XCTAssertEqual(r.meaning, "about a third of your day, in one plate.")
        XCTAssertTrue(r.hasFloor)
        XCTAssertNotNil(r.provenance)
    }

    func testTheFractionRendersInWordsAcrossTheBand() {
        func words(_ p: Double) -> String? {
            FirstPlateReadingEngine.compose(proteinG: p, kcal: 400, floorG: 100).meaning
        }
        XCTAssertEqual(words(8),  "a start on your day's protein.")
        XCTAssertEqual(words(25), "about a quarter of your day, in one plate.")
        XCTAssertEqual(words(35), "about a third of your day, in one plate.")
        XCTAssertEqual(words(52), "about half your day, in one plate.")
        XCTAssertEqual(words(70), "most of your day, in one plate.")
        XCTAssertEqual(words(95), "your whole day, in one plate.")
    }

    func testTheShortFormIsAFragmentAndTracksTheLongOne() {
        // The receipt row supplies its own label ("against your floor"),
        // so the short form carries no sentence furniture and no
        // terminal period. It must exist exactly when meaning does.
        for p in [Double?.none, 0.4, 8, 25, 35, 52, 70, 95, 140] {
            for floor in [Int?.none, 90] {
                let r = FirstPlateReadingEngine.compose(proteinG: p, kcal: 500, floorG: floor)
                XCTAssertEqual(
                    r.meaning == nil, r.meaningShort == nil,
                    "long and short forms disagree at protein \(String(describing: p))"
                )
                if let s = r.meaningShort {
                    XCTAssertFalse(s.hasSuffix("."), "\"\(s)\" ends a sentence it isn't")
                    XCTAssertFalse(s.isEmpty)
                }
            }
        }
        XCTAssertEqual(
            FirstPlateReadingEngine.compose(proteinG: 35, kcal: 400, floorG: 100).meaningShort,
            "about a third of your day"
        )
    }

    func testNoPercentageEverRenders() {
        for p in stride(from: 0.0, through: 140.0, by: 7.0) {
            let r = FirstPlateReadingEngine.compose(proteinG: p, kcal: 500, floorG: 90)
            XCTAssertFalse(r.headline.contains("%"), "headline leaked a percent at \(p)")
            XCTAssertFalse(r.meaning?.contains("%") ?? false, "meaning leaked a percent at \(p)")
        }
    }

    func testNoVerdictWordsAnywhere() {
        // The design law bans scoring. These are the words that would
        // turn a reading into a grade.
        let banned = ["good", "bad", "great", "poor", "too much", "too little",
                      "should", "better", "worse", "perfect", "excellent"]
        for p in [0.0, 5, 20, 45, 88, 130] {
            for floor in [Int?.none, 60, 90, 140] {
                let r = FirstPlateReadingEngine.compose(proteinG: p, kcal: 620, floorG: floor)
                let all = [r.headline, r.meaning ?? "", r.provenance ?? ""]
                    .joined(separator: " ").lowercased()
                for word in banned {
                    XCTAssertFalse(all.contains(word),
                                   "\"\(word)\" surfaced at protein \(p), floor \(String(describing: floor))")
                }
            }
        }
    }

    func testNoEmDashesInGeneratedCopy() {
        // Standing voice law (feedback_no_em_dash): em-dash and double
        // hyphen are banned between words, app-wide. The first cut of
        // this era shipped two of them; this is the guard.
        for p in [Double?.none, 0.4, 32, 95] {
            for floor in [Int?.none, 90] {
                let r = FirstPlateReadingEngine.compose(proteinG: p, kcal: 500, floorG: floor)
                let all = [r.headline, r.meaning ?? "", r.provenance ?? ""].joined(separator: " ")
                XCTAssertFalse(all.contains("—"), "em-dash in \"\(all)\"")
                XCTAssertFalse(all.contains("--"), "double hyphen in \"\(all)\"")
            }
        }
    }

    func testCopyStaysLowercaseExceptTheUnitsAndNumbers() {
        // Register law: lowercase casual. Nothing the engine composes
        // may open with a capital.
        let r = FirstPlateReadingEngine.compose(proteinG: 32, kcal: 480, floorG: 90)
        for s in [r.headline, r.meaning ?? "", r.provenance ?? ""] where !s.isEmpty {
            let first = s.first!
            XCTAssertFalse(first.isUppercase, "\"\(s)\" opens with a capital")
        }
    }

    // MARK: the thin record

    func testNoWeightOnFileMeansNoFloorAndNoMeaning() {
        let r = FirstPlateReadingEngine.compose(proteinG: 32, kcal: 480, floorG: nil)
        XCTAssertEqual(r.headline, "32 g of protein")
        XCTAssertNil(r.meaning, "a floor was invented without a weight on file")
        XCTAssertNil(r.provenance)
        XCTAssertFalse(r.hasFloor)
    }

    func testNoProteinFallsBackToKcalNeverToSilence() {
        let r = FirstPlateReadingEngine.compose(proteinG: nil, kcal: 620, floorG: 90)
        XCTAssertEqual(r.headline, "about 620 calories")
        XCTAssertNil(r.meaning)
        XCTAssertFalse(r.hasFloor)
    }

    func testTraceProteinIsTreatedAsNoProtein() {
        // A 0.4 g reading is noise, not a fact worth a headline.
        let r = FirstPlateReadingEngine.compose(proteinG: 0.4, kcal: 210, floorG: 90)
        XCTAssertEqual(r.headline, "about 210 calories")
    }

    func testAnEmptyRecordSaysSomethingTrueAndNothingMore() {
        let r = FirstPlateReadingEngine.compose(proteinG: nil, kcal: nil, floorG: 90)
        XCTAssertEqual(r.headline, "it's on file")
        XCTAssertNil(r.meaning)
        XCTAssertFalse(r.hasFloor)
    }

    // MARK: rounding

    func testProteinRoundsToWholeGramsAndNeverShowsFalsePrecision() {
        XCTAssertEqual(
            FirstPlateReadingEngine.compose(proteinG: 31.6, kcal: 400, floorG: 90).headline,
            "32 g of protein"
        )
        XCTAssertEqual(
            FirstPlateReadingEngine.compose(proteinG: nil, kcal: 617.4, floorG: nil).headline,
            "about 620 calories"
        )
    }
}

// MARK: - FirstPlateStateTests (v25 E5)
//
// The beat is offered exactly once — but "once" has an edge the first
// cut got wrong: an empty return from the capture is indistinguishable
// from a decline, and on a first run it is just as likely to be a
// dropped network or a denied camera permission. One retry, never a
// loop.

@MainActor
final class FirstPlateStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        FirstPlateState.reset()
    }

    override func tearDown() {
        FirstPlateState.reset()
        super.tearDown()
    }

    func testAFreshDeviceHasNoOutcome() {
        XCTAssertEqual(FirstPlateState.outcome, .none)
    }

    // MARK: the production flag (founder steer, 2026-08-11)

    func testTheFirstPlateIsOffUnlessExplicitlyEnabled() {
        // THE production assertion. The hard-paywall funnel is under an
        // active test and proof-before-paywall is a separate experiment;
        // shipping both at once would make neither measurable.
        //
        // An explicit ENABLE (not a `disabled` kill switch) is the point:
        // a wiped UserDefaults, a fresh install or a restored backup all
        // resolve to false, so the experiment cannot ship by accident.
        UserDefaults.standard.removeObject(forKey: "e5.firstPlate.enabled")
        XCTAssertFalse(
            FirstPlateState.isEnabled,
            "THE FIRST PLATE would ship into the live hard-paywall test"
        )

        // And the legacy key from the first cut must not resurrect it.
        UserDefaults.standard.set(false, forKey: "e5.firstPlate.disabled")
        XCTAssertFalse(FirstPlateState.isEnabled)
        UserDefaults.standard.removeObject(forKey: "e5.firstPlate.disabled")
    }

    func testTheExperimentTurnsOnWithOneKeyAndNothingElse() {
        UserDefaults.standard.set(true, forKey: "e5.firstPlate.enabled")
        XCTAssertTrue(FirstPlateState.isEnabled)
        UserDefaults.standard.removeObject(forKey: "e5.firstPlate.enabled")
        XCTAssertFalse(FirstPlateState.isEnabled)
    }

    func testLoggingStampsOnceAndIsNotOverwritable() {
        FirstPlateState.markLogged()
        XCTAssertEqual(FirstPlateState.outcome, .logged)
        FirstPlateState.markSkipped()
        XCTAssertEqual(FirstPlateState.outcome, .logged, "a skip overwrote a real plate")
    }

    func testDecliningAtTheInviteResolvesImmediately() {
        FirstPlateState.markSkipped()
        XCTAssertEqual(FirstPlateState.outcome, .skipped)
    }

    func testAnEmptyCaptureGetsExactlyOneRetry() {
        XCTAssertFalse(
            FirstPlateState.markCaptureClosedWithoutAPlate(),
            "the first empty return should leave the beat open"
        )
        XCTAssertEqual(FirstPlateState.outcome, .none)

        XCTAssertTrue(
            FirstPlateState.markCaptureClosedWithoutAPlate(),
            "the second empty return should resolve"
        )
        XCTAssertEqual(FirstPlateState.outcome, .skipped)
    }

    func testTheRetryNeverLoops() {
        for _ in 0..<10 { _ = FirstPlateState.markCaptureClosedWithoutAPlate() }
        XCTAssertEqual(FirstPlateState.outcome, .skipped)
    }

    func testLoggingAfterARetryStillStampsLogged() {
        _ = FirstPlateState.markCaptureClosedWithoutAPlate()   // failed scan
        FirstPlateState.markLogged()                           // retried, worked
        XCTAssertEqual(FirstPlateState.outcome, .logged)
    }

    func testResetClearsTheAttemptCounterToo() {
        _ = FirstPlateState.markCaptureClosedWithoutAPlate()
        FirstPlateState.reset()
        XCTAssertFalse(
            FirstPlateState.markCaptureClosedWithoutAPlate(),
            "reset left a stale attempt behind"
        )
    }
}
