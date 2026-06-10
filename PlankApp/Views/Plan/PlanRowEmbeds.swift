import SwiftUI
import PlankFood

// MARK: - PlanRow fat-row embeds (v5 per UX spec)
//
// Three mini-components that render INSIDE fat PlanRows:
//   - StepsHourChartEmbed: 24-bar hourly distribution chart, peak-scaled,
//     pink palette (accent past + accentSubtle future + solid accent current)
//   - SnapMealEmbed: 48pt meal thumb + macro strip (kcal in accent rose)
//   - MoveExerciseEmbed: 3 × 56pt exercise tiles + "+N more" affordance
//
// All embeds sit BELOW the row header line (sticky + title + subtitle +
// trailing). They start at the same 40pt left indent as the title text
// for visual cohesion — single column down the row.

// MARK: - Steps hourly chart embed

struct StepsHourChartEmbed: View {

    /// 24 ints, oldest → newest (hour 0–23 local). All zeros for
    /// empty / morning state — renders as 1pt min-height bars
    /// (chart skeleton) so the row doesn't reflow when data arrives.
    let hourlyCounts: [Int]

    /// Current hour 0–23 local. Drives the solid-accent "this hour"
    /// cell + the past/future color split.
    let currentHour: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            chart
            axis
        }
    }

    // MARK: Chart

    private var chart: some View {
        GeometryReader { geo in
            let barCount = 24
            let totalGap = CGFloat(barCount - 1) * 2
            let barWidth = max(2, (geo.size.width - totalGap) / CGFloat(barCount))

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { hour in
                    Capsule()
                        .fill(barColor(for: hour))
                        .frame(width: barWidth, height: barHeight(for: hour, maxHeight: geo.size.height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private func barHeight(for hour: Int, maxHeight: CGFloat) -> CGFloat {
        let peak = max(hourlyCounts.max() ?? 0, 1)   // avoid /0
        let value = hourlyCounts[hour]
        // 1pt min so the skeleton is always visible
        let fraction = Double(value) / Double(peak)
        return max(1, maxHeight * CGFloat(fraction))
    }

    /// Founder direction 2026-06-09: pink-first palette over the
    /// cocoa designer-spec default. Brand identity > register-purity.
    /// past = accent rose @ 100%, future = accentSubtle pale pink,
    /// current = solid accent (brightest).
    private func barColor(for hour: Int) -> Color {
        if hour == currentHour { return Palette.accent }
        if hour < currentHour { return Palette.accent.opacity(0.7) }
        return Palette.accentSubtle
    }

    // MARK: Axis labels

    private var axis: some View {
        HStack {
            axisLabel("6a", hour: 6)
            Spacer()
            axisLabel("9a", hour: 9)
            Spacer()
            axisLabel("12p", hour: 12)
            Spacer()
            axisLabel("3p", hour: 15)
            Spacer()
            axisLabel("6p", hour: 18)
            Spacer()
            axisLabel("9p", hour: 21)
        }
        .accessibilityHidden(true)
    }

    private func axisLabel(_ text: String, hour: Int) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .regular))
            .foregroundStyle(Palette.cocoaTertiary)
    }
}

// MARK: - Snap meal embed

struct SnapMealEmbed: View {

    /// Total kcal for today from FoodLogPersister.todayMacros().
    let kcal: Int
    /// Total protein g from FoodLogPersister.todayMacros().
    let proteinG: Int
    /// Total carbs g.
    let carbsG: Int
    /// Total fat g.
    let fatG: Int
    /// Today's most recent meal photo, if any. Phase 1.B can wire
    /// FoodLogRecord image data; for Phase 1 ship we render the
    /// placeholder unless `image != nil`.
    let mostRecentMealImage: UIImage?

    private var isEmpty: Bool { kcal == 0 }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            if isEmpty {
                emptyCopy
            } else {
                macroStrip
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Thumbnail (48pt)

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Palette.bgPrimary)
            if let image = mostRecentMealImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "camera")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .frame(width: 48, height: 48)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Palette.hairlineCocoa, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    // MARK: Empty-state copy (italic Fraunces full-phrase exception)

    private var emptyCopy: some View {
        // v5 §v5.7 sanctioned the full-phrase italic Fraunces here
        // as the empty-state CTA — the only spot on PlanView where
        // italic Fraunces runs a full sentence (vs punch word only).
        Text("tap to snap your first")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
            .foregroundStyle(Palette.cocoaSecondary)
    }

    // MARK: Macro strip — kcal in accent rose, macros in cocoaSecondary

    private var macroStrip: some View {
        (
            Text("\(kcal.formatted(.number.grouping(.automatic))) cal")
                .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.accent)
            +
            Text("  ·  \(proteinG)p  ·  \(carbsG)c  ·  \(fatG)f")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
        )
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

// MARK: - Move exercise preview embed

struct MoveExerciseEmbed: View {

    /// 3-tile preview of today's workout. Static placeholders for
    /// Phase 1 ship; Phase 1.B will wire WorkoutGenerator's actual
    /// previewExercises(profile:bodyFocus:limit:) here.
    struct Exercise {
        let displayNumber: Int   // 1, 2, 3
        let name: String         // truncated single line
    }

    let exercises: [Exercise]
    let moreCount: Int   // 0 = hide "+N more"

    /// Phase 1 ship placeholder — three generic session phases until
    /// Phase 1.B wires WorkoutGenerator.previewExercises with the
    /// actual exercise IDs for today's prescription.
    static let placeholder: [Exercise] = [
        .init(displayNumber: 1, name: "warm-up"),
        .init(displayNumber: 2, name: "main set"),
        .init(displayNumber: 3, name: "stretch"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(exercises.prefix(3), id: \.displayNumber) { exercise in
                tile(for: exercise)
            }
            if moreCount > 0 {
                moreIndicator
            }
            Spacer(minLength: 0)
        }
    }

    private func tile(for exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    // Founder direction 2026-06-09: pink-first palette.
                    // accentSubtle fill + accent rose display numeral.
                    .fill(Palette.accentSubtle)
                Text("\(exercise.displayNumber)")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .title3))
                    .foregroundStyle(Palette.accent)
                    .padding(.top, 6)
                    .padding(.leading, 8)
            }
            .frame(width: 56, height: 56)

            Text(exercise.name)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Palette.cocoaSecondary)
                .lineLimit(1)
                .frame(width: 56, alignment: .leading)
        }
    }

    private var moreIndicator: some View {
        HStack(spacing: 4) {
            Text("·")
                .foregroundStyle(Palette.cocoaTertiary)
            Text("+ \(moreCount) more")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
        }
        .padding(.top, 18)   // vertically center on the 56pt tile row
    }
}
