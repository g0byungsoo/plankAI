import Foundation
import PlankSync

// MARK: - WeightEMA (v11 T4 — the shared trend math)
//
// WeightTrendChart died with the journal, but its EMA was never
// chart chrome — it is the app's trend definition, consumed by the
// chat weight card, the notification anchor, and Becoming's weight
// tile. Extracted verbatim so every surface reads ONE line.
//
// Kept under the old type name as a typealias-free enum: call sites
// only ever used `WeightTrendChart.computeEMA` / `.EMAPoint`, which
// now live here.

enum WeightTrendChart {
    struct EMAPoint: Hashable {
        let date: Date
        let rawKg: Double?
        let emaKg: Double
    }

    static let alpha: Double = 2.0 / (7.0 + 1.0)   // standard 7-day EMA
    static let windowDays: Int = 60

    /// Compute the EMA series across the last `windowDays` days. Each day
    /// gets a point if the EMA is initialized (i.e., at least one log has
    /// happened on or before that day).
    static func computeEMA(logs: [WeightLogRecord]) -> [EMAPoint] {
        guard !logs.isEmpty else { return [] }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let startDay = cal.date(byAdding: .day, value: -windowDays + 1, to: today)!

        // One sample per day: the EARLIEST of the day — the canonical
        // reduction (pass 51). This used to keep the LATEST while the
        // week read kept the earliest, so one physical weigh-in day
        // could count differently on two surfaces. Order-independent
        // on purpose (callers used to promise a sort).
        var earliestAt: [Date: Date] = [:]
        var byDay: [Date: Double] = [:]
        for log in logs {
            let dayStart = cal.startOfDay(for: log.loggedAt)
            if let held = earliestAt[dayStart], held <= log.loggedAt { continue }
            earliestAt[dayStart] = log.loggedAt
            byDay[dayStart] = log.weightKg
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
