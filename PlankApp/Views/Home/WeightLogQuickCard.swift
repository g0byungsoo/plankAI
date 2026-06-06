import SwiftUI
import PlankSync

/// Home-tab health-anchor weight surface. Per
/// docs/becoming_home_minimal_spec_2026_06_06.md "Home tab reorder":
///
/// > "Health anchor slot → weight log + steps pulse, side-by-side.
/// >  Single-tap log. Last-7 trend behind the number. This fixes
/// >  weight-logging-near-zero by moving the ask to the highest-
/// >  traffic surface."
///
/// Production data (v1.0.6 build 11): weight-logging near-zero
/// despite Becoming dashboarding weight as a hero metric. The leak
/// is upstream — users don't see a log affordance on the daily
/// surface they actually open (Home). This card sits one slot
/// below the lesson hero so a one-tap log is the second visible
/// action on every Home open.
///
/// Visual register: minimal-functional-aesthetic per Phase 3
/// numeral spec — Fraunces Light for the hero digit (NOT italic),
/// 3-tier cocoa scale, 0.5pt cocoa-12 hairline, jeweledRose only
/// on the delta direction word. No card chrome — sits flush on
/// the cream backdrop with editorial hairline marks above + below.
///
/// Empty state: editorial invitation — "tap to log today's weight"
/// + flower3D 28pt sticker.
struct WeightLogQuickCard: View {
    let latestKg: Double?
    let startingKg: Double?
    let logs: [WeightLogRecord]
    let unit: WeightUnit
    let hasTodaysLog: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(hasTodaysLog ? "tap to update today's weight" : "tap to log today's weight")
    }

    @ViewBuilder private var content: some View {
        if latestKg == nil {
            emptyState
        } else {
            HStack(alignment: .center, spacing: 14) {
                weightBlock
                Spacer(minLength: 0)
                miniSparkline
                // v1.0.7 founder feedback fix 2026-06-06: "weight log
                // input button is very confusing (users won't know
                // where it is)." The previous trailing arrow tap hint
                // was easy to miss — the whole card was tappable but
                // the affordance read as a passive display. Replaced
                // with a visible cocoa CTA pill ("log" / "update")
                // that matches the start-workout pill register, so
                // the action is obvious at-a-glance.
                logCTAPill
            }
            .padding(.vertical, Space.md)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.divider).frame(height: 0.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.divider).frame(height: 0.5)
            }
        }
    }

    // MARK: - Loaded weight

    @ViewBuilder private var weightBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                if let kg = latestKg {
                    Text(String(format: "%.1f", unit.display(fromKg: kg)))
                        .font(.custom("Fraunces72pt-Light", size: 36))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaPrimary)
                        .contentTransition(.numericText())
                }
                Text(unit.label)
                    .font(Typo.numeralMeta)
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            deltaLine
        }
    }

    @ViewBuilder private var deltaLine: some View {
        if let starting = startingKg, let latest = latestKg, abs(latest - starting) >= 0.05 {
            let deltaKg = latest - starting
            let absDisplay = abs(unit.display(fromKg: deltaKg))
            let direction = deltaKg < 0 ? "down" : "up"
            let color: Color = deltaKg < 0 ? Palette.jeweledRose.opacity(0.85) : Palette.cocoaSecondary
            HStack(spacing: 4) {
                Text(direction)
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(color)
                Text("\(String(format: "%.1f", absDisplay)) \(unit.label)")
                    .font(.custom("DMSans-Regular", size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaSecondary)
            }
        } else if hasTodaysLog {
            Text("logged today ♥")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.cocoaTertiary)
        } else {
            Text("tap to log today")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }

    // MARK: - Mini sparkline

    private var miniSparkline: some View {
        GeometryReader { geo in
            let points = sparklinePoints(in: geo.size)
            if points.count >= 2 {
                Path { p in
                    p.move(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(
                    Palette.jeweledRose.opacity(0.75),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: 64, height: 28)
        .accessibilityHidden(true)
    }

    private func sparklinePoints(in size: CGSize) -> [CGPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
        let recent = logs.filter { $0.loggedAt >= cutoff }.sorted { $0.loggedAt < $1.loggedAt }
        guard recent.count >= 2 else { return [] }

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
        let range = max(maxVal - minVal, 0.1)
        let first = recent.first!.loggedAt.timeIntervalSinceReferenceDate
        let last = recent.last!.loggedAt.timeIntervalSinceReferenceDate
        let timeRange = max(last - first, 1)
        return zip(recent, ema).map { (log, value) in
            let x = CGFloat((log.loggedAt.timeIntervalSinceReferenceDate - first) / timeRange) * size.width
            let y = CGFloat(1 - (value - minVal) / range) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Log CTA pill

    /// Cocoa-on-cream pill mirroring the JeniMethodTodayCard and
    /// workout "begin" pill register. Says "log" or "update" based
    /// on whether today's log already exists. The pill is the
    /// visible-on-card affordance — the entire card is still a
    /// tap target (Button wrapper) so the hit area covers the
    /// hero number too, but the pill makes the action obvious.
    private var logCTAPill: some View {
        HStack(spacing: 6) {
            Text(hasTodaysLog ? "update" : "log")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Palette.textInverse)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Palette.bgInverse)
        .clipShape(Capsule())
    }

    // MARK: - Empty state (editorial invitation)

    private var emptyState: some View {
        EditorialEmptyState(
            headline: "weight stays your call.",
            cta: "tap to log when you're ready.",
            sticker: .flower3D
        )
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        guard let kg = latestKg else { return "Weight not yet logged" }
        let display = unit.display(fromKg: kg)
        var label = "Latest weight \(String(format: "%.1f", display)) \(unit.label)"
        if let starting = startingKg, abs(kg - starting) >= 0.05 {
            let deltaKg = kg - starting
            let absDisplay = abs(unit.display(fromKg: deltaKg))
            let direction = deltaKg < 0 ? "down" : "up"
            label += ", \(direction) \(String(format: "%.1f", absDisplay)) \(unit.label) overall"
        }
        return label
    }
}
