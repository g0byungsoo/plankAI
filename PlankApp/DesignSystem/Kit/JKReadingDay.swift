import SwiftUI
import Auth
import PlankFood
import PlankSync

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

// MARK: - JeniNoteView

/// THE NOTE — jeni's full reading as a RECEIVED moment (the minimal
/// correction, 06_MINIMAL_CORRECTION.md). Home carries only her
/// line; tapping it opens this full-screen letter: the dateline, the
/// sentences cascading in line by line with a soft haptic each (the
/// her75 reveal — the app's one cinematic gesture), the mechanism as
/// a caption, her signature, REPLY into the chat, and a quiet keep.
struct JeniNoteView: View {
    let brief: DailyBriefEngine.Brief
    /// Lowercase weekday for the dateline ("sunday").
    var dateline: String = ""
    let onReply: () -> Void
    let onClose: () -> Void

    @State private var tailSettled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sealed = false

    var body: some View {
        JKScreenChrome {
            VStack(alignment: .leading, spacing: 0) {
                // Mission 2 (02_VISUAL.md §2): the block floats at
                // optical center — the emptiness reads composed, not
                // leftover.
                Spacer(minLength: Space.hero)

                // Dateline
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

                // The letter — line by line, a breath apart.
                LineCascadeText(
                    lines: cascadeLines,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 28, relativeTo: .title),
                    color: Palette.textPrimary
                )
                .padding(.top, Space.xl)

                if let mechanism = brief.mechanism {
                    Text(mechanism)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .opacity(tailSettled ? 1 : 0)
                        .offset(y: tailSettled ? 0 : 6)
                }

                HStack {
                    Spacer()
                    Text("— jeni")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .padding(.top, Space.lg)
                .opacity(tailSettled ? 1 : 0)

                Spacer(minLength: 0)

                // The doors: reply leads, keep excuses quietly.
                VStack(spacing: Space.md) {
                    Button {
                        Haptics.soft()
                        onReply()
                    } label: {
                        Text("reply")
                            .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Palette.cocoaPrimary))
                    }
                    .buttonStyle(JKPress())

                    // Mission 2: keeping the letter is the SEAL —
                    // jeni's mark fills at her touch, the her-file
                    // commit haptic lands, the page files itself.
                    Button {
                        guard !sealed else { return }
                        sealed = true
                        ActivationHaptics.shared.commit()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            onClose()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12, weight: sealed ? .medium : .light))
                                .symbolVariant(sealed ? .fill : .none)
                                .foregroundStyle(
                                    sealed ? Palette.jeweledRose : Palette.cocoaSecondary
                                )
                                .scaleEffect(sealed ? 1.2 : 1)
                                .animation(Motion.bloom, value: sealed)
                            Text("keep it")
                                .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                                .foregroundStyle(Palette.cocoaSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, Space.lg)
                .opacity(tailSettled ? 1 : 0)
                .offset(y: tailSettled ? 0 : 8)
            }
            .padding(.horizontal, Space.lg)
        }
        .onAppear {
            if reduceMotion { tailSettled = true; return }
            // The tail (mechanism + signature + doors) follows the
            // cascade: ~0.5s per line + a settling breath.
            let delay = 0.4 + Double(cascadeLines.count) * 0.5
            withAnimation(Motion.entranceSoft.delay(delay)) { tailSettled = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("a note from jeni. \([brief.line, brief.second, brief.mechanism].compactMap { $0 }.joined(separator: " "))")
    }

    private var cascadeLines: [LineCascadeText.Line] {
        var lines: [LineCascadeText.Line] = [
            .composite(base: brief.line, italic: brief.italic)
        ]
        if let second = brief.second {
            lines.append(.composite(base: second, italic: brief.secondItalic))
        }
        return lines
    }
}

// v7: JKDayRail deleted — the position line on Today carries
// the week's place in one legible line (docs/app_v7 §1).

// MARK: - jkTapWithLongPress

