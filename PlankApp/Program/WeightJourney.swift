import Foundation

/// THE WHOLE DISTANCE — start, now, and the goal she named.
///
/// `weight_logged` is the second most-used action in this product
/// (measured 2026-08-13: 72 users / 193 events over 90 days, against
/// 82 users for food logging). And until this file, the app could not
/// perform the arithmetic that every one of those users came for:
///
///   grep -rn "startWeight\|sinceStart\|totalChange"  →  no matches
///
/// `BodyStateService.weightRead` computes a 7-day EMA delta, a weekly
/// loss rate, a stall flag and a too-fast flag — a rich clinical read
/// with no answer to "how much have I lost?". Becoming's body card
/// therefore led with *"down about 1 lb this week"*, which on a
/// twelve-day-old record is the least motivating true sentence
/// available. Meanwhile onboarding asks her goal weight, stores it in
/// `onboardingGoalWeightKg`, feeds it to the calorie target and **never
/// shows it to her again** — `goalWeightKg` appears in no view outside
/// the onboarding screens that collect it.
///
/// Total change since the start is the number people screenshot. It is
/// the number the reviews of every competing product are written about.
/// It is four lines of arithmetic over data this app has held all
/// along.
///
/// ## The honesty rules
///
/// - **The present is a trend; the start is a fact.** Today's endpoint
///   is the EMA, never the scale, so one heavy morning cannot end the
///   journey on a lie. The start is her earliest logged weight, because
///   `WeightTrendChart.computeEMA` windows to 60 days — its first point
///   is "sixty days ago", not "when you started", and reading a total
///   off it would quietly shorten every record older than two months.
///   The asymmetry is the honest one: the start is a fixed historical
///   measurement she can name, the present is a direction.
/// - **It waits for a record worth reading.** The threshold is
///   `BodyStateService`'s existing `trendEstablished` (≥3 logs spanning
///   ≥5 days) rather than a second invented one. Before that, there is
///   no journey to state and this returns nil.
/// - **A goal only speaks when it is hers and still ahead.** No goal on
///   file, or a goal already reached, produces no "to go" line — a
///   remaining figure that counts up from a met goal is a scold.
/// - **Direction is a word, never a colour**, and a gain is stated as
///   flatly as a loss.
struct WeightJourney: Equatable {

    /// Her earliest logged weight — the anchor, as measured.
    let startKg: Double
    /// EMA-smoothed value today.
    let currentKg: Double
    /// Negative = down. The whole distance.
    let changeKg: Double
    /// Her goal, when one is on file and below where she started.
    let goalKg: Double?
    /// Distance still ahead, nil when there is no goal or it is met.
    let remainingKg: Double?
    let reachedGoal: Bool
    /// Days between the first and latest weigh-in.
    let days: Int

    var isDown: Bool { changeKg < 0 }

    // MARK: - Deriving

    /// nil when the record cannot yet support a claim about the whole
    /// distance. `startKg`/`startedAt` are her EARLIEST weigh-in (the
    /// caller holds the fetch); `trend` is the CANONICAL fold's drawn
    /// series (p53 — this used to read the fast trigger EMA, so
    /// Home's change line could disagree with Becoming's line and the
    /// spoken trend for the same person).
    static func from(
        startKg: Double,
        startedAt: Date,
        trend: [WeightWeekReadEngine.TrendPoint],
        trendEstablished: Bool,
        goalKg: Double?,
        calendar: Calendar = .current
    ) -> WeightJourney? {
        guard trendEstablished, startKg > 0,
              let last = trend.last,
              calendar.startOfDay(for: startedAt)
                  < calendar.startOfDay(for: last.day)
        else { return nil }

        let change = last.trendKg - startKg
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startedAt),
            to: calendar.startOfDay(for: last.day)
        ).day ?? 0

        // A goal at or above where she started is not a loss goal, and
        // this engine has nothing true to say about it. Maintenance is
        // a different read, and it is not invented here.
        var goal: Double? = nil
        var remaining: Double? = nil
        var reached = false
        if let g = goalKg, g > 30, g < startKg {
            goal = g
            reached = last.trendKg <= g
            remaining = reached ? nil : last.trendKg - g
        }

        return WeightJourney(
            startKg: startKg,
            currentKg: last.trendKg,
            changeKg: change,
            goalKg: goal,
            remainingKg: remaining,
            reachedGoal: reached,
            days: days
        )
    }

    // MARK: - Reading

    /// `"down 4.2 lb since you started"` — the whole distance in her
    /// unit. Movement under a tenth of a display unit is not a
    /// direction, so it reads as holding rather than as a false trend.
    func changeLine(unit: WeightUnit = .current) -> String {
        let magnitude = unit.display(fromKg: abs(changeKg))
        guard magnitude >= 0.1 else { return "holding where you started" }
        let word = isDown ? "down" : "up"
        return "\(word) \(formatted(magnitude)) \(unit.label) since you started"
    }

    /// `"14.6 lb to go"`, or the arrival. nil when no goal is on file —
    /// a surface with no goal simply does not draw this.
    func goalLine(unit: WeightUnit = .current) -> String? {
        if reachedGoal { return "you reached your goal" }
        guard let remainingKg else { return nil }
        let magnitude = unit.display(fromKg: remainingKg)
        guard magnitude >= 0.1 else { return "you reached your goal" }
        return "\(formatted(magnitude)) \(unit.label) to go"
    }

    /// One element for VoiceOver — the two facts as a sentence.
    func voiceOver(unit: WeightUnit = .current) -> String {
        [changeLine(unit: unit), goalLine(unit: unit)]
            .compactMap { $0 }
            .joined(separator: ", ")
            .appending(".")
    }

    /// Drops a trailing `.0` — `"12 lb"`, never `"12.0 lb"`, the same
    /// grammar the rest of the food and weight surfaces keep.
    private func formatted(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
    }
}
