import XCTest
@testable import plankAI

// E8.2 — the close redesigned on the founder's steer + the evidence
// pass. The engine now returns ONE hero sentence (meaning), a LEDGER
// (facts, right-aligned in the view), an optional drafted INTENTION
// (one tap, gap nights only), and an optional ANCHOR (tomorrow's real
// hold). The honesty laws are unchanged and re-pinned here:
//   protein leads · no denominator without a floor · met drops the
//   denominator · never "0 g" · no verdict · suppression = words only ·
//   silence over filler.
final class EveningCloseEngineTests: XCTestCase {

    private func input(
        name: String = "maya",
        protein: Int = 0, floor: Int? = nil, plates: Int = 0,
        done: Int = 0, total: Int = 0, weighed: Bool = false,
        suppressed: Bool = false, net: Bool = false,
        doseDay: Bool = false, weighDay: Bool = false, adopted: Bool = false
    ) -> EveningCloseEngine.Input {
        EveningCloseEngine.Input(
            name: name, proteinEatenG: protein, proteinFloorG: floor,
            plateCount: plates, beatsDone: done, beatsTotal: total,
            weighedInToday: weighed, numericsSuppressed: suppressed,
            adequacyNetShowing: net,
            tomorrowIsDoseDay: doseDay,
            // p55 — the fixture means a WEEKLY user (the suite's
            // standing persona); the cadence-aware anchor variants
            // are pinned in Pass55RegimenTruthTests.
            tomorrowDoseCadence: doseDay ? .weekly(anchor: 4) : nil,
            tomorrowIsWeighDay: weighDay,
            weighAdopted: adopted
        )
    }

    // MARK: - The hero

    func testAGapNightHeroIsTheProteinClose() {
        let close = EveningCloseEngine.close(input(protein: 72, floor: 90, plates: 3))
        XCTAssertTrue(close.hero.text.contains("still time tonight"))
        XCTAssertTrue(close.hero.text.contains("18 g"),
                      "a small gap names the number")
    }

    func testAMetNightHeroConfirmsWithoutTheEducationTail() {
        let close = EveningCloseEngine.close(input(protein: 122, floor: 90, plates: 3))
        XCTAssertEqual(close.hero.text, "you hit your protein goal today. nice work.")
        XCTAssertFalse(close.hero.text.contains("muscle"),
                       "the mechanism lecture is a MethodNote's job, not a nightly fixture")
    }

    func testAMidGapNamesAFoodButNotTheNumber() {
        let close = EveningCloseEngine.close(input(protein: 55, floor: 90))
        XCTAssertTrue(close.hero.text.contains("still time tonight"))
        // p67 — the gap is the useful information, so the mid band
        // now says it (35 g to go) alongside the food idea.
        XCTAssertTrue(close.hero.text.contains("35"),
                      "mid gaps say the number and offer a food")
    }

    func testALargeGapNeverNamesTheNumber() {
        let close = EveningCloseEngine.close(input(protein: 10, floor: 90))
        XCTAssertFalse(close.hero.text.contains("80"),
                       "an impossible ask reads as shame")
        XCTAssertTrue(close.hero.text.contains("even something small"))
    }

    func testNoFloorHeroIsOnFileNeverADenominator() {
        let close = EveningCloseEngine.close(input(protein: 96, plates: 2))
        XCTAssertEqual(close.hero.text, "the day is logged.")
        XCTAssertFalse(close.hero.text.contains("of"))
    }

    func testThePlanCarriesTheDayWhenNoFoodIsOnFile() {
        let close = EveningCloseEngine.close(input(done: 2, total: 3))
        XCTAssertEqual(close.hero.text, "you kept the plan today.")
    }

    func testAWeighInAloneIsARecord() {
        let close = EveningCloseEngine.close(input(weighed: true))
        XCTAssertTrue(close.hero.text.contains("weighed in"))
    }

    func testTheQuietDayCarriesNoReprimand() {
        let close = EveningCloseEngine.close(input())
        XCTAssertEqual(close.hero.text, "a quiet day, maya. it still counts.")
        for word in ["should", "missed", "only", "just", "didn't", "failed"] {
            XCTAssertFalse(close.hero.text.contains(word))
        }
    }

    func testNamelessUserStillGetsACompleteLine() {
        let close = EveningCloseEngine.close(input(name: ""))
        XCTAssertEqual(close.hero.text, "a quiet day. it still counts.")
    }

    func testTheAdequacyNetOwnsTheLightNight() {
        let close = EveningCloseEngine.close(
            input(protein: 12, floor: 90, plates: 1, net: true)
        )
        XCTAssertEqual(close.hero.text, "a light day. what you logged still counts.")
        XCTAssertNil(close.intention,
                     "no drafted plan on the night the care net is speaking")
    }

    // MARK: - The ledger (facts live here, never in the prose)

