import SwiftUI

// MARK: - JKBeatRow
//
// The plan beat — the row the onboarding device demo promised
// (44pt photo matte · title/sub · state circle) speaking the OV5
// cross-off language: completing a beat draws a 1.5pt strike across
// the title left-to-right with a capped tick cascade, and the row
// settles to 62%. In onboarding the strike meant "not me"; on the
// plan it means "done" — the her75 checklist gesture, where crossing
// off IS the satisfaction.
//
// Tap = enter the module (never toggles state). The circle is
// render-only; long-press is the manual override, wired by the host.

struct JKBeatState: Equatable {
    var isDone: Bool
    var isAuto: Bool          // autoCompleted → sparkle instead of check
    /// Live progress rows (steps) render a fraction instead of a circle.
    var progress: Double?     // nil = binary row

    static let empty = JKBeatState(isDone: false, isAuto: false, progress: nil)
}

struct JKBeatRow: View {
    let title: String
    var subtitle: String? = nil
    /// Bundled image asset for the leading matte; nil → SF glyph.
    var thumbAsset: String? = nil
    var glyph: String = "circle"
    var state: JKBeatState = .empty
    /// Hero rows get the serif title treatment (one per day).
    var isHero: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var strike: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// v1.1.4 — set the instant the LongPressGesture fires; checked in
    /// the Button action to swallow the follow-up tap. SwiftUI's Button
    /// fires its action on touch-RELEASE regardless of how long the
    /// finger was held, so a long-press previously ran onLongPress AND
    /// onTap (the override sheet AND the module cover, back to back).
    /// Mirrors PlanRow's shipped v1.1.1 fix. Auto-resets after 0.7s so a
    /// long-press that drags off the row (Button tap cancelled, flag
    /// never cleared by a release) can't swallow a later real tap.
    @State private var longPressJustFired = false

    var body: some View {
        Button(action: {
            // Long-press already handled this touch: eat the release tap.
            if longPressJustFired {
                longPressJustFired = false
                return
            }
            Haptics.light()
            onTap()
        }) {
            rowLabel
        }
        .buttonStyle(JKPress())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                // No handler (e.g. progress rows pass nil) → never arm the
                // swallow, so the row's normal tap keeps working.
                guard let onLongPress else { return }
                longPressJustFired = true
                onLongPress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    longPressJustFired = false
                }
            }
        )
        .animation(Motion.entranceSoft, value: state.isDone)
        .onChange(of: state.isDone) { _, done in
            guard done else {
                withAnimation(Motion.exit) { strike = 0 }
                return
            }
            if reduceMotion { strike = 1; return }
            // v2.7 — the strike is a MOMENT, not a state flip: it
            // waits for the module cover to clear (0.28s), then draws
            // at pen speed with the tick cascade riding the line.
            withAnimation(.easeOut(duration: 0.34).delay(0.28)) { strike = 1 }
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28 + 0.09 * Double(i)) {
                    Haptics.tick()
                }
            }
        }
        .onAppear { strike = state.isDone ? 1 : 0 }
        .accessibilityLabel("\(title)\(state.isDone ? ", done" : "")")
        .accessibilityHint(state.isDone ? "" : "opens \(title)")
    }

    private var rowLabel: some View {
        HStack(spacing: 12) {
            thumb
            titleStack
            Spacer(minLength: 8)
            trailingState
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
        .opacity(state.isDone ? 0.62 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Palette.textPrimary.opacity(0.55))
                            .frame(width: geo.size.width * strike, height: 1.5)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .allowsHitTesting(false)
                }
            if let subtitle {
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }

    @ViewBuilder private var trailingState: some View {
        if let progress = state.progress {
            JKMiniRing(progress: progress, isDone: state.isDone)
        } else {
            JKStateCircle(isDone: state.isDone, isAuto: state.isAuto)
        }
    }

    private var titleFont: Font {
        isHero
            ? .custom("JeniHeroSerif-Regular", size: 19)
            : .custom("DMSans-SemiBold", size: 16)
    }

    @ViewBuilder private var thumb: some View {
        Group {
            if let thumbAsset {
                Image(thumbAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Palette.accentSubtle.opacity(0.55)
                    Image(systemName: glyph)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .saturation(state.isDone ? 0.35 : 1)
    }
}

// MARK: - JKStateCircle
//
// The 26pt cross-off circle from the onboarding radio language:
// hairline when empty, cocoa fill + drawn check when done, tiny
// sparkle for auto-completed (system saw it happen).

struct JKStateCircle: View {
    let isDone: Bool
    var isAuto: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isDone ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.25),
                    lineWidth: 1.5
                )
            if isDone {
                Circle().fill(Palette.cocoaPrimary)
                Image(systemName: isAuto ? "sparkle" : "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textInverse)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .frame(width: 26, height: 26)
        .animation(Motion.bloom, value: isDone)
        .accessibilityHidden(true)
    }
}

// MARK: - JKMiniRing
//
// Inline progress ring for live rows (steps) — the device-demo
// steps-row ring at beat-row scale. Fills accent, completes cocoa.

struct JKMiniRing: View {
    let progress: Double
    var isDone: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.accentSubtle, lineWidth: 3)
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(
                        isDone ? Palette.cocoaPrimary : Palette.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(Motion.easedFinal, value: progress)
                    .transition(.opacity)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}
