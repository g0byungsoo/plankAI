import SwiftUI
import PlankSync

struct PostRoutineView: View {
    let exerciseResults: [ExerciseResultEntry]
    let totalDuration: TimeInterval
    let workoutName: String
    let streakCount: Int
    let isFirstWorkoutToday: Bool
    let onRate: (Int, [String]) -> Void
    let onDone: () -> Void

    @State private var phase = 0           // 0=black, 1=fire, 2=stats, 3=streak, 4=rate
    @State private var selectedRating: Int = 0
    @State private var selectedTags: Set<String> = []
    @State private var confettiTrigger = 0
    @State private var fireScale: CGFloat = 0.3
    @State private var fireOpacity: Double = 0
    @State private var streakScale: CGFloat = 0.5
    @State private var particles: [ConfettiParticle] = []

    private var completedCount: Int {
        exerciseResults.filter { !$0.skipped }.count
    }

    private var completionRate: Double {
        guard !exerciseResults.isEmpty else { return 0 }
        return Double(completedCount) / Double(exerciseResults.count)
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            // Confetti particles
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(p.position)
                    .opacity(p.opacity)
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
        // Phase 1: Fire burst (0.6s)
        Haptics.doubleVibrate()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            phase = 1
            fireScale = 1.0
            fireOpacity = 1.0
        }

        // Spawn confetti
        spawnConfetti()

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
                // Extra confetti for streak
                spawnConfetti()
            } else {
                phase = 3
            }
        }

        // Phase 4: Rating (2.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.3)) {
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
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var headline: String {
        if completionRate >= 0.9 { return "You ate that." }
        if completionRate >= 0.6 { return "Good work." }
        return "You showed up."
    }

    // MARK: - Stats Block

    private var statsBlock: some View {
        VStack(spacing: Space.md) {
            Text(workoutName.uppercased())
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            HStack(spacing: Space.md) {
                statPill(
                    value: formatDuration(totalDuration),
                    label: "TIME",
                    icon: "clock"
                )
                statPill(
                    value: "\(completedCount)/\(exerciseResults.count)",
                    label: "DONE",
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
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
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

            Text("\(streakCount) DAY STREAK")
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)
                .tracking(2)

            Text(streakMessage)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
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
        .plankShadow()
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
            Text("HOW WAS THAT?")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            HStack(spacing: Space.lg) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.light()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                star <= selectedRating ? Palette.accent : Palette.divider
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
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

    // MARK: - Confetti

    private func spawnConfetti() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let colors: [Color] = [Palette.accent, Palette.stateGood, Palette.accentSubtle, .orange, .yellow]

        for _ in 0..<40 {
            let p = ConfettiParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: -50...0)
                ),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                opacity: 1.0
            )
            particles.append(p)
        }

        // Animate particles falling
        withAnimation(.easeIn(duration: 2.5)) {
            for i in particles.indices {
                particles[i].position.y += screenHeight + 100
                particles[i].position.x += CGFloat.random(in: -80...80)
                particles[i].opacity = 0
            }
        }

        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            particles.removeAll()
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

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
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
