import XCTest
@testable import PlankFood

// MARK: - FirstRecordGateTests (pass 52 — THE FIRST DAY)
//
// The door-aware gate laws, as executable tests. Pass 50 filmed the
// BEFORE state: a typed first meal hit the consent gate and the gate
// exited to the CAMERA — the sentence survived only as a hidden
// prefill, and the OS camera dialog fired over a meal that never
// needed a lens. These tests pin the laws that make that impossible:
//
//   1. AN ENTRANCE NEVER MUTATES INTO ANOTHER ENTRANCE. The gates
//      exit to the door she chose.
//   2. CONSENT SPEAKS THE DOOR'S LANGUAGE. A typed sentence is never
//      consented under photo-only copy.
//   3. NOTHING OPTIONAL STANDS BEFORE RECORD #1. The three soft
//      questions offer themselves after the first reading files.
final class FirstRecordGateTests: XCTestCase {

    // MARK: 1 · the landing follows the door

    func testAWordsEntryLandsOnWordsAfterEveryGate() {
        XCTAssertEqual(
            CaptureGateFlow.landing(entry: .words, prefill: nil), .words,
            "the words door must exit the gates onto the words path — the BEFORE build dropped her into the camera"
        )
    }

    func testAHandedInSentenceLandsOnWordsEvenThroughTheCameraEntry() {
        // jeni's prefill is the user's own words by contract; a flow
        // opened with them must never land on the lens.
        XCTAssertEqual(
            CaptureGateFlow.landing(entry: .camera, prefill: "a chicken burrito"),
            .words
        )
    }

    func testTheCameraDoorStillLandsOnTheCamera() {
        // Control: door-awareness must not break the photo path.
        XCTAssertEqual(CaptureGateFlow.landing(entry: .camera, prefill: nil), .camera)
        XCTAssertEqual(CaptureGateFlow.landing(entry: .camera, prefill: "   "), .camera)
    }

    // MARK: 2 · consent is the only pre-record gate, and it exits home

    func testConsentIsTheOnlyGateBeforeARecord() {
        XCTAssertEqual(CaptureGateFlow.firstPhase(consented: false), .consent)
        XCTAssertEqual(
            CaptureGateFlow.firstPhase(consented: true), .landing,
            "a consented user goes straight to her door — the questions may not stand here"
        )
    }

    func testTheQuestionsOfferThemselvesOnlyAfterTheFirstKeptPlate() {
        XCTAssertTrue(CaptureGateFlow.offersQuestionsAfterLog(questionsDone: false))
        XCTAssertFalse(
            CaptureGateFlow.offersQuestionsAfterLog(questionsDone: true),
            "the offer is made once, ever"
        )
    }

    // MARK: 3 · door-aware consent copy

    func testTheWordsDoorConsentSpeaksAboutWordsFirst() {
        let facts = FoodAIConsentCopy.facts(for: .words)
        XCTAssertTrue(
            facts.first?.contains("sentence") == true
                || facts.first?.contains("words") == true,
            "the words door's disclosure must lead with her words, not the photo"
        )
        XCTAssertTrue(
            FoodAIConsentCopy.factsLabel(for: .words).contains("words"),
            "the facts label names what is actually leaving the phone"
        )
    }

    func testTheWordsDoorConsentStillDisclosesTheFuturePhotoTrip() {
        // One acceptance covers the feature, so the words variant must
        // still name the photo's trip — otherwise her first camera use
        // would ride a consent that never mentioned photographs.
        XCTAssertTrue(
            FoodAIConsentCopy.facts(for: .words).contains { $0.contains("photo") }
        )
    }

    func testThePhotoDoorConsentIsByteIdenticalToTheShippedSheet() {
        // Control: the reviewed 5.1.2(i) copy must not drift.
        XCTAssertEqual(FoodAIConsentCopy.facts(for: .photo), [
            "it goes to OpenAI's vision model",
            "they don't train on it",
            "it's deleted after analysis, unless you opt to keep it",
        ])
        XCTAssertEqual(FoodAIConsentCopy.header(for: .photo).text, "how jeni reads a plate")
        XCTAssertEqual(FoodAIConsentCopy.factsLabel(for: .photo), "what happens to the photo")
    }

    func testTheDrawnTeachingsBelongToThePhotoDoorOnly() {
        XCTAssertTrue(FoodAIConsentCopy.showsTeachings(for: .photo))
        XCTAssertFalse(
            FoodAIConsentCopy.showsTeachings(for: .words),
            "framing advice over a typed sentence is the category error, drawn"
        )
    }

    func testConsentCopyKeepsTheVoiceLaws() {
        for door: FoodAIConsentCopy.Door in [.photo, .words] {
            let all = FoodAIConsentCopy.facts(for: door)
                + [FoodAIConsentCopy.subline(for: door),
                   FoodAIConsentCopy.header(for: door).text,
                   FoodAIConsentCopy.factsLabel(for: door)]
            for line in all {
                XCTAssertFalse(line.contains("\u{2014}"), "em-dash banned: \(line)")
                XCTAssertFalse(line.contains(" AI "), "the product never says AI: \(line)")
                XCTAssertEqual(line, line.lowercased()
                    .replacingOccurrences(of: "openai", with: "OpenAI"),
                    "lowercase voice (proper nouns excepted): \(line)")
            }
        }
    }
}
