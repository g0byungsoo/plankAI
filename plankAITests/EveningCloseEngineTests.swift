import XCTest
@testable import plankAI

// MARK: - EveningCloseEngineTests (v25 E8)
//
// The evening close said "that's the day, maya." / "tomorrow: a
// balanced day." every night to everyone — two sentences carrying no
// information, while the same snapshot three inches below held the
// plates, the protein and the beats. These pin the replacement AND the
// honesty laws it inherits from E6/E7, which are the only reason the
// old copy was safe: a line that says nothing cannot say anything
// wrong, and a line that says something can.

final class EveningCloseEngineTests: XCTestCase {

    private func input(
        name: String = "maya",
        protein: Int = 0,
        floor: Int? = 90,
        plates: Int = 0,
        beatsDone: Int = 0,
        beatsTotal: Int = 3,
        weighed: Bool = false,
        suppressed: Bool = false,
        tomorrow: ProgramDayArchetype = .balanced
    ) -> EveningCloseEngine.Input {
        EveningCloseEngine.Input(
            name: name, proteinEatenG: protein, proteinFloorG: floor,
            plateCount: plates, beatsDone: beatsDone, beatsTotal: beatsTotal,
            weighedInToday: weighed, numericsSuppressed: suppressed,
            tomorrow: tomorrow
        )
    }

    private func today(_ i: EveningCloseEngine.Input) -> String {
        EveningCloseEngine.todayLine(i).text
    }

    // MARK: - proof, not a claim

    func testProteinLeadsWhenItCanSpeak() {
        let line = today(input(protein: 96, floor: 90, plates: 3))
        XCTAssertTrue(line.contains("96 g of protein"), line)
        XCTAssertTrue(line.contains("3 plates"), line)
    }

    func testUnderTheFloorShowsThePosition() {
        XCTAssertEqual(
            today(input(protein: 72, floor: 90, plates: 2)),
            "2 plates. 72 of 90 g of protein."
        )
    }

    /// E7 §6.6 — "123 of 90 g" read as a typo. Once the floor is met the
    /// ratio stops being the interesting fact, so it stops being said.
    func testFloorMetDropsTheDenominator() {
        let line = today(input(protein: 123, floor: 90, plates: 3))
        XCTAssertFalse(line.contains("of 90"), line)
        XCTAssertTrue(line.contains("123 g of protein"), line)
    }

    /// E7's law: no denominator without a floor on file.
    func testNoFloorNeverRendersADenominator() {
        let line = today(input(protein: 72, floor: nil, plates: 2))
        // "of" also occurs in "72 g of protein" — the thing that must
        // be absent is a DENOMINATOR ("of 90 g"), not the word.
        XCTAssertFalse(Self.hasDenominator(line), line)
        XCTAssertTrue(line.contains("72 g of protein"), line)
    }

    // MARK: - matchers
    //
    // E7 §5.4 recorded a `CONTAINS "0 g of protein"` assertion that
    // fired on "9(0 g) of protein" and a leg that asserted a grid six
    // seconds after it had correctly been replaced. Both were rewritten
    // there with the note that an assertion firing on prose it should
    // allow teaches the next person to delete it. These matchers are
    // anchored so the same trap does not get re-set here.

