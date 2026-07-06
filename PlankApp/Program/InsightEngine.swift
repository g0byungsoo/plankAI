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
    let emaSeries: [WeightTrendChart.EMAPoint]
    /// Newest-first weight logs (the trend canvas consumes these raw).
    let weightLogs: [WeightLogRecord]
    let proteinTargetG: Int?
    let stepsGoal: Int

    var last7: ArraySlice<DaySlice> { days.suffix(7) }

    var proteinDaysHit: Int {
        guard let target = proteinTargetG else { return 0 }
        return last7.filter { $0.proteinG >= Double(target) }.count
    }
    var loggedDays7: Int { last7.filter { $0.plates > 0 }.count }
    var avgProtein7: Int {
        let logged = last7.filter { $0.plates > 0 }
        guard !logged.isEmpty else { return 0 }
        return Int((logged.map(\.proteinG).reduce(0, +) / Double(logged.count)).rounded())
    }
    var emaDelta7dKg: Double? { TodayStateService.emaDelta7d(emaSeries) }

    /// A quiet day (nothing logged) followed by a logged day — the
    /// begin-again pattern worth naming (flexible restraint).
    var resumedAfterQuietDay: Bool {
        let slices = Array(last7)
        guard slices.count >= 3 else { return false }
        for i in 1..<slices.count where slices[i].plates > 0 && slices[i - 1].plates == 0 {
            // Only counts if she HAD been logging before the quiet day.
            if slices[..<(i - 1)].contains(where: { $0.plates > 0 }) { return true }
        }
        return false
    }

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

        let uid = userId
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        let latestKg = logs.first?.weightKg

        return WeekState(
            days: days,
            emaSeries: WeightTrendChart.computeEMA(logs: logs),
            weightLogs: logs,
            proteinTargetG: latestKg.map { TargetsService.proteinTargetG(weightKg: $0) },
            // ONE goal source (v3 spine): a tier-9000 user used to see
            // 9000 on Today's ring but 7500 in the week strip.
            stepsGoal: TargetsService.stepsGoal(
                plan: ProgramService.shared.activePlan(userId: userId, in: context)
            )
        )
    }
}

// MARK: - InsightEngine
//
// App v2.1 (docs/app_v2/12_BECOMING_V2.md). The premium insight
// layer: a ranked, deterministic cascade that turns her real
// patterns into a coach's explanation — "why your weight moved" as
// a sentence with a mechanism, never a chart with a caption. Max
// two insights surface at once; each carries a chat seed so jeni
// can take the conversation deeper.
//
// Voice contract applies (lowercase, italic arrays, ♥ terminal
// sparse, no em-dashes). Every clause traces to a stored value.

struct Insight: Identifiable, Equatable {
    enum Kind: String {
        case trendStory        // rides the trend hero, not a card
        case proteinPattern
        case beginAgain
        case stepPattern
        case glp1Rhythm
        case maintenanceBand
        case weekendRhythm     // v3 zero-input: weekend vs weekday shape
        case showingUp
    }
    let kind: Kind
    let line: String
    let italic: [String]
    /// One quieter mechanism sentence under the line. nil = line only.
    let detail: String?
    let chatSeed: String
    var id: String { kind.rawValue }
}

enum InsightEngine {

    struct Output {
        /// The narrative that sits WITH the trend canvas.
        let trendStory: Insight?
        /// Ranked pattern cards below (max 2).
        let cards: [Insight]
    }

    static func insights(week: WeekState, snapshot: TodaySnapshot) -> Output {
        let story = trendStory(week: week, snapshot: snapshot)
        var cards: [Insight] = []

        if let protein = proteinPattern(week: week) { cards.append(protein) }
        if let resume = beginAgain(week: week) { cards.append(resume) }
        if let glp1 = glp1Rhythm(week: week, snapshot: snapshot) { cards.append(glp1) }
        if let band = maintenanceBand(week: week, snapshot: snapshot) { cards.append(band) }
        if let steps = stepPattern(week: week) { cards.append(steps) }
        if let weekend = weekendRhythm(week: week, snapshot: snapshot) { cards.append(weekend) }
        if cards.isEmpty, let fallback = showingUp(snapshot: snapshot) { cards.append(fallback) }

        return Output(trendStory: story, cards: Array(cards.prefix(2)))
    }

