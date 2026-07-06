import SwiftUI

// MARK: - JKReadingDay (app v3, docs/app_v3/02_DESIGN_LANGUAGE.md)
//
// The reading-first day's components: THE READING (jeni's morning
// note — the screen's hero), THE ONE THING (the single ask, the
// screen's only filled container), THE RHYTHM (hairline rows — the
// day's shape, present but never debt), and the BREAK card.
//
// Register: serif editorial + receipt grammar from onboarding v5.
// No at-rest circles, no locks, no counts. Completion stays her75:
// the strike IS the satisfaction.

// MARK: - JKJeniNote

/// THE NOTE FROM JENI — the morning letter, the app's presence
/// artifact (04_PREMIUM_PASS move A). A paper-grade card: "JENI" +
/// hairline + the weekday as a dateline, the reading in serif (line
/// one leads; the second sentence follows in the secondary ink), the
/// mechanism as a quiet caption, "reply ↗" and her signature
/// ("jeni ♥") on the closing line. The whole note is the reply
/// affordance. Entrance: the two-beat settle; idle: the breathing
/// shadow — nothing else moves.
struct JKJeniNote: View {
    let brief: DailyBriefEngine.Brief
    /// Lowercase weekday for the dateline ("sunday").
    var dateline: String = ""
    var onOpenChat: (() -> Void)? = nil

    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            guard let onOpenChat else { return }
            Haptics.soft()
            onOpenChat()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Dateline — hers, from her coach, this morning.
                HStack(spacing: 10) {
                    Text("jeni")
                        .font(Typo.captionTracked)
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                    if !dateline.isEmpty {
                        Text(dateline)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                }

                ItalicAccentText(
                    brief.line,
                    italic: brief.italic,
                    baseFont: Typo.reading,
                    italicFont: Typo.readingItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(-3)
                .kerning(-0.2)
                .fixedSize(horizontal: false, vertical: true)

                if brief.second != nil || brief.mechanism != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let second = brief.second {
                            ItalicAccentText(
                                second,
                                italic: brief.secondItalic,
                                baseFont: .custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body),
                                italicFont: .custom("JeniHeroSerif-Italic", size: 18, relativeTo: .body),
                                color: Palette.textSecondary,
                                alignment: .leading
                            )
                            .lineSpacing(-1)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        if let mechanism = brief.mechanism {
                            Text(mechanism)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .opacity(settled ? 1 : 0)
                    .offset(y: settled ? 0 : 6)
                }

                // The closing line: reply on the left, her hand on
                // the right. The signature IS jeni's presence mark.
                HStack {
                    if onOpenChat != nil {
                        HStack(spacing: 5) {
                            Text("reply")
                                .font(Typo.captionTracked)
                                .kerning(1.6)
                                .textCase(.uppercase)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(Palette.cocoaTertiary)
                    }
                    Spacer()
                    Text("jeni \u{2665}\u{FE0E}")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .padding(.top, 2)
                .opacity(settled ? 1 : 0)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
            )
            .shadow(color: .black.opacity(0.05), radius: 9, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(JKPress())
        .disabled(onOpenChat == nil)
        .breathingShadow()
        .onAppear {
            guard !settled else { return }
            if reduceMotion { settled = true; return }
            withAnimation(Motion.entranceSoft.delay(0.34)) { settled = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("a note from jeni. \(accessibilityText)")
        .accessibilityHint(onOpenChat != nil ? "opens jeni to reply" : "")
    }

    private var accessibilityText: String {
        [brief.line, brief.second, brief.mechanism]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

// MARK: - jkTapWithLongPress

/// Tap-enters + long-press-overrides with the v1.1.4 tap-swallow fix
/// (Button fires on release regardless of hold length; the flag eats
/// the follow-up tap and self-resets). Shared by the one-thing card
/// and rhythm rows; JKBeatRow keeps its own identical copy.
private struct JKTapWithLongPress: ViewModifier {
    let onTap: () -> Void
    var onLongPress: (() -> Void)?

    @State private var longPressJustFired = false

    func body(content: Content) -> some View {
        Button {
            if longPressJustFired {
                longPressJustFired = false
                return
            }
            Haptics.light()
            onTap()
        } label: {
            content
        }
        .buttonStyle(JKPress())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard let onLongPress else { return }
                longPressJustFired = true
                onLongPress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    longPressJustFired = false
                }
            }
        )
    }
}

// MARK: - JKOneThingCard

/// The single ask — the screen's ONE dark object (04_PREMIUM_PASS
/// move B). Cocoa field, cream serif, the italic punch word tinted
/// accent-subtle; the strike draws in cream. Done: the card exhales
/// into a cream kept-receipt row, so the dark anchor literally
/// leaves the screen once the ask is met. Permission days stay
/// cream — dark means an ask exists.
struct JKOneThingCard: View {
    let title: String
    var italic: [String] = []
    var subtitle: String? = nil
    var isDone: Bool = false
    /// Permission days (rest-with-no-ask / break) render statement-only.
    var isPermission: Bool = false
    var onTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let onTap, !isDone, !isPermission {
                cardBody.modifier(
                    JKTapWithLongPress(onTap: onTap, onLongPress: onLongPress)
                )
            } else {
                cardBody
            }
        }
        .animation(reduceMotion ? nil : Motion.easedFinal, value: isDone)
    }

    private var isDark: Bool { !isDone && !isPermission }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: isDone ? 4 : 10) {
            Text(isDone ? "kept" : "the one thing")
                .font(Typo.captionTracked)
                .kerning(2.0)
                .textCase(.uppercase)
                .foregroundStyle(
                    isDone ? Palette.cocoaSecondary
                           : (isDark ? Palette.textInverse.opacity(0.55)
                                     : Palette.cocoaTertiary)
                )

            if isDone {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                        .strikethrough(true, color: Palette.textPrimary.opacity(0.55))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\u{2665}\u{FE0E}")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.accent)
                }
                .transition(.opacity)
            } else {
                ItalicAccentText(
                    title,
                    italic: italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 23, relativeTo: .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 23, relativeTo: .title3),
                    color: isDark ? Palette.textInverse : Palette.textPrimary,
                    italicColor: isDark ? Palette.accentSubtle : nil,
                    alignment: .leading
                )
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)

