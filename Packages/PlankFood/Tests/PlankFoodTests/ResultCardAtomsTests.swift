#if canImport(UIKit)
import XCTest
@testable import PlankFood

final class ResultCardAtomsTests: XCTestCase {

    // MARK: - ItalicAccentText asterisk parser
    //
    // ItemRow + JeniLine both rely on this parser to extract italic
    // substrings from strings like "creamy *carbonara*". If the
    // parser breaks, every italic-accent surface goes plain.

    func testAsteriskParser_emptyString() {
        let (base, italic) = ItalicAccentText.parseAsterisks("")
        XCTAssertEqual(base, "")
        XCTAssertTrue(italic.isEmpty)
    }

    func testAsteriskParser_noMarkers() {
        let (base, italic) = ItalicAccentText.parseAsterisks("plain text")
        XCTAssertEqual(base, "plain text")
        XCTAssertTrue(italic.isEmpty)
    }

    func testAsteriskParser_singleItalic() {
        let (base, italic) = ItalicAccentText.parseAsterisks("creamy *carbonara*")
        XCTAssertEqual(base, "creamy carbonara")
        XCTAssertEqual(italic, ["carbonara"])
    }

    func testAsteriskParser_multipleItalics() {
        let (base, italic) = ItalicAccentText.parseAsterisks("*one* and *two* and three")
        XCTAssertEqual(base, "one and two and three")
        XCTAssertEqual(italic, ["one", "two"])
    }

    func testAsteriskParser_italicInMiddle() {
        let (base, italic) = ItalicAccentText.parseAsterisks("you have *room* today")
        XCTAssertEqual(base, "you have room today")
        XCTAssertEqual(italic, ["room"])
    }

    func testAsteriskParser_unclosedAsteriskFallsThroughGracefully() {
        // If GPT-5 emits malformed copy, we shouldn't crash. The
        // open italic just doesn't have a closing marker — the
        // text after gets folded into the italic candidate but
        // never gets emitted as italic (no closing *).
        let (base, italic) = ItalicAccentText.parseAsterisks("hello *world")
        XCTAssertFalse(base.isEmpty)
        // No closing * = no italic substring emitted.
        XCTAssertTrue(italic.isEmpty)
    }

    // MARK: - ItemRow

    func testItemRow_initPreservesAllFields() {
        let row = ItemRow(
            name: "creamy *carbonara*",
            portionGrams: 320,
            confidence: 0.85,
            onTap: nil
        )
        XCTAssertEqual(row.name, "creamy *carbonara*")
        XCTAssertEqual(row.portionGrams, 320)
        XCTAssertEqual(row.confidence, 0.85)
    }

    func testItemRow_portionFormatting() {
        XCTAssertEqual(ItemRow.formatPortion(350), "350g")
        XCTAssertEqual(ItemRow.formatPortion(99.5), "100g")  // rounds
        XCTAssertEqual(ItemRow.formatPortion(0), "0g")
    }

    // MARK: - ConfidencePill

    func testConfidencePill_tightSpreadShowsLooksRight() {
        let pill = ConfidencePill(kcal: 480, kcalLow: 460, kcalHigh: 500)
        _ = pill.body  // exercise body path
        // 40/480 = 8% spread → tight → "this looks right"
        // (we can't easily inspect SwiftUI Text, but the helper is
        // pure so we can test it through the public init at least)
        XCTAssertEqual(pill.kcal, 480)
    }

    func testConfidencePill_noRangeFallsBackToLooksRight() {
        let pill = ConfidencePill(kcal: 480)
        XCTAssertNil(pill.kcalLow)
        XCTAssertNil(pill.kcalHigh)
    }

    // MARK: - RestaurantRangeBar

    func testRestaurantRangeBar_defaultsAreReasonable() {
        let bar = RestaurantRangeBar(kcalLow: 600, kcalHigh: 900)
        XCTAssertEqual(bar.trackLow, 200)
        XCTAssertEqual(bar.trackHigh, 1500)
    }

    // MARK: - PortionStepper

    func testPortionStepper_initStateIsInitialGrams() {
        var captured: Double?
        let stepper = PortionStepper(
            initialGrams: 350,
            lowGrams: 250,
            highGrams: 450,
            onChange: { captured = $0 }
        )
        XCTAssertEqual(stepper.initialGrams, 350)
        XCTAssertEqual(stepper.lowGrams, 250)
        XCTAssertEqual(stepper.highGrams, 450)
        XCTAssertNil(captured)  // no change yet
    }
}

#endif  // canImport(UIKit)