    // MARK: - The trend story (the hero's voice)

    private static func trendStory(week: WeekState, snapshot: TodaySnapshot) -> Insight? {
        guard week.emaSeries.count >= 2 else { return nil }
        guard !snapshot.targets.numericsSuppressed else {
            return Insight(
                kind: .trendStory,
                line: "your rhythm is the measure here.",
                italic: ["rhythm"],
                detail: nil,
                chatSeed: "her numerics are suppressed for safety. talk rhythm and care, no numbers."
            )
        }
        guard let delta = week.emaDelta7dKg else {
            return Insight(
                kind: .trendStory,
                line: "two more mornings and your trend line speaks.",
                italic: ["speaks"],
                detail: nil,
                chatSeed: "she has under a week of weigh-ins. explain what the trend line will show and why it beats single weigh-ins."
            )
        }

        let gramsAbs = Int((abs(delta) * 1000).rounded(toNearest: 50))
        if delta <= -0.15 {
            let mechanism: String? = week.proteinDaysHit >= 4
                ? "protein landed \(week.proteinDaysHit) of 7 days. that's the mechanism, not magic."
                : (week.loggedDays7 >= 5 ? "you saw \(week.loggedDays7) of 7 days of plates. seeing is steering." : nil)
            return Insight(
                kind: .trendStory,
                line: "the line eased down about \(gramsAbs)g this week.",
                italic: ["eased down"],
                detail: mechanism,
                chatSeed: "her 7-day trend is down ~\(gramsAbs)g. name what she did that drove it and one thing to keep."
            )
        }
        if delta >= 0.25 {
            return Insight(
                kind: .trendStory,
                line: "the line drifted up about \(gramsAbs)g. water and rhythm do this.",
                italic: ["water and rhythm"],
                detail: "sodium, cycle timing, and sleep move the scale days before fat does. the week decides.",
                chatSeed: "her trend ticked up ~\(gramsAbs)g over 7 days. explain fluctuation mechanisms calmly and give one anchor."
            )
        }
        return Insight(
            kind: .trendStory,
            line: "holding steady. that's a skill, not a stall.",
            italic: ["skill"],
            detail: nil,
            chatSeed: "her trend is flat this week. reframe steady as capacity, then one gentle lever if she wants movement."
        )
    }

    // MARK: - Pattern cards

    private static func proteinPattern(week: WeekState) -> Insight? {
        guard let target = week.proteinTargetG, week.loggedDays7 >= 3 else { return nil }
        let hit = week.proteinDaysHit
        if hit >= 4 {
            return Insight(
                kind: .proteinPattern,
                line: "protein landed \(hit) of 7 days.",
                italic: ["landed"],
                detail: "your average was \(week.avgProtein7)g against the \(target)g floor. muscle stays when this holds.",
                chatSeed: "her protein hit target \(hit)/7 days, avg \(week.avgProtein7)g vs \(target)g. celebrate the pattern and ask what made those days work."
            )
        }
        if week.avgProtein7 > 0, week.avgProtein7 < Int(Double(target) * 0.75) {
            return Insight(
                kind: .proteinPattern,
                line: "protein is running quiet — about \(week.avgProtein7)g most days.",
                italic: ["quiet"],
                detail: "one anchor plate (eggs, yogurt, chicken, tofu) moves this more than tracking harder.",
                chatSeed: "her protein averages \(week.avgProtein7)g vs a \(target)g floor. suggest one concrete anchor-plate habit, zero guilt."
            )
        }
        return nil
    }

    private static func beginAgain(week: WeekState) -> Insight? {
        guard week.resumedAfterQuietDay else { return nil }
        return Insight(
            kind: .beginAgain,
            line: "you came back the day after a quiet day.",
            italic: ["came back"],
            detail: "that reflex is what separates people who keep weight off from people who restart. it has a name: flexible restraint.",
            chatSeed: "she resumed logging right after a zero-log day. name the flexible-restraint skill and reinforce it."
        )
    }

