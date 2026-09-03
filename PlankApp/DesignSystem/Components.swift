import SwiftUI

// MARK: - ItalicAccentText
//
// Renders a base string with selected substrings rendered in Fraunces italic
// for editorial emphasis (e.g., "Kept *twelve* days."). Implementation
// concatenates Text fragments via the `+` operator — Text concatenation
// preserves per-fragment fonts and produces a single layout-aware Text node,
// which avoids the wrapping artifacts an HStack of Texts would introduce.
//
// Deliberately avoids AttributedString / NSAttributedString so the
// implementation surface is small and predictable. Headlines are short, so
// the linear scan to locate italic substrings is not a performance concern.
//
// Usage:
//   ItalicAccentText(
//       "Kept twelve days.",
//       italic: ["twelve"],
//       baseFont: Typo.title,
//       italicFont: Typo.titleItalic
//   )

struct ItalicAccentText: View {
    let base: String
    let italic: [String]
    var baseFont: Font = Typo.title
    var italicFont: Font = Typo.titleItalic
    var color: Color = Palette.textPrimary
    /// v3 premium pass: optional distinct ink for the italic punch
    /// (the cocoa one-thing card tints it accent-subtle). nil = the
    /// punch shares `color` (every existing call site unchanged).
    var italicColor: Color? = nil
    var alignment: TextAlignment = .leading

    init(_ base: String,
         italic: [String],
         baseFont: Font = Typo.title,
         italicFont: Font = Typo.titleItalic,
         color: Color = Palette.textPrimary,
         italicColor: Color? = nil,
         alignment: TextAlignment = .leading) {
        self.base = base
        self.italic = italic
        self.baseFont = baseFont
        self.italicFont = italicFont
        self.color = color
        self.italicColor = italicColor
        self.alignment = alignment
    }

    var body: some View {
        composed
            .multilineTextAlignment(alignment)
    }

    private var composed: Text {
        var output = Text("")
        var cursor = base.startIndex
        let end = base.endIndex
        while cursor < end {
            // Find the earliest italic substring at or after cursor across
            // all candidates. First-match-wins so callers can pass overlapping
            // candidates without surprising precedence.
            var nearest: Range<String.Index>? = nil
            for needle in italic where !needle.isEmpty {
                if let r = base.range(of: needle, range: cursor..<end),
                   nearest == nil || r.lowerBound < nearest!.lowerBound {
                    nearest = r
                }
            }
            if let match = nearest {
                if match.lowerBound > cursor {
                    output = output + Text(String(base[cursor..<match.lowerBound]))
                        .font(baseFont)
                        .foregroundColor(color)
                }
                output = output + Text(String(base[match]))
                    .font(italicFont)
                    .foregroundColor(italicColor ?? color)
                cursor = match.upperBound
            } else {
                output = output + Text(String(base[cursor..<end]))
                    .font(baseFont)
                    .foregroundColor(color)
                cursor = end
            }
        }
        return output
    }
}

// MARK: - LineCascadeText (v9 P9.6 — her75 hero reveal)
//
// Reveals a stacked hero phrase one LINE at a time, with a soft
// `Haptics.soft()` tap firing the moment each line starts animating
// in. Founder pattern via her75 reference (2026-06-10): the line-
// by-line cadence + paired haptic is what reads as "luxurious."
//
// Usage:
//   LineCascadeText(
//       lines: [
//           .plain("you'll get there by"),
//           .italic("september 12.")
//       ],
//       baseFont: Typo.questionHero,
//       italicFont: Typo.questionHeroItalic,
//       color: Palette.textPrimary,
//       perLineDelay: 0.42
//   )
//
// Reduce-motion gate: when `accessibilityReduceMotion` is true, all
// lines render at full opacity immediately + the haptic is skipped.
// Apply ONLY to hero moments — overuse kills the luxury signal per
// [[feedback-her75-line-cascade]]. Cap at 3-4 lines per hero.

struct LineCascadeText: View {

