import XCTest
@testable import plankAI

// MARK: - MethodAdversarialTests (app v25 pass 54, §17 of the brief)
//
// Realistic histories, asked what jeni says — and above all, what she
// REFUSES to say. Each test is one of the brief's lettered histories;
// the ones not here are owned elsewhere and named in the pass record
// (H usuals → AnsweringFoodTests; I the late q10d shot → the regimen
// suite + MethodSpineTests' interval band tests; K/L the cycle signal
// → MethodSpineTests; M's surface lines → WeightWeekReadTests'
// forming-line pin).

final class MethodAdversarialTests: XCTestCase {

    /// The shared quiet base: an established record with nothing
    /// remarkable happening.
    private func base() -> MethodEngine.Input {
        var i = MethodEngine.Input()
        i.plateCountEver = 40
        i.proteinEatenTodayG = 70
        i.proteinFloorG = 90
        i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
        i.metProteinFloorBeforeToday = true
        i.loggedDayOffsets = Set(0..<7)
        i.weekendDayOffsets = [2, 3]
        i.programDay = 30
        i.hourOfDay = 10
        i.trendIsEstablished = true
        i.weighInCount = 12
        i.emaDelta7dKg = -0.2
        i.daysOfWeightHistory = 40
        i.latestWeightKg = 74.0
        i.previousWeightKg = 74.1
        i.strengthSessionsLast7 = 2
        i.steps7dMean = 7_000
        i.steps28dMean = 7_200
        return i
    }

    // MARK: - A vs B · the same jump, two different weeks

    /// A: +0.7 kg overnight, trend flat, 3,400 mg of sodium yesterday
    /// → the salty explanation, named as water.
    func testHistoryA_SaltyJumpAgainstAFlatTrendIsExplained() {
        var a = base()
        a.latestWeightKg = 74.7
        a.previousWeightKg = 74.0
        a.lastWeighInDaysAgo = 0
        a.emaDelta7dKg = 0.0
        a.yesterdaySodiumMg = 3_400
        let note = MethodEngine.note(a)
        XCTAssertEqual(note?.note.trigger, .saltyDinnerScaleBump)
        XCTAssertTrue(note?.line.lowercased().contains("water") ?? false)
    }

    /// B: the SAME jump against a trend that has genuinely been rising
    /// — every explanation note refuses (the water story would hide a
    /// real change), and nothing else is true, so jeni says NOTHING.
    /// A and B must never receive the same answer.
    func testHistoryB_TheSameJumpAgainstARisingTrendGetsNoReassurance() {
        var b = base()
        b.latestWeightKg = 74.7
        b.previousWeightKg = 74.0
        b.lastWeighInDaysAgo = 0
        b.emaDelta7dKg = 0.35            // rising for weeks
        b.yesterdaySodiumMg = 3_400
        b.cycleSeasonIsMenstrual = true  // even with a cycle signal
        XCTAssertNil(
            MethodEngine.note(b),
            "reassurance over a rising line is a lie of kindness — silence is the honest answer"
        )
    }

    // MARK: - C vs D · the same plates, two different bodies

    /// C: a GLP-1 user on the day after her dose, intake very low —
    /// the adequacy net is already speaking ("did you eat enough?").
    /// The Method must not stack a protein lecture on top of the care
    /// line: one hard day, one voice.
    func testHistoryC_TheAdequacyNetSilencesTheProteinTeachings() {
        var c = base()
        c.adequacyNetShowing = true
        c.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        c.morningLowProteinDays = 4
        c.typicalDayGapG = 30
        c.doseCycleDay = 2
        c.doseCycleLength = 7
        XCTAssertNil(
            MethodEngine.note(c),
            "two prompts about one hard day, one of them counting grams, is the pile-on"
        )
    }

    /// D: a non-medicated user with the same protein shape and no
    /// adequacy net — the pattern teaching is exactly what she should
    /// hear, and the two histories must not receive the same answer.
    func testHistoryD_TheSamePlatesWithoutTheNetEarnTheTeaching() {
        var d = base()
        d.adequacyNetShowing = false
        d.recentLoggedDayProteins = [40, 45, 50, 91, 94]
        d.morningLowProteinDays = 4
        d.typicalDayGapG = 30
        let note = MethodEngine.note(d)
        XCTAssertEqual(
            note?.note.trigger, .morningProteinGap,
            "the located gap outranks the counting note; both outrank silence here"
        )
    }

