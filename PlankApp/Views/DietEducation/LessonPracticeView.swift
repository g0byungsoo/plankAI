import SwiftUI

// MARK: - LessonPracticeView (v1.1 — roundtable redesign 2026-06-14)
//
// Three embedded-practice surfaces that swap a lesson page's prose body
// for an interactive moment. Per the 4-expert roundtable consensus:
// psychoeducation alone has a low clinical ceiling; the three lessons
// whose mechanism IS the practice (Day 8 self-compassion, Day 9 cyclic
// sighing under food noise, Day 14 implementation intention) each get a
// surface that gates the lesson's terminal CTA on completing the
// practice instead of just tapping past it.
//
// Design rules locked in this file:
//   • All practice state is ephemeral @State. Nothing is written to
//     Supabase, SwiftData, AppStorage, or the analytics props blob.
//     The user's words / breath count are her own; data-provenance +
//     restriction-cohort safety both require this.
//   • Skip-X stays available at the parent (`JeniMethodRitualView`);
//     this view does not own the close affordance. Wellness, not
//     prescription.
//   • Reduce-motion path: timer rings snap to filled state, phrases
//     cross-fade instead of staircase, breath ring opacity-only.
//   • Dynamic Type ≥ accessibility1 tested — no fixed body heights.

struct LessonPracticeView: View {
    let practice: LessonPracticeKind
    /// Fires when the practice's gating condition completes (timer
    /// runs out / field commits). Parent enables the CTA in response.
    let onComplete: () -> Void

    var body: some View {
        switch practice {
        case let .timedPause(seconds, phrases):
            TimedPausePractice(totalSeconds: seconds,
                               phrases: phrases,
                               onComplete: onComplete)
        case let .guidedBreath(seconds):
            GuidedBreathPractice(totalSeconds: seconds,
                                 onComplete: onComplete)
        case let .implementationIntention(promptIf, promptThen):
            ImplementationIntentionPractice(promptIf: promptIf,
                                            promptThen: promptThen,
                                            onComplete: onComplete)
        }
    }
}

// MARK: - 1. Timed pause (Day 8 self-compassion)
//
// Neff 2003 self-compassion break. Three phrases cycled on a timer
// (~20s each at default 60s total). Ring fills from 0 → 1 over the
// full duration; on completion the ring snaps to solid + a success
// haptic + onComplete fires (which unlocks the parent CTA). Lock-
// screen / app-background pauses the timer instead of resetting.

private struct TimedPausePractice: View {
    let totalSeconds: Int
    let phrases: [String]
    let onComplete: () -> Void

    @State private var elapsed: Double = 0
    @State private var phraseIndex: Int = 0
    @State private var completed: Bool = false
    @State private var timer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Space.xl) {
            ringWithText
                .frame(width: 220, height: 220)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(currentPhrase)
                .accessibilityValue(completed
                                    ? "complete"
                                    : "\(Int(elapsed)) of \(totalSeconds) seconds")
            captionLine
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
        .onAppear(perform: startTimer)
        .onDisappear { timer?.invalidate() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:   if !completed { startTimer() }
            case .inactive, .background: timer?.invalidate()
            @unknown default: break
            }
        }
    }

    private var ringWithText: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Palette.hairlineCocoa, lineWidth: 2)
            // Progress ring — fills clockwise from 12 o'clock
            Circle()
                .trim(from: 0, to: completed ? 1 : min(elapsed / Double(totalSeconds), 1))
                .stroke(Palette.cocoaPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .none : .linear(duration: 0.25), value: elapsed)
            // Centered phrase — cross-fades on phrase change
            phraseText
                .padding(.horizontal, Space.lg)
        }
    }

    private var phraseText: some View {
        ItalicAccentText(
            currentPhrase,
            italic: italicPunchWords(in: currentPhrase),
            baseFont: Typo.heroHeadline,
            italicFont: Typo.heroHeadlineItalic,
            color: Palette.textPrimary,
            alignment: .center
        )
        .id(phraseIndex)
        .transition(.opacity)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.45),
                   value: phraseIndex)
    }

    private var captionLine: some View {
        Text(completed ? "rest here as long as you'd like." : "stay here. breathe slow.")
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.45),
                       value: completed)
    }

    private var currentPhrase: String {
        guard !phrases.isEmpty else { return "" }
        return phrases[min(phraseIndex, phrases.count - 1)]
    }

    /// Punch words to italicize per phrase. Founder voice signal —
    /// italic-Fraunces only on the load-bearing word. Conservative
    /// match list per Neff's canonical phrasing.
    private func italicPunchWords(in phrase: String) -> [String] {
        let candidates = ["struggle", "human", "kind"]
        return candidates.filter { phrase.contains($0) }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { t in
            elapsed += 0.25
            // Advance phrase at even slices
            let perPhrase = Double(totalSeconds) / Double(max(phrases.count, 1))
            let newIndex = min(Int(elapsed / perPhrase), phrases.count - 1)
            if newIndex != phraseIndex { phraseIndex = newIndex }
            if elapsed >= Double(totalSeconds), !completed {
                completed = true
                Haptics.success()
                onComplete()
                t.invalidate()
            }
        }
    }
}

