import XCTest
@testable import plankAI

// MARK: - PlateAnswerEngineTests (v25 E7 — SAY IT)
//
// The engine's honesty table, walked row by row, plus the refusal set
// asserted across the whole cross-product. Falsification condition #3
// in 20_E7_DECISION §5 says a composed sentence that renders praise,
// blame, a percentage or a number the user never gave us means the
// engine must be PULLED, not tuned. This suite is what makes that
// condition observable instead of aspirational.

final class PlateAnswerEngineTests: XCTestCase {

    private typealias E = PlateAnswerEngine
    private typealias I = PlateAnswerEngine.Input

    // MARK: - Standing (before the plate)

    func testStanding_nothingOnFileAndNoFloor_saysNothing() {
        // The empty state may not invent a start. No record, no floor,
        // no sentence.
        XCTAssertNil(E.standing(I(proteinOnFileG: 0, proteinFloorG: nil)))
    }

    func testStanding_nothingOnFileWithFloor_statesTheFloorOnly() {
        let a = E.standing(I(proteinOnFileG: 0, proteinFloorG: 123))
        XCTAssertEqual(a?.text, "123 g of protein today. nothing on the record yet.")
        XCTAssertEqual(a?.punch, "123 g of protein")
    }

    func testStanding_onFileWithoutFloor_neverInventsADenominator() {
        let a = E.standing(I(proteinOnFileG: 71, proteinFloorG: nil))
        XCTAssertEqual(a?.text, "71 g of protein so far.")
        XCTAssertFalse(Self.hasDenominator(a!.text), "no floor on file → no denominator")
    }

