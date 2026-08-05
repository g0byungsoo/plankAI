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
//   "not measured", not "she ate none"
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
        case protein, fiber, sugar, sodium, saturatedFat

        /// Whether this nutrient rides the "0 = not collected"
        /// convention (sums of all-zero = a silent day).
        var zeroMeansSilent: Bool {
            switch self {
            case .protein, .fiber: return false
            case .sugar, .sodium, .saturatedFat: return true
            }
        }

        func value(of entry: FoodLogPersister.FoodLogEntry) -> Double {
            switch self {
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
        let end = calendar.startOfDay(for: endingOn)
        let dayStarts: [Date] = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0 - 6, to: end)
        }

        // Bucket entries by local day once.
        var sums: [Date: Double] = [:]
        var hadPlates: Set<Date> = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.loggedAt)
            guard day >= dayStarts.first ?? end, day <= end else { continue }
            hadPlates.insert(day)
            sums[day, default: 0] += nutrient.value(of: entry)
        }

        let days = dayStarts.map { day -> NutrientWeekSeries.Day in
            guard hadPlates.contains(day) else {
                return .init(date: day, value: nil)
            }
            let sum = sums[day] ?? 0
            if nutrient.zeroMeansSilent && sum <= 0 {
                // Plates existed, but none carried this nutrient —
                // the day is unmeasured, not zero.
                return .init(date: day, value: nil)
            }
            return .init(date: day, value: sum)
        }

        return NutrientWeekSeries(days: days)
    }
}
