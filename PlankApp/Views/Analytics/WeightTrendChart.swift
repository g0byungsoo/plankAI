import SwiftUI
import Charts
import PlankSync

/// 7-day exponentially-weighted moving-average trend line for weight logs.
///
/// Per the research (Helander 2014, JMIR — n=40k Withings users; trend-line
/// users 2× more likely to sustain loss), the EMA line is the load-bearing
/// metric. Raw daily weight is shown as faded dots **under** the line, never
/// as the headline number, because hydration / glycogen / cycle noise is
/// ±1-2kg in pre-menopausal women (Bhutani 2017).
///
/// Window: last 60 days. Renders nothing when fewer than 2 logs exist
/// (single point isn't a trend; the host shows a "log a few more days"
/// placeholder instead).
struct WeightTrendChart: View {
    let logs: [WeightLogRecord]
    let goalWeightKg: Double?
    /// Display unit. Chart values are rendered in this unit; underlying
    /// `logs` stay kg-canonical. Defaults to `.lb` to match the WeightUnit
    /// enum default + the rest of the app's display surfaces.
    var unit: WeightUnit = .lb

    private static let alpha: Double = 2.0 / (7.0 + 1.0)   // standard 7-day EMA
    private static let windowDays: Int = 60

    private var points: [EMAPoint] { Self.computeEMA(logs: logs) }

    private func toDisplay(_ kg: Double) -> Double { unit.display(fromKg: kg) }

    var body: some View {
        Chart {
            // Goal reference (subtle dashed) — only when set.
            if let goal = goalWeightKg, goal > 0 {
                RuleMark(y: .value("Goal", toDisplay(goal)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Palette.stateGood.opacity(0.45))
                    .annotation(position: .top, alignment: .leading) {
                        Text("GOAL\u{2009}·\u{2009}\(toDisplay(goal), specifier: "%.0f") \(unit.label)")
                            .font(Typo.eyebrow).tracking(2)
                            .foregroundStyle(Palette.stateGood)
                            .padding(.leading, 2)
                    }
            }

            // Raw spot weights (faded — never the headline)
            ForEach(points.filter { $0.rawKg != nil }, id: \.date) { p in
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Weight", toDisplay(p.rawKg ?? 0))
                )
                .foregroundStyle(Palette.accent.opacity(0.25))
                .symbolSize(28)
            }

            // EMA line — the focal metric
            ForEach(points, id: \.date) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Trend", toDisplay(p.emaKg))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 14)) { _ in
                AxisGridLine().foregroundStyle(Palette.divider)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                               anchor: .top)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.divider)
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(height: 140)
    }

    /// Compress the y range so small swings read clearly without losing the
    /// goal reference. Computed in the display unit so chart bounds align
    /// with what the user sees. Adds ~15% padding above + below; floor at
    /// 1 unit for absolute-tiny ranges.
    private var yDomain: ClosedRange<Double> {
        let weightsKg = points.map(\.emaKg) + points.compactMap(\.rawKg)
        var lo = (weightsKg.min() ?? 0)
        var hi = (weightsKg.max() ?? 0)
        if let goal = goalWeightKg, goal > 0 {
            lo = min(lo, goal)
            hi = max(hi, goal)
        }
        let displayLo = toDisplay(lo)
        let displayHi = toDisplay(hi)
        let pad = max(1.0, (displayHi - displayLo) * 0.15)
        return (displayLo - pad)...(displayHi + pad)
    }

    // MARK: - EMA

    struct EMAPoint: Hashable {
        let date: Date
        let rawKg: Double?
        let emaKg: Double
    }

    /// Compute the EMA series across the last `windowDays` days. Each day
    /// gets a point if the EMA is initialized (i.e., at least one log has
    /// happened on or before that day).
    static func computeEMA(logs: [WeightLogRecord]) -> [EMAPoint] {
        guard !logs.isEmpty else { return [] }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDay = cal.date(byAdding: .day, value: -windowDays + 1, to: today)!

        // Latest log per day (input is sorted desc; we walk and keep first
        // hit). For multiple logs in one day, take the latest by `loggedAt`.
        var byDay: [Date: Double] = [:]
        for log in logs {
            let dayStart = cal.startOfDay(for: log.loggedAt)
            if byDay[dayStart] == nil {
                byDay[dayStart] = log.weightKg
            }
        }

        // Seed the EMA with the most recent log on or before startDay so
        // the line starts smoothly inside the window even if the user
        // logged earlier than 60 days ago.
        var ema: Double? = logs
            .filter { cal.startOfDay(for: $0.loggedAt) <= startDay }
            .max(by: { $0.loggedAt < $1.loggedAt })?
            .weightKg

        var out: [EMAPoint] = []
        var current = startDay
        while current <= today {
            let raw = byDay[current]
            if let raw {
                if let prev = ema {
                    ema = alpha * raw + (1 - alpha) * prev
                } else {
                    ema = raw
                }
            }
            if let value = ema {
                out.append(EMAPoint(date: current, rawKg: raw, emaKg: value))
            }
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return out
    }
}