    enum Line: Hashable {
        case plain(String)
        case italic(String)
        /// v3 (2026-06-10) — composite line with mid-line italic
        /// accent ("you *became* them."). `base` is the full sentence
        /// as it should render; `italic` is the substring set to
        /// switch to the italic font. Rendered via ItalicAccentText
        /// per [[feedback-no-italic-markdown-markers]]. Use for hero
        /// beats where the italic punch sits inside the line, not
        /// as its own line.
        case composite(base: String, italic: [String])

        var text: String {
            switch self {
            case .plain(let s), .italic(let s): return s
            case .composite(let base, _):       return base
            }
        }
    }

    let lines: [Line]
    var baseFont: Font = Typo.questionHero
    var italicFont: Font = Typo.questionHeroItalic
    var color: Color = Palette.textPrimary
    var alignment: HorizontalAlignment = .leading
    var lineSpacing: CGFloat = Typo.questionHeroLineGap
    /// Delay between consecutive line reveals. Default 0.42s is the
    /// her75 cadence — slow enough that the haptic taps land
    /// distinctly, fast enough that a 3-line hero finishes inside
    /// 1.3s.
    var perLineDelay: Double = 0.42
    /// True after the screen's primary reveal has fired upstream.
    /// Pass an external @State Bool so the cascade can be coordinated
    /// with other entrance choreography. Defaults to true (cascade
    /// starts on appear).
    var trigger: Bool = true
    /// p63 — external completion (§5.7, impatience is a valid input):
    /// flip true to land every remaining line at once. Pending
    /// reveals cancel; skipped lines carry no haptic — her tap was
    /// the input, not an arrival.
    var completed: Bool = false

    @State private var revealedCount: Int = 0
    @State private var pending: [DispatchWorkItem] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                lineView(for: line)
                    .lineSpacing(lineSpacing)
                    .opacity(reduceMotion || idx < revealedCount ? 1 : 0)
                    .offset(y: reduceMotion || idx < revealedCount ? 0 : 8)
                    .animation(.easeOut(duration: 0.35), value: revealedCount)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .onAppear { runCascade() }
        .onChange(of: trigger) { _, newValue in
            if newValue { runCascade() }
        }
        .onChange(of: completed) { _, done in
            if done { finishNow() }
        }
        .onDisappear {
            // p63 — the timers die with the view: a cascade that left
            // the screen kept firing its per-line haptics into
            // whatever surface came next.
            pending.forEach { $0.cancel() }
            pending = []
        }
    }

    private func runCascade() {
        guard revealedCount == 0 else { return }
        if reduceMotion || completed {
            revealedCount = lines.count
            return
        }
        for i in 0..<lines.count {
            let item = DispatchWorkItem {
                Haptics.soft()
                revealedCount = i + 1
            }
            pending.append(item)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(i) * perLineDelay, execute: item
            )
        }
    }

    private func finishNow() {
        pending.forEach { $0.cancel() }
        pending = []
        withAnimation(.easeOut(duration: 0.25)) { revealedCount = lines.count }
    }

    @ViewBuilder
    private func lineView(for line: Line) -> some View {
        switch line {
        case .plain(let s):
            Text(s)
                .font(baseFont)
                .foregroundStyle(color)
        case .italic(let s):
            Text(s)
                .font(italicFont)
                .foregroundStyle(color)
        case .composite(let base, let italics):
            ItalicAccentText(
                base,
                italic: italics,
                baseFont: baseFont,
                italicFont: italicFont,
                color: color,
                alignment: alignment == .center ? .center : .leading
            )
        }
    }
}

