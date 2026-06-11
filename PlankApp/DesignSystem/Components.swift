import SwiftUI

// (CTAButtonStyle deleted 2026-06-11 — the one-CTA system
// (JFContinueButton) absorbed every production call site; the
// three-variant style family had zero consumers left.)

// MARK: - WeAskBecauseRow
//
// Inline trust-anchor block for onboarding v2 sensitive questions
// (sleep, stress, hormonal stage, GLP-1, eating). Two pieces of
// content stacked vertically:
//
//   • A small lowercase citation chip — the credibility license
//     ("stanford 2023", "lancet 2022", "who 2020"). Per the data-
//     provenance rule, every citation must be real; never fabricate.
//   • A one-line "we ask because *<reason>*" body — italic-Fraunces
//     on the punch word(s) per JeniFit voice signal.
//
// Slots between the screen header and the option list. Visually
// quiet: muted gray, small type, ample whitespace. Existence is the
// trust signal; volume is not. ZOE uses citation chips heavily, but
// JeniFit makes them work via restraint (one chip per screen, max).
//
// Usage:
//   WeAskBecauseRow(
//       citation: "stanford 2023",
//       reason: "cortisol regulation shapes recovery.",
//       italicWords: ["cortisol", "recovery"]
//   )

struct WeAskBecauseRow: View {
    let citation: String?
    let reason: String
    let italicWords: [String]

    init(citation: String? = nil, reason: String, italicWords: [String] = []) {
        self.citation = citation
        self.reason = reason
        self.italicWords = italicWords
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let citation {
                Text(citation)
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.lowercase)
                    .tracking(0.6)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .stroke(Palette.divider, lineWidth: 1)
                    )
            }
            ItalicAccentText(
                "we ask because " + reason,
                italic: italicWords,
                baseFont: .custom("Fraunces72pt-Regular", size: 13),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 13),
                color: Palette.textSecondary,
                alignment: .leading
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.screenPadding)
    }
}

#Preview("WeAskBecauseRow — with citation") {
    VStack(alignment: .leading, spacing: Space.md) {
        WeAskBecauseRow(
            citation: "stanford 2023",
            reason: "cortisol regulation shapes recovery, sleep, and how your body holds weight.",
            italicWords: ["cortisol", "recovery", "weight"]
        )
        WeAskBecauseRow(
            citation: "endocrine society 2025",
            reason: "GLP-1s shift roughly 40% of loss to lean mass — your program protects what matters.",
            italicWords: ["lean mass", "protects"]
        )
        WeAskBecauseRow(
            reason: "cycle stage shifts hunger, energy, and recovery week to week.",
            italicWords: ["cycle", "hunger", "energy"]
        )
    }
    .padding()
    .background(Palette.bgPrimary)
}

// MARK: - ItalicAccentText
//
// Renders a base string with selected substrings rendered in Fraunces italic
// for editorial emphasis (e.g., "Become *her* in 30 days"). Implementation
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
//       "Become her in 30 days.",
//       italic: ["her"],
//       baseFont: Typo.title,
//       italicFont: Typo.titleItalic
//   )

struct ItalicAccentText: View {
    let base: String
    let italic: [String]
    var baseFont: Font = Typo.title
    var italicFont: Font = Typo.titleItalic
    var color: Color = Palette.textPrimary
    var alignment: TextAlignment = .leading

    init(_ base: String,
         italic: [String],
         baseFont: Font = Typo.title,
         italicFont: Font = Typo.titleItalic,
         color: Color = Palette.textPrimary,
         alignment: TextAlignment = .leading) {
        self.base = base
        self.italic = italic
        self.baseFont = baseFont
        self.italicFont = italicFont
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        composed
            .foregroundStyle(color)
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
                    output = output + Text(String(base[cursor..<match.lowerBound])).font(baseFont)
                }
                output = output + Text(String(base[match])).font(italicFont)
                cursor = match.upperBound
            } else {
                output = output + Text(String(base[cursor..<end])).font(baseFont)
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
        /// accent ("you *became* her."). `base` is the full sentence
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

    @State private var revealedCount: Int = 0
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
    }

    private func runCascade() {
        guard revealedCount == 0 else { return }
        if reduceMotion {
            revealedCount = lines.count
            return
        }
        for i in 0..<lines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * perLineDelay) {
                Haptics.soft()
                revealedCount = i + 1
            }
        }
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

// MARK: - OnboardingOptionCard
//
// Tappable row used in onboarding multi-choice screens. Layout:
//   [icon circle] [title / optional subtitle] ......... [radio]
// Selected state swaps the border to accent + lights the radio dot. Card bg
// stays bgElevated in both states so the selected row reads as "highlighted"
// rather than "filled" — closer to JustFit / CalAI than to the chunkier iOS
// settings cell.

