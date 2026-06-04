import XCTest
import SwiftUI
@testable import PlankFood

final class FoodThemeTests: XCTestCase {

    // MARK: - Palette pins
    //
    // FoodTheme is a manual copy of PlankApp/DesignSystem/Palette.swift
    // values (PlankFood can't import the main app target — would cycle).
    // If a hex code drifts in either file, the food rail views go subtly
    // off-brand. These tests catch the drift.
    //
    // TODO: when Palette extracts to a shared SPM package, delete this
    // file and let the type system enforce parity.

    func testBgPrimaryMatchesPlankAppPalette() {
        // PlankApp/DesignSystem/Palette.swift -> static let bgPrimary = Color(hex: "#FDF6F4")
        let expected = Color(hex: "#FDF6F4")
        XCTAssertEqual(describe(FoodTheme.bgPrimary), describe(expected))
    }

    func testTextPrimaryMatchesPlankAppPalette() {
        // PlankApp/DesignSystem/Palette.swift -> static let textPrimary = Color(hex: "#3D2A2A")
        let expected = Color(hex: "#3D2A2A")
        XCTAssertEqual(describe(FoodTheme.textPrimary), describe(expected))
    }

    func testAccentMatchesPlankAppPalette() {
        // PlankApp/DesignSystem/Palette.swift -> static let accent = Color(hex: "#C4677A")
        let expected = Color(hex: "#C4677A")
        XCTAssertEqual(describe(FoodTheme.accent), describe(expected))
    }

    func testAccentSubtleMatchesPlankAppPalette() {
        // PlankApp/DesignSystem/Palette.swift -> static let accentSubtle = Color(hex: "#F5D5D8")
        let expected = Color(hex: "#F5D5D8")
        XCTAssertEqual(describe(FoodTheme.accentSubtle), describe(expected))
    }

    // MARK: - Scrapbook chrome pins
    //
    // v5 D37 + chrome lock: 24pt corners + 1.5pt cocoa border. If
    // these drift, the food rail card chrome diverges from the rest
    // of the app's scrapbook chrome.

    func testScrapbookRadius() {
        XCTAssertEqual(FoodTheme.Radius.card, 24)
    }

    func testScrapbookStroke() {
        XCTAssertEqual(FoodTheme.Stroke.scrapbook, 1.5)
    }

    // MARK: - Hex parsing

    func testHexParserHandlesThreeDigit() {
        let c1 = Color(hex: "#F00")
        let c2 = Color(hex: "#FF0000")
        XCTAssertEqual(describe(c1), describe(c2),
                       "#F00 should equal #FF0000")
    }

    func testHexParserStripsHash() {
        let withHash = Color(hex: "#FDF6F4")
        let noHash = Color(hex: "FDF6F4")
        XCTAssertEqual(describe(withHash), describe(noHash))
    }

    // MARK: - Helpers

    /// SwiftUI Color is opaque to direct comparison; describe()
    /// stringifies the underlying components via reflection. Good
    /// enough for equality assertions in tests.
    private func describe(_ color: Color) -> String {
        return String(describing: color)
    }
}
