import XCTest
import SwiftUI
@testable import plankAI

// v7 a11y floor (docs/app_v7 §6): accessibility floors are
// design-system LAW, not review notes — no future restraint pass may
// ship the quiet tier below WCAG AA on the cream ground. These tests
// resolve the actual tokens, composite alpha over bgPrimary, and
// compute the WCAG 2.x contrast ratio.

final class TokensContrastTests: XCTestCase {

    private func rgba(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    /// Composites `fg` over `bg` (both resolved), returns WCAG ratio.
    private func contrast(_ fg: Color, over bg: Color) -> CGFloat {
        let f = rgba(fg), b = rgba(bg)
        let cr = f.a * f.r + (1 - f.a) * b.r
        let cg = f.a * f.g + (1 - f.a) * b.g
        let cb = f.a * f.b + (1 - f.a) * b.b
        func lin(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func lum(_ r: CGFloat, _ g: CGFloat, _ bl: CGFloat) -> CGFloat {
            0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(bl)
        }
        let l1 = lum(cr, cg, cb)
        let l2 = lum(b.r, b.g, b.b)
        let (hi, lo) = (max(l1, l2), min(l1, l2))
        return (hi + 0.05) / (lo + 0.05)
    }

    func testQuietTierMeetsAAOnCream() {
        // The tracked-caps wayfinding tier (kickers, stat labels,
        // dates) — the app's navigation skeleton.
        XCTAssertGreaterThanOrEqual(
            contrast(Palette.cocoaTertiary, over: Palette.bgPrimary), 4.5,
            "cocoaTertiary fell below WCAG AA on cream — quiet must mean calm, not faint"
        )
    }

    func testBodyTiersMeetAAOnCream() {
        XCTAssertGreaterThanOrEqual(
            contrast(Palette.textSecondary, over: Palette.bgPrimary), 4.5
        )
        XCTAssertGreaterThanOrEqual(
            contrast(Palette.textPrimary, over: Palette.bgPrimary), 7.0
        )
    }

    func testJeweledRoseCarriesSmallRoseText() {
        // Small rose text sites use jeweledRose (accent is reserved
        // for ≥19pt where 3:1 applies).
        XCTAssertGreaterThanOrEqual(
            contrast(Palette.jeweledRose, over: Palette.bgPrimary), 4.5
        )
    }
}