// MARK: - JeniMark + JeniWordmark (the official identity, MARK 01)
//
// The founder's identity spec (docs/jeni_release/identity/Design.pdf,
// "Jeni — AI care operations · Mark 01") is LAW here:
//
//   THE MARK — a hand-drawn lowercase j: a dose above, the vessel
//   below, and a gap that is not empty but load-bearing ("the
//   distance is the idea"). Gap = half the dose; the terminal equals
//   the dose; the sphere leans; the tail lifts 12°.
//   · Clear space: one sphere diameter on every side.
//   · Never rotate, never mirror, never outline (mass, not line).
//   · ONE COLOUR: ink on ceramic, ceramic on ink. No gradients
//     inside the mark. In-app that means textPrimary on the paper,
//     or textInverse on ink surfaces — nothing else, never rose.
//
//   THE LOCKUP — "set quietly beside its name": the mark beside
//   "Jeni" (Title case) in the rounded utility sans. The mark's
//   height matches the wordmark's cap-to-descender band; the gap
//   between them is generous, never tight.
//
// `size` is the TEXT size; the mark scales to match its cap height.

struct JeniMark: View {
    var height: CGFloat
    var color: Color = Palette.textPrimary

    var body: some View {
        // Two cuts per the spec's scale law: the SMALL cut (sphere,
        // gap and stroke all grown) carries chrome sizes; the display
        // cut carries large brand moments. Each imageset ships true
        // 1x/2x/3x rasters so the mark never minifies at runtime —
        // the mass stays clean-edged at every size.
        let display = height > 40
        Image(display ? "JeniMarkDisplay" : "JeniMark")
            .resizable()
            .renderingMode(.template)
            .aspectRatio(display ? 0.4814 : 0.4941, contentMode: .fit)
            .frame(height: height)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

struct JeniWordmark: View {
    var size: CGFloat = 32
    var color: Color = Palette.textPrimary
    var markOnly: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.42) {
            JeniMark(height: size * 1.18, color: color)
            if !markOnly {
                Text("Jeni")
                    .font(.custom("DMSans-SemiBold", size: size))
                    .foregroundStyle(color)
                    .kerning(size * 0.01)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jeni")
    }
}

// MARK: - SectionDividerScreen
//
// Brief interstitial between the six onboarding parts. Auto-advances after
// `dwellSeconds` so the user gets a moment to register the section name
// without having to tap. Layout is intentionally sparse: small "Part N"
// eyebrow, then the section name in Fraunces title, then a short
// supporting line.
//
// Used as a screen body inside OnboardingView; the parent owns the
// dispatch to the next screen.

// MARK: - JFPageHero (her75 Phase 5 — Archetype D page hero)
//
// The canonical drop-in for every dashboard / settings page hero per
// docs/her75_redesign_phase2_plan_2026_06_10.md §7. her75's page-level
// structure (her75-homescreen.webp): big italic-Fraunces hero at the
// SAME register as onboarding (38pt heroHeadline), ONE optional cocoa
// social-proof / status pill below, then modules. No tab labels, no
// eyebrow breadcrumbs, no sticker decoration.
//
// Every Archetype D surface (Becoming, Settings hub, Settings
// sub-pages, PlanView) drops this in — no surface ships a one-off
// page hero composition. The structural consistency IS the fix for
// the founder's "everything is inconsistent" complaint.
//
// Pill content must trace to collected data per
// [[feedback-data-provenance]] — "becoming since march", "day 12",
// never a fabricated count.

struct JFPageHero: View {
    let title: String
    var italic: [String] = []
    /// Optional cocoa status pill ("becoming since march", "day 12 of 75").
    var pill: String? = nil
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 14) {
            ItalicAccentText(
                title,
                italic: italic,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: alignment == .leading ? .leading : .center
            )
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .fixedSize(horizontal: false, vertical: true)
            // p70 — the JFContinueButton cap (~1.5× resting), for the
            // same reason: past accessibility2 a single-word hero
            // exceeds the SE's line and SwiftUI breaks it MID-WORD
            // ("notification / s." — AX5-filmed). VoiceOver reads the
            // full title; the visual cap keeps the word whole.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

            if let pill {
                Text(pill)
                    .font(Typo.heroSubpill)
                    .kerning(0.2)
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.cocoaPrimary))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.md)
    }
}

