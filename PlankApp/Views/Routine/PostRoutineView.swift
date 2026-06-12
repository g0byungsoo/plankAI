import SwiftUI
import PlankSync

struct PostRoutineView: View {
    let exerciseResults: [ExerciseResultEntry]
    let totalDuration: TimeInterval
    let workoutName: String
    let streakCount: Int
    let isFirstWorkoutToday: Bool
    /// `false` when the user ended below the 70% completion threshold.
    /// Drives a quieter "session ended early" body instead of the
    /// celebration sequence — the session won't have been saved either.
    let didMeetThreshold: Bool
    let onRate: (Int, [String]) -> Void
    let onDone: () -> Void

    @State private var phase = 0           // 0=black, 1=fire, 2=stats, 3=streak, 4=rate
    @State private var selectedRating: Int = 0
    @State private var selectedTags: Set<String> = []
    /// Relative difficulty feedback ("too_easy"/"just_right"/"too_hard").
    /// Feeling-based + relative (not RPE numbers) — beginners can't
    /// self-rate exertion. Nudges next session's energy.
    @State private var effortFeel: String = ""
    @State private var fireScale: CGFloat = 0.3
    @State private var fireOpacity: Double = 0
    @State private var streakScale: CGFloat = 0.5
    @State private var fireworksKey: Int = 0    // bumps to retrigger LottieEffectView playback

    private var completedCount: Int {
        exerciseResults.filter { !$0.skipped }.count
    }

    private var completionRate: Double {
        guard !exerciseResults.isEmpty else { return 0 }
        return Double(completedCount) / Double(exerciseResults.count)
    }

