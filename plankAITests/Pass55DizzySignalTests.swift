import XCTest
@testable import plankAI

// MARK: - Pass55DizzySignalTests (pass 55 §4B)
//
// The one evidence-earned hydration addition. The labels for this
// medication class carry the same post-marketing warning: acute
// kidney injury, mostly in people whose nausea/vomiting/diarrhea led
// to volume depletion — and the drugs quiet thirst itself (Winzeler
// 2021), so the signal a person would normally rely on is the signal
// being suppressed. Lightheadedness in the same stretch as a rough
// stomach is the pairing the labels ask a prescriber to hear about.
// Jeni ROUTES it — no volume, no diagnosis, observed-never-prescribed.

final class Pass55DizzySignalTests: XCTestCase {

    private func base() -> MethodEngine.Input {
        var i = MethodEngine.Input()
        i.plateCountEver = 40
        i.proteinEatenTodayG = 70
        i.proteinFloorG = 90
        i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
        i.metProteinFloorBeforeToday = true
        i.loggedDayOffsets = Set(0..<7)
        i.programDay = 30
        i.hourOfDay = 10
        i.trendIsEstablished = true
        i.weighInCount = 12
        i.daysOfWeightHistory = 40
        i.emaDelta7dKg = -0.2
        i.latestWeightKg = 74.0
        i.previousWeightKg = 74.1
        i.strengthSessionsLast7 = 2
        return i
    }

    func testDizzyBesideARoughStomachRoutesToThePrescriber() {
        var i = base()
        i.recentDizzyLogged = true
        i.recentQueasySymptomWord = "loose stomach"
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .dizzyOnAFluidLossDay)
        XCTAssertEqual(note?.note.evidenceTier, .strong,
                       "the claim is the label's own — regulatory tier")
        XCTAssertTrue(
            note?.line.contains("loose stomach") ?? false,
            "the note names HER logged symptom back: \(note?.line ?? "nil")"
        )
        XCTAssertTrue(
            note?.line.lowercased().contains("prescriber") ?? false,
            "the whole point is the routing: \(note?.line ?? "nil")"
        )
        // No volume, ever — the standing law covers the new note too.
        for text in [note?.line ?? "", note?.note.because ?? ""] {
            XCTAssertFalse(text.contains(" ml"), text)
            XCTAssertFalse(text.contains(" liter"), text)
            XCTAssertFalse(text.contains(" oz"), text)
            XCTAssertFalse(text.lowercased().contains("glasses"), text)
        }
    }

    func testDizzyAloneIsNotAFluidLossSignal() {
        var i = base()
        i.recentDizzyLogged = true
        XCTAssertNil(
            MethodEngine.note(i),
            "lightheaded without the GI half has too many ordinary causes; silence"
        )
    }

    func testARoughStomachAloneKeepsTheFluidsTeaching() {
        var i = base()
        i.recentQueasySymptomWord = "queasy"
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .fluidsOnAQueasyDay,
            "control: the p54 teaching is unchanged when nothing routes"
        )
    }

    /// The adequacy net silences TEACHINGS (one voice on a hard day).
    /// A routing note is not a teaching: the label's warning outranks
    /// the one-voice law.
    func testTheRoutingNoteSpeaksEvenOverTheAdequacyNet() {
        var i = base()
        i.recentDizzyLogged = true
        i.recentQueasySymptomWord = "queasy"
        i.adequacyNetShowing = true
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .dizzyOnAFluidLossDay
        )
    }
}
