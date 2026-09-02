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
// Never a grey box. p66 — an empty state is the canonical site for
// THE ILLUSTRATION REGISTER: one big drifting doodle above the line
// (`JeniDoodle`), because bare paper under a lone sentence read as
// unfinished, not composed (the founder's illustration law).

struct JKEmptyState: View {
    let line: String
    var italic: [String] = []
    /// `doodle-*` asset name for the illustration above the line.
    var doodle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.md) {
            if let doodle {
                JeniDoodle(name: doodle)
                    .padding(.bottom, Space.sm)
            }
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

// p66 — JKChainLine + JKCoachMark deleted: zero shipping call sites
// (their only renderer was the v2-era JKGallery, deleted with them).

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

