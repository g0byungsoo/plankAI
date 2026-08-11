import Foundation
import PlankFood

// MARK: - NutrientWeekSeries (v11 T4 — the tile aggregator)
//
// Seven local days of one nutrient, oldest first, for Becoming's
// tiles and detail pages (docs/app_v11/00_REBIRTH.md §7).
//
// Provenance is geometry here (L8):
// - a day with no plates is nil (a gap, never a zero bar)
// - sodium / sugar / saturated fat ride the "0 = not collected,
//   silent" convention on FoodLogEntry — a day whose plates all
//   carry 0 for such a nutrient is ALSO nil, because the truth is
//   "not measured", not "they ate none"
// - protein and fiber are collected whenever a plate is logged, so
//   a logged day always carries their sum

struct NutrientWeekSeries: Equatable {
    struct Day: Equatable {
        let date: Date
        let value: Double?   // nil = not logged / not collected
    }

    /// Exactly 7, oldest first; `days.last` is `endingOn`'s day.
    let days: [Day]

    /// Days that carry a real value.
    var loggedCount: Int { days.filter { $0.value != nil }.count }

    /// The becoming data floor: 3+ collected days before a tile may
    /// draw a trend. Below it the tile speaks its standing instead.
    var meetsFloor: Bool { loggedCount >= 3 }

    /// Chart-ready values (oldest first).
    var values: [Double?] { days.map(\.value) }

    /// The week's total across collected days (display use only —
    /// never averaged across gaps as if they were zeros).
    var collectedTotal: Double {
        days.compactMap(\.value).reduce(0, +)
    }
}

enum NutrientWeekAggregator {
    enum Nutrient {
        case calories, protein, fiber, sugar, sodium, saturatedFat

        /// Whether this nutrient rides the "0 = not collected"
        /// convention (sums of all-zero = a silent day).
        var zeroMeansSilent: Bool {
            switch self {
            case .calories, .protein, .fiber: return false
            case .sugar, .sodium, .saturatedFat: return true
            }
        }

        func value(of entry: FoodLogPersister.FoodLogEntry) -> Double {
            switch self {
            case .calories: return entry.kcal
            case .protein: return entry.protein
            case .fiber: return entry.fiber
            case .sugar: return entry.sugar
            case .sodium: return entry.sodiumMg
            case .saturatedFat: return entry.satFatG
            }
        }
    }

    static func week(
        for nutrient: Nutrient,
        entries: [FoodLogPersister.FoodLogEntry],
        endingOn: Date,
        calendar: Calendar
    ) -> NutrientWeekSeries {
        series(for: nutrient, entries: entries, endingOn: endingOn,
               days: 7, bucketDays: 1, calendar: calendar)
    }

    /// v12 — the scoped generalization. `days` is the window ending on
    /// `endingOn`; `bucketDays` folds the window into slots (1 = daily
    /// bars, 7 = weekly averages, 30 = monthly). A bucket's value is
    /// the AVERAGE of its collected days — "about X a day" stays the
    /// sentence at every scope — and a bucket with nothing collected
    /// is nil, never zero (L8).
    static func series(
        for nutrient: Nutrient,
        entries: [FoodLogPersister.FoodLogEntry],
        endingOn: Date,
        days windowDays: Int,
        bucketDays: Int,
        calendar: Calendar
    ) -> NutrientWeekSeries {
        let end = calendar.startOfDay(for: endingOn)
        let window = max(1, windowDays)
        let bucket = max(1, bucketDays)
        guard let windowStart = calendar.date(byAdding: .day, value: -(window - 1), to: end)
        else { return NutrientWeekSeries(days: []) }

        // Bucket entries by local day once.
        var sums: [Date: Double] = [:]
        var hadPlates: Set<Date> = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.loggedAt)
            guard day >= windowStart, day <= end else { continue }
            hadPlates.insert(day)
            sums[day, default: 0] += nutrient.value(of: entry)
        }

        func dayValue(_ day: Date) -> Double? {
            guard hadPlates.contains(day) else { return nil }
            let sum = sums[day] ?? 0
            if nutrient.zeroMeansSilent && sum <= 0 {
                // Plates existed, but none carried this nutrient —
                // the day is unmeasured, not zero.
                return nil
            }
            return sum
        }

        // Slots anchor on TODAY: the newest slot always ends on `end`,
        // and earlier slots step back a bucket at a time (a partial
        // oldest slot clamps to the window).
        let slotCount = Int((Double(window) / Double(bucket)).rounded(.up))
        let days: [NutrientWeekSeries.Day] = (0..<slotCount).compactMap { i in
            guard let slotEnd = calendar.date(
                byAdding: .day, value: -(slotCount - 1 - i) * bucket, to: end
            ) else { return nil }
            var collected: [Double] = []
            for d in 0..<bucket {
                guard let day = calendar.date(byAdding: .day, value: -d, to: slotEnd),
                      day >= windowStart else { continue }
                if let v = dayValue(day) { collected.append(v) }
            }
            let slotStart = calendar.date(
                byAdding: .day, value: -(bucket - 1), to: slotEnd
            ) ?? slotEnd
            return .init(
                date: max(slotStart, windowStart),
                value: collected.isEmpty
                    ? nil
                    : collected.reduce(0, +) / Double(collected.count)
            )
        }

        return NutrientWeekSeries(days: days)
    }
}
