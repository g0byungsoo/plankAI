import SwiftUI
import PlankSync

// MARK: - TrendHeroCard
//
// v1.0.7 Phase B Home redesign hero. Per the synthesized expert
// research pass (docs/home_becoming_research_*_2026_06_06.md), Home
// leads with the weight TREND, not the calorie number. Behavioral
// expert citations: Helander 2014 + Pacanowski 2024 + Linardon 2025
// systematic review + post-Ozempic Body Image 2025. The calorie-as-
// hero pattern is a known disordered-eating accelerator for
// TikTok-acquired Gen-Z women specifically; trend-as-hero is the only
// defensible choice for this cohort.
//
// What lands in this slot:
//   - latest weight (large Fraunces, with eye-toggle privacy)
//   - delta vs starting baseline (italic-Fraunces direction word)
//   - 30-day EMA sparkline (small inline)
//   - "log" pill button → opens LogWeightSheet via onLogTap closure
//
// Empty state (no logs yet):
//   - "your *trend* lives here" headline
//   - "log to start the story ♥" subtitle
//   - prominent "log weight" pill
//
// Hidden state (hideStats=true):
//   - same chrome, weight number replaced with "—"
//   - sparkline still renders but values are masked
//   - eye toggle flips back to show

struct TrendHeroCard: View {

    /// Most recent kg, or nil for empty state.
    let latestWeightKg: Double?
    /// All weight logs in chronological order (oldest first). Used to
    /// render the EMA sparkline + delta.
    let logs: [WeightLogRecord]
    /// Starting weight for the delta calc — onboarding-seeded or first log.
    let startingKg: Double?
    /// Display unit. Storage stays kg.
    let unit: WeightUnit
    @Binding var hideStats: Bool
    /// Whether a weight log exists for today — drives the log-button
    /// copy ("update" vs "log").
    let hasTodaysLog: Bool
    /// Callback to surface the LogWeightSheet from HomeView.
    let onLogTap: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if latestWeightKg == nil {
                emptyState
            } else {
                stockedHero
                if logs.count >= 2 {
                    sparkline
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
                )
        )
        .shadow(color: Palette.textPrimary.opacity(0.2), radius: 0, x: 3, y: 3)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("becoming")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Palette.accent)
                Text("your trend")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.18)) {
                    hideStats.toggle()
                }
            } label: {
                Image(systemName: hideStats ? "eye.slash" : "eye")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgPrimary)
                    .clipShape(Circle())
            }
            .accessibilityLabel(hideStats ? "show weight" : "hide weight")

            Button {
                Haptics.light()
                onLogTap()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: hasTodaysLog ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(hasTodaysLog ? "update" : "log")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                }
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Palette.bgInverse)
                .clipShape(Capsule())
            }
            .accessibilityLabel(hasTodaysLog ? "update today's weight" : "log weight")
        }
    }

    // MARK: - Empty state

    /// v1.0.7 §6 editorial empty state. Brief copy:
    /// "*your week is unwritten.*" + "log when you're ready." +
    /// flower3D 28pt. The CTA button below (rendered by the
    /// caller's `actionRow`) carries the actual "log weight"
    /// interaction — this view is the editorial mark.
    private var emptyState: some View {
        EditorialEmptyState(
            headline: "your week is unwritten.",
            cta: "log when you're ready.",
            sticker: .flower3D
        )
    }

    // MARK: - Stocked hero (number + delta)

    @ViewBuilder
    private var stockedHero: some View {
        if hideStats {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("—")
                    .font(.custom("Fraunces72pt-SemiBold", size: 36))
                    .foregroundStyle(Palette.textSecondary)
                Text("hidden")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
        } else if let latest = latestWeightKg {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(unit.display(fromKg: latest), specifier: "%.1f")")
                    .font(.custom("Fraunces72pt-SemiBold", size: 36))
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text(unit.label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            deltaCopy
        }
    }

    /// "down 2.3 lb · 14 days" / "even with where you started · 7 days" /
    /// nil when not enough data. Italic-Fraunces punch on the direction
    /// word only — keeps the voice signal.
    @ViewBuilder
    private var deltaCopy: some View {
        if let starting = startingKg, let latest = latestWeightKg, !hideStats {
            let deltaKg = latest - starting
            let absDisplay = abs(unit.display(fromKg: deltaKg))
            let direction: (verb: String, color: Color) = {
                if abs(deltaKg) < 0.05 {
                    return ("even", Palette.textSecondary)
                } else if deltaKg < 0 {
                    return ("down", Palette.stateGood)
                } else {
                    return ("up", Palette.textSecondary)
                }
            }()

            let dayCount = daysSinceFirstLog()
            HStack(spacing: 6) {
                (Text(direction.verb)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(direction.color)
                 + Text(direction.verb == "even"
                        ? " with where you started"
                        : " \(String(format: "%.1f", absDisplay)) \(unit.label)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary))

                if let dayCount, dayCount > 0 {
                    Text("·")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary.opacity(0.6))
                    Text("\(dayCount) day\(dayCount == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    // MARK: - Sparkline

    /// Tight EMA sparkline using SwiftUI Path. ~38pt tall, no axes, no
    /// labels. The shape is the story; numbers live in the hero
    /// above. Last 30 days of logs.
    private var sparkline: some View {
        GeometryReader { geo in
            let points = sparklinePoints(in: geo.size)
            ZStack {
                // Fill — soft accent halo under the line.
                if points.count >= 2 {
                    Path { p in
                        p.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        p.addLine(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [Palette.accent.opacity(0.18), Palette.accent.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                    Path { p in
                        p.move(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 38)
        .accessibilityHidden(true)
    }

    private func sparklinePoints(in size: CGSize) -> [CGPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recent = logs
            .filter { $0.loggedAt >= cutoff }
            .sorted { $0.loggedAt < $1.loggedAt }
        guard recent.count >= 2 else { return [] }

        // EMA smoothing — 7-day alpha matches the WeightTrendChart in
        // Becoming so Home + Becoming agree on direction.
        let alpha: Double = 2.0 / (7.0 + 1.0)
        var ema: [Double] = []
        for (i, log) in recent.enumerated() {
            if i == 0 {
                ema.append(log.weightKg)
            } else {
                ema.append(alpha * log.weightKg + (1 - alpha) * ema[i - 1])
            }
        }

        let minVal = ema.min() ?? 0
        let maxVal = ema.max() ?? 1
        let range = max(maxVal - minVal, 0.1)  // avoid divide-by-zero on flat trends

        let firstDate = recent.first!.loggedAt.timeIntervalSinceReferenceDate
        let lastDate = recent.last!.loggedAt.timeIntervalSinceReferenceDate
        let timeRange = max(lastDate - firstDate, 1)

        return zip(recent, ema).map { (log, value) in
            let x = CGFloat((log.loggedAt.timeIntervalSinceReferenceDate - firstDate) / timeRange) * size.width
            let y = CGFloat(1 - (value - minVal) / range) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Helpers

    private func daysSinceFirstLog() -> Int? {
        guard let first = logs.first?.loggedAt ?? logs.last?.loggedAt else { return nil }
        let earliest = logs.min(by: { $0.loggedAt < $1.loggedAt })?.loggedAt ?? first
        let days = Calendar.current.dateComponents([.day], from: earliest, to: .now).day
        return days
    }
}