/// Tap-enters + long-press-overrides with the v1.1.4 tap-swallow fix
/// (Button fires on release regardless of hold length; the flag eats
/// the follow-up tap and self-resets). Shared by the one-thing card
/// and rhythm rows; JKBeatRow keeps its own identical copy.
// v7.2: internal (was private) — TodayView's type-first ask block
// shares the tap-enters + long-press-overrides grammar.
struct JKTapWithLongPress: ViewModifier {
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

// v7.4: JKOneThingCard deleted — the type-first askBlock on Today
// replaced the cocoa slab (docs/app_v7/01_BUILD.md v7.2).


// MARK: - JKRhythmRow

/// The day's shape, one quiet line at a time: glyph · title · inline
/// note · live trailing state. No circles, no cards. The strike is
/// the done state (pen speed + tick cascade, the her75 gesture).
struct JKRhythmRow: View {
    let title: String
    var note: String? = nil
    /// The glossy ritual sticker on its pastel tile — THE app's own
    /// icon language (founder direction 2026-07-06: the iridescent
    /// peach / candy / balloon dog / mary-jane / heart-lock / bubble
    /// ARE the identity). 34pt: present, never loud.
    var sticker: (asset: String, tile: Color)? = nil
    /// Fallback line mark when a row has no sticker.
    var mark: JKMarkKind? = nil
    var state: JKBeatState = .empty
    /// Live trailing text for auto rows (steps count).
    var liveTrailing: String? = nil
    /// v6.4 (founder call, reversing the v3 no-at-rest-circles law):
    /// required rows wear a visible trailing check ring so the day
    /// reads as a checkable list at a glance. Optional/quiet rows
    /// keep the old render-only grammar.
    var showsCheckRing: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var strike: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            if let sticker {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(sticker.tile.opacity(state.isDone ? 0.45 : 0.85))
                    Image(sticker.asset)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                }
                .frame(width: 34, height: 34)
                .saturation(state.isDone ? 0.4 : 1)
            } else if let mark {
                JKMark(
                    kind: mark,
                    size: 18,
                    color: Palette.cocoaSecondary.opacity(state.isDone ? 0.5 : 0.85)
                )
                .frame(width: 20)
            }
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
            } else if !showsCheckRing, state.isDone, state.isAuto {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.cocoaSecondary)
            }

            if showsCheckRing {
                ZStack {
                    Circle()
                        .strokeBorder(
                            state.isDone ? Color.clear : Palette.cocoaPrimary.opacity(0.28),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if state.isDone {
                        Circle()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 22, height: 22)
                        Image(systemName: state.isAuto ? "sparkle" : "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Motion.gentleSpring, value: state.isDone)
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
        .accessibilityLabel(
            "\(title)\(state.isDone ? ", done" : (note.map { ", \($0)" } ?? ""))".a11yStripped
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(state.isDone ? "" : "opens \(title)")
        // v7 a11y contract (docs/app_v7 §9): completion must be
        // reachable without the undiscoverable long-press — assistive
        // tech gets a named action wherever the override exists.
        .accessibilityActions {
            if let onLongPress, !state.isDone {
                Button("mark as done") { onLongPress() }
            }
        }
    }
}

// MARK: - Spoken-label hygiene (v7)

extension String {
    /// Strips the brand's terminal hearts (and trailing space) from
    /// text bound for VoiceOver — "♥" reads as "black heart suit" at
    /// the end of most sentences otherwise, degrading jeni's voice
    /// for exactly the users who only ever hear her.
    var a11yStripped: String {
        self
            .replacingOccurrences(of: "\u{2665}\u{FE0E}", with: "")
            .replacingOccurrences(of: "\u{2665}", with: "")
            .replacingOccurrences(of: "\u{2661}", with: "")
            .trimmingCharacters(in: .whitespaces)
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

// MARK: - JKFlowLayout
//
// A wrapping row layout: lays children left-to-right and wraps to a new
// line the moment the next child would overflow the proposed width. Each
// child keeps its ideal size, so chips hug their labels and never
// truncate (the fix for the breathwork occasion chips that got squeezed
// into one HStack). iOS 16+. Left-aligned; equal spacing horizontally
// and between lines.
struct JKFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        let total = y + rowHeight
        return CGSize(width: min(maxWidth, widest), height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > maxX {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