// MARK: - 2. Guided breath (Day 9 food noise)
//
// 60s cyclic sighing per Balban 2023 — double inhale through nose,
// long exhale through mouth, repeat. Pattern: 1.5s short inhale +
// 1.0s second inhale + 4.5s exhale ≈ 7s cycle. Ring expands on
// inhale, contracts on exhale; soft haptic at each transition. Same
// scene-phase pause behavior as TimedPause.

private struct GuidedBreathPractice: View {
    let totalSeconds: Int
    let onComplete: () -> Void

    /// Cycle phase indices: 0 = inhale-1, 1 = inhale-2, 2 = exhale.
    @State private var phase: Int = 0
    @State private var elapsed: Double = 0
    @State private var completed: Bool = false
    @State private var timer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let inhale1: Double = 1.5
    private let inhale2: Double = 1.0
    private let exhale:  Double = 4.5

    var body: some View {
        VStack(spacing: Space.xl) {
            breathRing
                .frame(width: 240, height: 240)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(phaseLabel)
                .accessibilityValue(completed
                                    ? "complete"
                                    : "\(Int(elapsed)) of \(totalSeconds) seconds")
            captionLine
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
        .onAppear(perform: startTimer)
        .onDisappear { timer?.invalidate() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:   if !completed { startTimer() }
            case .inactive, .background: timer?.invalidate()
            @unknown default: break
            }
        }
    }

    private var breathRing: some View {
        ZStack {
            Circle()
                .stroke(Palette.hairlineCocoa, lineWidth: 2)
            Circle()
                .fill(Palette.accentSubtle.opacity(0.45))
                .scaleEffect(ringScale)
                .animation(reduceMotion ? .none : phaseAnimation, value: phase)
            Text(phaseLabel)
                .font(Typo.heroHeadline)
                .foregroundStyle(Palette.textPrimary)
                .id(phase)
                .transition(.opacity)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.4),
                           value: phase)
        }
    }

    private var ringScale: CGFloat {
        // Inhale phases swell toward 1.0; exhale collapses toward 0.6.
        switch phase {
        case 0:  return 0.75   // small inhale-1
        case 1:  return 1.0    // peak inhale-2
        default: return 0.6    // long exhale
        }
    }

    private var phaseAnimation: Animation {
        switch phase {
        case 0:  return .easeOut(duration: inhale1)
        case 1:  return .easeOut(duration: inhale2)
        default: return .easeIn(duration: exhale)
        }
    }

    private var phaseLabel: String {
        switch phase {
        case 0:  return "in"
        case 1:  return "in"
        default: return "out"
        }
    }

    private var captionLine: some View {
        Text(completed ? "you're back. now decide." : "double in. long out.")
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.45),
                       value: completed)
    }

    private func startTimer() {
        timer?.invalidate()
        scheduleNextPhase()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { t in
            elapsed += 0.25
            if elapsed >= Double(totalSeconds), !completed {
                completed = true
                Haptics.success()
                onComplete()
                t.invalidate()
            }
        }
    }

    /// Walks 0 → 1 → 2 → 0 with each step's wall-clock dwell.
    /// Soft haptic on every transition.
    private func scheduleNextPhase() {
        let dwell: Double
        switch phase {
        case 0:  dwell = inhale1
        case 1:  dwell = inhale2
        default: dwell = exhale
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dwell) {
            guard !completed else { return }
            phase = (phase + 1) % 3
            Haptics.soft()
            scheduleNextPhase()
        }
    }
}

