import SwiftUI
import PlankFood
import Combine

// MARK: - TodayPathStrip
//
// v1.0.7 Phase B Today strip per the 2-expert anxiety-review pass:
//   docs/today_strip_research_fitness_ux_2026_06_06.md (path-bars verdict)
//   docs/today_strip_research_wl_genz_ux_2026_06_06.md (no-reset verdict)
//
// Replaces the Apple Activity Ring metaphor. Both experts pushed back
// strongly: ring closure is a documented retention liability for
// TikTok-acquired Gen-Z women (post-Ozempic + ED-vulnerability +
// post-Apple-Watch backlash). Apple themselves shipped Pause Rings in
// watchOS 11 as a partial admission of the moral-failure framing.
//
// What ships instead:
//   - 3 horizontal capsule bars with soft asymptote at 85%
//     - Food kcal today (anti-restriction: positive copy at low values)
//     - Steps today (HealthKit-backed, 7,500 anchor)
//     - Breath: dot strip (3 dots max — counting breathing kills its
//       mechanism per the WL Gen-Z brief §3)
//   - Italic-Fraunces qualitative word LEFT of each bar
//     (state → "fueled" / "steady" / "moving" / "grounded")
//   - Soft cocoa fill on bars — never red, never percentages, never
//     fractions
//   - No daily reset visual semantics. The empty state IS positive
//     copy ("ready when you are"), so there's no "you failed" moment
//     to recover from.

struct TodayPathStrip: View {

    let userId: String
    let foodTargetKcal: Double

    @State private var foodTodayKcal: Double = 0
    @State private var stepsToday: Int = 0
    @State private var breathSessionsToday: Int = 0

    @State private var cancellable: AnyCancellable?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 12) {
                foodRow
                stepsRow
                breathRow
            }
            .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.accent.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Palette.textPrimary.opacity(0.12), radius: 0, x: 2, y: 2)
        .onAppear(perform: refresh)
        .onAppear {
            cancellable = FoodLogPersister.changeNotifier.sink { _ in refresh() }
        }
        .onDisappear { cancellable?.cancel() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TODAY")
                .font(Typo.eyebrow)
                .tracking(2)
                .foregroundStyle(Palette.accent)
            Text("♥")
                .font(.system(size: 11))
                .foregroundStyle(Palette.accent)
            Spacer()
        }
    }

    // MARK: - Food row

    private var foodRow: some View {
        rowLayout(
            word: foodWord,
            italicTokens: ["fueled", "steady", "starting", "ready"],
            bar: AnyView(softBar(progress: foodProgress)),
            trailingLabel: "\(Int(foodTodayKcal.rounded())) cal"
        )
    }

    /// 0-30%  → "*starting* ♥" (anti-restriction; "starting" is a
    ///          positive invitation, never a failure read)
    /// 30-70% → "*steady* ♥"
    /// 70%+   → "*fueled* ♥"
    private var foodWord: (base: String, italic: [String]) {
        let frac = foodTodayKcal / max(foodTargetKcal, 1)
        switch frac {
        case ..<0.30:   return ("starting ♥", ["starting"])
        case 0.30..<0.70: return ("steady ♥", ["steady"])
        default:        return ("fueled ♥", ["fueled"])
        }
    }

    /// Soft asymptote — bar visually caps at 85% even when user crosses
    /// 100% of target. Removes the "you went over" anxiety read.
    private var foodProgress: Double {
        let raw = foodTodayKcal / max(foodTargetKcal, 1)
        return min(0.85, raw)
    }

    // MARK: - Steps row

    private var stepsRow: some View {
        rowLayout(
            word: stepsWord,
            italicTokens: ["moving", "steady", "lots"],
            bar: AnyView(softBar(progress: stepsProgress)),
            trailingLabel: stepsToday.formatted(.number.grouping(.automatic))
        )
    }

    /// <2500 → "*moving*"
    /// 2500-7500 → "*steady* ♥"
    /// 7500+ → "*lots* ♥"
    /// All positive — no "you didn't walk enough" read.
    private var stepsWord: (base: String, italic: [String]) {
        switch stepsToday {
        case ..<2500:    return ("moving", ["moving"])
        case 2500..<7500: return ("steady ♥", ["steady"])
        default:         return ("lots ♥", ["lots"])
        }
    }

    private var stepsProgress: Double {
        let raw = Double(stepsToday) / 7500.0
        return min(0.85, raw)
    }

    // MARK: - Breath row (dots, not bar)

    /// Three dots, fill left→right. 0 sessions = all three outlined
    /// (positive empty state copy carries the meaning, not the dots).
    /// Per the Gen-Z UX brief §3: counting breath kills its mechanism;
    /// the dots cap at 3 and reframe additional sessions as "kept
    /// coming back ♥" rather than incrementing a counter.
    private var breathRow: some View {
        rowLayout(
            word: breathWord,
            italicTokens: ["grounded", "ready", "kept"],
            bar: AnyView(breathDots),
            trailingLabel: breathSessionsToday > 0
                ? "\(min(breathSessionsToday, 3))"
                : ""
        )
    }

    private var breathWord: (base: String, italic: [String]) {
        if breathSessionsToday == 0 {
            return ("ready when you are", [])
        } else if breathSessionsToday >= 3 {
            return ("kept coming back ♥", ["kept"])
        } else {
            return ("grounded ♥", ["grounded"])
        }
    }

    private var breathDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                let filled = idx < min(breathSessionsToday, 3)
                Circle()
                    .fill(filled ? Palette.accent : Color.clear)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle().stroke(Palette.accent.opacity(0.5), lineWidth: 1)
                    )
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared row layout

    @ViewBuilder
    private func rowLayout(
        word: (base: String, italic: [String]),
        italicTokens: [String],
        bar: AnyView,
        trailingLabel: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ItalicAccentText(
                word.base,
                italic: word.italic,
                baseFont: .custom("Fraunces72pt-Regular", size: 14),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .frame(width: 124, alignment: .leading)

            bar
                .frame(maxWidth: .infinity)

            if !trailingLabel.isEmpty {
                Text(trailingLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
            } else {
                Spacer().frame(width: 64)
            }
        }
        .frame(height: 36)
        .accessibilityElement(children: .combine)
    }

    /// Soft capsule bar. Caps visually at 85% by the progress clamp
    /// upstream; the bar itself is just a clean linear fill with no
    /// "100% closed" state, no red, no goal-line marker.
    private func softBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.accent.opacity(0.12))
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    // MARK: - Data refresh

    private func refresh() {
        // Food — in-memory FoodLogPersister stop-gap (until v1.0.8
        // SwiftData lands). today aggregator is already userId-scoped.
        let today = FoodLogPersister.todayAndWeekly(userId: userId)
        foodTodayKcal = today.today

        // Steps — published @Observable on StepsService.shared.
        stepsToday = StepsService.shared.todayCount

        // Breath — derive "did she breathe today" from lastCompletedAt
        // (BreathworkState doesn't track per-day counts). Counted as
        // 1+ when lastCompletedAt is today; the dot strip caps at 3 so
        // we never need an exact count.
        if let last = BreathworkState.shared.lastCompletedAt,
           Calendar.current.isDateInToday(last) {
            // Conservative: assume 1 session today unless the local
            // engagement signal says otherwise. v1.0.8 will track
            // per-day counts directly when BreathworkState adds it.
            breathSessionsToday = 1
        } else {
            breathSessionsToday = 0
        }
    }
}
