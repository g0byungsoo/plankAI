import SwiftUI

// MARK: - BreathworkFlowView
//
// v1.1 module-experience pass (2026-06-11). The single daily entry
// for breathwork: intro (occasion chips → protocol card → duration)
// → session → receipt. Replaces PlanView's direct hardcoded-.calming
// mount (founder QA: "breathwork screen doesn't even have an intro
// screen... going right into the session").
//
// Collapse rule (per docs/breathwork_apps_teardown_2026_06_11.md):
// ≥3 lifetime completions = she knows the ritual; quick-start lands
// her on the session with her last-used occasion + duration in <3s
// (the session's own ~4s settle beat remains the only pause). The
// intro stays one tap away via the session's X → re-entry.

struct BreathworkFlowView: View {
    let onComplete: (_ minutes: Int, _ techProtocol: BreathworkProtocol) -> Void
    let onDismiss: () -> Void

    @AppStorage("breathwork.lastOccasion") private var lastOccasionRaw = BreathOccasion.settled.rawValue
    @AppStorage("breathwork.lastMinutes") private var lastMinutes = 1

    private enum Stage { case intro, session }
    @State private var stage: Stage
    @State private var occasion: BreathOccasion
    @State private var minutes: Int

    init(onComplete: @escaping (_ minutes: Int, _ techProtocol: BreathworkProtocol) -> Void,
         onDismiss: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        let defaults = UserDefaults.standard
        let last = BreathOccasion(rawValue: defaults.string(forKey: "breathwork.lastOccasion") ?? "") ?? .settled
        let mins = max(1, defaults.integer(forKey: "breathwork.lastMinutes"))
        _occasion = State(initialValue: last)
        _minutes = State(initialValue: mins == 0 ? 1 : mins)
        _stage = State(initialValue: BreathworkState.shared.totalCompleted >= 3 ? .session : .intro)
    }

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()
            switch stage {
            case .intro:
                BreathworkIntroView(
                    occasion: $occasion,
                    minutes: $minutes,
                    onBegin: {
                        lastOccasionRaw = occasion.rawValue
                        lastMinutes = minutes
                        withAnimation(Motion.crossFade) { stage = .session }
                    },
                    onDismiss: onDismiss
                )
                .transition(JFPageTransition.standard)
            case .session:
                BreathworkSessionView(
                    onReadyToMove: { onComplete(minutes, occasion.techProtocol) },
                    onLater: { onComplete(minutes, occasion.techProtocol) },
                    onDismiss: onDismiss,
                    techProtocol: occasion.techProtocol,
                    sessionMinutes: minutes,
                    occasion: occasion,
                    context: .daily
                )
                .transition(JFPageTransition.standard)
            }
        }
    }
}

// MARK: - BreathworkIntroView

/// The moment between tap and first breath: "how do you want to
/// feel?" chips over ONE protocol card (default-with-swap, never a
/// lobby), a quiet duration link, one begin pill.
struct BreathworkIntroView: View {
    @Binding var occasion: BreathOccasion
    @Binding var minutes: Int
    let onBegin: () -> Void
    let onDismiss: () -> Void

    @State private var animateIn = false
    @Namespace private var chipNamespace

    private var techProtocol: BreathworkProtocol { occasion.techProtocol }