    // MARK: - E · one loud saturday, six ordinary days, trend falling

    /// The weekly read names the shape and attributes it to its days —
    /// and never says "over", never grades the saturday.
    func testHistoryE_ALoudSaturdayIsAShapeNeverAVerdict() {
        var i = WeeklyReadComposer.Inputs(
            windowStartDay: "2026-08-10",
            anchorKind: .enrollment,
            offer: .v4(.holdSteady(reason: "the plan holds."))
        )
        i.plateDays = 7
        i.plateCount = 15
        i.proteinDaysMet = 5
        i.weekendKcalDelta = 400
        i.weight = .init(
            band: "trending_down", sufficiency: "established",
            deltaText: "0.8 lb"
        )
        let model = WeeklyReadComposer.compose(i)
        XCTAssertTrue(model.observations.contains {
            $0.text.contains("weekends ran about 400 kcal above")
        })
        for line in model.observations.map(\.text) + [model.heroLine]
            + [model.teaching ?? ""] {
            XCTAssertFalse(line.contains(" over"), "verdict language: \(line)")
            XCTAssertFalse(line.lowercased().contains("too much"), line)
        }
    }

    // MARK: - F vs G · the same plateau, two different records

    /// F: 21 flat days over SPARSE logging — a flat line with an empty
    /// record is an unlogged stretch, and calling it a plateau would
    /// teach her something false about her own body.
    func testHistoryF_ASparsePlateauIsNotCalledOne() {
        var f = base()
        f.flatWeeks = 3
        f.loggedDayOffsets = [0, 5]      // two logged days in two weeks
        f.recentLoggedDayProteins = [91, 94]
        XCTAssertNil(MethodEngine.note(f))
    }

    /// G: the same 21 flat days over a dense, internally consistent
    /// record — the honest plateau note, whose action is the
    /// guideline's own response (a tighter week of records), not a
    /// harder diet and not a metabolism story.
    func testHistoryG_ADensePlateauEarnsTheHonestNote() {
        var g = base()
        g.flatWeeks = 3
        let note = MethodEngine.note(g)
        XCTAssertEqual(note?.note.trigger, .trendFlatWhileLogging)
        XCTAssertEqual(note?.note.action?.label, "keep the record tight this week")
        XCTAssertFalse(
            note?.note.because.contains("settles at a new weight") ?? true,
            "the adaptation story left the catalog; it must not return"
        )
    }

    // MARK: - J · strength recorded by hand, no watch

    /// A hand-recorded session counts everywhere: the resistance note
    /// must stand down for a user whose only strength evidence is her
    /// own entry (the builder already sums MoveManualStore into
    /// `strengthSessionsLast7`; this pins the engine's side).
    func testHistoryJ_HandRecordedStrengthStandsTheResistanceNoteDown() {
        var j = base()
        j.emaDelta7dKg = -0.6            // losing at a real rate
        j.strengthSessionsLast7 = 1      // one session — hers, by hand
        XCTAssertNotEqual(
            MethodEngine.note(j)?.note.trigger, .losingWithoutResistanceWork,
            "a user who recorded strength must never be told nothing is asking her muscles to stay"
        )
        j.strengthSessionsLast7 = 0
        XCTAssertEqual(
            MethodEngine.note(j)?.note.trigger, .losingWithoutResistanceWork,
            "control: with genuinely nothing on file the pairing note is the right teaching"
        )
    }

    // MARK: - M · almost no data

    /// The brief's most important history: jeni must know how to say
    /// I DON'T KNOW YET. An empty record produces no note, and a
    /// two-weigh-in record produces the forming line, never a
    /// direction (pinned in WeightWeekReadTests).
    func testHistoryM_AnEmptyRecordProducesNothingAtAll() {
        XCTAssertNil(MethodEngine.note(MethodEngine.Input()))
        XCTAssertTrue(MethodEngine.activeTriggers(MethodEngine.Input()).isEmpty)
    }
}
