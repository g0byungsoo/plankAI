import Foundation
import SwiftData
import PlankFood
import PlankSync

// MARK: - WeekState
//
// App v2.1. The week-scale aggregates the insight layer reads —
// Becoming thinks in weeks the way Today thinks in hours. One fetch
// pass, provenance-only (absent data stays absent, never defaulted).

struct WeekState {
    /// Last 14 days, oldest → newest. One slot per calendar day.
    struct DaySlice {
        let date: Date
        let kcal: Double
        let proteinG: Double
        let plates: Int
        let steps: Int?          // nil for days outside HealthKit's week window
    }

    let days: [DaySlice]                 // 14 entries
    let proteinTargetG: Int?

    var last7: ArraySlice<DaySlice> { days.suffix(7) }

    var proteinDaysHit: Int {
        guard let target = proteinTargetG else { return 0 }
        return last7.filter { $0.proteinG >= Double(target) }.count
    }
    var loggedDays7: Int { last7.filter { $0.plates > 0 }.count }

    @MainActor
    static func load(userId: String, in context: ModelContext) -> WeekState {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Food per day (14 days) from the device-local store.
        let entries = FoodLogPersister.allEntries(userId: userId)
        var byDay: [Date: (kcal: Double, protein: Double, plates: Int)] = [:]
        for entry in entries {
            let day = cal.startOfDay(for: entry.loggedAt)
            guard let gap = cal.dateComponents([.day], from: day, to: today).day,
                  gap >= 0, gap < 14 else { continue }
            var slot = byDay[day] ?? (0, 0, 0)
            slot.kcal += entry.kcal
            slot.protein += entry.protein
            slot.plates += 1
            byDay[day] = slot
        }

        // Steps: HealthKit exposes the trailing week only.
        let weekly = StepsService.shared.weeklyCounts

        var days: [DaySlice] = []
        for offset in stride(from: 13, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let food = byDay[date] ?? (0, 0, 0)
            let steps: Int? = offset < weekly.count
                ? weekly[weekly.count - 1 - offset]
                : nil
            days.append(DaySlice(
                date: date, kcal: food.kcal, proteinG: food.protein,
                plates: food.plates, steps: steps
            ))
        }

        // The protein floor's numerator comes from THE ladder, which
        // owns the fallback rungs (freshest row → onboarding answer →
        // plan), instead of a raw freshest-row read. p54 — the fast
        // EMA left this file entirely: the trend story now consumes
        // the canonical `WeightWeekRead` its caller passes in, so the
        // week state carries food and steps only.
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let latestKg = TargetsService.resolvedWeightKg(
            userId: userId, plan: plan, in: context
        )

        return WeekState(
            days: days,
            proteinTargetG: latestKg.map { TargetsService.proteinTargetG(weightKg: $0) }
        )
    }
}

// MARK: - InsightEngine
//
// p54 — REDUCED TO THE ONE LIVE SENTENCE. The v2.1 design shipped a
// ranked card cascade (protein pattern · begin-again · glp-1 rhythm ·
// maintenance band · step pattern · weekend rhythm · showing-up), and
// a census proved the cards had exactly ZERO reachable surfaces —
// `BecomingSummaryView.composeReview()` consumed only
// `trendStory?.line`, and `Output.cards` was discarded at its single
// call site. Roughly twenty-five authored claim sentences were
// shipping as dead weight, several drifting out of date unreviewed
// (the exact hazard §19 names). The weekend-shape computation was the
// one card worth keeping and it moved to the weekly read, where it
// finally has a surface.
//
// What remains is the trend story — and it moved onto the CANONICAL
// fold. Until this pass it computed its own fast EMA over the raw
// rows with NO sufficiency gate, so Becoming's body-card hero could
// claim "down about 1 lb this week" over a record the one trend
// authority rated insufficient, directly above a tile that refused
// the same sentence. The pass-51 law, finally finished here: lines
// drawn by `trendSeries`, words by `read`, and nothing speaks a
// direction the band withholds.
//
// Voice contract applies (lowercase, italic arrays, no em-dashes).
// Every clause traces to a stored value.

struct Insight: Equatable {
    let line: String
    let italic: [String]
    /// One quieter mechanism sentence under the line. nil = line only.
    let detail: String?
}

enum InsightEngine {

    // MARK: - The trend story (the hero's voice)

    /// The one sentence this engine still owns, spoken from the
    /// canonical read. The BAND decides the direction word (the same
    /// authority behind the tile, the weekly read, jeni's tool and
    /// the clinician packet); a withheld band produces the honest
    /// forming line, never a direction.
    static func trendStory(
        read: WeightWeekRead, week: WeekState, numericsSuppressed: Bool
    ) -> Insight? {
        guard !numericsSuppressed else {
            return Insight(
                line: "showing up is what this page measures.",
                italic: ["rhythm"],
                detail: nil
            )
        }
        guard let band = read.band, let delta = read.weeklyDeltaKg else {
            return Insight(
                line: "a few more weigh-ins and your trend line starts.",
                italic: ["trend line"],
                detail: nil
            )
        }

        // An early read says so — the weekly read's own vocabulary for
        // a provisional band, carried here so the two surfaces agree.
        let earlyRead: String? = read.sufficiency == .provisional
            ? "an early read." : nil

        // v5: the story speaks HER unit — "500g" read as a foreign
        // measure to a lb user one line above a lb headline.
        let phrase = deltaPhrase(delta)
        switch band {
        case .trendingDown:
            // p54 — the ratio's denominator is the days she LOGGED,
            // never a hardcoded 7: "4 of 7" over a 4-day record read
            // as three failures that never happened.
            let mechanism: String? = week.proteinDaysHit >= 4
                ? "protein landed \(week.proteinDaysHit) of \(week.loggedDays7) logged days."
                : (week.loggedDays7 >= 5 ? "you logged \(week.loggedDays7) of 7 days." : nil)
            return Insight(
                line: "down \(phrase) this week.",
                italic: ["down"],
                detail: earlyRead ?? mechanism
            )
        case .driftingUp:
            return Insight(
                line: "up \(phrase). usually water, not fat.",
                italic: ["water"],
                detail: earlyRead ?? "salt, cycle timing and sleep move the scale days before fat does."
            )
        case .holdingSteady:
            return Insight(
                line: "holding steady this week.",
                italic: ["steady"],
                detail: earlyRead
            )
        }
    }

    /// The trend delta in her display unit, rounded to honest steps
    /// ("about half a pound" / "about 1.5 lb" / "about 500g").
    private static func deltaPhrase(_ deltaKg: Double) -> String {
        let unitRaw = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        if unitRaw == "kg" {
            let grams = Int((abs(deltaKg) * 1000).rounded(toNearest: 50))
            return grams >= 950
                ? String(format: "about %.1f kg", abs(deltaKg))
                : "about \(grams)g"
        }
        let lb = (abs(deltaKg) * 2.20462 * 2).rounded() / 2
        if lb < 0.5 { return "about half a pound" }
        return lb == lb.rounded(.down)
            ? "about \(Int(lb)) lb"
            : String(format: "about %.1f lb", lb)
    }

}

private extension Double {
    func rounded(toNearest step: Double) -> Double {
        (self / step).rounded() * step
    }
}
