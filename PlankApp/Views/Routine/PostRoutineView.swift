import SwiftUI
import PlankSync

struct PostRoutineView: View {
    let exerciseResults: [ExerciseResultEntry]
    let totalDuration: TimeInterval
    let workoutName: String
    let onRate: (Int, [String]) -> Void
    let onDone: () -> Void

    @State private var showStats = false
    @State private var selectedRating: Int = 0
    @State private var selectedTags: Set<String> = []

    private var completedCount: Int {
        exerciseResults.filter { !$0.skipped }.count
    }

    private var skippedCount: Int {
        exerciseResults.filter { $0.skipped }.count
    }

    private var completionRate: Double {
        guard !exerciseResults.isEmpty else { return 0 }
        return Double(completedCount) / Double(exerciseResults.count)
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.lg) {
                    Spacer().frame(height: Space.xl)

                    if showStats {
                        // Celebration
                        Text(completionRate >= 0.9 ? "🔥" : completionRate >= 0.6 ? "💪" : "👏")
                            .font(.system(size: 64))
                            .transition(.scale.combined(with: .opacity))

                        Text(headline)
                            .font(Typo.title)
                            .foregroundStyle(Palette.textPrimary)

                        Text(workoutName)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)

                        // Stats
                        HStack(spacing: Space.sm) {
                            statCard(
                                value: formatDuration(totalDuration),
                                label: "DURATION"
                            )
                            statCard(
                                value: "\(completedCount)/\(exerciseResults.count)",
                                label: "EXERCISES"
                            )
                        }
                        .padding(.horizontal, Space.screenPadding)

                        // Rating
                        ratingSection
                            .padding(.horizontal, Space.screenPadding)

                        // Tags (show after rating)
                        if selectedRating > 0 {
                            tagSection
                                .padding(.horizontal, Space.screenPadding)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer().frame(height: Space.lg)

                        // Done button
                        Button {
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
                        .padding(.horizontal, Space.screenPadding)
                        .padding(.bottom, Space.lg)
                    }
                }
            }
        }
        .onAppear {
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                Haptics.heavy()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showStats = true
                }
            }
        }
    }

    // MARK: - Headline

    private var headline: String {
        if completionRate >= 0.9 { return "Crushed it." }
        if completionRate >= 0.6 { return "Good work." }
        return "You showed up."
    }

    // MARK: - Rating

    private var ratingSection: some View {
        VStack(spacing: Space.sm) {
            Text("HOW WAS THAT?")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            HStack(spacing: Space.md) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.light()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                star <= selectedRating ? Palette.accent : Palette.divider
                            )
                    }
                }
            }
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    // MARK: - Tags

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("ANY NOTES?")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            FlowLayout(spacing: Space.sm) {
                ForEach(availableTags, id: \.self) { tag in
                    TagButton(
                        label: tagLabel(tag),
                        isSelected: selectedTags.contains(tag)
                    ) {
                        Haptics.light()
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    private var availableTags: [String] {
        ["too_easy", "too_hard", "loved_it", "boring", "good_variety", "too_long", "too_short"]
    }

    private func tagLabel(_ tag: String) -> String {
        switch tag {
        case "too_easy": return "Too Easy"
        case "too_hard": return "Too Hard"
        case "loved_it": return "Loved It"
        case "boring": return "Boring"
        case "good_variety": return "Good Variety"
        case "too_long": return "Too Long"
        case "too_short": return "Too Short"
        default: return tag
        }
    }

    // MARK: - Helpers

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: Space.xs) {
            Text(value)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}

// MARK: - Tag Button

private struct TagButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typo.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Palette.textInverse : Palette.textPrimary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(isSelected ? Palette.bgInverse : Palette.bgElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Palette.divider, lineWidth: 1)
                )
        }
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
