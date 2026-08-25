import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - OutcomeRestoreTests (app v25 pass 58)
//
// THE CORRECTION OF A TWO-PASS ERROR. p37 recorded the outcome answer
// ("what do you want to change most?" — myself / noise / energy /
// clothes / keep) as having no server column, and p57 §40 inherited
// that into a founder-gated migration ask. Both were wrong: the
// answer has ridden `users.onboarding_motivation` since the v5
// assembler (`data.motivation = outcome` → `record.onboardingMotivation`
// → the upsert), and `hydrateUser` adopts it back present-only. The
// server held her most personal answer the whole time; the client
// simply never mirrored it back to the `onb_v5_outcome` key that the
// coach envelope's `came_for` reads. So on a reinstall the coach
// forgot why she came — for want of ONE restore line, not a migration.
//
// RED: testTheOutcomeAnswerSurvivesTheAccountTransition failed
// against the shipped `restoreCohortDefaults` (the key stayed swept);
// the two refusal controls passed before and after, because they pin
// behavior the merge closure already enforces for its siblings.

@MainActor
final class OutcomeRestoreTests: XCTestCase {

    private let d = UserDefaults.standard
    private var savedOutcome: String?

    override func setUp() {
        super.setUp()
        savedOutcome = d.string(forKey: "onb_v5_outcome")
    }

    override func tearDown() {
        if let savedOutcome { d.set(savedOutcome, forKey: "onb_v5_outcome") }
        else { d.removeObject(forKey: "onb_v5_outcome") }
        super.tearDown()
    }

    private func serverRecord(motivation: String, pending: Bool = false) -> UserRecord {
        let record = UserRecord(id: "p58-outcome", name: "restored")
        record.onboardingMotivation = motivation
        record.pendingUpsert = pending
        return record
    }

    func testTheOutcomeAnswerSurvivesTheAccountTransition() {
        // She told the consult she came to quiet the food noise; the
        // sweep (sign-out, correctly) removes the whole onb_v5_ family.
        d.set("noise", forKey: "onb_v5_outcome")
        AppSync.shared.clearOnboardingUserDefaults()
        XCTAssertNil(
            d.string(forKey: "onb_v5_outcome"),
            "control: the sweep removes the key (cross-account isolation)"
        )

        // The server row has carried it as onboarding_motivation since
        // the v5 assembler. The restore must bring it home.
        AppSync.restoreCohortDefaults(from: serverRecord(motivation: "noise"), into: d)

        XCTAssertEqual(
            d.string(forKey: "onb_v5_outcome"), "noise",
            "came_for must survive reinstall — the coach speaks in the words she gave on day 0"
        )
    }

    // Refusal control (passes before and after): an unsent local edit
    // is not server truth and is never mirrored over a held answer.
    func testAPendingRecordNeverOverwritesAHeldAnswer() {
        d.set("energy", forKey: "onb_v5_outcome")
        AppSync.restoreCohortDefaults(
            from: serverRecord(motivation: "keep", pending: true), into: d
        )
        XCTAssertEqual(d.string(forKey: "onb_v5_outcome"), "energy")
    }

    // Refusal control (passes before and after): an absent server
    // value never deletes a fact the device holds.
    func testAnEmptyServerValueNeverBlanksAHeldAnswer() {
        d.set("clothes", forKey: "onb_v5_outcome")
        AppSync.restoreCohortDefaults(from: serverRecord(motivation: ""), into: d)
        XCTAssertEqual(d.string(forKey: "onb_v5_outcome"), "clothes")
    }
}
