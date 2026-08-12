import XCTest
@testable import PlankFood

// MARK: - EntryMethodTests (v25 E8 — THE MERGE · E8.1 — THE TRUTH)
//
// The defect these pin: `CapturedFood.source` used to be decided by a
// decoder shared between three inputs, stamping `.photo` for a
// photograph, a nutrition-label photograph AND a typed sentence. E7
// shipped "the door is words" and planned to falsify itself on a
// words-vs-photo split the data could not express.
//
// E8 fixed the telemetry with a parallel `entryMethod` field. E8.1
// collapsed the two — one vocabulary in the row, the event and the enum
// — because two names for one idea is the bug, not the fix.
//
// EntryMethod is derived from the INPUT case, the last place the doors
// are still distinguishable.

final class EntryMethodTests: XCTestCase {

    // MARK: - the mapping

    func testEveryInputMapsToItsOwnMethod() {
        XCTAssertEqual(EntryMethod(.photo(Data())), .photo)
        XCTAssertEqual(EntryMethod(.labelPhoto(Data())), .label)
        XCTAssertEqual(EntryMethod(.text("two eggs", cuisineProfile: nil)), .words)
        XCTAssertEqual(EntryMethod(.quickAdd(PantryItemID("x"))), .pantry)
        XCTAssertEqual(EntryMethod(.imOutTonight(cuisine: .italian)), .restaurant)
    }

    /// THE ROW THAT MATTERS. These three used to be one value; if they
    /// ever collapse again, E7 becomes unfalsifiable and nothing else in
    /// the codebase would notice.
    func testWordsLabelAndPhotoAreDistinguishable() {
        let words = EntryMethod(.text("a burrito", cuisineProfile: nil))
        let label = EntryMethod(.labelPhoto(Data()))
        let photo = EntryMethod(.photo(Data()))
        XCTAssertEqual(Set([words, label, photo]).count, 3)
        XCTAssertEqual(words.rawValue, "words")
        XCTAssertEqual(label.rawValue, "label")
        XCTAssertEqual(photo.rawValue, "photo")
    }

    func testTextInputIsWordsRegardlessOfCuisineProfile() {
        XCTAssertEqual(
            EntryMethod(.text("pad thai", cuisineProfile: "thai")), .words
        )
        XCTAssertEqual(
            EntryMethod(.text("pad thai", cuisineProfile: nil)), .words
        )
    }

    // MARK: - the default

    func testCapturedFoodDefaultsToUnknownNotPhoto() {
        // An unattributed construction site must be VISIBLE in the data,
        // not silently folded into the largest real category. The
        // decoders rely on this: FoodVisionService omits `source`
        // entirely and the dispatcher stamps it.
        let food = CapturedFood(
            items: [], plateType: .single,
            confidence: nil, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        XCTAssertEqual(food.source, .unknown)
    }

    // MARK: - barcode stamps itself

    func testBarcodeIsNotReachableFromTheInputEnum() {
        // Barcode reads live off the video output and never pass through
        // FoodCaptureDispatcher, so barcode has no FoodCapture case and
        // must stamp itself (BarcodeRead). This test exists to make that
        // asymmetry deliberate rather than forgotten.
        XCTAssertTrue(EntryMethod.allCases.contains(.barcode))
    }

    // MARK: - hygiene

    func testAllMethodsAreCategoricalTokens() {
        for m in EntryMethod.allCases {
            XCTAssertEqual(m.rawValue, m.rawValue.lowercased())
            XCTAssertFalse(m.rawValue.contains(" "), "\(m) has a space")
            XCTAssertFalse(m.rawValue.isEmpty)
            XCTAssertTrue(m.rawValue.count <= 40)
        }
    }

    func testMethodsAreDistinct() {
        XCTAssertEqual(
            Set(EntryMethod.allCases.map(\.rawValue)).count,
            EntryMethod.allCases.count
        )
    }

    // MARK: - the database contract

    /// THE CONSTRAINT PIN. Every raw value must appear in the CHECK list
    /// of migration `20260811120000_food_source_truth`, or a real user's
    /// log silently fails to sync with a 23514 the client never surfaces.
    /// Duplicated here on purpose: the test must fail when someone adds
    /// a case, and reading the .sql file from a unit test would make the
    /// package depend on the repo layout.
    func testEveryMethodIsAcceptedByTheSourceCheckConstraint() {
        let checkList: Set<String> = [
            // canonical doors
            "photo", "label", "words", "barcode", "again",
            "restaurant_estimate", "quick_add", "unknown",
            // legacy, tolerated for historical rows, never written again
            "im_out", "voice", "menu", "text",
        ]
        for m in EntryMethod.allCases {
            XCTAssertTrue(
                checkList.contains(m.rawValue),
                """
                EntryMethod.\(m) persists as "\(m.rawValue)", which the \
                food_logs_source_door_check constraint would reject. Add a \
                migration widening the CHECK before shipping this case.
                """
            )
        }
    }

    /// The two doors whose spelling is inherited rather than chosen. A
    /// "nicer" rename here would orphan every row already in the column.
    func testHistoricalSpellingsArePreserved() {
        XCTAssertEqual(EntryMethod.restaurant.rawValue, "restaurant_estimate")
        XCTAssertEqual(EntryMethod.pantry.rawValue, "quick_add")
    }

    func testPrintedTruthIsExactlyLabelAndBarcode() {
        let printed = EntryMethod.allCases.filter(\.isPrintedTruth)
        XCTAssertEqual(Set(printed), Set([.label, .barcode]))
    }

    // MARK: - what gets upserted

    func testEveryDoorSurvivesTheUpsertUnchanged() {
        for m in EntryMethod.allCases {
            XCTAssertEqual(
                EntryMethod.persistedSourceValue(for: m.rawValue), m.rawValue
            )
        }
    }

    /// The absence of an attribution must READ as absent. This defaulted
    /// to `photo` for four versions, so every pre-D3.B entry that
    /// re-synced arrived as a photograph nobody took.
    func testMissingSourceBecomesUnknownNotPhoto() {
        XCTAssertEqual(EntryMethod.persistedSourceValue(for: nil), "unknown")
        XCTAssertEqual(EntryMethod.persistedSourceValue(for: ""), "unknown")
    }

    /// Legacy values are preserved verbatim. `text` in particular LOOKS
    /// like it means `words` — mapping it would invent a fact about a row
    /// no shipped build can explain.
    func testLegacyValuesAreNeverTranslated() {
        for legacy in ["im_out", "voice", "menu", "text"] {
            XCTAssertEqual(
                EntryMethod.persistedSourceValue(for: legacy), legacy,
                "\(legacy) must round-trip untouched"
            )
        }
    }

    func testGarbageBecomesUnknownRatherThanRiskingA23514() {
        // A value the CHECK would reject must never reach the upsert: the
        // client fire-and-forgets the row, so a constraint violation is a
        // silently lost log.
        XCTAssertEqual(EntryMethod.persistedSourceValue(for: "relog"), "unknown")
        XCTAssertEqual(EntryMethod.persistedSourceValue(for: "Photo"), "unknown")
    }
}