    func testTheLedgerCarriesTheNumbersTheProseDoesNot() {
        let close = EveningCloseEngine.close(input(protein: 122, floor: 90, plates: 3, done: 2, total: 2))
        XCTAssertFalse(close.hero.text.contains("122"),
                       "numbers belong to the ledger now")
        XCTAssertTrue(close.ledger.contains(
            EveningCloseEngine.LedgerRow(label: "plates", value: "3")))
        XCTAssertTrue(close.ledger.contains(
            EveningCloseEngine.LedgerRow(label: "protein", value: "122 g · goal hit")))
        XCTAssertTrue(close.ledger.contains(
            EveningCloseEngine.LedgerRow(label: "the plan", value: "2 of 2")))
    }

    func testUnderTheFloorTheLedgerShowsThePosition() {
        let close = EveningCloseEngine.close(input(protein: 72, floor: 90, plates: 2))
        XCTAssertTrue(close.ledger.contains(
            EveningCloseEngine.LedgerRow(label: "protein", value: "72 of 90 g")))
    }

    func testNoFloorLedgerNeverRendersADenominator() {
        let close = EveningCloseEngine.close(input(protein: 96, plates: 2))
        XCTAssertTrue(close.ledger.contains(
            EveningCloseEngine.LedgerRow(label: "protein", value: "96 g")))
    }

    func testOnePlateIsSingularAndZeroIsAbsent() {
        XCTAssertTrue(EveningCloseEngine.close(input(protein: 20, plates: 1)).ledger
            .contains(EveningCloseEngine.LedgerRow(label: "plates", value: "one")))
        let none = EveningCloseEngine.close(input(weighed: true))
        XCTAssertFalse(none.ledger.contains { $0.label == "plates" })
        XCTAssertFalse(none.ledger.contains { $0.value.hasPrefix("0") },
                       "never 0 g, never 0 plates")
    }

    func testSuppressionYieldsWordsOnlyInHeroAndLedger() {
        let close = EveningCloseEngine.close(
            input(protein: 72, floor: 90, plates: 3, done: 1, total: 2, suppressed: true)
        )
        XCTAssertTrue(close.hero.text.contains("still time tonight"))
        for row in close.ledger {
            XCTAssertFalse(row.label == "protein", "no gram rows under suppression")
            XCTAssertFalse(row.label == "plates", "no count rows under suppression")
        }
        XCTAssertTrue(close.ledger.contains(
            EveningCloseEngine.LedgerRow(label: "the plan", value: "1 of 2")),
            "plan counts are behavioral and stay")
    }

    // MARK: - The intention (drafted, one tap, gap nights only)

    func testAGapNightDraftsABreakfastIntention() {
        let close = EveningCloseEngine.close(input(protein: 40, floor: 90))
        let intention = try! XCTUnwrap(close.intention)
        XCTAssertEqual(intention.key, "breakfast_protein")
        XCTAssertEqual(intention.text,
                       "tomorrow at breakfast: 30 g of protein, before anything else.")
    }

    func testTheDraftClampsToABreakfastAPersonCanEat() {
        let low = EveningCloseEngine.close(input(protein: 10, floor: 45))
        XCTAssertTrue(try! XCTUnwrap(low.intention).text.contains("20 g"),
                      "floor/3 below 20 clamps up")
        let high = EveningCloseEngine.close(input(protein: 10, floor: 150))
        XCTAssertTrue(try! XCTUnwrap(high.intention).text.contains("40 g"),
                      "floor/3 above 40 clamps down")
    }

    func testAMetNightDraftsNothing() {
        XCTAssertNil(EveningCloseEngine.close(input(protein: 95, floor: 90)).intention,
                     "the close asks for nothing on a met night")
    }

    func testNoFloorDraftsNothing() {
        XCTAssertNil(EveningCloseEngine.close(input(protein: 40, plates: 2)).intention)
    }

    func testSuppressionDraftsWordsOnly() {
        let close = EveningCloseEngine.close(input(protein: 40, floor: 90, suppressed: true))
        let intention = try! XCTUnwrap(close.intention)
        XCTAssertFalse(intention.text.contains(where: \.isNumber))
        XCTAssertTrue(intention.text.contains("protein first"))
    }

    // MARK: - The anchor (only when tomorrow holds something)

    func testADoseDayAnchorsTomorrow() {
        let close = EveningCloseEngine.close(input(doseDay: true))
        XCTAssertEqual(close.anchor, "tomorrow is your dose day.")
    }

    func testTheScaleCueNeedsAdoptionAndNumbers() {
        XCTAssertNotNil(EveningCloseEngine.close(
            input(weighDay: true, adopted: true)).anchor)
        XCTAssertNil(EveningCloseEngine.close(
            input(weighDay: true, adopted: false)).anchor,
            "an invitation to a habit she has shown, never an assignment")
        XCTAssertNil(EveningCloseEngine.close(
            input(suppressed: true, weighDay: true, adopted: true)).anchor)
    }

    func testDoseDayOutranksTheScaleCue() {
        let close = EveningCloseEngine.close(
            input(doseDay: true, weighDay: true, adopted: true))
        XCTAssertTrue(try! XCTUnwrap(close.anchor).contains("dose day"))
    }