    private static func stepPattern(week: WeekState) -> Insight? {
        let stepped = week.last7.compactMap(\.steps).filter { $0 > 0 }
        guard stepped.count >= 5 else { return nil }
        let avg = stepped.reduce(0, +) / stepped.count
        guard let best = stepped.max(), best > Int(Double(avg) * 1.6), avg > 1_000 else { return nil }
        return Insight(
            kind: .stepPattern,
            line: "one day this week you walked \(best.formatted()) steps.",
            italic: ["\(best.formatted())"],
            detail: "your body already knows how. borrowing 15 minutes of that day into two others changes the week.",
            chatSeed: "her best step day was \(best) vs a \(avg) average. suggest how to borrow a slice of that pattern into weekdays."
        )
    }

    private static func glp1Rhythm(week: WeekState, snapshot: TodaySnapshot) -> Insight? {
        guard CohortStore.isGLP1Current else { return nil }
        guard let target = week.proteinTargetG, week.loggedDays7 >= 3 else { return nil }
        if week.avgProtein7 < Int(Double(target) * 0.8) {
            return Insight(
                kind: .glp1Rhythm,
                line: "small appetite weeks still need their protein.",
                italic: ["protein"],
                detail: "when hunger is quiet, dense small plates protect your muscle while the medication does its part.",
                chatSeed: "glp-1 user averaging \(week.avgProtein7)g protein vs \(target)g. suggest dense low-volume options for low-appetite days."
            )
        }
        return nil
    }

    private static func maintenanceBand(week: WeekState, snapshot: TodaySnapshot) -> Insight? {
        guard CohortStore.isMaintenanceMode, let delta = week.emaDelta7dKg else { return nil }
        if abs(delta) <= 0.3 {
            return Insight(
                kind: .maintenanceBand,
                line: "another week inside your band.",
                italic: ["inside"],
                detail: "keeping is quieter than losing. it counts more.",
                chatSeed: "maintainer holding steady within ±300g this week. reinforce that maintenance is the achievement."
            )
        }
        return nil
    }

    /// v3 zero-input pattern: the weekend runs warmer (or it doesn't)
    /// — the shape of her week from plates she already logged. Kcal
    /// register, so it's gated off suppressed + restriction-risk
    /// identities; needs 3 logged weekend days + 5 logged weekdays
    /// across the 14-day frame; speaks only at >=150 kcal of shape,
    /// rounded to 50 (never false precision). A rhythm named, never
    /// a problem assigned.
    private static func weekendRhythm(week: WeekState, snapshot: TodaySnapshot) -> Insight? {
        guard !snapshot.targets.numericsSuppressed,
              !CohortStore.isRestrictiveRisk else { return nil }
        let cal = Calendar.current
        let logged = week.days.filter { $0.plates > 0 }
        let weekend = logged.filter { cal.isDateInWeekend($0.date) }
        let weekdays = logged.filter { !cal.isDateInWeekend($0.date) }
        guard weekend.count >= 3, weekdays.count >= 5 else { return nil }
        let wAvg = weekend.map(\.kcal).reduce(0, +) / Double(weekend.count)
        let dAvg = weekdays.map(\.kcal).reduce(0, +) / Double(weekdays.count)
        let delta = wAvg - dAvg
        guard delta >= 150 else { return nil }
        let rounded = Int((delta / 50).rounded() * 50)
        return Insight(
            kind: .weekendRhythm,
            line: "your weekends run about \(rounded) warmer. that's a rhythm, not a problem.",
            italic: ["rhythm"],
            detail: "knowing the week's shape beats fighting it. the quiet days already absorb it.",
            chatSeed: "her weekends average about \(rounded) kcal above weekdays across two weeks. normalize it as a plannable rhythm and offer one gentle weekend anchor if she wants one."
        )
    }

    private static func showingUp(snapshot: TodaySnapshot) -> Insight? {
        let count = UserDefaults.standard.integer(forKey: "stats.shown_up_count")
        guard count > 0 else { return nil }
        return Insight(
            kind: .showingUp,
            line: "you've shown up \(count) times.",
            italic: ["shown up"],
            detail: "the pattern is the product. everything else compounds from it.",
            chatSeed: "she has \(count) shown-up days. connect consistency to identity, briefly."
        )
    }
}

private extension Double {
    func rounded(toNearest step: Double) -> Double {
        (self / step).rounded() * step
    }
}
