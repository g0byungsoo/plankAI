import SwiftUI

// MARK: - FoodTheme
//
// Local copy of the brand palette tokens PlankFood views need. Mirrors
// the main app's `Palette` (PlankApp/DesignSystem/) exactly.
//
// Why duplicated: PlankFood is a leaf SPM package and can't import the
// main app target (would create a cycle: app → PlankFood → app). The
// main app's `Palette` enum lives in the app target, not a shared
// package, so PlankFood needs its own copy of the constants it uses.
//
// TODO: extract Palette into a shared `PlankDesignSystem` SPM package
// once we have a second consumer beyond PlankApp + PlankFood. Per
// v3 D27 "no abstraction until 3+ examples" — defer the refactor.
//
// If a hex value drifts here vs in PlankApp/DesignSystem/Palette.swift,
// the food rail views will look subtly off-brand. FoodThemeTests pins
// the values so a silent drift fails CI.

public enum FoodTheme {

    // Brand palette — match PlankApp/DesignSystem/Palette.swift exactly.
    public static let bgPrimary    = Color(hex: "#FDF6F4")  // cream
    public static let textPrimary  = Color(hex: "#3D2A2A")  // cocoa
    public static let textSecondary = Color(hex: "#7B5959")
    public static let accent       = Color(hex: "#C4677A")  // rose
    public static let accentSubtle = Color(hex: "#F5D5D8")  // light pink
    public static let bgElevated   = Color(hex: "#FFFBF9")

    // v1.0.8 Phase H — state tokens for the full-bleed camera's
    // adaptive corner brackets. Matches PlankApp's WCAG-AA palette
    // for state communication. Sage/amber chosen over neon (the
    // plank coach's green/pink) because food scan is a one-shot
    // calm-camera moment, not a continuous biomechanical feedback
    // surface — clinical-calm beats high-saturation here.
    public static let stateGood    = Color(hex: "#5F7345")  // sage — success
    public static let stateWarn    = Color(hex: "#8D6A2E")  // amber — error/warning

    // v1.0.9 D2 — split-role camera pinks per expert recommendation.
    // The camera surface keeps a distinctive pink wedge (the recognizable
    // "scan mode" signal) but warms it at rest so the screen doesn't
    // shout when nothing's happening. Resting state reads coquette;
    // capture moment jolts to neon for the energy beat.
    public static let cameraIdlePink = Color(hex: "#FF7AD9")  // softened neon, 60% saturation
    public static let cameraScanPink = Color(hex: "#FF13F0")  // neon hot pink — capture only
    /// Inner shutter disc tint during active scan — sugar-pink hint
    /// so the disc reads warm without going saturated.
    public static let cameraScanDisc = Color(hex: "#FFE7F7")

    // Spacing — minimal set used by food rail views.
    public enum Space {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let screenPadding: CGFloat = 20
    }

    // Radius — scrapbook chrome is 24pt corners per v5 lock.
    public enum Radius {
        public static let card: CGFloat = 24
        public static let pill: CGFloat = 999
    }

    // Stroke widths — 1.5pt cocoa border per scrapbook chrome lock.
    public enum Stroke {
        public static let scrapbook: CGFloat = 1.5
    }
}

// MARK: - Color(hex:) helper

extension Color {
    /// Mirrors the helper in PlankApp/DesignSystem/Palette.swift.
    /// Accepts "#RGB" / "#RRGGBB" / "#AARRGGBB" with or without the #.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)

        let r: Double
        let g: Double
        let b: Double
        let a: Double

        switch s.count {
        case 3:
            r = Double((int >> 8) & 0xF) / 15
            g = Double((int >> 4) & 0xF) / 15
            b = Double(int & 0xF) / 15
            a = 1
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        case 8:
            a = Double((int >> 24) & 0xFF) / 255
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
