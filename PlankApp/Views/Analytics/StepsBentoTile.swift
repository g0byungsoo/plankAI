import SwiftUI

// MARK: - StepsBentoTile
//
// The depth read of step count — slotted in the Becoming bento grid. Where
// the home pulse is a today-only anchor, this tile is the 7-day trend +
// week total, framed as evidence of becoming, not a quota.
//
// Composition follows the established bento idiom (see AnalyticsView's
// trendTile / cadenceTile): tileHeader eyebrow with ⓘ explainer, a small
// y2k sticker overhang, soft bentoChrome card. The 7-day bar chart is
// hand-drawn rectangles (no Charts framework dependency — calmer visual
// + matches the existing weekly bars in WeekProgressStrip).
//
// Anti-shame rules in effect:
//   - under-goal days render the SAME bar style as over-goal days
//     (no red-bar shame, no "missed" labels)
//   - the trailing copy line reads off the trend, not the daily count
//   - .notDetermined / .denied surfaces a quiet "tap home to connect"
//     fallback that points the user back to the pulse CTA (one place to
//     handle permission, not two)

struct StepsBentoTile: View {
    @Bindable var service: StepsService

    /// Caller injects to open the explainer sheet — matches the existing
    /// `tileHeader(_:_:)` pattern in AnalyticsView where the ⓘ tap sets
    /// `presentedMetric` on the parent.
    var onExplain: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Index of the bar currently being scrubbed (0…6). `nil` = default,
    /// header shows week-total + this-week trend line. Tap or drag on the
    /// chart sets this; release schedules a soft revert.
    @State private var scrubIndex: Int? = nil
    /// Reverts the header back to its default state ~1.0s after the user
    /// lifts their finger (matches Apple Health's weekly-chart linger).
    /// Cancelled when a new drag begins so the user can keep exploring.
    @State private var revertTask: Task<Void, Never>? = nil

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
        .task {
            await service.refresh()
            Analytics.track(.stepsViewedBecoming, properties: [
                "week_total": service.weekTotal,
                "auth_status": authStatusString
            ])
        }
    }

    // MARK: - Layers

    private var header: some View {
        HStack(spacing: 5) {
            Text("moving")
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
            .accessibilityLabel("what moving means")
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .authorized = service.authStatus {
            authorizedContent
        } else {
            fallbackContent
        }
    }

    private var authorizedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header morphs between default (week total · "this week") and
            // scrub mode (day count · day label). The default trailing
            // "this week" is replaced by the italic-Fraunces day label so
            // the same horizontal real estate carries either signal —
            // Apple Health pattern: don't float a tooltip, transform the
            // primary read in place. Number rolls via .numericText.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayedCount.formatted(.number))
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("steps")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
                Group {
                    if let i = scrubIndex {
                        Text(dayLabel(for: i))
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                            .foregroundStyle(Palette.accent)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .id("scrub-\(i)")   // re-trigger transition per bar
                    } else {
                        Text("this week")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeOut(duration: 0.18), value: scrubIndex)

            chart

            // Vibe line under the chart morphs the same way the header
            // does — week trend by default, per-day vibe during scrub.
            // Cross-fades so the height stays stable (.fixedSize prevents
            // wraps from shifting the layout mid-drag).
            Text(scrubIndex == nil
                 ? trendLine
                 : dayVibe(for: scrubbedCount))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.18), value: scrubIndex)
        }
    }

    // MARK: - Chart (scrubbable)

    private var chart: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let columns = service.weeklyCounts.count
            let columnW = max(6, (geo.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            let maxCount = max(1, service.weeklyCounts.max() ?? 1)
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(service.weeklyCounts.enumerated()), id: \.offset) { idx, count in
                        let h = max(4, geo.size.height * CGFloat(count) / CGFloat(maxCount))
                        Capsule()
                            .fill(Palette.accent)
                            .opacity(opacity(for: idx))
                            .frame(width: columnW, height: h)
                            .animation(.easeOut(duration: 0.16), value: scrubIndex)
                    }
                }

                // Hairline rule under the selected bar (Apple Health's
                // bottom-axis tick made calmer: 1pt accent line spanning
                // the bar width, no chrome). Only renders during scrub.
                if let i = scrubIndex {
                    Rectangle()
                        .fill(Palette.accent)
                        .frame(width: columnW, height: 1.5)
                        .offset(x: barX(for: i, columnW: columnW, spacing: spacing), y: 0)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.16), value: scrubIndex)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            // Expand the gesture target across the full chart frame so
            // a finger landing in negative space (between bars) still
            // resolves to the nearest bar — matches Apple Health.
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: geo.size.width, columns: columns))
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel("Step bars for the last 7 days. Drag to inspect a single day.")
    }

    private func scrubGesture(width: CGFloat, columns: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let raw = value.location.x / max(1, width)
                let idx = max(0, min(columns - 1, Int(raw * CGFloat(columns))))
                if scrubIndex != idx {
                    scrubIndex = idx
                    Haptics.tick()
                }
                // A new touch cancels any pending revert.
                revertTask?.cancel()
                revertTask = nil
            }
            .onEnded { _ in
                scheduleRevert()
            }
    }

    /// X offset of the leading edge of bar `i` inside the chart's frame.
    private func barX(for i: Int, columnW: CGFloat, spacing: CGFloat) -> CGFloat {
        (columnW + spacing) * CGFloat(i)
    }

    /// 1.0 for the selected bar (or today, when nothing is selected),
    /// 0.35 for everything else. Matches Apple Health's chart contrast.
    private func opacity(for idx: Int) -> Double {
        if let s = scrubIndex { return s == idx ? 1.0 : 0.35 }
        return idx == service.weeklyCounts.count - 1 ? 1.0 : 0.35
    }

    /// Holds the scrub display for ~1.0s after the user lifts their
    /// finger, then revert. Skipped (snap-revert) under reduce-motion.
    private func scheduleRevert() {
        revertTask?.cancel()
        if reduceMotion {
            scrubIndex = nil
            return
        }
        revertTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                scrubIndex = nil
            }
        }
    }

    // MARK: - Per-day copy

    /// Number rendered in the header: scrub overrides week total.
    private var displayedCount: Int {
        if scrubIndex != nil { return scrubbedCount }
        return service.weekTotal
    }

    /// Bounds-safe read of the scrubbed day's count. Returns 0 when the
    /// index is nil or out-of-range (defensive — the gesture clamps to
    /// `0…columns-1` so out-of-range shouldn't happen, but the read is
    /// cheap insurance against a future race with a refresh that
    /// shortened the array mid-frame).
    private var scrubbedCount: Int {
        guard let i = scrubIndex,
              service.weeklyCounts.indices.contains(i) else { return 0 }
        return service.weeklyCounts[i]
    }

    /// Day label for the scrub readout: today / yesterday / weekday.
    /// `idx == 6` is today; `idx == 0` is 6 days ago. Lowercase.
    private func dayLabel(for idx: Int) -> String {
        let daysAgo = (service.weeklyCounts.count - 1) - idx
        if daysAgo == 0 { return "today" }
        if daysAgo == 1 { return "yesterday" }
        let cal = Calendar.current
        guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).lowercased()
    }

    /// Anti-shame vibe line for the scrubbed day's count. Zero is framed
    /// as a rest day (deliberate, not a miss); under-goal stays warm; the
    /// threshold ladder mirrors the home pulse helper line. Never red,
    /// never "you didn't hit goal."
    private func dayVibe(for count: Int) -> String {
        if count == 0 { return "rest day ♥" }
        if count >= StepsService.dailyGoal { return "above the line ♥" }
        if count >= 2_500 { return "you moved ♥" }
        return "every step counts ♥"
    }

    private var fallbackContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("connect on home")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                .foregroundStyle(Palette.textPrimary)
            Text("tap the steps card under today's workout and jeni starts noticing your week ♥")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sticker: some View {
        Image(StickerName.shoeIridescent.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 38, height: 38)
            .rotationEffect(.degrees(10))
            .offset(x: 8, y: -12)
            .opacity(StickerName.shoeIridescent.style.opacity * 0.9)
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

    // MARK: - Copy

    /// Identity-forward read of the week. Three cascading branches:
    ///   - any day at/above goal → "you crossed [n]× this week"
    ///   - any movement at all   → "every walk added up to this ♥"
    ///   - zero week             → quiet starter ("a little walk later")
    private var trendLine: String {
        let aboveGoal = service.weeklyCounts.filter { $0 >= StepsService.dailyGoal }.count
        if aboveGoal >= 2 { return "you crossed the line \(aboveGoal)× this week ♥" }
        if aboveGoal == 1 { return "one day above the line — that counts ♥" }
        if service.weekTotal > 0 { return "every walk added up to this ♥" }
        return "a little walk later ♥"
    }

    private var accessibilityLabel: String {
        switch service.authStatus {
        case .authorized:
            return "Moving this week: \(service.weekTotal) steps. \(trendLine)"
        case .notDetermined, .denied, .unavailable:
            return "Moving. Connect Apple Health on the home steps card to see your week."
        }
    }

    private var authStatusString: String {
        switch service.authStatus {
        case .authorized:    return "authorized"
        case .notDetermined: return "not_determined"
        case .denied:        return "denied"
        case .unavailable:   return "unavailable"
        }
    }
}

#if DEBUG
#Preview("steps bento") {
    StepsBentoTile(service: StepsService.shared, onExplain: {})
        .padding()
        .background(Palette.bgPrimary)
}
#endif