// MARK: - 3. Implementation intention (Day 14 fresh-start)
//
// Single-field if-then builder. User types her own tiny intention
// ("after my morning coffee, i'll move"). On commit the field
// collapses into a mirrored read-back below ("you said: …"), success
// haptic, and onComplete fires. Field stays editable until commit; X
// at the parent can still close without commit.

private struct ImplementationIntentionPractice: View {
    let promptIf: String
    let promptThen: String
    let onComplete: () -> Void

    @State private var text: String = ""
    @State private var committed: String? = nil
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            promptStack
            if let committed {
                mirror(committed)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                inputField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.lg)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.32),
                   value: committed)
    }

    private var promptStack: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(promptIf)
                .font(Typo.eyebrow)
                .foregroundStyle(Palette.textSecondary)
                .textCase(.lowercase)
            Text(promptThen)
                .font(Typo.eyebrow)
                .foregroundStyle(Palette.textSecondary)
                .textCase(.lowercase)
        }
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            TextField("", text: $text, axis: .vertical)
                .font(Typo.heroHeadline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2...3)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(commit)
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)
            HStack {
                Text("type yours, then tap save")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Button("save", action: commit)
                    .font(.custom("DMSans-SemiBold", size: 14))
                    .foregroundStyle(text.trimmed.isEmpty
                                     ? Palette.cocoaTertiary
                                     : Palette.cocoaPrimary)
                    .disabled(text.trimmed.isEmpty)
                    .accessibilityHint("commits your intention and unlocks continue")
            }
        }
        .onAppear { isFocused = true }
    }

    private func mirror(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("you said")
                .font(Typo.eyebrow)
                .foregroundStyle(Palette.textSecondary)
            ItalicAccentText(
                "\u{201C}\(value)\u{201D}",
                italic: [],
                baseFont: Typo.heroHeadlineItalic,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text("that's the line. start there.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.xs)
        }
    }

    private func commit() {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty, committed == nil else { return }
        committed = trimmed
        isFocused = false
        Haptics.success()
        onComplete()
    }
}

private extension String {
    var trimmed: String { self.trimmingCharacters(in: .whitespacesAndNewlines) }
}

#if DEBUG
#Preview("timed pause") {
    LessonPracticeView(
        practice: .timedPause(
            seconds: 10,
            phrases: [
                "this is a moment of struggle.",
                "struggle is part of being human.",
                "may i be kind to myself."
            ]
        ),
        onComplete: {}
    )
    .padding(Space.lg)
    .background(Palette.bgPrimary)
}

#Preview("guided breath") {
    LessonPracticeView(
        practice: .guidedBreath(seconds: 12),
        onComplete: {}
    )
    .padding(Space.lg)
    .background(Palette.bgPrimary)
}

#Preview("implementation intention") {
    LessonPracticeView(
        practice: .implementationIntention(
            promptIf: "after my morning coffee,",
            promptThen: "i'll _________________."
        ),
        onComplete: {}
    )
    .padding(Space.lg)
    .background(Palette.bgPrimary)
}
#endif
