import SwiftUI

// MARK: - BreathworkBentoTile
//
// The depth read of breathwork — slotted in the Becoming bento alongside
// the trend, forecast, milestone, and movement tiles. Same chrome + ⓘ
// explainer pattern as `StepsBentoTile`.
//
// Where the home card is an actionable CTA ("breathe with jeni →"), this
// tile is a passive identity read of the practice — how many distinct
// days you breathed this week, total breaths over time, and a warm vibe
// line. Tapping the tile itself does NOT launch a session here (the home
// card carries that affordance); tapping the ⓘ opens the .breath
// explainer with the science.
//
// Empty state ("you haven't tried it yet") points the user gently back
// to the home card — one entry point, never duplicated affordances.

struct BreathworkBentoTile: View {
    @Bindable var state: BreathworkState

    /// Caller injects to open the explainer sheet — matches the existing
    /// `tileHeader(_:_:)` pattern in AnalyticsView where the ⓘ tap sets
    /// `presentedMetric` on the parent.
    var onExplain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(chrome)
        .overlay(alignment: .topTrailing) { sticker }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Layers

    private var header: some View {
        HStack(spacing: 5) {
            Text("breath")
                .font(Typo.eyebrow).tracking(1.5)
                .foregroundStyle(Palette.accent)
            Button {
                Haptics.light()
                onExplain()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary.opacity(0.55))
                    .tappableArea()
            }
            .accessibilityLabel("what breath means")
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.totalCompleted == 0 {
            emptyContent
        } else {
            stockedContent
        }
    }

    private var stockedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(state.distinctDaysThisWeek.formatted(.number))
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text(state.distinctDaysThisWeek == 1 ? "day" : "days")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
                Text("this week")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            // 7-day strip — small dots, one per day, oldest → newest.
            // Filled dot = breathed that day; hollow = quiet day. Calmer
            // than bars (this is binary data; bar heights would mislead).
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { idx in
                    let breathed = dotForOffset(6 - idx)
                    Circle()
                        .fill(breathed ? Palette.accent : Color.clear)
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle().stroke(Palette.accent.opacity(0.5), lineWidth: 1)
                        )
                }
                Spacer(minLength: 0)
            }
            .frame(height: 12)

            Text(vibeLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("try one minute")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                .foregroundStyle(Palette.textPrimary)
            Text("the breath card on home opens a quick guided session. it lowers cortisol, the stress hormone keeping your body holding on ♥")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sticker: some View {
        Image(StickerName.heartGlossy.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 38, height: 38)
            .rotationEffect(.degrees(10))
            .offset(x: 8, y: -12)
            .opacity(StickerName.heartGlossy.style.opacity * 0.9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var chrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.accent.opacity(0.12))
                .offset(x: 3, y: 3)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.accent.opacity(0.45), lineWidth: 1.5)
        }
    }

    // MARK: - Reads

    /// Was the user breathed on the day `daysAgo` before today?
    private func dotForOffset(_ daysAgo: Int) -> Bool {
        let cal = Calendar.current
        guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return false }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return state.weekDayKeys.contains(f.string(from: date))
    }

    /// Anti-shame vibe line. Three reads:
    ///   - 3+ days this week → identity affirmation ("steady ritual")
    ///   - 1-2 days this week → "every breath counts"
    ///   - 0 this week BUT total > 0 → soft re-invite
    private var vibeLine: String {
        let d = state.distinctDaysThisWeek
        if d >= 3 { return "this is becoming a ritual ♥" }
        if d >= 1 { return "every breath counts ♥" }
        return "settle for a minute when you can ♥"
    }

    private var accessibilityLabel: String {
        if state.totalCompleted == 0 {
            return "Breath. You haven't tried it yet. Open the breath card on home to try a one-minute session."
        }
        return "Breath. \(state.distinctDaysThisWeek) days this week. \(vibeLine)"
    }
}

#if DEBUG
#Preview("breathwork bento · empty") {
    BreathworkBentoTile(state: BreathworkState.shared, onExplain: {})
        .padding()
        .background(Palette.bgPrimary)
}
#endif