struct OnboardingOptionCard: View {
    var icon: String? = nil
    /// 17d-1: when set, the icon circle renders this sticker asset
    /// instead of the SF Symbol (icon param ignored). Used by Q140
    /// (identity feeling) + Q141 (reward) where each option deserves
    /// a JeniFit visual handle rather than a generic glyph.
    var sticker: StickerName? = nil
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    /// v1.0.7 (2026-06-07): when both icon and sticker are nil, render
    /// the card in compact mode — no decorative circle, shorter min
    /// height, tighter vertical padding. Without this, callers like
    /// case 169 (cuisine multi-pick with 8 options) overflow the
    /// screen: 8 cards × 72pt + chrome pushes the title under the
    /// status bar and the Continue button below the visible area.
    private var isCompact: Bool { icon == nil && sticker == nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                if !isCompact {
                    ZStack {
                        Circle()
                            .fill(Palette.accentSubtle)
                            .frame(width: 44, height: 44)
                        if let sticker {
                            Image(sticker.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .opacity(sticker.style.opacity)
                        } else if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title)
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: Space.sm)

                ZStack {
                    Circle()
                        .stroke(isSelected ? Palette.accent : Palette.divider, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, isCompact ? Space.sm : Space.md)
            .frame(minHeight: isCompact ? 52 : 72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PricingCard
//
// Used on the paywall to present a single plan. The yearly card carries a
// floating "Save N%" badge and the selected plan gets a 2pt accent border.
// Weekly stays bordered with the divider color so the visual weight tilts
// toward the yearly choice even before selection.
//
// Pricing copy (price + perWeekEquivalent) is passed in as already-formatted
// strings — the caller (PaywallView) sources these from RevenueCat offerings,
// not hardcoded.

struct PricingCard: View {
    let title: String
    let price: String
    var perWeekEquivalent: String? = nil
    var savings: String? = nil
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    if let perWeekEquivalent {
                        Text(perWeekEquivalent)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: Space.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(Typo.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.textPrimary)
                    if let savings {
                        Text(savings)
                            .font(Typo.eyebrow)
                            .tracking(1.5)
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
            .padding(Space.md)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(Typo.eyebrow)
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 4)
                        .background(Palette.accent, in: Capsule())
                        .offset(x: -Space.md, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PricingCardCompact
//
// Vertical-stack compact variant of PricingCard for the v2 single-screen
// paywall (2026-05-31). Built to fit 3-across on iPhone 14 (~110pt wide ×
// 150pt tall each). Layout: title → price → subtitle → optional badge.
//
// 2026 luxury chrome lock: 1pt border (textSecondary @ 20%), 16pt corners,
// NO shadow, NO gradient, near-black border on selected (textPrimary @ 90%)
// plus subtle accent-tint fill. Selected state pulls the eye via border
// weight + fill warmth, not scale or glow. Matches Hims/Hers, Glossier,
// Cal AI April 2026 convention.
//
// Badge ("3-day free" / "best value") sits as a floating pill at the top
// edge, half-clipping out of the card so it reads as label-on-content not
// chrome-inside-chrome.

struct PricingCardCompact: View {
    let title: String
    let price: String
    var subtitle: String? = nil
    var anchor: String? = nil   // strikethrough above price (e.g. "$95.88")
    var badge: String? = nil
    var badgeKind: BadgeKind = .neutral
    let isSelected: Bool
    var isDefault: Bool = false
    let action: () -> Void

    enum BadgeKind {
        case neutral   // accent-subtle tint — "most popular"
        case trial     // near-black fill — "3-day free"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let anchor {
                    Text(anchor)
                        .font(.system(size: 11))
                        .strikethrough(true, color: Palette.textSecondary.opacity(0.75))
                        .foregroundStyle(Palette.textSecondary.opacity(0.75))
                        .lineLimit(1)
                }

                Text(price)
                    .font(.custom("Fraunces72pt-SemiBold", size: 22))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 142)
            .background(cardFill)
            .overlay(cardBorder)
            .overlay(alignment: .top) { badgePill }
        }
        .buttonStyle(.plain)
    }

    /// Card fill — warmer cream on default (4% accent tint) so the
    /// recommended tier carries quiet visual weight even before tap.
    /// Selected adds another 2% accent tint on top.
    private var cardFill: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fillColor)
    }

    private var fillColor: Color {
        if isSelected && isDefault { return Palette.accent.opacity(0.08) }
        if isSelected              { return Palette.accent.opacity(0.06) }
        if isDefault               { return Palette.accent.opacity(0.04) }
        return Palette.bgElevated
    }

    /// Border weight stack (research Q3): default = 2pt warm-red even
    /// when not selected (anchors the recommendation visually). Selected
    /// non-default = 1.5pt textPrimary near-black. Untouched = hairline.
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        if isDefault            { return Palette.accent }
        if isSelected           { return Palette.textPrimary.opacity(0.85) }
        return Palette.textSecondary.opacity(0.18)
    }

    private var borderWidth: CGFloat {
        if isDefault  { return 2 }
        if isSelected { return 1.5 }
        return 1
    }

    @ViewBuilder
    private var badgePill: some View {
        if let badge {
            Text(badge)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(badgeKind == .trial ? Palette.textInverse : Palette.textInverse)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(badgeKind == .trial ? Palette.textPrimary : Palette.accent)
                )
                .offset(y: -8)
        }
    }
}

// MARK: - DayBadge
//
// Small editorial pill used for day-count labels in the activity calendar,
// streak indicators, and "Day 7 of 30" copy on the paywall. AccentSubtle bg
// keeps it quiet enough to drop into a card without competing.

struct DayBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typo.eyebrow)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 4)
            .background(Palette.accentSubtle, in: Capsule())
    }
}

// MARK: - JeniFitWordmark
//
// The brand mark: lowercase Fraunces SemiBold flanking a thin Light-weight
// bullet ("jeni • fit"). Used on the onboarding top bar. Single canonical
// size so the brand reads identically everywhere; if a future surface
// needs scale variants, parametrize then.
//
// The bullet uses Fraunces72pt-Light at a smaller size with thin spaces
// (U+2009) padding either side — SemiBold's bullet glyph reads chunky next
// to the lowercase letterforms, so we step it down for breathing room.