    /// "N of M" — a target the user did not give us. Deliberately NOT
    /// a bare `" of "` search: "g of protein" is prose, and an
    /// assertion that cannot tell the two apart proves nothing.
    private static func hasDenominator(_ text: String) -> Bool {
        text.range(of: #"\d+\s+of\s+\d+"#, options: .regularExpression) != nil
    }

    func testStanding_onFileWithFloor_showsPosition() {
        let a = E.standing(I(proteinOnFileG: 71, proteinFloorG: 123))
        XCTAssertEqual(a?.text, "71 of 123 g of protein so far.")
    }

    func testStanding_atOrAboveFloor_dropsTheRatio() {
        // Frame-caught on the capture surface: "123 of 90 g" reads as
        // a typo, not a position. Once covered, the ratio stops being
        // the interesting fact.
        XCTAssertEqual(
            E.standing(I(proteinOnFileG: 123, proteinFloorG: 90))?.text,
            "123 g of protein today, floor covered."
        )
        XCTAssertEqual(
            E.standing(I(proteinOnFileG: 90, proteinFloorG: 90))?.text,
            "90 g of protein today, floor covered."
        )
        // One gram short still shows the position.
        XCTAssertEqual(
            E.standing(I(proteinOnFileG: 89, proteinFloorG: 90))?.text,
            "89 of 90 g of protein so far."
        )
    }

    func testStanding_suppressedCohort_rendersNothing() {
        XCTAssertNil(E.standing(I(
            proteinOnFileG: 71, proteinFloorG: 123, numericsSuppressed: true
        )))
    }

    func testStanding_zeroFloorTreatedAsNoFloor() {
        // A floor of 0 is a bug upstream, not a target. It must never
        // render as "0 of 0 g".
        let a = E.standing(I(proteinOnFileG: 40, proteinFloorG: 0))
        XCTAssertEqual(a?.text, "40 g of protein so far.")
        XCTAssertNil(E.standing(I(proteinOnFileG: 0, proteinFloorG: 0)))
    }

    // MARK: - After the plate

    func testAfterPlate_firstPlateNoFloor_statesThePlate() {
        // p64 — the day's first plate leads its own answer now.
        let a = E.afterPlate(I(proteinOnFileG: 0, plateProteinG: 21, proteinFloorG: nil))
        XCTAssertEqual(a.text, "today's first plate. 21 g of protein.")
    }

    func testAfterPlate_withFloor_showsWhatIsLeft() {
        let a = E.afterPlate(I(
            proteinOnFileG: 50, plateProteinG: 21, proteinFloorG: 123,
            platesOnFile: 2
        ))
        XCTAssertEqual(a.text, "21 g of protein. 71 of 123 g, 52 g to go.")
        XCTAssertEqual(a.punch, "52 g to go")
    }

    func testAfterPlate_oneMoreLikeThat_onlyWhenTheArithmeticSupportsIt() {
        // 30 left, this plate was 34 → a plate like this closes it.
        let closes = E.afterPlate(I(
            proteinOnFileG: 59, plateProteinG: 34, proteinFloorG: 123,
            platesOnFile: 2
        ))
        XCTAssertTrue(closes.text.hasSuffix("one more like that closes it."))
        // 52 left, this plate was 21 → it would not, so we don't say it.
        let doesNot = E.afterPlate(I(
            proteinOnFileG: 50, plateProteinG: 21, proteinFloorG: 123,
            platesOnFile: 2
        ))
        XCTAssertFalse(doesNot.text.contains("one more"))
    }

    func testAfterPlate_floorMet_saidPlainlyWithoutPraise() {
        let a = E.afterPlate(I(
            proteinOnFileG: 110, plateProteinG: 21, proteinFloorG: 123,
            platesOnFile: 3
        ))
        XCTAssertEqual(a.text, "21 g of protein. that's 131 of 123 g, floor covered.")
        XCTAssertFalse(a.text.contains("!"))
    }

    func testAfterPlate_plateWithNoProtein_neverRendersZeroGrams() {
        // A described drink, or a scan that could not resolve macros.
        // The PLATE may not say "0 g"; the DAY still answers.
        let a = E.afterPlate(I(
            proteinOnFileG: 71, plateProteinG: 0, proteinFloorG: 123,
            platesOnFile: 2
        ))
        XCTAssertEqual(a.text, "on the record. 71 of 123 g of protein today.")
        XCTAssertFalse(a.text.contains("0 g of protein."))
    }

    func testAfterPlate_emptyPlateOnAnEmptyDay_marksTheDaysStart() {
        // p64 — even a macro-empty plate begins the day's record; the
        // fact is stated, and never as "0 g".
        let a = E.afterPlate(I(proteinOnFileG: 0, plateProteinG: 0, proteinFloorG: 123))
        XCTAssertEqual(a.text, "today's first plate. on the record.")
    }

    func testAfterPlate_nilPlateProteinBehavesAsZero() {
        let a = E.afterPlate(I(proteinOnFileG: 0, plateProteinG: nil, proteinFloorG: nil))
        XCTAssertEqual(a.text, "today's first plate. on the record.")
    }

    func testAfterPlate_suppressedCohort_carriesNoFigure() {
        let a = E.afterPlate(I(
            proteinOnFileG: 71, plateProteinG: 21, proteinFloorG: 123,
            platesOnFile: 2, numericsSuppressed: true
        ))
        XCTAssertEqual(a.text, "on the record.")
        XCTAssertFalse(a.text.contains(where: \.isNumber))
    }

    func testAfterPlate_negativesAreClamped() {
        // Defensive: a corrupt store must not produce "-12 g to go".
        let a = E.afterPlate(I(proteinOnFileG: -30, plateProteinG: -5, proteinFloorG: 100))
        XCTAssertFalse(a.text.contains("-"))
    }

    // MARK: - The first plate ever (p63 — the record's start is a moment)

    func testAfterPlate_firstPlateEver_marksTheRecordsStart() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: 115,
            isFirstPlateEver: true
        ))
        XCTAssertEqual(a.text, "your record starts here. 32 of 115 g of protein.")
        XCTAssertEqual(a.punch, "starts here")
    }

    func testAfterPlate_firstPlateEver_noFloor_statesOnlyThePlate() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: nil,
            isFirstPlateEver: true
        ))
        XCTAssertEqual(a.text, "your record starts here. 32 g of protein.")
        XCTAssertEqual(a.punch, "starts here")
    }

    func testAfterPlate_firstPlateEver_suppressed_speaksWithoutNumerals() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: 115,
            numericsSuppressed: true, isFirstPlateEver: true
        ))
        XCTAssertEqual(a.text, "your record starts here.")
        XCTAssertFalse(a.text.contains(where: \.isNumber))
    }

    func testAfterPlate_firstPlateEver_noDetail_neverRendersZero() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 0, proteinFloorG: 115,
            isFirstPlateEver: true
        ))
        XCTAssertEqual(a.text, "your record starts here.")
    }

    func testAfterPlate_firstPlateEverCoveringTheFloor_saysBoth() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 118, proteinFloorG: 115,
            isFirstPlateEver: true
        ))
        XCTAssertEqual(a.text, "your record starts here. 118 of 115 g, floor covered.")
        XCTAssertTrue(a.floorCrossed)
    }

    // MARK: - The crossing (p63 — the crest fires once, on the crossing)

    func testAfterPlate_floorCrossing_isMarked() {
        let crossed = E.afterPlate(I(
            proteinOnFileG: 100, plateProteinG: 30, proteinFloorG: 115
        ))
        XCTAssertTrue(crossed.floorCrossed)
        XCTAssertTrue(crossed.text.contains("floor covered"))
    }

    func testAfterPlate_alreadyCovered_isNotACrossing() {
        let again = E.afterPlate(I(
            proteinOnFileG: 130, plateProteinG: 20, proteinFloorG: 115
        ))
        XCTAssertTrue(again.text.contains("floor covered"))
        XCTAssertFalse(again.floorCrossed, "restating a covered floor is not the crossing")
    }

    func testAfterPlate_suppressedCohort_neverMarksACrossing() {
        // The haptic confirms what happened visually (§8). A cohort
        // shown no floor may not receive a floor's celebration.
        let a = E.afterPlate(I(
            proteinOnFileG: 100, plateProteinG: 30, proteinFloorG: 115,
            numericsSuppressed: true
        ))
        XCTAssertFalse(a.floorCrossed)
    }

    func testAfterPlate_plateWithoutProtein_neverMarksACrossing() {
        let a = E.afterPlate(I(
            proteinOnFileG: 115, plateProteinG: 0, proteinFloorG: 115
        ))
        XCTAssertFalse(a.floorCrossed)
    }

    // MARK: - The punch is always part of the sentence

    func testPunchIsAlwaysASubstringOfTheText() {
        // The reading renders `punch` in the italic serif INSIDE
        // `text`. A punch that is not a substring would render twice
        // or not at all.
        for input in Self.crossProduct {
            if let s = E.standing(input) {
                XCTAssertTrue(s.text.contains(s.punch),
                              "standing punch '\(s.punch)' not in '\(s.text)'")
            }
            let a = E.afterPlate(input)
            XCTAssertTrue(a.text.contains(a.punch),
                          "after punch '\(a.punch)' not in '\(a.text)'")
        }
    }

    // MARK: - The refusal set, across the whole cross-product

    func testNoOutputEverCarriesABannedWord() {
        for input in Self.crossProduct {
            for text in [E.standing(input)?.text, E.afterPlate(input).text].compactMap({ $0 }) {
                for banned in E.bannedWords {
                    XCTAssertFalse(
                        Self.containsWord(banned, in: text),
                        "'\(banned)' surfaced in '\(text)' for \(input)"
                    )
                }
            }
        }
    }

    /// WORD boundaries, not substrings. A naive `contains` reports
    /// "over" inside "covered" and "bad" inside "badge" — an assertion
    /// that fires on prose it should allow trains the next person to
    /// weaken it, which is worse than not having it.
    private static func containsWord(_ needle: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        // Punctuation-only needles ("%") have no word boundary.
        let pattern = needle.rangeOfCharacter(from: .letters) == nil
            ? escaped
            : #"(?<![a-z])"# + escaped + #"(?![a-z])"#
        return text.lowercased().range(of: pattern, options: .regularExpression) != nil
    }

    func testNoOutputEverCarriesAPercentageOrAnEmDashOrAHeart() {
        for input in Self.crossProduct {
            for text in [E.standing(input)?.text, E.afterPlate(input).text].compactMap({ $0 }) {
                XCTAssertFalse(text.contains("%"), text)
                XCTAssertFalse(text.contains("—"), text)
                XCTAssertFalse(text.contains("--"), text)
                XCTAssertFalse(text.contains("\u{2665}"), text)
                XCTAssertFalse(text.contains("!"), text)
            }
        }
    }

    func testEverythingIsLowercase() {
        for input in Self.crossProduct {
            for text in [E.standing(input)?.text, E.afterPlate(input).text].compactMap({ $0 }) {
                XCTAssertEqual(text, text.lowercased(), text)
            }
        }
    }

    func testNoDenominatorEverRendersWithoutAFloorOnFile() {
        // The single most important honesty rule: a user with no
        // weight on file has no floor, and must never be shown one.
        for input in Self.crossProduct where input.proteinFloorG == nil || input.proteinFloorG == 0 {
            for text in [E.standing(input)?.text, E.afterPlate(input).text].compactMap({ $0 }) {
                XCTAssertFalse(Self.hasDenominator(text),
                               "denominator without a floor: '\(text)' for \(input)")
                XCTAssertFalse(text.contains("to go"), text)
                XCTAssertFalse(text.contains("floor"), text)
            }
        }
    }

    // MARK: - The walk

    /// Every combination the table can be asked. 5 × 5 × 4 × 2 × 2
    /// × 2 = 800 inputs, each asserted against every refusal (p64
    /// grew the walk by platesOnFile so the first-of-day branch is
    /// swept too).
    private static var crossProduct: [I] {
        var out: [I] = []
        for onFile in [0, 1, 40, 122, 300] {
            for plate in [nil, 0, 1, 21, 200] as [Int?] {
                for floor in [nil, 0, 1, 123] as [Int?] {
                    for suppressed in [false, true] {
                        for firstEver in [false, true] {
                            for plates in [0, 2] {
                                out.append(I(
                                    proteinOnFileG: onFile,
                                    plateProteinG: plate,
                                    proteinFloorG: floor,
                                    platesOnFile: plates,
                                    numericsSuppressed: suppressed,
                                    isFirstPlateEver: firstEver
                                ))
                            }
                        }
                    }
                }
            }
        }
        return out
    }
}