    func testAnEmptyTomorrowSaysNothing() {
        XCTAssertNil(EveningCloseEngine.close(input()).anchor,
                     "a schedule label is not an anchor")
    }

    // MARK: - Voice rules across the table

    func testVoiceRulesHoldAcrossTheWholeTable() {
        let inputs: [EveningCloseEngine.Input] = [
            input(protein: 72, floor: 90, plates: 3),
            input(protein: 122, floor: 90, plates: 3),
            input(protein: 96, plates: 2),
            input(done: 2, total: 3),
            input(weighed: true),
            input(),
            input(protein: 72, floor: 90, suppressed: true),
            input(protein: 12, floor: 90, plates: 1, net: true),
        ]
        for i in inputs {
            let close = EveningCloseEngine.close(i)
            var texts = [close.hero.text]
            if let intention = close.intention { texts.append(intention.text) }
            if let anchor = close.anchor { texts.append(anchor) }
            for t in texts {
                XCTAssertEqual(t, t.lowercased(), "lowercase voice: \(t)")
                XCTAssertFalse(t.contains("—"), "no em-dash: \(t)")
                XCTAssertFalse(t.contains("!"), "no exclamation: \(t)")
                // Word-bounded: E8's own record warns `contains("0 g")`
                // fires on "4**0 g**" — and this suite promptly proved
                // it again on "3**0 g** of protein".
                XCTAssertNil(
                    t.range(of: #"(^|[^0-9])0 g"#, options: .regularExpression),
                    "never zero grams: \(t)"
                )
            }
        }
    }

    func testPunchWordsAppearInTheirLine() {
        let close = EveningCloseEngine.close(input(protein: 72, floor: 90))
        for punch in close.hero.punch {
            XCTAssertTrue(close.hero.text.contains(punch))
        }
        if let intention = close.intention {
            for punch in intention.punch {
                XCTAssertTrue(intention.text.contains(punch))
            }
        }
    }

    // MARK: - p54 · the sit-check acknowledgment (out of the view body)

    /// The three GI lines lived in `HomeEvening`'s body, where no test
    /// could reach them — and one of them was folklore ("cold and
    /// plain sits easier than warm and rich" is the pregnancy-nausea
    /// odor story; the 2025 advisory's guidance is smaller, plainer,
    /// lower-fat meals). Advice with a health claim lives in an
    /// engine, with its words pinned.
    func testSitAcknowledgmentsAreEvidenceShaped() {
        XCTAssertEqual(
            EveningCloseEngine.sitAck("heavy"),
            "noted. staying upright a while tends to help"
        )
        XCTAssertEqual(
            EveningCloseEngine.sitAck("queasy"),
            "noted. small, plain and low-fat tends to sit easier"
        )
        XCTAssertEqual(
            EveningCloseEngine.sitAck("backed up"),
            "noted. water tonight. fiber and a walk tomorrow"
        )
        XCTAssertEqual(EveningCloseEngine.sitAck("fine"), "noted")
    }

    /// The folklore stays dead, and no acknowledgment ever names a
    /// fluid volume (the E9 law) or grades the day.
    func testSitAcknowledgmentsCarryNoFolkloreOrVolume() {
        let banned = [
            "cold and plain", "warm and rich",
            "ml", "millilit", " oz", "ounce", "litre", "liter",
            "glasses", "cups", "should", "\u{2014}",
        ]
        for word in ["heavy", "queasy", "backed up", "fine", "light"] {
            let ack = EveningCloseEngine.sitAck(word)
            XCTAssertEqual(ack, ack.lowercased())
            for token in banned {
                XCTAssertFalse(
                    ack.contains(token),
                    "'\(token)' in sitAck(\(word)): \(ack)"
                )
            }
        }
    }

    // MARK: - p63 · the terminus receipt

    func testGoodnightCarriesHerNameInTheGreetingsOwnTransform() {
        let r = EveningCloseEngine.goodnight(name: " Maya ")
        XCTAssertEqual(r.line, "that's the day, maya.")
        XCTAssertEqual(r.italic, ["maya."])
        XCTAssertEqual(r.sub, "logged. tomorrow starts fresh.")
    }

    func testGoodnightWithoutANameStandsAlone() {
        for name in [nil, "", "   "] as [String?] {
            let r = EveningCloseEngine.goodnight(name: name)
            XCTAssertEqual(r.line, "that's the day.")
            XCTAssertEqual(r.italic, ["the day."])
            XCTAssertEqual(r.sub, "logged. tomorrow starts fresh.")
        }
    }

    func testGoodnightNeverShoutsAndStaysLowercase() {
        for name in [nil, "Maya", "MARY JO"] {
            let r = EveningCloseEngine.goodnight(name: name)
            XCTAssertFalse(r.line.contains("!"))
            XCTAssertFalse(r.sub.contains("!"))
            XCTAssertEqual(r.line, r.line.lowercased())
            XCTAssertTrue(r.line.contains(r.italic.first ?? ""),
                          "the punch must live inside the line")
        }
    }
}