struct JeniFitWordmark: View {
    var color: Color = Palette.textPrimary

    var body: some View {
        let base = Typo.title
        let separator = Font(UIFont(name: "Fraunces72pt-Light", size: 26)
                             ?? .systemFont(ofSize: 26))

        return (Text("jeni").font(base)
                + Text("\u{2009}•\u{2009}").font(separator)
                + Text("fit").font(base))
            .foregroundStyle(color)
    }
}

// MARK: - EditorialPlaceholder
//
// Holds the slot where coach photography will eventually live. Until the
// shoot happens, we render a diagonal-stripe block with a small label tag
// in the corner so the placeholder reads "intentionally unfinished" rather
// than "broken layout". Stripes use accent over accentSubtle for a quiet
// pink-on-pink hash; the label uses the eyebrow token in inverse on a 60%
// black scrim so it stays legible regardless of stripe contrast.

struct EditorialPlaceholder: View {
    let label: String
    var cornerRadius: CGFloat = Radius.lg

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.accentSubtle

            Canvas { context, size in
                let spacing: CGFloat = 18
                let diag = sqrt(size.width * size.width + size.height * size.height)
                var x: CGFloat = -diag
                while x < size.width + diag {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: -diag))
                    path.addLine(to: CGPoint(x: x + diag, y: diag))
                    context.stroke(path,
                                   with: .color(Palette.accent.opacity(0.18)),
                                   lineWidth: 6)
                    x += spacing
                }
            }

            Text(label)
                .font(Typo.eyebrow)
                .foregroundStyle(Color.white)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6), in: Capsule())
                .padding(Space.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - OnboardingProgressBar
//
// 4pt-tall capsule progress indicator that lives at the top of every
// onboarding screen. Fill is dusty rose on a soft divider track. Animates
// the width between screens with easeOut so forward motion always reads
// as forward (a spring would overshoot on small fraction deltas like
// 69% → 73% and look like a regression).

struct OnboardingProgressBar: View {
    let fraction: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.divider)
                    .frame(height: 4)
                Capsule().fill(Palette.accent)
                    .frame(width: max(8, geo.size.width * fraction), height: 4)
                    .animation(.easeOut(duration: 0.35), value: fraction)
            }
        }
        .frame(height: 4)
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

struct SectionDividerScreen: View {
    let partNumber: Int
    let title: String
    let supporting: String
    let dwellSeconds: Double
    let onAdvance: () -> Void
    // her75 Phase 3 (2026-06-10) — sticker params removed entirely.
    // Dividers are Archetype B (audit §2): editorial eyebrow + centered
    // 38pt heroHeadline cascade + ONE supporting line. Total cream
    // restraint per IMG_6280; the eyebrow carries the chapter beat.

    @State private var subVisible = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            // Editorial eyebrow — lowercase "part one" register at the
            // 11pt tracked-caps mark (her75 IMG_6279 footer convention).
            Text("part \(spelledPart(partNumber))")
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.accent)

            Spacer().frame(height: 4)

            // Line-cascade with `.soft` haptic per line at the ONE
            // in-app hero register (38pt heroHeadline post-re-ladder).
            LineCascadeText(
                lines: cascadeLines,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .center,
                lineSpacing: Typo.heroHeadlineLineGap,
                perLineDelay: 0.42
            )
            .padding(.horizontal, Space.lg)

            Spacer().frame(height: 8)

            Text(supporting)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
                .opacity(subVisible ? 1 : 0)
                .offset(y: subVisible ? 0 : 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Subhead fades in after the cascade's final line lands
            // (cascadeLines.count * 0.42s + 0.15s breathing room).
            let subDelay = Double(cascadeLines.count) * 0.42 + 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + subDelay) {
                withAnimation(.easeOut(duration: 0.4)) { subVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + dwellSeconds) {
                onAdvance()
            }
        }
    }

    /// Splits the title into 1-2 cascade lines on a natural break
    /// (`/`, ` / `, or single line if no marker). Authors can write
    /// `"your story"` for single-line OR `"the version / you're becoming"`
    /// for 2-line stacked. Designer-locked: 2-line bridges only when
    /// both halves carry semantic substance (per
    /// [[feedback-hero-typography-rule]]).
    private var cascadeLines: [LineCascadeText.Line] {
        if title.contains("/") {
            let parts = title.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.map { LineCascadeText.Line.plain($0) }
        }
        return [.plain(title)]
    }

    private func spelledPart(_ n: Int) -> String {
        switch n {
        case 1: return "one"
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        default: return "\(n)"
        }
    }
}

// MARK: - ConfirmationBadge
//
// Centered toast shown for ~1.2s after major onboarding commits. Used
// sparingly (5–7 times across the full flow, not after every question)
// so each appearance reads as a moment of acknowledgement rather than
// noise. Cocoa pill, cream label, dusty rose checkmark dot.

struct ConfirmationBadge: View {
    let message: String
    var accentSticker: StickerName? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: Space.sm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .frame(width: 22, height: 22)
                    .background(Palette.accent, in: Circle())

