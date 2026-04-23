import SwiftUI
import UIKit

// MARK: - Typography

enum Typo {
    private static func font(_ name: String, size: CGFloat) -> Font {
        Font(UIFont(name: name, size: size) ?? .systemFont(ofSize: size))
    }

    static let display = font("DMSans-Light", size: 56).leading(.tight)
    static let title = font("DMSans-SemiBold", size: 32)
    static let heading = font("DMSans-SemiBold", size: 20)
    static let body = font("DMSans-Regular", size: 16)
    static let caption = font("DMSans-Medium", size: 13)
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

enum Palette {
    static let bgPrimary = Color(hex: "#F7F3EE")
    static let bgElevated = Color(hex: "#FFFEFB")
    static let bgInverse = Color(hex: "#2C2218")

    static let textPrimary = Color(hex: "#2C2218")
    static let textSecondary = Color(hex: "#6B5D4F")
    static let textInverse = Color(hex: "#F7F3EE")

    static let accent = Color(hex: "#C8612C")
    static let accentSubtle = Color(hex: "#E8C9A8")

    static let stateGood = Color(hex: "#7A9E5C")
    static let stateWarn = Color(hex: "#C8823C")
    static let stateBad = Color(hex: "#9E5C5C")

    static let divider = Color(hex: "#E8DFD3")
}

// MARK: - Corner Radius

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 24
}

// MARK: - Shadow

struct PlankShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(
            color: Color(red: 44/255, green: 34/255, blue: 24/255).opacity(0.08),
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