    /// "6 on file \u{00B7} the last one on tuesday" — or an invitation when
    /// there is nothing to count. Never "0 sessions", never a streak.
    @ViewBuilder private var recordLine: some View {
        let state = BreathworkState.shared
        VStack(alignment: .leading, spacing: Space.sm) {
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.5)
            Text(recordWords(total: state.totalCompleted, last: state.lastCompletedAt))
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func recordWords(total: Int, last: Date?) -> String {
        guard total > 0 else {
            return "one minute is a whole session. that is the point of it."
        }
        let count = total == 1 ? "one so far" : "\(total) so far"
        guard let last else { return count }
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: .now)
        ).day ?? 0
        switch days {
        case 0:  return "\(count) \u{00B7} one of them today"
        case 1:  return "\(count) \u{00B7} the last one yesterday"
        case 2...6:
            return "\(count) \u{00B7} the last one on "
                + last.formatted(.dateTime.weekday(.wide)).lowercased()
        default: return count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    Haptics.light()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 36, height: 36)
                        // E8.1 — `Color.white` is not a token. `bgPrimary` is the
                        // only background in this system, and at 50% over
                        // itself the circle was invisible anyway.
                        .background(Circle().fill(Palette.bgPrimary))
                }
                .accessibilityLabel("Close")
            }
            .padding(.top, Space.md)

            Spacer().frame(height: Space.lg)

            ItalicAccentText(
                "what are we resetting?",
                italic: ["feel"],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading
            )
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 12)

            Spacer().frame(height: Space.lg)

            // Occasion chips — the reset-reason doorways. A wrapping flow
            // layout lets every full label breathe (no single-row
            // truncation), and the cocoa fill glides between chips so
            // choosing a reason reads as one object moving, not four
            // toggles blinking. A tap swaps the card beneath.
            BreathOccasionChips(occasion: $occasion, namespace: chipNamespace)
                .opacity(animateIn ? 1 : 0)

            Spacer().frame(height: Space.lg)

            // THE protocol card — pattern + honest why + citation,
            // straight off the existing protocol library.
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(techProtocol.title)
                        .font(.custom("JeniHeroSerif-Italic", size: 22))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(techProtocol.patternLabel)
                        .font(.custom("DMSans-SemiBold", size: 14))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }

                Text(occasion.occasionLine)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(techProtocol.citation)
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.divider, lineWidth: 1)
            )
            .id(occasion)
            .transition(.opacity)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 8)

            Spacer().frame(height: Space.md)

            // Duration — a quiet link row, not a control panel. 5 min
            // is the studied dose (Balban); 1 min is the doorway.
            HStack(spacing: Space.sm) {
                ForEach([1, 2, 5], id: \.self) { m in
                    let selected = minutes == m
                    Button {
                        Haptics.light()
                        withAnimation(Motion.tap) { minutes = m }
                    } label: {
                        // v25 E9 — SELECTION IS INK (§3, §5.4). The
                        // occasion chips directly above this row already
                        // said so; these said it with a white capsule
                        // instead, so one screen answered the same
                        // question two ways. Choosing is a statement, and
                        // a statement is ink.
                        Text("\(m) min")
                            .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                            .monospacedDigit()
                            .foregroundStyle(selected ? Palette.textInverse : Palette.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                Capsule().fill(selected ? Palette.bgInverse : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                if minutes == 5 {
                    Text("the studied dose")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Palette.textSecondary.opacity(0.7))
                }
                Spacer()
            }
            .opacity(animateIn ? 1 : 0)

            Spacer()

            // v25 E8.1 — HER OWN RECORD WITH THIS TOOL, closing the void
            // the photograph left behind.
            //
            // Deleting the figure was right and it left ~450pt of dead
            // space, which is the same defect E8's walk caught when the
            // protein face started leading. What belongs in it is not
            // decoration: it is proof, which is the law E6 established on
            // the desk (a claim became "4 plates and 123 g of protein, on
            // file"). This tool is the one thing in the product people
            // genuinely repeat — 2.16 sessions per user across 90 days —
            // so the record is worth showing, and showing it is what
            // makes a repeated action feel fast.
            //
            // Never a zero: a first-timer gets the invitation, not an
            // empty tally. And never a streak, per D35.
            recordLine
                .opacity(animateIn ? 1 : 0)
                .padding(.bottom, Space.md)
        }
        .padding(.horizontal, Space.lg)
        // v25 E8.1 — THE PHOTOGRAPH IS GONE, and its removal is the whole
        // redesign of this screen.
        //
        // `itgirl-breathe` was a female-presenting cutout sitting
        // cross-legged above the CTA. Three defects in one asset:
        //
        //   1. It made the surface women-only, which is the unisex debt
        //      E6 and E8 both recorded and neither fixed.
        //   2. It made the screen read as a MEDITATION app. This is not
        //      one. Every word on it is about a craving wave, and the
        //      lotus pose argued with all of them.
        //   3. It collided with the duration row and sat behind the
        //      begin button — caught by looking at a frame, not by a
        //      test, because nothing about it was testable.
        //
        // Nothing replaced it. The design constitution's first rule is
        // remove before add, and what is left is the type, the chips and
        // the evidence, which is what the screen was always about.
        // Deleting a 178pt figure also gave the 5-minute option back its
        // tap target.
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "begin") {
                onBegin()
            }
            .opacity(animateIn ? 1 : 0)
        }
        .onAppear {
            Analytics.captureScreen("BreathworkIntro")
            withAnimation(Motion.entranceSoft) { animateIn = true }
        }
    }
}

// MARK: - BreathOccasionChips
//
// The occasion selector, pulled out so the wrapping + gliding-fill
// behavior is one testable unit. `JKFlowLayout` sizes each chip to its
// own label and wraps to a second line rather than truncating; the
// selected chip carries a matched-geometry cocoa fill, so the selection
// springs from the old chip to the tapped one as a single moving pill.
private struct BreathOccasionChips: View {
    @Binding var occasion: BreathOccasion
    var namespace: Namespace.ID

    var body: some View {
        JKFlowLayout(spacing: Space.sm, lineSpacing: Space.sm) {
            ForEach(BreathOccasion.allCases) { item in
                chip(item)
            }
        }
    }

    @ViewBuilder
    private func chip(_ item: BreathOccasion) -> some View {
        let selected = occasion == item
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                occasion = item
            }
        } label: {
            Text(item.chipLabel)
                .font(.custom("DMSans-SemiBold", size: 14))
                .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                .padding(.horizontal, 15)
                .frame(height: 38)
                .background {
                    if selected {
                        Capsule()
                            .fill(Palette.bgInverse)
                            .matchedGeometryEffect(id: "occasionFill", in: namespace)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Capsule().strokeBorder(Palette.divider, lineWidth: 1))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(JKPress())
    }
}
