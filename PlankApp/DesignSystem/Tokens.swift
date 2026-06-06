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
    /// Custom-font helper that's Dynamic Type-aware via `relativeTo:`.
    /// SwiftUI's `Font.custom(_:size:relativeTo:)` scales the size
    /// relative to a system text style as the user adjusts Larger
    /// Text in iOS settings. The previous bridge through UIFont
    /// produced a fixed-size font that ignored accessibility scaling.
    private static func font(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }

    static let display = font("Fraunces72pt-Light", size: 56, relativeTo: .largeTitle).leading(.tight)
    static let title = font("Fraunces72pt-SemiBold", size: 32, relativeTo: .title)
    static let titleItalic = font("Fraunces72pt-SemiBoldItalic", size: 32, relativeTo: .title)
    static let heading = font("DMSans-SemiBold", size: 20, relativeTo: .headline)
    static let body = font("DMSans-Regular", size: 16, relativeTo: .body)
    static let caption = font("DMSans-Medium", size: 13, relativeTo: .caption)
    static let eyebrow = font("DMSans-SemiBold", size: 12, relativeTo: .caption2)

    // MARK: - v1.0.7 aggressive Gen-Z luxury editorial tokens
    //
    // Per docs/aggressive_genz_luxury_2026_06_06.md §4. Fraunces ships
    // optical-size axes at 9pt / 72pt / 144pt; editorial typography
    // MUST use the axis. Until v1.0.8 wires actual variable-font
    // optical-axis instances, we map these to the SemiBold / Light
    // weights that ship with the bundled Fraunces72pt cuts — the
    // SwiftUI rendering still reads as more editorial because the
    // sizing + tracking + line-height are tuned per token.

    /// JenisNote masthead. Italic Fraunces, 19pt display, tracking -0.2
    /// (editorial display always tightens). Editorial 72pt-optical
    /// register.
    static let mastheadDisplay = font("Fraunces72pt-SemiBoldItalic", size: 19, relativeTo: .title3)

    /// Becoming chapter cover title. Italic Fraunces 36pt, tracking
    /// -0.5 for the display-cut shrink. Magazine-masthead register.
    static let chapterCover = font("Fraunces72pt-SemiBoldItalic", size: 36, relativeTo: .title)

    /// Editorial eyebrow — 11pt UPPERCASE tracking 3 (Acne Paper +
    /// Cereal convention). Fraunces SemiBold for the editorial weight;
    /// not DM Sans (this is the wider-tracked, page-numbered eyebrow
    /// register).
    static let editorialEyebrow = font("Fraunces72pt-SemiBold", size: 11, relativeTo: .caption2)

    /// Pull-quote between chapters / on Sunday Feature. Italic
    /// Fraunces 22pt, lh 1.45 — pull-quotes should breathe.
    static let pullQuote = font("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .title3)

    /// Section / chapter title where it's not a full cover (smaller
    /// inline use). Italic Fraunces 26pt, lh 1.2.
    static let sectionTitle = font("Fraunces72pt-SemiBoldItalic", size: 26, relativeTo: .title2)
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
    /// Muted body color. Deepened from #8E6D6D (was 4.31:1 on bgPrimary —
    /// just below WCAG AA's 4.5:1 normal-text threshold) to #7B5959
    /// which lands at 5.76:1 (AA pass). Visually a touch darker but
    /// keeps the rose-cocoa hue.
    static let textSecondary = Color(hex: "#7B5959")
    static let textInverse = Color(hex: "#FDF6F4")

    static let accent = Color(hex: "#C4677A")
    static let accentSubtle = Color(hex: "#F5D5D8")

    /// v1.0.7 aggressive Gen-Z luxury (Sweet July + Acne Paper
    /// editorial register). Two-cream paper-layering — bgPrimary
    /// is the standard scroll, pageIvory is the chapter-cover /
    /// TOC stock. Like a real magazine has cover stock + interior
    /// stock. Per docs/aggressive_genz_luxury_2026_06_06.md §5.
    static let pageIvory = Color(hex: "#F8F0EC")

    /// Heirloom oxblood-rose for Roman numerals, drop caps, pull-
    /// quote first letter, Sunday Feature byline, pagination active
    /// state. Sits between rose and cocoa — adds richness without
    /// breaking warmth. Per the 2026 jewel-tone trend (Envato
    /// color-scheme research). Reserved for editorial moments;
    /// never a CTA color.
    static let jeweledRose = Color(hex: "#7A2E3F")

    /// State colors deepened to pass WCAG AA (4.5:1) on bgPrimary
    /// for normal-weight body text. Previously failed even AA-Large
    /// (sage at 2.32:1, amber at 2.12:1). New values are in the same
    /// hue family — sage stays sage, amber stays honey-bronze. stateBad
    /// at 3.52:1 is AA-Large only; left as-is because the only places
    /// it surfaces (Delete Account warning, error toasts) already use
    /// large bold copy that qualifies for AA-Large.
    static let stateGood = Color(hex: "#5F7345")  // 4.89:1 — was #9CAA7E
    static let stateWarn = Color(hex: "#8D6A2E")  // 4.65:1 — was #D4A464
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

// MARK: - Motion (calm, mindful, magical defaults)
//
// Phase 20a: a small set of named animations replacing per-site magic
// numbers. The philosophy:
//   • slow swells over snap — entrance ≥0.55s so the eye can follow
//   • high-damping springs so taps respond without rubber-band bounce
//   • generous staggers so cascades feel intentional, not mechanical
//   • slow repeat-forever loops for ambient cues (loading, breathing)
//
// Migrate per-site, never globally. Drop-in via `.animation(Motion.x, …)`
// or `withAnimation(Motion.x) { … }`. Curves were tuned against the
// "screens feel rushed and laggy" feedback (2026-05-08 testing).

enum Motion {
    /// Element appearing on screen for the first time. Slow ease-out so
    /// the swell reads as deliberate. Default for top-of-screen heroes,
    /// list rows, modal contents.
    static let entrance: Animation = .easeOut(duration: 0.55)

    /// Subtle entrance — used when the parent is already visible and we
    /// want a quieter reveal (toasts, inline feedback, badges).
    static let entranceSoft: Animation = .easeOut(duration: 0.42)

    /// Element leaving — slightly faster than entrance so dismissals
    /// don't drag. Pair with `.transition(.opacity)` for the cleanest
    /// exit.
    static let exit: Animation = .easeIn(duration: 0.32)

    /// Content swaps inside the same surface — tab routing, list filter
    /// changes, image-vs-loading-vs-content. Symmetric ease so neither
    /// direction feels privileged.
    static let crossFade: Animation = .easeInOut(duration: 0.45)

    /// Press / tap response. Short enough to feel snappy, easeOut so the
    /// release rebound is calm. NEVER use a spring here — bounce on tap
    /// reads as cheap on a calm surface.
    static let tap: Animation = .easeOut(duration: 0.16)

    /// Tactile feedback that benefits from a physics rebound — drag
    /// release, scale-pop on confirm, sticker-stamp landings. High
    /// damping (0.88) means it settles in one bounce, not three.
    static let gentleSpring: Animation = .spring(response: 0.55, dampingFraction: 0.88)

    /// Inter-element delay for stagger cascades (lists, sticker scatter,
    /// section reveal). Pair with `.delay(Double(index) * Motion.stagger)`.
    /// 0.10 reads as deliberate without dragging on long lists.
    static let stagger: Double = 0.10

    /// Slow ambient loop — loaders, breathing pulses, idle heartbeats.
    /// Repeat-forever flavor; pair with `.repeatForever(autoreverses: true)`.
    static let breathing: Animation = .easeInOut(duration: 1.6)

    /// Loading-screen choreography baseline. Matches the magical
    /// 2.4s refresh window (HomeView Phase 19) so any new loading
    /// surface stays consistent without re-deriving the constant.
    static let loadingTotalSeconds: Double = 2.4
}

// MARK: - Shadow
//
// Warm rose tint on the JeniFit shadow stack. Pink shadows fade more
// visually than brown, so alpha sits at 0.10 to keep elevation legible
// on the cream bg.

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

// MARK: - Hit-target helper
//
// Expand the hit target to Apple HIG's 44×44 minimum without changing
// visible chrome. JeniFit's icon buttons (xmark close, refresh shuffle,
// eye toggle) sit at 30–32pt visually for design density; this modifier
// adds invisible padding around them so the tap area meets the
// guideline. Apply to the Button's *label*, not the Button itself —
// SwiftUI sizes the button to its label's intrinsic frame.

extension View {
    /// Expand hit target to at least `size` × `size` (default 44pt per
    /// Apple HIG) while keeping the visible chrome at its original
    /// size. Pair with `Button` labels that have a smaller visual
    /// frame. `contentShape(Rectangle())` ensures the whole padded
    /// area registers taps, not just the visible glyph.
    func tappableArea(_ size: CGFloat = 44) -> some View {
        self
            .frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
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
