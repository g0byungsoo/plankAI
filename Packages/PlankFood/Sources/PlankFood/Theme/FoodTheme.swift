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
    // v22 ONE HAND (2026-08-07): the copy had drifted a whole era —
    // the package was still on the pre-v20 paper (#FCFAF7) while the
    // app stepped down to #F5F3EF so cards separate by fill, and on
    // the pre-v11.5 ink. Synced, and the v21 rose ramp joins so food
    // surfaces can draw quantities in the app's own data hue.
    public static let bgPrimary    = Color(hex: "#F5F3EF")  // warm paper
    public static let textPrimary  = Color(hex: "#18100F")  // ink
    public static let textSecondary = Color(hex: "#5A4340")
    public static let accent       = Color(hex: "#C4677A")  // dusty rose
    public static let accentSubtle = Color(hex: "#F5D5D8")  // blush wash
    public static let bgElevated   = Color(hex: "#FFFFFF")
    /// v21 ramp — the rest (receded marks).
    public static let roseBlush    = Color(hex: "#E7B3BE")
    /// v21 ramp — the emphasis (now, strong, the arriving end).
    public static let roseBerry    = Color(hex: "#9E4A5F")

    // v22 — the sage/amber state pair retired from this package (law
    // §12.5: never a colour to carry state; the words carry the
    // judgment, the ramp carries emphasis). Kept as deprecated
    // aliases mapped into the one-hue system so no call site can
    // reintroduce green.
    public static let stateGood    = roseBerry
    public static let stateWarn    = Color(hex: "#5A4340")

    // v1.2 (2026-07-01) — the v1.0.9 neon camera pinks (cameraIdlePink /
    // cameraScanPink / cameraScanDisc) were removed: every consumer
    // migrated to the locked `accent` rose in the 2026-06-23 calm-down,
    // and unused neon tokens invited the palette violation back.

    // Spacing — minimal set used by food rail views.
    public enum Space {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        /// p61 — 20 → 16, the app's own gutter (`Space.screenPadding`
        /// in Tokens.swift). The food rail sat 4pt narrower than every
        /// other surface — the diffuse "this section feels different"
        /// no single screen explained.
        public static let screenPadding: CGFloat = 16
    }

    // Radius — p61: 24 → 22, the app's own card radius
    // (`Radius.card`). The scrapbook 24pt corner outlived the
    // scrapbook chrome it belonged to.
    public enum Radius {
        public static let card: CGFloat = 22
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

// MARK: - The sheet grammar, package side (p62)
//
// The app's presentation grammar (`jeniSheet`, p57) stops at the
// package boundary, so the food rail's three hand-rolled sheets — the
// ingredient editor, the repair editor, the gallery/error pair —
// rendered with the SYSTEM corner radius and background, one visible
// step off every sheet in the app, on three heights no token names
// (0.72 · 0.66 · `.medium`). `foodSheet` mirrors the app fold's four
// properties exactly: tokened detents, the 28pt corner, the paper
// ground, and the ALWAYS-visible grabber. The grammar sweep
// (PresentationGrammarTests) walks this package too now; a bare
// `.sheet(` here fails the build's tests, same as in the app target.
//
// Values mirror JeniSheetHeight (JeniKit.swift) — if one moves, move
// the other. The TODO at the top of this file (extract a shared
// design-system package) is still the real fix.
public enum FoodSheetHeight {
    /// A sheet with a body of content. Two thirds, expandable.
    public static let tall: Set<PresentationDetent> = [.fraction(0.68), .large]
    /// A sheet with one question in it.
    public static let brief: Set<PresentationDetent> = [.fraction(0.42), .large]
    /// A sheet whose content is a full page.
    public static let full: Set<PresentationDetent> = [.large]
}

extension View {

    /// The package's one legal sheet presenter — see the mark above.
    func foodSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = FoodSheetHeight.tall,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { value in
            content(value)
                .presentationDetents(detents)
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(FoodTheme.bgPrimary)
        }
    }

    /// The `isPresented:` fold of the same grammar.
    func foodSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = FoodSheetHeight.tall,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(FoodTheme.bgPrimary)
        }
    }
}
