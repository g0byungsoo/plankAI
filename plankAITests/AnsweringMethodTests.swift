import XCTest
@testable import plankAI

// MARK: - AnsweringMethodTests (app v25 pass 53)
//
// The Method becomes an instrument that measures itself and earns
// its claims: the evidence spine (every external claim carries a
// typed tier; "weak" cannot be typed, so it cannot ship), the
// one-note-per-day law finally enforced (re-opening the door
// re-renders the day's note instead of falling through the cooldown
// to a second one), note 14's documented adequacy-net QUIET made
// real, and two new notes earned from records the product already
// keeps (the breakfast gap; the salty-day scale bump).
//
// RED before GREEN against honest-BEFORE stubs.

@MainActor
final class AnsweringMethodTests: XCTestCase {

    // MARK: the adequacy net outranks the fluids note (E2's law, enforced)

    func testAQueasyNoteStandsDownWhenTheAdequacyNetIsSpeaking() {
        var i = MethodEngine.Input()
        i.recentQueasySymptomWord = "queasy"
        i.adequacyNetShowing = true
        let note = MethodEngine.note(i)
        XCTAssertNotEqual(
            note?.note.trigger, .fluidsOnAQueasyDay,
            "two prompts about one hard day, one of them counting, is the pile-on the net exists to prevent — its own catalog line promised this QUIET"
        )
    }

    func testAQueasyNoteStillFiresWhenTheNetIsQuiet() {
        // Control: the guard must not over-silence.
        var i = MethodEngine.Input()
        i.recentQueasySymptomWord = "queasy"
        i.adequacyNetShowing = false
        XCTAssertEqual(MethodEngine.note(i)?.note.trigger, .fluidsOnAQueasyDay)
    }

    // MARK: the day's note is the day's note

    func testReopeningTheDoorRerendersTodaysNote() {
        var i = MethodEngine.Input()
        i.recentQueasySymptomWord = "queasy"
        i.daysSinceLastOpen = 5   // returnedAfterGap is ALSO true
        let first = MethodEngine.note(i)
        XCTAssertNotNil(first)
        // She saw it; the ledger stamped today.
        i.shownDaysAgoById[first!.note.id] = 0
        i.shownTodayNoteId = first!.note.id
        let second = MethodEngine.note(i)
        XCTAssertEqual(
            second?.note.id, first?.note.id,
            "one note per day means the SAME note all day — not a second teaching every time the door opens"
        )
    }

    func testTomorrowMovesOnPastYesterdaysNote() {
        // Control: yesterday's note cooling down must not pin forever.
        var i = MethodEngine.Input()
        i.recentQueasySymptomWord = "queasy"
        i.daysSinceLastOpen = 5
        let first = MethodEngine.note(i)
        i.shownDaysAgoById[first!.note.id] = 1   // shown YESTERDAY
        i.shownTodayNoteId = nil
        let next = MethodEngine.note(i)
        XCTAssertNotNil(next)
        XCTAssertNotEqual(next?.note.id, first?.note.id)
    }

    // MARK: the evidence spine, machine-checked

    func testEveryExternalClaimCarriesItsTier() {
        for note in MethodCatalog.notes {
            if note.evidence != nil {
                XCTAssertNotEqual(
                    note.evidenceTier, .arithmetic,
                    "\(note.id) cites a finding — it must carry a strong or reasonable-practice tier"
                )
            } else {
                XCTAssertEqual(
                    note.evidenceTier, .arithmetic,
                    "\(note.id) makes no external claim — a tier without an attribution line is authority cosplay"
                )
            }
        }
    }

    func testTieredNotesAttributeInWords() {
        // A reasonable-practice tier must point at WHO says so —
        // guidance, label, trial, review — in the evidence line
        // itself, so the sentence a person reads carries the source.
        let sourceWords = [
            "guidance", "guideline", "guides", "trial", "review",
            "label", "study", "studies",
        ]
        for note in MethodCatalog.notes where note.evidenceTier != .arithmetic {
            let line = (note.evidence ?? "").lowercased()
            XCTAssertTrue(
                sourceWords.contains(where: line.contains),
                "\(note.id)'s evidence line names no source: \(line)"
            )
        }
    }

    // MARK: the breakfast gap — earned from her own logged days

    func testTheMorningGapNoteSpeaksHerOwnNumbers() {
        var i = MethodEngine.Input()
        i.proteinFloorG = 85
        i.morningLowProteinDays = 4
        i.typicalDayGapG = 22
        i.hourOfDay = 9
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .morningProteinGap)
        XCTAssertTrue(
            note?.line.contains("22") ?? false,
            "the gap is HER number, from her own missed days"
        )
    }

    func testTheMorningGapNoteRespectsItsQuiet() {
        var i = MethodEngine.Input()
        i.proteinFloorG = 85
        i.morningLowProteinDays = 4
        i.typicalDayGapG = 22
        // Never in the evening (nothing actionable about breakfast at
        // 9pm), never over the adequacy net, never under 3 pattern days.
        i.hourOfDay = 20
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .morningProteinGap)
        i.hourOfDay = 9
        i.adequacyNetShowing = true
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .morningProteinGap)
        i.adequacyNetShowing = false
        i.morningLowProteinDays = 2
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .morningProteinGap)
    }

    // MARK: the salty-day bump — water named before it reads as failure

    func testTheSaltyBumpNoteNamesWaterNotFat() {
        var i = MethodEngine.Input()
        i.yesterdaySodiumMg = 3400
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        i.trendIsEstablished = true
        i.weighInCount = 12
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .saltyDinnerScaleBump)
        XCTAssertTrue(note?.line.lowercased().contains("water") ?? false)
    }

    func testTheSaltyBumpStaysQuietWithoutItsFacts() {
        var i = MethodEngine.Input()
        i.latestWeightKg = 78.6
        i.previousWeightKg = 78.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = -0.1
        i.trendIsEstablished = true
        // No sodium on file → the note has no fact to stand on; a
        // guess about her dinner would be an invented provenance.
        i.yesterdaySodiumMg = nil
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .saltyDinnerScaleBump)
        // Yesterday's weigh-in is not this morning's bump.
        i.yesterdaySodiumMg = 3400
        i.lastWeighInDaysAgo = 1
        XCTAssertNotEqual(MethodEngine.note(i)?.note.trigger, .saltyDinnerScaleBump)
    }
}
