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
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                Text("👋")
                    .font(.system(size: 72))

                VStack(spacing: Space.sm) {
                    Text("Session ended early")
                        .font(Typo.titleItalic)
                        .foregroundStyle(Palette.textPrimary)
                    Text("You completed \(Int(completionRate * 100))% — finish at least 70% next time and it'll count toward your streak.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                }

                Spacer()

                Button(action: onDone) {
                    Text("BACK")
                        .font(Typo.body).fontWeight(.bold).tracking(2)
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.minTapTarget + 12)
                        .background(Palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.xl)
            }
        }
    }

    // MARK: - Celebration

    private var celebrationBody: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

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

                        if selectedRating > 0 {
                            tagSection
                                .padding(.horizontal, Space.screenPadding)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer().frame(height: Space.sm)

                        doneButton
                            .padding(.horizontal, Space.screenPadding)
                            .transition(.opacity)
                    }

                    Spacer().frame(height: Space.xl)
                }
            }
        }
        .onAppear { runCelebrationSequence() }
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

        // Phase 2: Stats slide in (1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Haptics.medium()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = 2
            }
        }

        // Phase 3: Streak (2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if isFirstWorkoutToday && streakCount > 0 {
                Haptics.vibrate()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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
            HStack(spacing: Space.xs) {
                ForEach(0..<min(streakCount, 7), id: \.self) { i in
                    Text("🔥")
                        .font(.system(size: i == streakCount - 1 ? 32 : 20))
                        .scaleEffect(streakScale)
                }
            }

            (
                Text("\(streakCount) ").font(.custom("Fraunces72pt-SemiBold", size: 28)) +
                Text("day streak").font(Typo.titleItalic)
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

    private var streakMessage: String {
        switch streakCount {
        case 1: return "First day. This is how it starts."
        case 2...3: return "Building the habit."
        case 4...6: return "Consistency hits different."
        case 7: return "One full week. Respect."
        case 8...13: return "You're locked in."
        case 14: return "Two weeks. This is you now."
        case 15...29: return "Can't stop won't stop."
        default: return "Built different."
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
        ["too_easy", "too_hard", "loved_it", "boring", "good_variety"]
    }

    private func tagLabel(_ tag: String) -> String {
        switch tag {
        case "too_easy": return "Too Easy"
        case "too_hard": return "Too Hard"
        case "loved_it": return "Loved It"
        case "boring": return "Boring"
        case "good_variety": return "Good Variety"
        default: return tag
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            Haptics.medium()
            if selectedRating > 0 {
                onRate(selectedRating, Array(selectedTags))
            }
            onDone()
        } label: {
            Text("DONE")
                .font(Typo.body)
                .fontWeight(.bold)
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: Space.minTapTarget + 12)
                .background(Palette.bgInverse)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .padding(.bottom, Space.lg)
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
