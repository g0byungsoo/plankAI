import Foundation

// MARK: - FoodWeekRead
//
// app v9 P5 (docs/app_v9/02_PLAN.md) — the weekly food-quality read:
// qualitative BANDS, floor-gated, explicitly NOT a score. Three
// words the week can earn — protein-led (the win named first, the
// anti-shame order), late-heavy (an observation about timing, never
// a food), steady. nil under 4 logged days — a caption isn't a
// read. Renders as the becoming food page's headline; the atoms
// (sugar direction, window drift) stay with the P3 mechanisms so
// nothing double-speaks.

enum FoodWeekRead {

    enum Band: String, Equatable {
        case proteinLed, lateHeavy, steady
    }

    struct Read: Equatable {
        let band: Band
        let line: String
        let italic: [String]
    }

    /// One logged plate, reduced to what the read needs.
    struct Plate {
        let loggedAt: Date
        let kcal: Double
        let protein: Double
        init(loggedAt: Date, kcal: Double, protein: Double) {
            self.loggedAt = loggedAt
            self.kcal = kcal
            self.protein = protein
        }
    }

    static let loggedDaysFloor = 4
    static let lateHour = 20
    static let lateShareThreshold = 0.4

    static func compose(
        plates: [Plate],
        proteinTargetG: Int?,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Read? {
        let todayStart = calendar.startOfDay(for: now)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)
        else { return nil }
        let week = plates.filter { $0.loggedAt >= weekStart }
        guard !week.isEmpty else { return nil }

        var byDay: [Date: (kcal: Double, protein: Double)] = [:]
        for plate in week {
            let day = calendar.startOfDay(for: plate.loggedAt)
            var t = byDay[day] ?? (0, 0)
            t.kcal += plate.kcal
            t.protein += plate.protein
            byDay[day] = t
        }
        guard byDay.count >= loggedDaysFloor else { return nil }

        // The win first (anti-shame order): protein carried the week.
        if let target = proteinTargetG, target > 0 {
            let met = byDay.values.filter { $0.protein >= Double(target) }.count
            if met >= 4 {
                return Read(
                    band: .proteinLed,
                    line: "a protein-led week.",
                    italic: ["protein-led"]
                )
            }
        }

        // Timing observation — kcal share landing 8pm or later.
        let totalKcal = week.reduce(0) { $0 + $1.kcal }
        if totalKcal > 0 {
            let lateKcal = week
                .filter { calendar.component(.hour, from: $0.loggedAt) >= lateHour }
                .reduce(0) { $0 + $1.kcal }
            if lateKcal / totalKcal >= lateShareThreshold {
                return Read(
                    band: .lateHeavy,
                    line: "meals ran late this week.",
                    italic: ["late"]
                )
            }
        }

        return Read(
            band: .steady,
            line: "a steady week.",
            italic: ["steady"]
        )
    }
}