                if let subtitle {
                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(
                            isDark ? Palette.textInverse.opacity(0.62)
                                   : Palette.textSecondary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, isDone ? 14 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(isDark ? Palette.cocoaPrimary : Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(
                    isDark ? Color.white.opacity(0.06) : Palette.hairlineCocoa,
                    lineWidth: 0.66
                )
        )
        .shadow(
            color: isDark ? Palette.cocoaPrimary.opacity(0.22) : .black.opacity(0.03),
            radius: isDark ? 12 : 7,
            y: isDark ? 5 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(isDone || isPermission ? "" : "opens \(title)")
    }

    private var a11yLabel: String {
        if isDone { return "the one thing, \(title), done" }
        if isPermission { return title }
        return "the one thing, \(title)\(subtitle.map { ", \($0)" } ?? "")"
    }
}

// MARK: - JKRhythmRow

/// The day's shape, one quiet line at a time: glyph · title · inline
/// note · live trailing state. No circles, no cards. The strike is
/// the done state (pen speed + tick cascade, the her75 gesture).
struct JKRhythmRow: View {
    let title: String
    var note: String? = nil
    var glyph: String = "circle"
    var state: JKBeatState = .empty
    /// Live trailing text for auto rows (steps count).
    var liveTrailing: String? = nil
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var strike: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            // Premium pass move C: rows are text-set like a menu — no
            // leading glyph (utility-app residue). `glyph` survives in
            // the API for the gallery; it simply doesn't render here.
            HStack(spacing: 6) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let note {
                    Text("· \(note)")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Palette.textPrimary.opacity(0.55))
                        .frame(width: geo.size.width * strike, height: 1.5)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)
            }

            Spacer(minLength: 8)

            if let liveTrailing {
                Text(liveTrailing)
                    .font(Typo.caption.monospacedDigit())
                    .foregroundStyle(state.isDone ? Palette.cocoaSecondary : Palette.textSecondary)
            } else if state.isDone, state.isAuto {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .opacity(state.isDone ? 0.62 : 1)
        .modifier(JKTapWithLongPress(onTap: onTap, onLongPress: onLongPress))
        .animation(Motion.entranceSoft, value: state.isDone)
        .onChange(of: state.isDone) { _, done in
            guard done else {
                withAnimation(Motion.exit) { strike = 0 }
                return
            }
            if reduceMotion { strike = 1; return }
            withAnimation(.easeOut(duration: 0.34).delay(0.28)) { strike = 1 }
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28 + 0.09 * Double(i)) {
                    Haptics.tick()
                }
            }
        }
        .onAppear { strike = state.isDone ? 1 : 0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)\(state.isDone ? ", done" : (note.map { ", \($0)" } ?? ""))")
        .accessibilityHint(state.isDone ? "" : "opens \(title)")
    }
}

// MARK: - JKBreakCard

/// The "on a break" state — permission, not absence. One gentle
/// return door; ending the break is warm, never a catch-up.
struct JKBreakCard: View {
    let onReturn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ItalicAccentText(
                "on a break.",
                italic: ["break"],
                baseFont: .custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3),
                italicFont: .custom("JeniHeroSerif-Italic", size: 24, relativeTo: .title3),
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text("the rhythm and the reminders are asleep. coming back is one tap.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.soft()
                onReturn()
            } label: {
                Text("i'm back")
                    .font(.custom("DMSans-SemiBold", size: 14, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(JKPress())
            .padding(.top, 4)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
    }
}