                Text(message)
                    .font(Typo.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.textInverse)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md)
            .background(Palette.bgInverse, in: RoundedRectangle(cornerRadius: Radius.md))

            // Sticker accent peeks out of the top-right corner of the
            // pill — "decoration on a label" pattern, not scatter.
            // accessibilityHidden + non-interactive via Sticker's own
            // modifiers in Phase 14b.
            if let accent = accentSticker {
                Sticker(placement: StickerPlacement(
                    sticker: accent,
                    position: .zero,  // unused at this layer (no GeometryReader)
                    size: 32,
                    rotation: 12,
                    phaseDelay: 0
                ))
                .offset(x: 14, y: -14)
            }
        }
        .padding(.horizontal, Space.lg)
    }
}

// MARK: - BiometricSlider
//
// Vertical ruler picker for height / weight / target weight. Reads as
// a tape measure / scale: big Fraunces value at top, vertical tick
// column below, cocoa selection bar across the ruler's center
// marking the current tick, drag-to-scroll with per-tick haptic.
//
// Geometry note (the "ruler-stops-rendering-past-6'2"" bug history):
// the VStack of ticks naturally overflows the rulerHeight frame —
// 770pt for height, 1700pt for weight. SwiftUI's default alignment
// for an oversized child inside a fixed-height frame is .center,
// which positions the VStack with its center at the frame's center.
// That re-centering happens AFTER any internal ZStack alignment, so
// the contentOffset formula (rulerHeight/2 - (stepIndex + 0.5) *
// tickHeight) — which is correct relative to a top-pinned VStack —
// landed every tick ~rulerHeight/2 above where it should be, with
// high stepIndex values clipped past the frame's bottom.
//
// Fix: pin to top on BOTH the inner ZStack AND the outer
// .frame(height:) modifier. ZStack(alignment: .top) anchors VStack
// content at ZStack-y=0; .frame(height: rulerHeight, alignment: .top)
// keeps that anchor through the outer height clamp so the content
// offset math holds across the full range.

struct BiometricSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    /// How many `step` units per major (labeled) tick. Default 10 fits
    /// metric cm/kg cleanly; imperial overrides per config (12 for
    /// whole-foot height labels).
    var majorTickEvery: Int = 10
    /// Optional intermediate tier — every N steps a tick that's bolder
    /// than minor but unlabeled. Use for rhythm between majors (e.g.,
    /// half-foot mediums between whole-foot labels).
    var mediumTickEvery: Int? = nil
    /// Subscript unit shown below the big value (e.g. "ft", "cm"). nil
    /// hides it. The toggle pill in the wrapper screen still carries
    /// the active unit, so this is mostly redundant for the height
    /// case and can be left nil in practice.
    var unitLabel: String? = nil

    @State private var dragStartValue: Double?
    @State private var lastTickValue: Double?

    private let tickHeight: CGFloat = 10
    private let rulerHeight: CGFloat = 380
    private let majorTickWidth: CGFloat = 28
    private let mediumTickWidth: CGFloat = 16
    private let minorTickWidth: CGFloat = 10
    private let labelColumnWidth: CGFloat = 28
    private let labelTickGap: CGFloat = 8
    /// Total width of the left ruler column (label + tick + a hair of
    /// breathing room). The big value display fills the remainder.
    private let rulerColumnWidth: CGFloat = 88

    private var totalSteps: Int {
        Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1
    }

    private var stepIndex: Double {
        (value - range.lowerBound) / step
    }

    /// Vertical offset that places the selected tick at the ruler's
    /// vertical center. Each tick row sits at VStack-y
    /// `(i + 0.5) * tickHeight`; we shift the whole VStack so the
    /// selected tick aligns with the indicator line at rulerHeight/2.
    private var contentOffset: CGFloat {
        rulerHeight / 2 - (CGFloat(stepIndex) + 0.5) * tickHeight
    }

    /// Major-tick label text. Strips the unit suffix from the format
    /// closure ("150 cm" → "150"). For imperial whole-foot ticks the
    /// format produces e.g. "5'" — drop the apostrophe so the slim
    /// label column reads just the number.
    private func labelFor(_ index: Int) -> String {
        let raw = format(range.lowerBound + Double(index) * step)
        if let space = raw.lastIndex(of: " ") {
            return String(raw[..<space])
        }
        if raw.hasSuffix("'") {
            return String(raw.dropLast())
        }
        return raw
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // ── Left: ruler (labels + ticks + indicator). ──
            ZStack(alignment: .center) {
                VStack(spacing: 0) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        let major = (i % majorTickEvery == 0)
                        let medium = !major && (mediumTickEvery.map { i % $0 == 0 } ?? false)
                        let w: CGFloat = major ? majorTickWidth
                                       : medium ? mediumTickWidth
                                                : minorTickWidth
                        let h: CGFloat = major ? 2 : medium ? 1.5 : 1
                        let opacity: Double = major ? 0.65
                                            : medium ? 0.45
                                                     : 0.25
                        HStack(spacing: labelTickGap) {
                            // Right-aligned label column. Empty string
                            // reserves the same width on non-major rows
                            // so the tick column lines up vertically.
                            Text(major ? labelFor(i) : "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(width: labelColumnWidth, alignment: .trailing)
                            Rectangle()
                                .fill(Palette.textSecondary.opacity(opacity))
                                .frame(width: w, height: h)
                            Spacer(minLength: 0)
                        }
                        .frame(height: tickHeight)
                    }
                }
                .offset(y: contentOffset)

                // Horizontal accent indicator — extends from the right
                // of the label column across the tick column and a hair
                // beyond, marking the selected row.
                Rectangle()
                    .fill(Palette.accent)
                    .frame(height: 2)
                    .padding(.leading, labelColumnWidth + labelTickGap - 4)
            }
            .frame(width: rulerColumnWidth, height: rulerHeight)
            .clipped()

            // ── Right: big value display, centered vertically. ──
            VStack(spacing: 4) {
                Text(format(value))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .animation(.easeOut(duration: 0.12), value: value)
                if let unitLabel {
                    Text(unitLabel)
                        .font(Typo.caption)
                        .tracking(1.5)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: rulerHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if dragStartValue == nil {
                        dragStartValue = value
                        lastTickValue = value
                    }
                    guard let start = dragStartValue else { return }
                    // Drag down → smaller values (ruler scrolls down,
                    // exposing the lower end of the range above the
                    // indicator). Drag up → larger values.
                    let stepsDelta = -gesture.translation.height / tickHeight
                    let startIndex = (start - range.lowerBound) / step
                    let newIndex = (startIndex + stepsDelta).rounded()
                    let clampedIndex = max(0, min(Double(totalSteps - 1), newIndex))
                    let newValue = range.lowerBound + clampedIndex * step
                    if newValue != value {
                        value = newValue
                        if let last = lastTickValue, last != newValue {
                            Haptics.soft()
                        }
                        lastTickValue = newValue
                    }
                }
                .onEnded { _ in
                    dragStartValue = nil
                    lastTickValue = nil
                }
        )
    }
}