    /// A literal zero-gram reading, not any number ending in zero.
    static func hasZeroGrams(_ s: String) -> Bool {
        s.range(of: #"(?<![0-9])0 g\b"#, options: .regularExpression) != nil
    }

    /// "of 90 g" — a floor used as a denominator.
    static func hasDenominator(_ s: String) -> Bool {
        s.range(of: #"\bof [0-9]+ g\b"#, options: .regularExpression) != nil
    }

    func testTheMatchersThemselves() {
        // the exact false positive E7 hit
        XCTAssertFalse(Self.hasZeroGrams("90 g of protein."))
        XCTAssertFalse(Self.hasZeroGrams("40 g of protein."))
        XCTAssertTrue(Self.hasZeroGrams("0 g of protein."))
        XCTAssertTrue(Self.hasDenominator("72 of 90 g of protein."))
        XCTAssertFalse(Self.hasDenominator("72 g of protein."))
    }

    func testOnePlateIsSingular() {
        XCTAssertTrue(today(input(plates: 1)).contains("one plate."))
    }

    /// E6's law — an absent number is absent, never zero.
    func testNeverRendersZeroGrams() {
        for i in [input(protein: 0, plates: 2), input(protein: 0, plates: 0),
                  input(protein: 0, plates: 0, beatsDone: 2)] {
            XCTAssertFalse(Self.hasZeroGrams(today(i)), today(i))
        }
    }

    func testPlatesWithoutProteinDetailStillSpeak() {
        XCTAssertEqual(today(input(protein: 0, plates: 3)), "3 plates.")
    }

    func testThePlanCarriesTheDayWhenNoFoodIsOnFile() {
        XCTAssertEqual(
            today(input(protein: 0, plates: 0, beatsDone: 2, beatsTotal: 3)),
            "the plan: 2 of 3 done."
        )
    }

    func testAWeighInAloneIsARecord() {
        XCTAssertTrue(
            today(input(plates: 0, beatsDone: 0, weighed: true)).contains("weighed in")
        )
    }

    // MARK: - the empty day is never scolded

    func testNothingOnFileInventsNoProof() {
        let line = today(input(protein: 0, plates: 0, beatsDone: 0))
        XCTAssertTrue(line.contains("quiet day"), line)
        XCTAssertTrue(line.contains("still counts"), line)
        // no fabricated numerals at all
        XCTAssertNil(line.rangeOfCharacter(from: .decimalDigits), line)
    }

    func testTheQuietDayCarriesNoReprimand() {
        let banned = ["failed", "missed", "should", "forgot", "nothing to show",
                      "you didn't", "no excuses", "slipped", "lazy", "behind"]
        let line = today(input(protein: 0, plates: 0)).lowercased()
        for word in banned {
            XCTAssertFalse(line.contains(word), "reprimand '\(word)' in: \(line)")
        }
    }

    // MARK: - suppression

    func testSuppressionYieldsWordsOnly() {
        let withData = today(input(protein: 96, plates: 3, suppressed: true))
        XCTAssertNil(withData.rangeOfCharacter(from: .decimalDigits), withData)
        let empty = today(input(protein: 0, plates: 0, suppressed: true))
        XCTAssertNil(empty.rangeOfCharacter(from: .decimalDigits), empty)
    }

    // MARK: - THE PROTEIN CLOSE
    //
    // The only line on the screen that can still change TODAY. Every
    // guard here is load-bearing: the failure modes are "count grams at
    // someone who is already struggling to eat" and "name an impossible
    // number", both of which land on the medicated cohort hardest.

    private func close(_ i: EveningCloseEngine.Input) -> String {
        EveningCloseEngine.close(i).tomorrow.text
    }

    func testAGapOffersTonightNotTomorrow() {
        let line = close(input(protein: 72, floor: 90))
        XCTAssertTrue(line.contains("still time tonight"), line)
        XCTAssertFalse(line.hasPrefix("tomorrow"), line)
    }

    func testASmallGapNamesTheNumberAndOneFood() {
        let line = close(input(protein: 72, floor: 90))   // 18 g
        XCTAssertTrue(line.contains("18 g"), line)
        XCTAssertTrue(line.contains("greek yogurt"), line)
    }

    func testAMidGapNamesAFoodButNotTheNumber() {
        let line = close(input(protein: 55, floor: 90))   // 35 g
        XCTAssertFalse(line.contains("35 g"), line)
        XCTAssertTrue(line.contains("cottage cheese") || line.contains("shake"), line)
    }

    /// A gap this size is not a target, it is a rebuke. It must never be
    /// stated as a demand.
    func testALargeGapNeverNamesTheNumber() {
        let line = close(input(protein: 10, floor: 90))   // 80 g
        XCTAssertFalse(line.contains("80"), line)
        XCTAssertTrue(line.contains("even something small"), line)
    }

    func testTheFloorMetSaysWhyItMatteredWithoutPraise() {
        let line = close(input(protein: 123, floor: 90))
        XCTAssertTrue(line.contains("protein landed"), line)
        XCTAssertTrue(line.contains("muscle"), line)
        for praise in ["great", "amazing", "well done", "crushed", "nailed"] {
            XCTAssertFalse(line.lowercased().contains(praise), line)
        }
    }

    /// E7's law reaches this line too.
    func testNoFloorOnFileFallsBackToTomorrow() {
        let line = close(input(protein: 40, floor: nil, tomorrow: .rest))
        XCTAssertTrue(line.hasPrefix("tomorrow"), line)
        XCTAssertFalse(line.contains("still time tonight"), line)
    }

    /// The medication adequacy net already owns the very-light day with
    /// a gentler line. Two prompts about the same gap, one of them
    /// counting grams, is the pile-on this cohort must not get.
    func testTheAdequacyNetSuppressesTheProteinClose() {
        var i = input(protein: 20, floor: 90)
        i.adequacyNetShowing = true
        XCTAssertFalse(close(i).contains("still time tonight"), close(i))
        XCTAssertTrue(close(i).hasPrefix("tomorrow"), close(i))
    }

    func testSuppressionKeepsTheOfferButDropsEveryNumber() {
        var i = input(protein: 40, floor: 90)
        i.numericsSuppressed = true
        let line = close(i)
        XCTAssertTrue(line.contains("still time tonight"), line)
        XCTAssertNil(line.rangeOfCharacter(from: .decimalDigits), line)
    }

    func testTheOfferIsNeverAnOrder() {
        for protein in [0, 20, 55, 72, 89] {
            let line = close(input(protein: protein, floor: 90)).lowercased()
            for order in ["you must", "you need to", "you should", "make sure you"] {
                XCTAssertFalse(line.contains(order), "'\(order)' in: \(line)")
            }
        }
    }

    // MARK: - tomorrow carries a reason, not a label

    func testEveryArchetypeGivesAReasonNotJustAName() {
        for a: ProgramDayArchetype in [.protein, .movement, .balanced, .rest] {
            let line = EveningCloseEngine.tomorrowLine(input(tomorrow: a)).text
            XCTAssertTrue(line.hasPrefix("tomorrow"), line)
            // two sentences: the shape, then why it matters
            XCTAssertEqual(
                line.filter { $0 == "." }.count, 2,
                "\(a) should state a shape AND a reason: \(line)"
            )
        }
    }

    func testProteinDayNamesTheMechanism() {
        let line = EveningCloseEngine.tomorrowLine(input(tomorrow: .protein)).text
        XCTAssertTrue(line.contains("muscle"), line)
    }

    // MARK: - voice

    func testVoiceRulesHoldAcrossTheWholeTable() {
        var lines: [String] = []
        for protein in [0, 40, 96, 123] {
            for plates in [0, 1, 3] {
                for floor: Int? in [nil, 90] {
                    for a: ProgramDayArchetype in [.protein, .movement, .balanced, .rest] {
                        let i = input(protein: protein, floor: floor,
                                      plates: plates, tomorrow: a)
                        let c = EveningCloseEngine.close(i)
                        lines.append(c.today.text)
                        lines.append(c.tomorrow.text)
                    }
                }
            }
        }
        XCTAssertGreaterThan(lines.count, 100)
        for line in lines {
            XCTAssertFalse(line.contains("—"), "em-dash in: \(line)")
            XCTAssertFalse(line.contains("--"), "double hyphen in: \(line)")
            XCTAssertFalse(line.contains("!"), "exclamation in: \(line)")
            XCTAssertFalse(line.contains("♥"), "heart in: \(line)")
            XCTAssertFalse(Self.hasZeroGrams(line), "zero grams in: \(line)")
            // lowercase register: no sentence-initial capital
            XCTAssertEqual(String(line.prefix(1)), String(line.prefix(1)).lowercased(),
                           "capitalised: \(line)")
            // no verdicts
            for verdict in ["great", "amazing", "bad day", "well done", "perfect"] {
                XCTAssertFalse(line.lowercased().contains(verdict),
                               "verdict '\(verdict)' in: \(line)")
            }
        }
    }

    /// The punch words the moment sets in italic must actually occur in
    /// their own line, or the italic pass silently no-ops.
    func testPunchWordsAppearInTheirLine() {
        for a: ProgramDayArchetype in [.protein, .movement, .balanced, .rest] {
            for protein in [0, 96] {
                for plates in [0, 2] {
                    let c = EveningCloseEngine.close(
                        input(protein: protein, plates: plates, tomorrow: a)
                    )
                    for p in c.today.punch {
                        XCTAssertTrue(c.today.text.contains(p),
                                      "punch '\(p)' missing from '\(c.today.text)'")
                    }
                    for p in c.tomorrow.punch {
                        XCTAssertTrue(c.tomorrow.text.contains(p),
                                      "punch '\(p)' missing from '\(c.tomorrow.text)'")
                    }
                }
            }
        }
    }

    func testNamelessUserStillGetsACompleteLine() {
        let line = today(input(name: "", protein: 0, plates: 0))
        XCTAssertFalse(line.contains(", ."), line)
        XCTAssertTrue(line.contains("quiet day"), line)
    }
}
