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

    private var techProtocol: BreathworkProtocol { occasion.techProtocol }

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
                        .background(Circle().fill(Color.white.opacity(0.5)))
                }
                .accessibilityLabel("Close")
            }
            .padding(.top, Space.md)

            Spacer().frame(height: Space.lg)

            ItalicAccentText(
                "how do you want to feel?",
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

            // Occasion chips — single row, default pre-selected, a tap
            // swaps the card beneath (no navigation, no lobby).
            HStack(spacing: Space.sm) {
                ForEach(BreathOccasion.allCases) { item in
                    let selected = occasion == item
                    Button {
                        Haptics.light()
                        withAnimation(Motion.tap) { occasion = item }
                    } label: {
                        Text(item.chipLabel)
                            .font(.custom("DMSans-SemiBold", size: 14))
                            .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(
                                Capsule().fill(selected ? Palette.bgInverse : Color.white.opacity(0.55))
                            )
                            .overlay(
                                Capsule().stroke(Palette.divider, lineWidth: selected ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
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
                        Text("\(m) min")
                            .font(.custom("DMSans-Medium", size: 13))
                            .monospacedDigit()
                            .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(
                                Capsule().fill(selected ? Color.white.opacity(0.7) : .clear)
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
        }
        .padding(.horizontal, Space.lg)
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