// MARK: - BiometricRulerConfig + BiometricRulerScreen
//
// Wraps BiometricSlider with a unit toggle (cm/ft, kg/lb). Storage
// in the parent stays metric — the wrapper presents a per-unit
// binding to BiometricSlider via toMetric / fromMetric round-trip,
// so internal data never drifts off the metric grid. .id(unit) on
// the inner BiometricSlider forces a clean rebuild on toggle so
// the new range / step / format / majorTickEvery configuration
// takes effect.

struct BiometricRulerConfig {
    let range: ClosedRange<Double>
    let step: Double
    let majorEvery: Int
    /// Optional intermediate tick tier (e.g., every 5 cm on height) —
    /// renders with bolder weight + length than minor but no label.
    /// Default nil for the binary major/minor cadence.
    var mediumEvery: Int? = nil
    let format: (Double) -> String
    /// Toggle button label, e.g., "cm" / "ft" / "kg" / "lb".
    let unitName: String
}

struct BiometricRulerScreen<Annotation: View>: View {
    @Binding var valueMetric: Double
    let metric: BiometricRulerConfig
    let imperial: BiometricRulerConfig
    let toMetric: (Double) -> Double
    let fromMetric: (Double) -> Double
    @ViewBuilder var annotation: () -> Annotation

    @State private var useImperial = true   // US-first default

    private var activeConfig: BiometricRulerConfig {
        useImperial ? imperial : metric
    }

    /// Bridge between the parent's metric binding and BiometricSlider's
    /// active-unit value. Reads convert metric → active; writes convert
    /// active → metric. Toggling changes display only; underlying
    /// metric storage stays exact.
    private var activeBinding: Binding<Double> {
        Binding(
            get: { useImperial ? fromMetric(valueMetric) : valueMetric },
            set: { valueMetric = useImperial ? toMetric($0) : $0 }
        )
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            // Two-segment toggle pill — accent fill on the active side,
            // divider stroke around the pair. Wrapped in Spacer-pill-
            // Spacer to explicitly center horizontally regardless of
            // the parent VStack's alignment defaults. fixedSize on the
            // vertical axis locks the pill's intrinsic height so the
            // wrapper VStack can't compress it when the inner ruler +
            // annotation push total content close to available height
            // (the case-132 / case-133 "pill missing" walkthrough
            // report).
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    unitSegment(label: imperial.unitName, isImperial: true)
                    unitSegment(label: metric.unitName, isImperial: false)
                }
                .padding(2)
                .background(Palette.bgElevated, in: Capsule())
                .overlay(Capsule().stroke(Palette.divider, lineWidth: 1))
                Spacer()
            }
            .fixedSize(horizontal: false, vertical: true)

            // .id rebuilds the inner ruler on toggle so the new range
            // grid + tick layout takes effect cleanly.
            // .fixedSize on the vertical axis locks the slider's
            // intrinsic 344pt height so the wrapper VStack can't
            // compress it — without this, the outer Spacer-driven
            // layout in jfSliderScreen squeezed the ruler frame on
            // tall content (case 132 BMI annotation, case 133 goal
            // validation) and the inner ZStack(alignment: .top)
            // alignment fix lost its effect, regressing the upper-
            // bound height clip.
            BiometricSlider(
                value: activeBinding,
                range: activeConfig.range,
                step: activeConfig.step,
                format: activeConfig.format,
                majorTickEvery: activeConfig.majorEvery,
                mediumTickEvery: activeConfig.mediumEvery
            )
            .fixedSize(horizontal: false, vertical: true)
            .id(useImperial ? "imp" : "met")

            annotation()
        }
    }

    /// Single segment of the toggle pill. Uses Text + onTapGesture
    /// rather than Button — wrapping the segment in a Button with a
    /// per-state Capsule background produced animation glitches when
    /// the active segment flipped (the cm-active branch could render
    /// inconsistently mid-transition). Direct onTapGesture on the
    /// already-shaped Text avoids that.
    private func unitSegment(label: String, isImperial: Bool) -> some View {
        let active = useImperial == isImperial
        return Text(label)
            .font(Typo.eyebrow)
            .tracking(2)
            .foregroundStyle(active ? Palette.textInverse : Palette.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 6)
            .background(active ? Palette.bgInverse : Color.clear, in: Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                Haptics.light()
                withAnimation(.easeOut(duration: 0.18)) { useImperial = isImperial }
            }
    }
}

