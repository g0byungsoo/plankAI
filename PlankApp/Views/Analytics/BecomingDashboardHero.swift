import SwiftUI
import PlankSync

/// Daily Becoming top-of-scroll dashboard hero. Per
/// docs/becoming_home_minimal_spec_2026_06_06.md, distilled from
/// 7 expert briefs (2 rounds: The Row + Miu Miu + Cal AI + iOS UX,
/// then Whoop + Aesop + Typography).
///
/// Layout (5 elements, ~40% whitespace):
///   1. Hero weight digit — Fraunces Light 64pt, tabular, cocoa 100%
///   2. Unit + delta line — DM Sans Regular 15pt cocoa 72%
///   3. Sparkline — 1pt jeweledRose stroke, no fill, no axes
///   4. Hairline divider — 0.5pt cocoa 12%, generous breath
///   5. 3-stat row — streak · plank PR · this week
///      Labels DM Sans 11pt uppercase tracking +0.06em cocoa 48%
///      Numbers DM Sans Medium 22pt tabular cocoa 100%
///
/// Rules:
///   • NO italic on numerals. Italic-Fraunces stays only on COPY
///     punch words at the page hero level above. The contrast IS
///     the brand signature.
///   • All numbers `.monospacedDigit()` so deltas re-render without
///     horizontal shift.
///   • Cocoa scale uses 3 tiers via Palette.cocoaPrimary /
///     cocoaSecondary / cocoaTertiary — Things 3 / Linear / Reflect
///     register, NOT 2-tier (primary + 60% secondary = flat,
///     bolted-together feel).
///
/// Empty state (no weight logs): renders EditorialEmptyState with the
/// flower3D signature sticker — same editorial pattern as the rest
/// of the chapter empty states. The 3-stat row still shows if the
/// other signals exist (streak / plank PR / this week sessions can
/// all be non-zero before the first weight log).
struct BecomingDashboardHero: View {
    let latestWeightKg: Double?
    let startingWeightKg: Double?
    let logs: [WeightLogRecord]
    let unit: WeightUnit
    let streakDays: Int
    let bestPlankSeconds: Double
    let sessionsThisWeek: Int
    let onLogWeight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if latestWeightKg == nil {
                EditorialEmptyState(
                    headline: "your week is unwritten.",
                    cta: "log when you're ready.",
                    sticker: .flower3D
                )
            } else {
                weightBlock
                if hasSparkline {
                    sparkline.padding(.top, 4)
                }
            }

            hairline

            statRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Weight block

