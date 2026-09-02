import SwiftUI

// MARK: - JeniKit foundation
//
// App v2 (docs/app_v2/10_DESIGN_SYSTEM.md). The app-wide component
// kit that generalizes the onboarding v5 language: hairline
// discipline, two-beat entrances, cross-off completion, serif punch,
// quiet chrome. OV5* components stay onboarding-scoped; JK* is the
// in-app dialect of the same grammar. Everything reduce-motion
// gates; everything renders on the 8 locked tokens.

// MARK: - Two-beat entrance (the OV5 cadence, app-wide)
//
// Beat 1: the headline rides the screen transition with a 6pt
// settle. Beat 2: everything else holds invisible and arrives as
// ONE unit at +0.34s. The exact founder-tuned cadence from
// OV5Scaffold — re-declared here so in-app surfaces don't reach
// into onboarding files (and the v4.5 sweep can't orphan us).

private struct JKBeatModifier: ViewModifier {
    let delay: Double
    let fade: Bool
    var rise: CGFloat = 6
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(fade && !reduceMotion && !appeared ? 0 : 1)
            .offset(y: appeared || reduceMotion ? 0 : rise)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                withAnimation(Motion.revealFade) { appeared = true }
            }
    }
}

extension View {
    /// Headline beat — lands first with a small settle.
    func jkBeat1() -> some View {
        modifier(JKBeatModifier(delay: 0, fade: false))
    }
    /// Content beat — arrives as one unit after the headline.
    func jkBeat2(extraDelay: Double = 0) -> some View {
        modifier(JKBeatModifier(delay: 0.34 + extraDelay, fade: true))
    }
}

// MARK: - JKPress
//
// The kit's press style: 0.985 scale + 8% dim on press, Motion.tap
// timing, no bounce (bounce on tap reads cheap on a calm surface).
// Replaces reaching into the legacy onboarding monolith for
// PressFeedbackStyle.

// p63 — ONE press language. JKPress and JeniPressable had drifted
// into two near-identical dialects (0.985/Motion.tap vs
// 0.98/JeniMotion.press) across 111 call sites; the design law names
// JeniPressable (§5.1), so JKPress is now its second name, kept
// because renaming 93 sites is churn without meaning.
typealias JKPress = JeniPressable

// MARK: - JKScreenChrome
//
// The page: cream, optional paper grain, top-aligned content. The
// atmosphere never re-animates — only content swaps above it.

struct JKScreenChrome<Content: View>: View {
    var grain: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            if grain {
                PaperGrainBackground()
                    .ignoresSafeArea()
            }
            content()
        }
    }
}

// MARK: - JKQuietMark
//
// The masthead icon affordance: a thin SF glyph at cocoaSecondary
// with an invisible 44pt target. Max two per masthead.

struct JKQuietMark: View {
    let systemName: String
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.cocoaSecondary)
                .tappableArea()
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - JKEmptyState
//
// Editorial empty: one serif line (italic punch), one quiet action.
// Never an illustration dump, never a grey box.

struct JKEmptyState: View {
    let line: String
    var italic: [String] = []
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.md) {
            ItalicAccentText(
                line,
                italic: italic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 22),
                italicFont: .custom("JeniHeroSerif-Italic", size: 22),
                color: Palette.textPrimary,
                alignment: .center
            )
            .lineSpacing(-4)
            .fixedSize(horizontal: false, vertical: true)
            // p53 AX5 film: at accessibility sizes the scaled serif made
            // one word ("movement") wider than the padded column and
            // SwiftUI broke it MID-WORD. minimumScaleFactor cannot help
            // here — with fixedSize(vertical:) the text always "fits" by
            // wrapping, so the floor never engages. Wraps-or-scales law:
            // the decorative line caps at accessibility2 (~1.5× resting,
            // whole words hold); the action button below scales fully.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

            if let actionLabel, let action {
                Button {
                    Haptics.soft()
                    action()
                } label: {
                    Text(actionLabel)
                        .font(.custom("DMSans-SemiBold", size: 15))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .overlay(
                            Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1.5)
                        )
                }
                .buttonStyle(JKPress())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .padding(.horizontal, Space.lg)
    }
}

// MARK: - JKChainLine
//
// The module-exit "next:" suggestion — kills dead-end completions.
// One hairline row: quiet lead + serif punch + chevron.

struct JKChainLine: View {
    let lead: String            // "next"
    let suggestion: String      // "60 seconds of breath"
    var italic: [String] = []
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            VStack(spacing: 0) {
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(lead)
                        .font(Typo.captionTracked)
                        .kerning(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                    ItalicAccentText(
                        suggestion,
                        italic: italic,
                        baseFont: .custom("DMSans-Medium", size: 15),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 17),
                        color: Palette.textPrimary,
                        alignment: .leading
                    )
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.vertical, 14)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
    }
}

// MARK: - JKCoachMark
//
// First-run education caption: a hairline pointer + one lowercase
// caption, dismissed forever on first interaction. Never modal.

struct JKCoachMark: View {
    let text: String
    /// AppStorage key that retires this mark once true.
    let seenKey: String

    @AppStorage private var seen: Bool

    init(text: String, seenKey: String) {
        self.text = text
        self.seenKey = seenKey
        self._seen = AppStorage(wrappedValue: false, seenKey)
    }

    var body: some View {
        if !seen {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Palette.cocoaTertiary)
                    .frame(width: 0.75, height: 22)
                Text(text)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    withAnimation(Motion.exit) { seen = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .tappableArea(32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.lg)
            .transition(.opacity)
        }
    }

    /// Programmatic retirement (call when the user performs the
    /// gesture the mark teaches).
    static func retire(_ seenKey: String) {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}

// MARK: - JKQuietSeam (rehomed from JourneyAtoms, v11 T4 — the
// chat composer still seams with it)

/// hairlines, air on both sides.
struct JKQuietSeam: View {
    let line: String

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Rectangle().fill(Palette.hairlineCocoa).frame(width: 26, height: 0.5)
            Text(line)
                .font(.custom("DMSans-Medium", size: 10.5, relativeTo: .caption2))
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize()
            Rectangle().fill(Palette.hairlineCocoa).frame(width: 26, height: 0.5)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line)
    }
}

