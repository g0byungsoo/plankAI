import SwiftUI
import UIKit

// MARK: - Typography
//
// Two families:
//   - Fraunces (serif, editorial) for hero/title/italic-accent slots
//   - DM Sans (utility sans) for heading/body/caption/eyebrow
//
// Fraunces ships per-optical-size in the upstream repo. We bundle the 72pt
// optical (designed for ≥24pt usage) since title (32pt) and display (56pt)
// both sit comfortably in that range. PostScript names: Fraunces72pt-Light,
// Fraunces72pt-Regular, Fraunces72pt-SemiBold, Fraunces72pt-SemiBoldItalic.
//
// "Medium" doesn't ship at 72pt opsz — SemiBold is the closest weight and
// reads as more emphatic anyway, which matches the editorial intent.

enum Typo {
    private static func font(_ name: String, size: CGFloat) -> Font {
        Font(UIFont(name: name, size: size) ?? .systemFont(ofSize: size))
    }

    static let display = font("Fraunces72pt-Light", size: 56).leading(.tight)
    static let title = font("Fraunces72pt-SemiBold", size: 32)
    static let titleItalic = font("Fraunces72pt-SemiBoldItalic", size: 32)
    static let heading = font("DMSans-SemiBold", size: 20)
    static let body = font("DMSans-Regular", size: 16)
    static let caption = font("DMSans-Medium", size: 13)
    static let eyebrow = font("DMSans-SemiBold", size: 12)
}

// MARK: - Spacing (4pt base)

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 48

    static let screenPadding: CGFloat = md
    static let cardPadding: CGFloat = md
    static let minTapTarget: CGFloat = 44
}

// MARK: - Colors
//
// JeniFit palette — dusty rose accent on a soft pink-cream base.
// Cocoa (bgInverse / textPrimary share the same hex) anchors the dark
// surfaces. Pink (accent / accentSubtle) is reserved for selected states,
// celebrations, and badges — primary CTAs use cocoa, not pink.

enum Palette {
    static let bgPrimary = Color(hex: "#FDF6F4")
    static let bgElevated = Color(hex: "#FFFAF8")
    static let bgInverse = Color(hex: "#3D2A2A")

    static let textPrimary = Color(hex: "#3D2A2A")
    static let textSecondary = Color(hex: "#8E6D6D")
    static let textInverse = Color(hex: "#FDF6F4")

    static let accent = Color(hex: "#C4677A")
    static let accentSubtle = Color(hex: "#F5D5D8")

    static let stateGood = Color(hex: "#9CAA7E")
    static let stateWarn = Color(hex: "#D4A464")
    static let stateBad = Color(hex: "#B47272")

    static let divider = Color(hex: "#EFE0DC")

    /// Activity-calendar "frozen day" cell. Aliased to accentSubtle so the
    /// calendar reads cohesive with the rest of the palette. Promoted from
    /// the inline `Color(hex: "#D6EBF5")` literal noted in the screen audit.
    static let frozenDay = accentSubtle
}

// MARK: - Corner Radius

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 24
}

// MARK: - Shadow
//
// Warm rose tint replaces the brown of the absmaxxing era. Pink shadows
// fade more visually than brown, so we bump alpha 0.08 → 0.10 to keep
// elevation legible on the cream bg.

struct PlankShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(
            color: Color(red: 196/255, green: 103/255, blue: 122/255).opacity(0.10),
            radius: 12,
            x: 0,
            y: 2
        )
    }
}

extension View {
    func plankShadow() -> some View {
        modifier(PlankShadow())
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