// MARK: - Previews
//
// Visual scratchpad for the design system primitives. Run in the Xcode
// canvas (Editor → Canvas) to inspect each component in isolation against
// the JeniFit palette. These previews are #if DEBUG-gated implicitly by
// the #Preview macro — they don't ship in release builds.

#Preview("CTA button") {
    JFContinueButton(label: "continue", action: {})
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
}

#Preview("ItalicAccentText") {
    VStack(spacing: Space.lg) {
        ItalicAccentText("Kept twelve days.", italic: ["twelve"])
        ItalicAccentText(
            "Sculpt your strongest body, at home.",
            italic: ["strongest"]
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("JeniWordmark") {
    VStack(spacing: Space.lg) {
        JeniWordmark()
        JeniWordmark(size: 17, markOnly: true)
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

// MARK: - LuxuryPressable (v1.1.1, 2026-06-19; rewritten 2026-06-19)
//
// Instant press feedback for any tappable surface. Modern iOS apps
// (Notion, Linear, Things, Apple Stocks) flip a subtle scale + dim
// the moment a finger touches the target so the action visibly
// registers BEFORE the destination cover / sheet / push animates in.
// Without it the tap feels frozen for the 100-200ms while heavy
// destinations mount.
//
// Implementation: built on `ButtonStyle` so SwiftUI's native button
// system owns press detection. That gives us, for free:
//   • scroll-vs-tap discrimination (touch that converts to a scroll
//     drag CANCELS the press automatically — the user doesn't get
//     a press flash while scrolling, AND the scroll isn't blocked)
//   • cancel-on-drag-away (touch that wanders off the target snaps
//     the press state back)
//
// The earlier v1.1.1 implementation used `.simultaneousGesture(
// DragGesture(minimumDistance: 0))` which captured every touch
// start — including scroll initiations — and made Home un-scrollable
// while also stealing taps from underlying handlers. ButtonStyle is
// the correct primitive for this; falling back to it.
//
// Usage:
//   // Wrap content in a Button + apply the style. This is the
//   // recommended path for new code:
//   Button { action() } label: { rowContent }
//       .buttonStyle(LuxuryPressButtonStyle())
//
//   // OR — back-compat shim for existing surfaces that use
//   // .onTapGesture. Wraps the content in a Button under the hood,
//   // so scroll + tap arbitrate correctly:
//   rowContent.luxuryPressFeedback { action() }
//
// The feedback uses .interactiveSpring with high damping (0.86) so
// it lands snappy + non-bouncy — closer to a button's affordance
// than a celebratory animation.

/// Drop-in ButtonStyle for any new tappable surface. Wraps the label
/// in a press-aware Button so scroll + tap arbitrate correctly.
///
/// v1.1.1 (2026-06-19, second pass) — depth bumped (scale 0.985→0.97,
/// brightness -0.025→-0.06) so the press is actually visible at
/// thumb-tip glance. Adds a tap-acknowledge linger: the pressed
/// state holds for 220ms after release before snapping back, so even
/// when the destination cover takes 100-300ms to boot the user sees
/// confirmation that the tap landed.
struct LuxuryPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LuxuryPressButtonBody(configuration: configuration)
    }
}

private struct LuxuryPressButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var lingerPressed: Bool = false

    private var pressed: Bool { configuration.isPressed || lingerPressed }

    var body: some View {
        configuration.label
            .scaleEffect(pressed ? 0.97 : 1.0)
            .brightness(pressed ? -0.06 : 0)
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.86), value: pressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressedNow in
                if isPressedNow {
                    Haptics.soft()
                    lingerPressed = false
                } else if wasPressed {
                    // Touch up → hold the pressed look for ~220ms so
                    // the user sees "tap acknowledged" even when the
                    // destination takes time to mount.
                    lingerPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        lingerPressed = false
                    }
                }
            }
    }
}

// p66 — LuxuryPressFeedback + .luxuryPressFeedback() deleted: zero
// call sites (the onTapGesture era it back-compatted is gone).
