import XCTest
import PlankFood
@testable import plankAI

// MARK: - FoodSourceContractTests (v25 E8.1)
//
// E8 shipped analytics that could finally tell the food doors apart and
// left the RECORD lying: words, label and photo all persisted as
// `photo`, because one decoder served three inputs. E8.1 collapsed
// `CaptureSource` into `EntryMethod` so the column, the event and the
// plate speak one vocabulary, and migration 20260811120000 widened the
// CHECK to accept it.
//
// These pin the two places the app — not the package — can break it: the
// upsert value and the sentence the plate page says out loud.

final class FoodSourceContractTests: XCTestCase {

    // MARK: - the sentence a plate says about itself

    /// The defect: `entry.source == "photo" ? "read from your photo" :
    /// "logged from your words"` was wrong in BOTH directions once three
    /// doors shared one value. A typed plate claimed a photograph; a
    /// barcode claimed her words.
    func testTypedPlateNeverClaimsAPhotograph() {
        let line = PlateDetailSheet.provenanceLine(for: EntryMethod.words.rawValue)
        XCTAssertTrue(line.contains("your words"), line)
        XCTAssertFalse(line.contains("photo"), "a typed plate must not mention a photo")
    }

    func testPhotographedPlateSaysPhoto() {
        let line = PlateDetailSheet.provenanceLine(for: EntryMethod.photo.rawValue)
        XCTAssertTrue(line.contains("your photo"), line)
        XCTAssertFalse(line.contains("your words"))
    }

    /// Printed truth must not apologise for being an estimate. A
    /// nutrition panel and a barcode are transcriptions of the package's
    /// own numbers; hedging them taught people to distrust the most
    /// accurate reading in the app.
    func testPrintedTruthIsNotCalledAnEstimate() {
        for door in [EntryMethod.label, .barcode] {
            let line = PlateDetailSheet.provenanceLine(for: door.rawValue)
            XCTAssertFalse(
                line.contains("ranges, not exact"),
                "\(door.rawValue) is printed truth, not an estimate: \(line)"
            )
            XCTAssertTrue(line.contains("label"), line)
        }
    }

    func testRelogNeverPromisesAPhotoItDidNotKeep() {
        // `relog` deliberately drops the thumbnail ("the old thumbnail
        // belongs to the old moment"), so the line must not offer one.
        let line = PlateDetailSheet.provenanceLine(for: EntryMethod.again.rawValue)
        XCTAssertFalse(line.contains("photo"), line)
        XCTAssertTrue(line.contains("record"), line)
    }

    /// Every door renders SOMETHING, in the product's register: lowercase,
    /// no em-dash between words, no verdict.
    func testEveryDoorRendersALowercaseLine() {
        for door in EntryMethod.allCases {
            let line = PlateDetailSheet.provenanceLine(for: door.rawValue)
            XCTAssertFalse(line.isEmpty, "\(door.rawValue) renders nothing")
            XCTAssertEqual(line, line.lowercased(), "\(door.rawValue): \(line)")
            XCTAssertFalse(line.contains("\u{2014}"), "em-dash in \(line)")
            XCTAssertFalse(line.contains(" - "), "hyphen-as-dash in \(line)")
        }
    }

    /// Rows with no source at all (pre-D3.B) and the legacy values no
    /// build ever wrote must still say the one thing true of all of them,
    /// rather than falling through to a photograph.
    func testUnattributedAndLegacyRowsGetTheNeutralLine() {
        for stored in [nil, "", "im_out", "voice", "menu", "text", "relog"] as [String?] {
            let line = PlateDetailSheet.provenanceLine(for: stored)
            XCTAssertEqual(line, "ranges, not exact", "\(stored ?? "nil") → \(line)")
        }
    }

    // MARK: - the vocabulary is genuinely one vocabulary

    /// The whole point of E8.1. If these two sets ever diverge, the
    /// record and the telemetry are answering the same question with
    /// different words again, which is the bug E8 spent an era routing
    /// around.
    func testTheAnalyticsVocabularyIsTheRecordVocabulary() {
        XCTAssertEqual(
            AnalyticsHygiene.entryMethodWords,
            Set(EntryMethod.allCases.map(\.rawValue))
        )
    }

    /// The three values that were already in `food_logs.source` before
    /// this migration keep their exact spelling. A rename would orphan
    /// every historical row and silently break any insight filtering on
    /// them (E8 §3.1: split a value, never rename one).
    func testNoShippedValueWasRenamed() {
        let alreadyInTheColumn = ["photo", "restaurant_estimate", "quick_add"]
        let vocabulary = Set(EntryMethod.allCases.map(\.rawValue))
        for value in alreadyInTheColumn {
            XCTAssertTrue(
                vocabulary.contains(value),
                "\(value) is in production rows and must stay spellable"
            )
        }
    }
}