// MARK: - HorizontalBiometricSlider
//
// JustFit-style horizontal ruler — used by the weight and goal-weight
// onboarding screens. Big value display on top with a small unit
// subscript, vertical accent indicator dropping into a horizontal
// tick row with major number labels above the major ticks. Drag the
// row left/right to change value; the row scrolls under the fixed
// center indicator.
//
// Optional bandRange overlays a faded accent block between two values
// — used on the goal-weight screen to visualize the loss range
// between current and goal.

struct HorizontalBiometricSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    /// Major ticks every N steps. Major ticks render with a numeric
    /// label above and a taller, bolder tick mark.
    var majorTickEvery: Int = 10
    /// Optional middle tier — between minor and major. nil = binary.
    var mediumTickEvery: Int? = nil
    /// Subscript unit shown next to the big value (e.g. "Lbs", "kg").
    /// nil hides it.
    var unitLabel: String? = nil
    /// Faded accent band rendered between two values on the ruler.
    /// Used on goal-weight screen — band spans current ↔ goal.
    var bandRange: ClosedRange<Double>? = nil

    @State private var dragStartValue: Double?
    @State private var lastTickValue: Double?

    private let tickSpacing: CGFloat = 8     // horizontal pt per step
    private let rulerHeight: CGFloat = 84
    private let majorTickHeight: CGFloat = 28
    private let mediumTickHeight: CGFloat = 16
    private let minorTickHeight: CGFloat = 10
    private let indicatorHeight: CGFloat = 56

    private var totalSteps: Int {
        Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1
    }

    private var stepIndex: Double {
        (value - range.lowerBound) / step
    }

    private func xForStep(_ s: Double, centerX: CGFloat) -> CGFloat {
        // Position step `s` so its center sits at the right pixel —
        // selected stepIndex always lands at centerX, every other tick
        // offsets by (s - stepIndex) * tickSpacing.
        centerX + (CGFloat(s) - CGFloat(stepIndex)) * tickSpacing
    }

    /// Pulls the trailing unit text off a formatted value so the
    /// big number can render alone with a smaller unit subscript.
    /// Returns (number, unit). Imperial height ("5'8\"") collapses
    /// into the number with no unit since the symbols carry meaning.
    private func splitUnit(_ formatted: String) -> (String, String?) {
        if let space = formatted.lastIndex(of: " ") {
            let num = String(formatted[..<space])
            let unit = String(formatted[formatted.index(after: space)...])
            return (num, unit)
        }
        return (formatted, nil)
    }

    var body: some View {
        let (numberText, splitUnitText) = splitUnit(format(value))
        let displayedUnit = unitLabel ?? splitUnitText

        VStack(spacing: 0) {
            // Big value display + small unit subscript.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(numberText)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let u = displayedUnit {
                    Text(u)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            .animation(.easeOut(duration: 0.12), value: value)

            // Vertical indicator line dropping from value to ruler.
            Rectangle()
                .fill(Palette.accent)
                .frame(width: 2, height: indicatorHeight)
                .padding(.top, Space.xs)

            // Ruler row — labels + ticks scroll under a fixed indicator.
            GeometryReader { geo in
                let centerX = geo.size.width / 2

                ZStack {
                    // Faded loss-range band (goal-weight screen). Rendered
                    // before ticks so ticks read on top of the soft fill.
                    if let band = bandRange,
                       band.upperBound > band.lowerBound {
                        let bandLowerStep = (band.lowerBound - range.lowerBound) / step
                        let bandUpperStep = (band.upperBound - range.lowerBound) / step
                        let bandWidth = CGFloat(bandUpperStep - bandLowerStep) * tickSpacing
                        let bandCenterStep = (bandLowerStep + bandUpperStep) / 2
                        Rectangle()
                            .fill(Palette.accentSubtle)
                            .frame(width: bandWidth, height: majorTickHeight)
                            .position(x: xForStep(bandCenterStep, centerX: centerX),
                                      y: rulerHeight - majorTickHeight / 2 - 4)
                    }

                    // Major-tick number labels above the ticks.
                    ForEach(0..<totalSteps, id: \.self) { i in
                        if i % majorTickEvery == 0 {
                            let labelText = splitUnit(format(range.lowerBound + Double(i) * step)).0
                            Text(labelText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .position(x: xForStep(Double(i), centerX: centerX),
                                          y: rulerHeight - majorTickHeight - 16)
                        }
                    }

                    // Tick marks anchored to the bottom of the ruler.
                    ForEach(0..<totalSteps, id: \.self) { i in
                        let major = (i % majorTickEvery == 0)
                        let medium = !major && (mediumTickEvery.map { i % $0 == 0 } ?? false)
                        let h: CGFloat = major ? majorTickHeight
                                       : medium ? mediumTickHeight
                                                : minorTickHeight
                        let opacity: Double = major ? 0.7
                                            : medium ? 0.5
                                                     : 0.28
                        Rectangle()
                            .fill(Palette.textSecondary.opacity(opacity))
                            .frame(width: 1, height: h)
                            .position(x: xForStep(Double(i), centerX: centerX),
                                      y: rulerHeight - h / 2 - 4)
                    }

                    // Center selection indicator — extends a hair above
                    // the major ticks for emphasis.
                    Rectangle()
                        .fill(Palette.accent)
                        .frame(width: 2, height: majorTickHeight + 12)
                        .position(x: centerX, y: rulerHeight - (majorTickHeight + 12) / 2 - 2)
                }
                .frame(width: geo.size.width, height: rulerHeight)
                .contentShape(Rectangle())
                .clipped()
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if dragStartValue == nil {
                                dragStartValue = value
                                lastTickValue = value
                            }
                            guard let start = dragStartValue else { return }
                            // Drag right → values decrease (the ruler
                            // scrolls right under the fixed indicator,
                            // exposing smaller numbers). Drag left →
                            // values increase.
                            let stepsDelta = -gesture.translation.width / tickSpacing
                            let startIndex = (start - range.lowerBound) / step
                            let newIndex = (startIndex + stepsDelta).rounded()
                            let clampedIndex = max(0, min(Double(totalSteps - 1), newIndex))
                            let newValue = range.lowerBound + clampedIndex * step
                            if newValue != value {
                                value = newValue
                                if let last = lastTickValue, last != newValue {
                                    Haptics.soft()
                                }
                                lastTickValue = newValue
                            }
                        }
                        .onEnded { _ in
                            dragStartValue = nil
                            lastTickValue = nil
                        }
                )
            }
            .frame(height: rulerHeight)
        }
    }
}


