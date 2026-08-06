import XCTest
@testable import plankAI

// v11.5 — the heart guard is categorical, not a list. A red heart
// reached a live reply because 2764+FE0F was handled but the wider
// family was not; these pin the rule rather than the enumeration.
final class JeniChatVoiceTests: XCTestCase {

    private func stripped(_ s: String) -> String {
        JeniProse(text: s).normalizedTextForTesting
    }

    func testPlainAndVariantHeartsAreStripped() {
        XCTAssertEqual(stripped("nice work \u{2764}\u{FE0F}"), "nice work")
        XCTAssertEqual(stripped("nice work \u{2764}"), "nice work")
        XCTAssertEqual(stripped("nice work \u{2665}"), "nice work")
    }

    func testColouredHeartsOutsideTheOldListAreStripped() {
        // 1F496 / 1F499 / 1F5A4 / 1FA77 were all absent from the
        // enumerated guard and reached the eye.
        for scalar: UInt32 in [0x1F496, 0x1F499, 0x1F5A4, 0x1FA77, 0x1F90D] {
            let heart = String(UnicodeScalar(scalar)!)
            XCTAssertEqual(stripped("keep going \(heart)"), "keep going",
                           "heart U+\(String(scalar, radix: 16)) survived")
        }
    }

    func testOrdinaryTextSurvivesIntact() {
        XCTAssertEqual(stripped("down 2.1 lb this week."), "down 2.1 lb this week.")
        XCTAssertEqual(stripped("protein first · aim near 90g"), "protein first · aim near 90g")
    }
}
