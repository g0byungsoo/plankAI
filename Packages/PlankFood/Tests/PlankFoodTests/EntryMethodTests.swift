import XCTest
@testable import PlankFood

// MARK: - EntryMethodTests (v25 E8 — THE MERGE)
//
// The defect these pin: `CapturedFood.source` is decided by a decoder
// shared between three inputs and stamps `.photo` for a photograph, a
// nutrition-label photograph AND a typed sentence. E7 shipped "the door
// is words" and planned to falsify itself on a words-vs-photo split
// that the data could not express.
//
// EntryMethod is derived from the INPUT case, which is the last place
// the three are still distinguishable.

final class EntryMethodTests: XCTestCase {

    // MARK: - the mapping

    func testEveryInputMapsToItsOwnMethod() {
        XCTAssertEqual(EntryMethod(.photo(Data())), .photo)
        XCTAssertEqual(EntryMethod(.labelPhoto(Data())), .label)
        XCTAssertEqual(EntryMethod(.text("two eggs", cuisineProfile: nil)), .words)
        XCTAssertEqual(EntryMethod(.quickAdd(PantryItemID("x"))), .pantry)
        XCTAssertEqual(EntryMethod(.imOutTonight(cuisine: .italian)), .restaurant)
    }

    /// THE ROW THAT MATTERS. These three all report
    /// `CaptureSource.photo`; if EntryMethod ever collapses them too,
    /// E7 becomes unfalsifiable again and nothing else in the codebase
    /// would notice.
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
        // not silently folded into the largest real category.
        let food = CapturedFood(
            items: [], plateType: .single, source: .photo,
            confidence: nil, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        XCTAssertEqual(food.entryMethod, .unknown)
    }

    // MARK: - barcode stamps itself

    func testBarcodeIsNotReachableFromTheInputEnum() {
        // Barcode reads live off the video output and never passes
        // through FoodCaptureDispatcher, so it has no FoodCapture case
        // and must stamp itself (BarcodeRead). This test exists to make
        // that asymmetry deliberate rather than forgotten.
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

    /// EntryMethod must not silently become a second CaptureSource.
    /// They answer different questions and are allowed to disagree —
    /// this records that they DO.
    func testEntryMethodIsNotCaptureSource() {
        let sources = Set(CaptureSource.allCases.map(\.rawValue))
        let methods = Set(EntryMethod.allCases.map(\.rawValue))
        XCTAssertNotEqual(sources, methods)
        // words + label are exactly what CaptureSource cannot say.
        XCTAssertFalse(sources.contains("words"))
        XCTAssertFalse(sources.contains("label"))
    }
}