// MARK: - HorizontalBiometricRulerScreen
//
// Wraps HorizontalBiometricSlider with the same unit-toggle pill the
// vertical ruler uses, plus a free annotation slot below for BMI /
// goal cards. Storage in the parent stays metric — the wrapper
// presents a per-unit binding via toMetric / fromMetric.

struct HorizontalBiometricRulerScreen<Annotation: View>: View {
    @Binding var valueMetric: Double
    let metric: BiometricRulerConfig
    let imperial: BiometricRulerConfig
    let toMetric: (Double) -> Double
    let fromMetric: (Double) -> Double
    /// Optional band range expressed in METRIC units. Wrapper converts
    /// to active-unit coordinates so the band scrolls correctly when
    /// the user toggles between kg and lb.
    var bandMetric: ClosedRange<Double>? = nil
    @ViewBuilder var annotation: () -> Annotation

    @State private var useImperial = true   // US-first default

    private var activeConfig: BiometricRulerConfig {
        useImperial ? imperial : metric
    }

    private var activeBinding: Binding<Double> {
        Binding(
            get: { useImperial ? fromMetric(valueMetric) : valueMetric },
            set: { valueMetric = useImperial ? toMetric($0) : $0 }
        )
    }

    private var activeBand: ClosedRange<Double>? {
        guard let m = bandMetric else { return nil }
        let lo = useImperial ? fromMetric(m.lowerBound) : m.lowerBound
        let hi = useImperial ? fromMetric(m.upperBound) : m.upperBound
        guard hi > lo else { return nil }
        return lo...hi
    }

    var body: some View {
        VStack(spacing: Space.md) {
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    unitSegment(label: imperial.unitName, isImperial: true)
                    unitSegment(label: metric.unitName, isImperial: false)
                }
                .padding(2)
                .background(Palette.bgElevated, in: Capsule())
                .overlay(Capsule().stroke(Palette.divider, lineWidth: 1))
                Spacer()
            }
            .fixedSize(horizontal: false, vertical: true)

            HorizontalBiometricSlider(
                value: activeBinding,
                range: activeConfig.range,
                step: activeConfig.step,
                format: activeConfig.format,
                majorTickEvery: activeConfig.majorEvery,
                mediumTickEvery: activeConfig.mediumEvery,
                unitLabel: activeConfig.unitName,
                bandRange: activeBand
            )
            .id(useImperial ? "imp" : "met")

            annotation()
        }
    }

    private func unitSegment(label: String, isImperial: Bool) -> some View {
        let active = useImperial == isImperial
        return Text(label)
            .font(Typo.eyebrow)
            .tracking(2)
            .foregroundStyle(active ? Palette.textInverse : Palette.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 6)
            .background(active ? Palette.bgInverse : Color.clear, in: Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                Haptics.light()
                withAnimation(.easeOut(duration: 0.18)) { useImperial = isImperial }
            }
    }
}


// MARK: - BodyTypeSlider
//
// 6-position discrete slider (0–5) for "where are you now" /
// "where do you want to be" body-shape questions. Renders the
// current and target as illustrative labels above the slider.

struct BodyTypeSlider: View {
    @Binding var position: Int
    let labels: [String]   // length must be 6
    /// Optional upper bound on the slider (inclusive). Renders dots
    /// above this index in a disabled state so the user sees the full
    /// range with a clear "out of reach" affordance, rather than a
    /// shortened track that reads as a render bug.
    var maxPosition: Int? = nil
    /// Optional read-only marker showing a reference position on the
    /// track (e.g., "where you said you currently are" on the goal
    /// body type screen). Renders as a small accent dot below the row
    /// with a "you" caption.
    var markerPosition: Int? = nil

    private let dotSize: CGFloat = 14
    private let selectedDotSize: CGFloat = 22
    private let trackHeight: CGFloat = 2
    private let rowHeight: CGFloat = 60   // dot row + space for "you" marker

    private var effectiveMax: Int {
        let cap = maxPosition ?? (labels.count - 1)
        return max(0, min(labels.count - 1, cap))
    }

    private var clampedPosition: Int {
        max(0, min(effectiveMax, position))
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            Text(labels[clampedPosition])
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: position)

