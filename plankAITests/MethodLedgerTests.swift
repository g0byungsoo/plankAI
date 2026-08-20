import XCTest
@testable import plankAI

// MARK: - MethodLedgerTests (app v25 pass 54)
//
// The ledger is the Method's memory, and until this pass it had no
// tests at all — which is how three defects lived in 220 lines:
//
//   · a care-team note did not pin the day, so Jeni's default for the
//     SAME trigger could fire as a second telling the same afternoon —
//     the exact double voice the authority contract forbids
//   · "the latest telling" was read off the wrong end of a
//     newest-first array (Home's tile line inherited the inversion)
//   · the ledger survived the account sweep, so the next person on
//     this device inherited what Jeni told someone else — and the
//     trigger names alone (constipation, the salty scale, a dose
//     week's end) are health-state descriptors
//
// RED before GREEN against the shipped ledger.

@MainActor
final class MethodLedgerTests: XCTestCase {

    private var preserved: Data?

    override func setUp() {
        super.setUp()
        preserved = UserDefaults.standard.data(forKey: MethodLedger.storageKey)
        UserDefaults.standard.removeObject(forKey: MethodLedger.storageKey)
    }

    override func tearDown() {
        if let preserved {
            UserDefaults.standard.set(preserved, forKey: MethodLedger.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: MethodLedger.storageKey)
        }
        super.tearDown()
    }

    // MARK: - fixtures

    private func jeniNote(id: String = "protein_per_meal_v1") -> ResolvedMethodNote {
        let note = MethodCatalog.notes.first { $0.id == id }!
        return ResolvedMethodNote(note: note, line: "3 of 5 days under 90 g.", italic: [])
    }

    private func clinicNote() -> ResolvedMethodNote {
        let note = MethodNote(
            id: "clinic_protein_x",
            trigger: .proteinUnderFloorRepeatedly,
            noticed: "under your floor most days, per our plan.",
            because: "we set that together.",
            action: .init(label: "add protein", door: .describePlate),
            followUp: .proteinFloorMetToday,
            suppressedForm: "under your floor most days.",
            authority: .careTeam(attribution: "dr. okafor")
        )
        return ResolvedMethodNote(note: note, line: note.noticed, italic: [])
    }

    /// Write an entry with an arbitrary timestamp, bypassing
    /// `markShown`'s stamp-now behavior — the fixture for "yesterday".
    private func insertEntry(
        noteId: String, shownAt: Date, fromCareTeam: Bool = false
    ) {
        var rows = MethodLedger.entries()
        rows.insert(
            MethodLedger.Entry(
                noteId: noteId,
                trigger: MethodTrigger.proteinUnderFloorRepeatedly.rawValue,
                noteVersion: 1,
                catalogVersion: MethodCatalog.version,
                shownAt: shownAt,
                followUp: MethodNote.FollowUp.none.rawValue,
                fromCareTeam: fromCareTeam
            ),
            at: 0
        )
        let data = try! JSONEncoder().encode(rows)
        UserDefaults.standard.set(data, forKey: MethodLedger.storageKey)
    }

    // MARK: - the day pin

    /// A clinic note shown this morning IS the day's note. Without
    /// the pin, the same trigger re-resolves on the next open, the
    /// clinic note is inside its own cooldown, and Jeni's default
    /// fires as a second telling — two voices on one observation in
    /// one day, the thing the authority rules exist to prevent.
    func testAClinicNotePinsTheDayItWasShown() {
        MethodLedger.markShown(clinicNote())
        XCTAssertEqual(
            MethodLedger.shownTodayNoteId(), "clinic_protein_x",
            "a clinician's telling pins the day exactly as jeni's does"
        )
    }

    func testAJeniNotePinsTheDayItWasShown() {
        MethodLedger.markShown(jeniNote())
        XCTAssertEqual(MethodLedger.shownTodayNoteId(), "protein_per_meal_v1")
    }

    func testYesterdaysTellingDoesNotPinToday() {
        insertEntry(
            noteId: "protein_per_meal_v1",
            shownAt: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        )
        XCTAssertNil(MethodLedger.shownTodayNoteId())
    }

    // MARK: - the latest telling

    /// `entries()` is newest-first; "the latest telling" is the FIRST
    /// element. Home's tile line read `.last` — the oldest entry ever
    /// recorded — so "a note from your record" degraded permanently
    /// on day two.
    func testTheLatestTellingIsTheNewestEntry() {
        insertEntry(
            noteId: "old_note",
            shownAt: Calendar.current.date(byAdding: .day, value: -9, to: .now)!
        )
        MethodLedger.markShown(jeniNote())
        XCTAssertEqual(
            MethodLedger.latestEntry()?.noteId, "protein_per_meal_v1",
            "the latest telling is the newest entry, not the oldest survivor"
        )
    }

    // MARK: - idempotency (the shipped law, pinned at last)

    func testMarkShownIsIdempotentPerDay() {
        MethodLedger.markShown(jeniNote())
        MethodLedger.markShown(jeniNote())
        XCTAssertEqual(
            MethodLedger.entries().filter { $0.noteId == "protein_per_meal_v1" }.count,
            1,
            "a backgrounded relaunch must not read as two separate tellings"
        )
    }

    // MARK: - the sweep

    /// What Jeni told HER must not reach the next account on this
    /// device — the same sentence that put `move.manual.v1` (§38) and
    /// `day.intention.` (§44) into the sweep. The browse surface
    /// renders straight from this ledger, so before this pass account
    /// B's settings listed what account A was told, with trigger
    /// names that describe symptoms and scale events.
    func testTheSweepForgetsWhatJeniToldHer() {
        MethodLedger.markShown(jeniNote())
        XCTAssertNotNil(UserDefaults.standard.data(forKey: MethodLedger.storageKey))

        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertNil(
            UserDefaults.standard.data(forKey: MethodLedger.storageKey),
            "the note ledger is a record of what a system said to ONE person; it goes when her session does"
        )
    }
}