    @ViewBuilder private var weightBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let kg = latestWeightKg {
                Text(String(format: "%.1f", unit.display(fromKg: kg)))
                    .font(Typo.numeralHero)
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaPrimary)
                    .contentTransition(.numericText())
            }
            unitAndDeltaLine
        }
    }

    /// "lb · down 1.4 in 14 days" — unit + delta on one line. Unit and
    /// connective words DM Sans Regular cocoa 72%; numerals tabular.
    /// jeweledRose tinted only on the delta direction word to put the
    /// editorial accent on the meaning, not the metadata.
    @ViewBuilder private var unitAndDeltaLine: some View {
        let unitLabel = unit.label
        if let starting = startingWeightKg, let latest = latestWeightKg {
            let deltaKg = latest - starting
            let absDisplay = abs(unit.display(fromKg: deltaKg))
            let direction: (verb: String, color: Color) = {
                if abs(deltaKg) < 0.05 {
                    return ("even", Palette.cocoaSecondary)
                } else if deltaKg < 0 {
                    return ("down", Palette.jeweledRose.opacity(0.85))
                } else {
                    return ("up", Palette.cocoaSecondary)
                }
            }()
            let dayCount = daysSinceFirstLog() ?? 0
            HStack(spacing: 6) {
                Text(unitLabel)
                    .font(Typo.numeralMeta)
                    .foregroundStyle(Palette.cocoaSecondary)
                Text("·")
                    .font(Typo.numeralMeta)
                    .foregroundStyle(Palette.cocoaTertiary)
                Text(direction.verb)
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundStyle(direction.color)
                if direction.verb != "even" {
                    Text("\(String(format: "%.1f", absDisplay)) \(unitLabel)")
                        .font(Typo.numeralMeta)
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaSecondary)
                } else {
                    Text("with where you started")
                        .font(Typo.numeralMeta)
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                if dayCount > 0, direction.verb != "even" {
                    Text("· \(dayCount) days")
                        .font(Typo.numeralMeta)
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(deltaAccessibilityLabel(direction: direction.verb, value: absDisplay, days: dayCount, unitLabel: unitLabel))
        } else {
            // Single log — show unit only, no delta.
            Text(unitLabel)
                .font(Typo.numeralMeta)
                .foregroundStyle(Palette.cocoaSecondary)
        }
    }

    private func deltaAccessibilityLabel(direction: String, value: Double, days: Int, unitLabel: String) -> String {
        if direction == "even" {
            return "Weight even with starting value"
        }
        return "Weight \(direction) \(String(format: "%.1f", value)) \(unitLabel) over \(days) days"
    }

    // MARK: - Sparkline

    private var hasSparkline: Bool { sparklinePoints(in: CGSize(width: 320, height: 80)).count >= 2 }

    /// 1pt jeweledRose stroke, no fill, no axes — Cereal magazine
    /// data-treatment register. Pure shape, the numbers above carry
    /// the meaning.
    private var sparkline: some View {
        GeometryReader { geo in
            let points = sparklinePoints(in: geo.size)
            if points.count >= 2 {
                Path { p in
                    p.move(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(
                    Palette.jeweledRose.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 64)
        .accessibilityHidden(true)
    }

    private func sparklinePoints(in size: CGSize) -> [CGPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recent = logs
            .filter { $0.loggedAt >= cutoff }
            .sorted { $0.loggedAt < $1.loggedAt }
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

        let firstDate = recent.first!.loggedAt.timeIntervalSinceReferenceDate
        let lastDate = recent.last!.loggedAt.timeIntervalSinceReferenceDate
        let timeRange = max(lastDate - firstDate, 1)

        return zip(recent, ema).map { (log, value) in
            let x = CGFloat((log.loggedAt.timeIntervalSinceReferenceDate - firstDate) / timeRange) * size.width
            let y = CGFloat(1 - (value - minVal) / range) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func daysSinceFirstLog() -> Int? {
        guard let first = logs.first?.loggedAt else { return nil }
        let earliest = logs.min(by: { $0.loggedAt < $1.loggedAt })?.loggedAt ?? first
        return Calendar.current.dateComponents([.day], from: earliest, to: .now).day
    }

    // MARK: - Hairline

    /// 0.5pt cocoa at 12%. NEVER 1pt — the difference is the whole
    /// thing.
    private var hairline: some View {
        Rectangle()
            .fill(Palette.hairlineCocoa)
            .frame(height: 0.5)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }

    // MARK: - 3-stat row

    /// Streak · Plank PR · This week. Equal-weight 3-column layout.
    /// Labels uppercase tracked +0.06em cocoa 48%. Numbers DM Sans
    /// Medium 22pt tabular cocoa 100%. The Aesop specimen-label
    /// move: small uppercase labels with tracking are "60% of the
    /// difference between a warm tool and a tracker."
    private var statRow: some View {
        HStack(alignment: .top, spacing: 0) {
            statColumn(label: "STREAK", value: "\(streakDays)")
            statColumn(label: "PLANK PR", value: plankPRDisplay)
            statColumn(label: "THIS WEEK", value: "\(sessionsThisWeek)")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak \(streakDays) days, plank personal record \(plankPRDisplay), \(sessionsThisWeek) sessions this week")
    }

    private var plankPRDisplay: String {
        let total = Int(bestPlankSeconds.rounded())
        guard total > 0 else { return "—" }
        let m = total / 60
        let s = total % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return "\(s)s"
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.statLabel)
                .kerning(0.66) // +0.06em at 11pt
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(Typo.numeralStat)
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("With data") {
    BecomingDashboardHero(
        latestWeightKg: 64.5,
        startingWeightKg: 65.9,
        logs: [],
        unit: .lb,
        streakDays: 12,
        bestPlankSeconds: 102,
        sessionsThisWeek: 4,
        onLogWeight: {}
    )
    .padding(20)
    .background(Palette.bgPrimary)
}

#Preview("Empty state") {
    BecomingDashboardHero(
        latestWeightKg: nil,
        startingWeightKg: nil,
        logs: [],
        unit: .lb,
        streakDays: 0,
        bestPlankSeconds: 0,
        sessionsThisWeek: 0,
        onLogWeight: {}
    )
    .padding(20)
    .background(Palette.bgPrimary)
}
#endif