            GeometryReader { geo in
                let count = labels.count
                let denom = max(1, count - 1)
                let dotX: (Int) -> CGFloat = { i in
                    geo.size.width * CGFloat(i) / CGFloat(denom)
                }

                ZStack {
                    // Background track — full width, divider gray.
                    Rectangle()
                        .fill(Palette.divider)
                        .frame(height: trackHeight)
                        .position(x: geo.size.width / 2, y: rowHeight / 2)

                    // Filled portion of the track up to effectiveMax —
                    // visualizes the reachable range in soft accent.
                    Rectangle()
                        .fill(Palette.accent.opacity(0.45))
                        .frame(width: dotX(effectiveMax), height: trackHeight)
                        .position(x: dotX(effectiveMax) / 2, y: rowHeight / 2)

                    // Position dots. Filled accent for valid, hollow
                    // divider for disabled, outlined cocoa for selected.
                    ForEach(0..<count, id: \.self) { i in
                        let valid = i <= effectiveMax
                        let selected = i == clampedPosition && valid
                        ZStack {
                            if selected {
                                Circle()
                                    .fill(Palette.bgInverse)
                                    .frame(width: selectedDotSize, height: selectedDotSize)
                                Circle()
                                    .stroke(Palette.accent, lineWidth: 2)
                                    .frame(width: selectedDotSize, height: selectedDotSize)
                            } else if valid {
                                Circle()
                                    .fill(Palette.accent)
                                    .frame(width: dotSize, height: dotSize)
                            } else {
                                Circle()
                                    .stroke(Palette.divider, lineWidth: 1.5)
                                    .frame(width: dotSize, height: dotSize)
                            }
                        }
                        .position(x: dotX(i), y: rowHeight / 2)
                        .onTapGesture {
                            if valid {
                                Haptics.light()
                                position = i
                            } else {
                                Haptics.warning()
                            }
                        }
                    }

                    // "you" marker at markerPosition. Reads as the
                    // user's current body type when this slider is
                    // editing the goal — context for the gradient
                    // they're moving along.
                    if let marker = markerPosition {
                        let markerIdx = max(0, min(count - 1, marker))
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Palette.accent)
                                .frame(width: 6, height: 6)
                            Text("you")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Palette.accent)
                        }
                        .position(x: dotX(markerIdx), y: rowHeight / 2 + 22)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            // Snap to nearest valid dot (cap at
                            // effectiveMax so the thumb can't drag
                            // past the disabled positions).
                            let x = max(0, min(geo.size.width, gesture.location.x))
                            let raw = (x / geo.size.width) * CGFloat(denom)
                            let nearest = min(effectiveMax, max(0, Int(raw.rounded())))
                            if nearest != position {
                                Haptics.soft()
                                position = nearest
                            }
                        }
                )
            }
            .frame(height: rowHeight)
            .padding(.horizontal, Space.md)

            HStack {
                Text(labels.first ?? "")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                // Right-edge label always shows the actual upper bound
                // ("Cut") even when disabled — makes the gradient direction
                // unambiguous (lean ←→ heavier).
                Text(labels.last ?? "")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Space.md)
        }
        .padding(.vertical, Space.lg)
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

#Preview("OnboardingOptionCard") {
    VStack(spacing: Space.md) {
        OnboardingOptionCard(
            icon: "figure.core.training",
            title: "Definition",
            subtitle: "Visible abs, sculpted lines",
            isSelected: true,
            action: {}
        )
        OnboardingOptionCard(
            icon: "flame.fill",
            title: "Strength",
            subtitle: "Build a stronger core",
            isSelected: false,
            action: {}
        )
        OnboardingOptionCard(
            icon: "heart.fill",
            title: "Just feel better",
            isSelected: false,
            action: {}
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("PricingCard") {
    VStack(spacing: Space.md) {
        PricingCard(
            title: "Yearly",
            price: "$59.99",
            perWeekEquivalent: "$1.15 / week",
            badge: "SAVE 76%",
            isSelected: true,
            action: {}
        )
        PricingCard(
            title: "Weekly",
            price: "$4.99",
            perWeekEquivalent: nil,
            badge: nil,
            isSelected: false,
            action: {}
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("DayBadge") {
    HStack(spacing: Space.sm) {
        DayBadge(label: "DAY 1")
        DayBadge(label: "DAY 7")
        DayBadge(label: "DAY 30")
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("ItalicAccentText") {
    VStack(spacing: Space.lg) {
        ItalicAccentText("Become her in 30 days.", italic: ["her"])
        ItalicAccentText(
            "Sculpt your strongest body, at home.",
            italic: ["strongest"]
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("JeniFitWordmark") {
    VStack(spacing: Space.lg) {
        JeniFitWordmark()
        JeniFitWordmark(color: Palette.accent)
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("EditorialPlaceholder") {
    EditorialPlaceholder(label: "EDITORIAL · COACH PHOTO")
        .frame(width: 280, height: 380)
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
}

// dwellSeconds set to 9999 so the preview doesn't auto-advance —
// this is a render-only static preview, not a working onboarding step.
#Preview("SectionDividerScreen") {
    SectionDividerScreen(
        partNumber: 1,
        title: "Your story",
        supporting: "Three quick reads on what brought you here.",
        dwellSeconds: 9999,
        onAdvance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("ConfirmationBadge") {
    VStack {
        Spacer()
        ConfirmationBadge(message: "Got it. Your plan starts here.")
            .padding(.bottom, Space.xl)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}