    // Phase 16 — routine celebration scatter (HIGH treatment, 6 stickers,
    // 1 line-art / 5 painterly). Slightly different sticker mix from
    // PostSessionView so back-to-back single-hold + routine completion
    // don't read as the same screen. tulip_bouquet anchors the warmer
    // bottom-right beat.
    private static let celebrationPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.10, y: 0.06),
                         size: 30, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.92, y: 0.10),
                         size: 32, rotation: -10, phaseDelay: 0.18),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.06, y: 0.42),
                         size: 36, rotation: 13, phaseDelay: 0.36),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.94, y: 0.44),
                         size: 32, rotation: -8, phaseDelay: 0.55),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.08, y: 0.92),
                         size: 38, rotation: 11, phaseDelay: 0.72),
        StickerPlacement(sticker: .tulipBouquet,
                         position: CGPoint(x: 0.90, y: 0.93),
                         size: 40, rotation: -12, phaseDelay: 0.90),
    ]

    var body: some View {
        if didMeetThreshold {
            celebrationBody
        } else {
            partialCompletionBody
        }
    }

    // MARK: - Partial Completion

    private var partialCompletionBody: some View {
        ZStack {
            Palette.programEraBg.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                // v1.1 design pass — emoji swapped for the brand bow
                // sticker per the kill-list (no emoji) + sticker-accent
                // vocabulary every other module screen uses.
                Image(StickerName.bowIridescent.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-6))
                    .accessibilityHidden(true)

                VStack(spacing: Space.sm) {
                    // v1.1 module pass — the early exit is information,
                    // never a scolding. The old copy threatened the
                    // streak ("finish at least 70% next time") at the
                    // exact moment she's most likely to not come back.
                    Text("you moved. that counts.")
                        .font(Typo.titleItalic)
                        .foregroundStyle(Palette.textPrimary)
                    Text("you did \(Int(completionRate * 100))% today. stopping early is information, not failure. tomorrow's session will meet you where you are.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                }

                Spacer()

                JFContinueButton(label: "done", action: onDone)
            }
        }
    }

    // MARK: - Celebration

    private var celebrationBody: some View {
        ZStack {
            Palette.programEraBg.ignoresSafeArea()

            StickerScatter(placements: Self.celebrationPlacements)

            // Phase 19d — fireworks Lottie replaces the per-particle Circle
            // confetti shower. The Lottie is bigger / more deliberate; the
            // old shower felt like 2021 Duolingo. Retrigger via .id() bump
            // when the user gets to the celebration moment again.
            if phase >= 1 {
                LottieEffectView(.fireworks, loop: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, Space.xl)
                    .allowsHitTesting(false)
                    .id(fireworksKey)
            }

            // Sparkling-hearts Lottie kicks in at the streak phase, but
            // only when this is the user's first workout today (the
            // moment that earns the extra emotional payload).
            if phase >= 3 && isFirstWorkoutToday && streakCount > 0 {
                LottieEffectView(.sparklingHearts, loop: false)
                    .frame(width: 240, height: 240)
                    .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.lg) {
                    Spacer().frame(height: Space.xl + 20)

                    // Phase 1: Fire emoji burst
                    if phase >= 1 {
                        fireEmoji
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Phase 2: Stats
                    if phase >= 2 {
                        statsBlock
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Phase 3: Streak (only if first workout today)
                    if phase >= 3 && isFirstWorkoutToday && streakCount > 0 {
                        streakBlock
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Phase 4: Rating + done
                    if phase >= 4 {
                        ratingSection
                            .padding(.horizontal, Space.screenPadding)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        effortSection
                            .padding(.horizontal, Space.screenPadding)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        if selectedRating > 0 {
                            tagSection
                                .padding(.horizontal, Space.screenPadding)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Afterglow — soft reinforcement + return reason.
                        // Sits between rating and DONE so it reads as a
                        // parting note from the app, not a celebration
                        // afterthought. No buttons here intentionally:
                        // post-workout is reinforcement, not the moment
                        // to push another action.
                        afterglowBlock
                            .padding(.horizontal, Space.screenPadding)
                            .padding(.top, Space.sm)
                            .transition(.opacity)

                        Spacer().frame(height: Space.sm)

                        doneButton
                            .padding(.horizontal, Space.screenPadding)
                            .transition(.opacity)
                    }

                    Spacer().frame(height: Space.xl)
                }
            }
        }
        .onAppear {
            Analytics.captureScreen("PostRoutine")
            runCelebrationSequence()
        }
    }

    // MARK: - Celebration Sequence

    private func runCelebrationSequence() {
        // Phase 1: Fire burst (0.6s) — fireworks Lottie kicks in via the
        // `phase >= 1` gate in celebrationBody. .id(fireworksKey) bump
        // ensures the Lottie plays from frame 0 even if the view
        // re-renders during the celebration sequence.
        Haptics.doubleVibrate()
        fireworksKey += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            phase = 1
            fireScale = 1.0
            fireOpacity = 1.0
        }

        // Phase 2: Stats slide in. Calm settle (gentleSpring) rather than a
        // bouncy pop — the fire above is the one celebratory burst; the
        // content blocks should resolve smoothly so the sequence reads
        // cohesive, not clunky.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            Haptics.medium()
            withAnimation(Motion.gentleSpring) {
                phase = 2
            }
        }

        // Phase 3: Streak
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if isFirstWorkoutToday && streakCount > 0 {
                Haptics.vibrate()
                withAnimation(Motion.gentleSpring) {
                    phase = 3
                    streakScale = 1.0
                }
                // Re-trigger fireworks Lottie at the streak phase too —
                // doubled celebration when this is the user's first
                // workout of the day.
                fireworksKey += 1
            } else {
                phase = 3
            }
        }

        // Phase 4: Rating (2.8s) — calmer fade-in, the user has just
        // landed; no need to add another spring after the fireworks pop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(Motion.entrance) {
                phase = 4
            }
        }
    }

    // MARK: - Fire Emoji

    private var fireEmoji: some View {
        VStack(spacing: Space.sm) {
            Text(completionRate >= 0.9 ? "🔥" : completionRate >= 0.6 ? "💪" : "👏")
                .font(.system(size: 72))
                .scaleEffect(fireScale)
                .opacity(fireOpacity)

            Text(headline)
                .font(Typo.titleItalic)   // italic Fraunces — JeniFit voice signal
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var headline: String {
        if completionRate >= 0.9 { return "you ate that." }
        if completionRate >= 0.6 { return "good work." }
        return "you showed up."
    }

    // MARK: - Stats Block

    private var statsBlock: some View {
        VStack(spacing: Space.md) {
            Text(workoutName.lowercased())
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)

            HStack(spacing: Space.md) {
                statPill(
                    value: formatDuration(totalDuration),
                    label: "time",
                    icon: "clock"
                )
                statPill(
                    value: "\(completedCount)/\(exerciseResults.count)",
                    label: "done",
                    icon: "checkmark.circle"
                )
            }
            .padding(.horizontal, Space.screenPadding)
        }
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.custom("Fraunces72pt-SemiBold", size: 22))
                    .foregroundStyle(Palette.textPrimary)
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.cardPadding)
        .background(
            // Phase 19d — scrapbook chrome: 24pt corners, 1.5pt accent
            // border, hard offset shadow. Drops the soft drop shadow
            // (`plankShadow`) per the trend research.
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }

    // MARK: - Streak Block

    private var streakBlock: some View {
        VStack(spacing: Space.sm) {
            // v1.1 module pass — the flame-emoji row was the Cal AI
            // streak idiom the research killed app-wide; the cocoa
            // dot row (Becoming's grammar) replaces it. Gain-framed:
            // dots only ever fill.
            HStack(spacing: 6) {
                ForEach(0..<min(streakCount, 7), id: \.self) { _ in
                    Circle()
                        .fill(Palette.cocoaPrimary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(streakScale)
                }
            }

            (
                Text("\(streakCount) ").font(.custom("Fraunces72pt-SemiBold", size: 28)) +
                Text(streakCount == 1 ? "day in" : "days in").font(Typo.titleItalic)
            )
            .foregroundStyle(Palette.textPrimary)

            Text(streakMessage)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Palette.accent, Palette.accentSubtle],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .padding(.horizontal, Space.screenPadding)
    }

    // v1.1 module pass — lowercase voice; the bro register ("built
    // different", "can't stop won't stop") died with the rewrite.
    private var streakMessage: String {
        switch streakCount {
        case 1: return "first day. this is how it starts."
        case 2...3: return "the habit is forming."
        case 4...6: return "consistency looks good on you."
        case 7: return "one full week. that's real."
        case 8...13: return "this is a rhythm now."
        case 14: return "two weeks. this is you now."
        case 15...29: return "quietly unstoppable."
        default: return "this is just what you do now."
        }
    }

    // MARK: - Rating

    private var ratingSection: some View {
        VStack(spacing: Space.md) {
            Text("how was that?")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: Space.lg) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                star <= selectedRating ? Palette.accent : Palette.divider
                            )
                            .scaleEffect(star == selectedRating ? 1.15 : 1.0)
                            .tappableArea()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }

    // MARK: - Effort (relative difficulty → nudges next session's energy)

    private var effortSection: some View {
        VStack(spacing: Space.sm) {
            Text("how'd that feel?")
                .font(Typo.body).fontWeight(.semibold)
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: Space.sm) {
                effortChip("too easy", "too_easy")
                effortChip("just right", "just_right")
                effortChip("too hard", "too_hard")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.15))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }

    private func effortChip(_ label: String, _ value: String) -> some View {
        let sel = effortFeel == value
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { effortFeel = (sel ? "" : value) }
        } label: {
            Text(label)
                .font(Typo.caption).fontWeight(.medium)
                .foregroundStyle(sel ? Palette.textInverse : Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.sm)
                .background(Capsule().fill(sel ? Palette.accent : Palette.bgPrimary.opacity(0.6)))
                .overlay(Capsule().stroke(sel ? Color.clear : Palette.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tags

    private var tagSection: some View {
        FlowLayout(spacing: Space.sm) {
            ForEach(availableTags, id: \.self) { tag in
                Button {
                    Haptics.light()
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    Text(tagLabel(tag))
                        .font(Typo.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(selectedTags.contains(tag) ? Palette.textInverse : Palette.textPrimary)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .background(selectedTags.contains(tag) ? Palette.bgInverse : Palette.bgElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedTags.contains(tag) ? Color.clear : Palette.divider, lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    private var availableTags: [String] {
        ["loved_it", "boring", "good_variety"]
    }

    private func tagLabel(_ tag: String) -> String {
        switch tag {
        case "loved_it": return "loved it"
        case "boring": return "boring"
        case "good_variety": return "good variety"
        default: return tag
        }
    }

    // MARK: - Afterglow

    /// Two-line reinforcement block. First line confirms the loop (small
    /// repeats > single big effort — anti-shame, anti-streak-anxiety).
    /// Second line gives a concrete return reason without committing to
    /// a specific workout (we don't pre-generate tomorrow's routine; the
    /// promise is just "there will be one"). Soft register, calm cadence,
    /// no exclamation marks, no challenge language.
    private var afterglowBlock: some View {
        VStack(spacing: Space.xs) {
            Text("small repeats are how trends form.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            Text("tomorrow's short one is waiting.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Done Button

    // v1.1 module pass — one-CTA system (the caps "DONE" rounded-rect
    // was the last off-system button on the celebration).
    private var doneButton: some View {
        JFContinueButton(label: "done") {
            // Deliver the rating + tags + the relative effort feel (the
            // effort drives the next-session energy nudge in RoutineSessionView).
            let tags = Array(selectedTags) + (effortFeel.isEmpty ? [] : [effortFeel])
            if selectedRating > 0 || !effortFeel.isEmpty {
                onRate(selectedRating, tags)
            }
            onDone()
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions
        )
    }
}
