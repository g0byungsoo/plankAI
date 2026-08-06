import Foundation
import PlankFood

// MARK: - Signals (app v6 — the passive layer)
//
// Research base: docs/app_v6/00_RESEARCH.md. Five zero-input signals
// computed from streams the app already holds (plate timestamps,
// HealthKit steps/sleep, weigh-ins). The retention thesis: passive
// monitoring sustains engagement where active logging decays, and
// anti-shame framing is a retention mechanic, not just voice.
//
// Register floors (shared with QuietHours, non-negotiable):
//   - OBSERVED, NEVER PRESCRIBED. No targets, no timers, no
//     countdowns, no "extend" prompts. (v6.4 founder override: the
//     fast IS named — "the overnight fast" — and explained; the
//     no-target/no-timer/care-at-16h rails hold underneath.)
//   - Praise saturates at 14h; 16h+ speaks care, never bonus praise
//     (fasting prescriptions to this audience are a harm vector;
//     GLP-1 guidance caps at conservative 12:12-14:10).
//   - The on-medication chapter INVERTS the window: their clinical
//     risk is under-fueling, so their frame is "first plate landed",
//     never hour arithmetic.
//   - Hard-gated off for restriction-risk / numeric-suppressed
//     identities via QuietHours.mayNarrate.
//   - Absence never renders; every number traces to a stored field.

// MARK: - KitchenSignal — the overnight window, live

/// The Home window module's engine. Extends QuietHours (the pure
/// overnight math) with a LIVE phase machine: closed → settled →
/// evening across the day, plus the 7-night week story Becoming
/// reads.
enum KitchenSignal {

    /// How the module speaks about a window length. Encoded here so
    /// the safety clamp is engine truth, not copy discipline.
    enum Tone: Equatable {
        case plain      // < 12h or 14–16h: neutral ink
        case warm       // 12–14h: the steady band, warm acknowledgment
        case care       // >= 16h: nourishment frame, never praise
    }

    static func tone(forHours hours: Double) -> Tone {
        switch hours {
        case ..<12: return .plain
        case ..<14: return .warm
        case ..<16: return .plain
        default: return .care
        }
    }

    enum Phase: Equatable {
        /// No plate yet today — the stretch since yesterday's last
        /// plate is live and counting.
        case overnight(sinceHours: Double, closedAt: Date)
        /// First plate landed — the overnight window is a settled fact.
        case settled(hours: Double, closedAt: Date, openedAt: Date)
        /// Evening (20:00+), plates exist today, and the kitchen has
        /// been quiet for 90+ minutes.
        case evening(sinceHours: Double, closedAt: Date)
    }

    /// The live phase for "now". nil = the module stays silent
    /// (no plates in range, or the gap is outside the 8–20h sanity
    /// band QuietHours defines).
    static func phase(
        plateTimes: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Phase? {
        let dayStart = calendar.startOfDay(for: now)
        let today = plateTimes.filter { $0 >= dayStart && $0 <= now }.sorted()
        let lastBefore = plateTimes.filter { $0 < dayStart }.max()

        if today.isEmpty {
            guard let lastBefore else { return nil }
            let hours = now.timeIntervalSince(lastBefore) / 3600
            guard hours >= QuietHours.minNarratableHours,
                  hours <= QuietHours.maxNarratableHours else { return nil }
            return .overnight(sinceHours: hours, closedAt: lastBefore)
        }

        // Evening close: after 20:00 with 90+ quiet minutes, the day's
        // last plate becomes "the kitchen closed at…". Self-correcting:
        // a later plate simply re-renders the phase.
        let hour = calendar.component(.hour, from: now)
        if hour >= 20, let last = today.last {
            let since = now.timeIntervalSince(last) / 3600
            if since >= 1.5 {
                return .evening(sinceHours: since, closedAt: last)
            }
        }

        if let lastBefore, let first = today.first {
            let hours = first.timeIntervalSince(lastBefore) / 3600
            if hours >= QuietHours.minNarratableHours,
               hours <= QuietHours.maxNarratableHours {
                return .settled(hours: hours, closedAt: lastBefore, openedAt: first)
            }
        }
        return nil
    }

    /// The on-medication chapter's fact: when did the first plate
    /// land today? (Their module never does hour arithmetic.)
    static func firstPlateToday(
        plateTimes: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Date? {
        let dayStart = calendar.startOfDay(for: now)
        return plateTimes.filter { $0 >= dayStart && $0 <= now }.min()
    }

    // MARK: The week story (Becoming)

    struct Night: Equatable, Identifiable {
        /// 0 = the night that ended this morning, 6 = six mornings ago.
        let daysAgo: Int
        /// nil = that night can't be narrated (missing plates or the
        /// gap fell outside the sanity band).
        let hours: Double?
        let closedAt: Date?
        let openedAt: Date?
        var id: Int { daysAgo }
    }

    struct WeekStory: Equatable {
        /// Ordered oldest → newest (daysAgo 6 → 0) for left-to-right
        /// rendering.
        let nights: [Night]
        let narratedCount: Int
        let averageHours: Double?
        /// Median "kitchen closed" moment as minutes-of-day (e.g.
        /// 20:41 → 1241). nil under 3 narrated nights.
        let medianCloseMinutes: Int?
        /// Spread (max − min) of close times in minutes across
        /// narrated nights — the consistency signal.
        let closeSpreadMinutes: Int?
    }

    static func week(
        plateTimes: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> [Night] {
        var nights: [Night] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            guard let dayStart = calendar.date(
                byAdding: .day, value: -daysAgo,
                to: calendar.startOfDay(for: now)
            ) else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let cap = min(dayEnd, now)
            let lastBefore = plateTimes.filter { $0 < dayStart }.max()
            let firstOfDay = plateTimes
                .filter { $0 >= dayStart && $0 < cap }
                .min()
            guard let lastBefore, let firstOfDay else {
                nights.append(Night(daysAgo: daysAgo, hours: nil,
                                    closedAt: nil, openedAt: nil))
                continue
            }
            let hours = firstOfDay.timeIntervalSince(lastBefore) / 3600
            let narratable = hours >= QuietHours.minNarratableHours
                && hours <= QuietHours.maxNarratableHours
            nights.append(Night(
                daysAgo: daysAgo,
                hours: narratable ? hours : nil,
                closedAt: narratable ? lastBefore : nil,
                openedAt: narratable ? firstOfDay : nil
            ))
        }
        return nights
    }

    static func weekStory(
        plateTimes: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> WeekStory? {
        let nights = week(plateTimes: plateTimes, now: now, calendar: calendar)
        let narrated = nights.compactMap(\.hours)
        guard narrated.count >= 2 else { return nil }

        let avg = narrated.reduce(0, +) / Double(narrated.count)

        var medianClose: Int?
        var closeSpread: Int?
        let closeMinutes = nights.compactMap { night -> Int? in
            guard let closedAt = night.closedAt else { return nil }
            let c = calendar.dateComponents([.hour, .minute], from: closedAt)
            var minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            // Fold the after-midnight tail (a 00:30 close reads as
            // 24:30) so median/spread stay meaningful around midnight.
            if minutes < 6 * 60 { minutes += 24 * 60 }
            return minutes
        }.sorted()
        if closeMinutes.count >= 3 {
            medianClose = closeMinutes[closeMinutes.count / 2]
            closeSpread = (closeMinutes.last ?? 0) - (closeMinutes.first ?? 0)
        }

        return WeekStory(
            nights: nights,
            narratedCount: narrated.count,
            averageHours: avg,
            medianCloseMinutes: medianClose.map { $0 >= 24 * 60 ? $0 - 24 * 60 : $0 },
            closeSpreadMinutes: closeSpread
        )
    }

    // MARK: Live wrappers

    @MainActor
    static func livePhase(userId: String) -> Phase? {
        guard QuietHours.mayNarrate, !userId.isEmpty else { return nil }
        let times = FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        return phase(plateTimes: times)
    }

    @MainActor
    static func liveWeekStory(userId: String) -> WeekStory? {
        guard QuietHours.mayNarrate, !userId.isEmpty else { return nil }
        let times = FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        return weekStory(plateTimes: times)
    }

    @MainActor
    static func liveFirstPlateToday(userId: String) -> Date? {
        guard !userId.isEmpty else { return nil }
        let times = FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        return firstPlateToday(plateTimes: times)
    }
}

// MARK: - SleepSignal — last night, spoken as forgiveness

/// Sleep → appetite context (Tasali 2022: extending short sleep cut
/// intake ~270 kcal/day; short sleep raises ghrelin). The signal's
/// whole job is REFRAMING: a hungry day after a short night is
/// chemistry, not weakness. It never prescribes a bedtime.
enum SleepSignal {

    enum Band: Equatable {
        case short   // < 6h
        case light   // 6–7h
        case full    // >= 7h
    }

    static func band(asleepHours: Double) -> Band {
        switch asleepHours {
        case ..<6: return .short
        case ..<7: return .light
        default: return .full
        }
    }

    /// "6h 12m" — engine-owned so the format is one truth.
    static func durationWord(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((interval / 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h <= 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func caption(for band: Band) -> String {
        switch band {
        case .short:
            return "expect stronger hunger today. that's chemistry, not weakness"
        case .light:
            return "a little under. hunger may pick up this afternoon"
        case .full:
            return "a full night. hunger runs lower today"
        }
    }
}

// MARK: - MealMoves — movement after plates, receipts only

/// Post-meal movement detection (Buffey 2022: 2–5 min of light
/// walking after meals flattens the glucose/insulin rise vs
/// sitting). Purely celebratory: a detected move renders a receipt;
/// an undetected one renders NOTHING (receipts-never-absence).
enum MealMoves {

    struct Move: Equatable {
        let plateAt: Date
        /// "breakfast" / "lunch" / "your afternoon plate" / "dinner"
        let slot: String
        let steps: Int
    }

    /// ~250 steps in the following clock hour ≈ 2.5+ minutes of
    /// walking — Buffey's floor, kept conservative.
    static let stepFloor = 250

    /// `hourlySteps` = today's 24 hourly buckets (StepsService).
    /// A plate credits the NEXT full clock hour, and a bucket may
    /// credit only one plate — two plates in adjacent hours can't
    /// double-count one walk. The current (incomplete) hour never
    /// credits.
    static func detect(
        plateTimes: [Date], hourlySteps: [Int],
        now: Date = .now, calendar: Calendar = .current,
        floor: Int = stepFloor
    ) -> [Move] {
        guard hourlySteps.count == 24 else { return [] }
        let dayStart = calendar.startOfDay(for: now)
        let nowHour = calendar.component(.hour, from: now)
        let today = plateTimes
            .filter { $0 >= dayStart && $0 <= now }
            .sorted()

        var creditedBuckets = Set<Int>()
        var moves: [Move] = []
        for plate in today {
            let plateHour = calendar.component(.hour, from: plate)
            let bucket = plateHour + 1
            guard bucket < nowHour, bucket <= 23 else { continue }
            guard !creditedBuckets.contains(bucket) else { continue }
            let steps = hourlySteps[bucket]
            guard steps >= floor else { continue }
            creditedBuckets.insert(bucket)
            moves.append(Move(plateAt: plate, slot: slot(forHour: plateHour), steps: steps))
        }
        return moves
    }

    /// Mirrors the food rail's meal-slot hours, spoken plainly.
    static func slot(forHour hour: Int) -> String {
        switch hour {
        case ..<11: return "breakfast"
        case ..<15: return "lunch"
        case ..<18: return "your afternoon plate"
        default: return "dinner"
        }
    }
}

// MARK: - WeekRhythm — the consistency receipts

/// Cadence over intensity (Zheng 2015: consistency of self-weighing
/// beats raw frequency; regular meal timing tracks with better
/// metabolic profiles). Spoken as receipts of what she DID — never
/// a lapsed streak.
enum WeekRhythm {

    struct Story: Equatable {
        /// Distinct days with a weigh-in, trailing 14 days.
        let weighDayCount: Int
        /// Which of the trailing 14 days carry a weigh-in — oldest
        /// first, for the cadence dot figure.
        let weighDayFlags: [Bool]
        /// Days with at least one plate, trailing 7.
        let plateDayCount: Int
        /// Median first-plate moment (minutes-of-day) across trailing
        /// 7 days — nil under 4 plate-days.
        let firstPlateMedianMinutes: Int?
    }

    static func story(
        weighDates: [Date], plateTimes: [Date],
        now: Date = .now, calendar: Calendar = .current
    ) -> Story {
        let todayStart = calendar.startOfDay(for: now)

        var weighFlags: [Bool] = []
        let weighDays = Set(weighDates.map { calendar.startOfDay(for: $0) })
        for daysAgo in stride(from: 13, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart)
            else { weighFlags.append(false); continue }
            weighFlags.append(weighDays.contains(day))
        }

        var plateDays = Set<Date>()
        var firstPlateMinutes: [Int] = []
        for daysAgo in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart)
            else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let plates = plateTimes.filter { $0 >= day && $0 < dayEnd }
            guard let first = plates.min() else { continue }
            plateDays.insert(day)
            let c = calendar.dateComponents([.hour, .minute], from: first)
            firstPlateMinutes.append((c.hour ?? 0) * 60 + (c.minute ?? 0))
        }

        let median: Int? = firstPlateMinutes.count >= 4
            ? firstPlateMinutes.sorted()[firstPlateMinutes.count / 2]
            : nil

        return Story(
            weighDayCount: weighFlags.filter { $0 }.count,
            weighDayFlags: weighFlags,
            plateDayCount: plateDays.count,
            firstPlateMedianMinutes: median
        )
    }

    /// The cadence word — receipts grammar, no streak language.
    /// nil = the page shouldn't speak about weighing yet.
    static func cadenceWord(weighDayCount: Int) -> String? {
        switch weighDayCount {
        case ..<2: return nil
        case ..<4: return "finding shape"
        case ..<8: return "steady"
        default: return "daily-ish"
        }
    }
}

// MARK: - Sweetness — when sugar lands, never a verdict

/// The sugar pattern (WHO: free sugars are a determinant of body
/// weight). The plate-level `sugar` field ships since v1.1.5 and is
/// device-local; older plates read 0 (silent) — the floors below
/// keep the story honest. Language law: observation of WHEN and
/// which WAY it's moving. Never good/bad, never a gram budget.
enum Sweetness {

    enum Direction: Equatable { case easing, steady, rising }

    struct Story: Equatable {
        /// Trailing 7 days, oldest → today. nil = no plates that day.
        let dayGrams: [Double?]
        /// Days (of the 7) with plates that carried a sugar value.
        let sugarDayCount: Int
        let averageG: Int
        /// Where in the day sweetness lands, as weighted shares.
        let morningShare: Double
        let afternoonShare: Double
        let eveningShare: Double
        /// vs the PRIOR 7 days — nil when either week is under 3
        /// sugar-days (no fabricated trends).
        let direction: Direction?

        var dominantMoment: String {
            if eveningShare >= morningShare && eveningShare >= afternoonShare {
                return "evenings"
            }
            if morningShare >= afternoonShare { return "mornings" }
            return "afternoons"
        }
    }

    static func story(
        entries: [(at: Date, sugarG: Double)],
        now: Date = .now, calendar: Calendar = .current
    ) -> Story? {
        let todayStart = calendar.startOfDay(for: now)

        func weekSlice(endingDaysAgo offset: Int) -> [[(at: Date, sugarG: Double)]] {
            var days: [[(at: Date, sugarG: Double)]] = []
            for daysAgo in stride(from: 6 + offset, through: offset, by: -1) {
                guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart),
                      let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)
                else { days.append([]); continue }
                days.append(entries.filter { $0.at >= day && $0.at < dayEnd })
            }
            return days
        }

        let thisWeek = weekSlice(endingDaysAgo: 0)
        let dayGrams: [Double?] = thisWeek.map { day in
            day.isEmpty ? nil : day.reduce(0) { $0 + $1.sugarG }
        }
        let sugarDays = dayGrams.compactMap { $0 }.filter { $0 > 0 }
        guard sugarDays.count >= 3 else { return nil }
        let avg = sugarDays.reduce(0, +) / Double(sugarDays.count)

        // Weighted time-of-day shares over the week's sugar.
        var morning = 0.0, afternoon = 0.0, evening = 0.0
        for day in thisWeek {
            for entry in day where entry.sugarG > 0 {
                let hour = calendar.component(.hour, from: entry.at)
                switch hour {
                case ..<12: morning += entry.sugarG
                case ..<17: afternoon += entry.sugarG
                default: evening += entry.sugarG
                }
            }
        }
        let total = max(morning + afternoon + evening, 0.001)

        // Direction vs the prior week, floored on both sides.
        var direction: Direction?
        let priorWeek = weekSlice(endingDaysAgo: 7)
        let priorDays = priorWeek
            .map { day in day.reduce(0) { $0 + $1.sugarG } }
            .filter { $0 > 0 }
        if priorDays.count >= 3 {
            let priorAvg = priorDays.reduce(0, +) / Double(priorDays.count)
            let delta = avg - priorAvg
            if abs(delta) >= max(8, priorAvg * 0.15) {
                direction = delta < 0 ? .easing : .rising
            } else {
                direction = .steady
            }
        }

        return Story(
            dayGrams: dayGrams,
            sugarDayCount: sugarDays.count,
            averageG: Int(avg.rounded()),
            morningShare: morning / total,
            afternoonShare: afternoon / total,
            eveningShare: evening / total,
            direction: direction
        )
    }

    @MainActor
    static func liveStory(userId: String) -> Story? {
        guard QuietHours.mayNarrate, !userId.isEmpty else { return nil }
        let entries = FoodLogPersister.allEntries(userId: userId)
            .map { (at: $0.loggedAt, sugarG: $0.sugar) }
        return story(entries: entries)
    }
}

// MARK: - CycleSignal — her season, spoken as planning not prediction

/// Cycle-phase appetite context (meta-analysis: ~168 kcal/day higher
/// intake in the luteal phase while resting expenditure ALSO rises
/// ~100-300 kcal — hungrier weeks are chemistry on both sides of the
/// ledger). Register floors:
///   - NEVER a prediction surface: no next-period dates, no fertility
///     words, no ovulation claims. The phase is context for appetite,
///     nothing else.
///   - Home speaks ONLY when it helps (menstrual/luteal); quiet weeks
///     stay quiet.
///   - Perimenopausal identities are gated off (irregular cycles make
///     the phase math misleading).
enum CycleSignal {

    enum Phase: Equatable { case menstrual, follicular, luteal }

    struct Read: Equatable {
        let phase: Phase
        /// 1-based day of the current cycle — engine-internal
        /// provenance; views never render it as a countdown.
        let dayOfCycle: Int
        let cycleLengthDays: Int
    }

    /// Distinct flow-day starts → period starts. A gap of more than
    /// 7 days between flow days opens a new episode.
    static func periodStarts(
        flowDays: [Date], calendar: Calendar = .current
    ) -> [Date] {
        let days = Set(flowDays.map { calendar.startOfDay(for: $0) }).sorted()
        var starts: [Date] = []
        var previous: Date?
        for day in days {
            if let previous,
               let gap = calendar.dateComponents([.day], from: previous, to: day).day,
               gap <= 7 {
                // same episode continues
            } else {
                starts.append(day)
            }
            previous = day
        }
        return starts
    }

    /// The current read. nil = silent (no starts, or the last start
    /// is stale enough that any phase claim would be a guess).
    static func read(
        periodStarts: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Read? {
        let starts = periodStarts.map { calendar.startOfDay(for: $0) }.sorted()
        guard let last = starts.last,
              let gap = calendar.dateComponents(
                  [.day], from: last, to: calendar.startOfDay(for: now)
              ).day,
              gap >= 0, gap <= 45
        else { return nil }

        // Cycle length: median of recent start-to-start gaps inside
        // the plausible band; 28 when history is thin.
        var length = 28
        if starts.count >= 2 {
            let diffs = zip(starts.dropFirst(), starts).compactMap {
                calendar.dateComponents([.day], from: $1, to: $0).day
            }.filter { (20...40).contains($0) }
            if !diffs.isEmpty {
                length = diffs.sorted()[diffs.count / 2]
            }
        }

        let day = gap + 1
        let phase: Phase
        if day <= 5 {
            phase = .menstrual
        } else if day >= length - 10 {
            phase = .luteal
        } else {
            phase = .follicular
        }
        return Read(phase: phase, dayOfCycle: day, cycleLengthDays: length)
    }
}

// MARK: - ProteinPacing — when protein arrives, not just how much

/// Protein distribution across the day (Leidy RCTs: a 35g-protein
/// morning raises satiety and cuts evening snacking, especially
/// high-fat). The arc already answers "enough?"; this answers
/// "early enough?". Observation only — never a meal plan.
enum ProteinPacing {

    struct Story: Equatable {
        let morningShare: Double
        let afternoonShare: Double
        let eveningShare: Double
        /// Days (trailing 7) with protein-carrying plates.
        let proteinDayCount: Int

        var morningLeads: Bool { morningShare >= 0.30 }
        var eveningHeavy: Bool { eveningShare >= 0.55 }
    }

    static func story(
        entries: [(at: Date, proteinG: Double)],
        now: Date = .now, calendar: Calendar = .current
    ) -> Story? {
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: todayStart)
        else { return nil }
        let recent = entries.filter { $0.at >= windowStart && $0.proteinG > 0 }

        let proteinDays = Set(recent.map { calendar.startOfDay(for: $0.at) }).count
        guard proteinDays >= 4 else { return nil }

        var morning = 0.0, afternoon = 0.0, evening = 0.0
        for entry in recent {
            let hour = calendar.component(.hour, from: entry.at)
            switch hour {
            case ..<12: morning += entry.proteinG
            case ..<17: afternoon += entry.proteinG
            default: evening += entry.proteinG
            }
        }
        let total = max(morning + afternoon + evening, 0.001)
        return Story(
            morningShare: morning / total,
            afternoonShare: afternoon / total,
            eveningShare: evening / total,
            proteinDayCount: proteinDays
        )
    }

    @MainActor
    static func liveStory(userId: String) -> Story? {
        guard !userId.isEmpty else { return nil }
        let entries = FoodLogPersister.allEntries(userId: userId)
            .map { (at: $0.loggedAt, proteinG: $0.protein) }
        return story(entries: entries)
    }
}

// MARK: - BodyLine — the coach's "so what" (app v6.2, the cohesion layer)
//
// What a human coach does with every data point: ties it back to HER
// body and HER trend (docs/app_v6/02_COHESION.md). Laws:
//   - JUXTAPOSITION, never causation — a habit fact may sit beside an
//     eased trend ("·", "alongside", "with it"), never "because".
//   - The trend is only borrowed when it EASED and is established
//     (3+ weigh-ins over 5+ days); a rising trend is never paired
//     with her habits — that reads as blame.
//   - Mechanism lines carry no numerals, so suppression-safe callers
//     simply pass easedDisplay = nil.
enum BodyLine {

    /// The shared trend gate: an established, genuinely eased 7-day
    /// EMA delta (≤ −0.09 kg ≈ −0.2 lb — display-visible movement).
    static func easedDelta(established: Bool, emaDelta7dKg: Double?) -> Double? {
        guard established, let delta = emaDelta7dKg, delta <= -0.09 else { return nil }
        return delta
    }

    static func window(avgHours: Double?, narratedCount: Int, easedDisplay: String?) -> String? {
        guard let avgHours, narratedCount >= 4, avgHours < 16 else { return nil }
        if let easedDisplay {
            return "\(narratedCount) steady nights · your trend is down \(easedDisplay) this week"
        }
        return "a consistent overnight fast keeps next-day hunger lower"
    }

    static func sleep(avgHours: Double?, shortNights: Int, easedDisplay: String?) -> String? {
        guard avgHours != nil else { return nil }
        if shortNights >= 3 {
            return "short sleep raises hunger hormones. plan for hungrier days"
        }
        if let avgHours, avgHours >= 7, let easedDisplay {
            return "full nights this week · your trend is down \(easedDisplay) alongside"
        }
        return nil
    }

    static func sweetness(direction: Sweetness.Direction?, easedDisplay: String?) -> String? {
        guard direction == .easing, let easedDisplay else { return nil }
        return "sugar came down this week · your trend is down \(easedDisplay) with it"
    }

    static func rhythm(weighDayCount: Int, easedDisplay: String?) -> String? {
        guard weighDayCount >= 4 else { return nil }
        if let easedDisplay {
            return "\(weighDayCount) weigh-ins · your trend is down \(easedDisplay). keep that cadence"
        }
        return "the trend line gets sharper with every weigh-in"
    }

    static func pacing(story: ProteinPacing.Story) -> String? {
        if story.morningLeads {
            return "protein lands early in your day. that usually means less evening hunger"
        }
        if story.eveningHeavy {
            return "moving some protein to the morning usually cuts evening snacking"
        }
        return nil
    }

    /// The season's body line is where a coach earns trust: naming
    /// luteal water weight BEFORE the scale does.
    static func season(phase: CycleSignal.Phase) -> String? {
        switch phase {
        case .luteal:
            return "if the scale drifts up this week, it's mostly water retention, not fat. the trend line filters it out"
        case .menstrual:
            return "the scale is noisiest on period days. trust the trend line, not a single morning"
        case .follicular:
            return nil
        }
    }
}

// MARK: - CoachSummary — one move, chosen like a coach would

/// The becoming pager's closing synthesis (v6.5, the founder's
/// coherent-coaching ask): reads the whole signal week and names
/// EXACTLY ONE next move, by a fixed clinical priority — sleep debt
/// first (it drives hunger), then protein timing, then the fast's
/// edge, then sugar drift, then weigh cadence; a steady week
/// earns "change nothing". Deterministic and provenance-only: every
/// receipt row traces to a story that exists. Register: direct
/// coach language (v6.5 founder directive), warmth stays terminal.
enum CoachSummary {

    struct Input {
        var fastAvgHours: Double? = nil
        var fastNights: Int = 0
        var sleepAvgHours: Double? = nil
        var shortNights: Int = 0
        var pacing: ProteinPacing.Story? = nil
        var sweetDirection: Sweetness.Direction? = nil
        var weighDays14: Int? = nil
        var lutealNow: Bool = false
    }

    struct Output: Equatable {
        /// The one move, spoken as the page headline.
        let headline: String
        let italic: [String]
        /// The supporting mechanism line under the receipt.
        let why: String
        /// The seed jeni's chat opens with from the talk door.
        let chatSeed: String
        /// Season overlay when the hungrier stretch is running.
        let seasonNote: String?
    }

    /// nil until at least two signal stories exist — a summary of
    /// one fact is a caption, not coaching.
    static func compose(_ input: Input) -> Output? {
        var present = 0
        if input.fastAvgHours != nil { present += 1 }
        if input.sleepAvgHours != nil { present += 1 }
        if input.pacing != nil { present += 1 }
        if input.sweetDirection != nil { present += 1 }
        if input.weighDays14 != nil { present += 1 }
        guard present >= 2 else { return nil }

        let seasonNote = input.lutealNow
            ? "you're in the hungrier week of your cycle. the move above matters double right now"
            : nil

        // 1 — sleep debt outranks everything (it drives hunger).
        if input.sleepAvgHours != nil, input.shortNights >= 3 {
            return Output(
                headline: "this week: guard your sleep.",
                italic: ["sleep"],
                why: "\(input.shortNights) nights under 6 hours raises hunger hormones. one earlier night does more than any food rule",
                chatSeed: "her coaching summary picked sleep: \(input.shortNights) nights under 6h this week. help her find one realistic earlier night; no food talk unless she asks.",
                seasonNote: seasonNote
            )
        }
        // 2 — protein arriving late (the evening-snacking lever).
        if let pacing = input.pacing, pacing.eveningHeavy {
            return Output(
                headline: "this week: protein earlier in the day.",
                italic: ["earlier"],
                why: "most of your protein comes at night. moving some to the morning usually cuts evening snacking",
                chatSeed: "her coaching summary picked protein timing: ~\(Int((pacing.eveningShare * 100).rounded()))% of protein lands in the evening. suggest one easy morning protein she'd actually eat.",
                seasonNote: seasonNote
            )
        }
        // 3 — the fast's near edge (only when clearly short, never
        //     pushing past the gentle band).
        if let avg = input.fastAvgHours, input.fastNights >= 4, avg < 11 {
            return Output(
                headline: "this week: stop eating a little earlier.",
                italic: ["earlier"],
                why: "your overnight fast averages \(Int(avg.rounded())) hours. finishing about 30 minutes earlier at night gets you near 12",
                chatSeed: "her coaching summary picked the overnight fast: averaging \(Int(avg.rounded()))h. help her pick a realistic last-plate time; never push past 14h.",
                seasonNote: seasonNote
            )
        }
        // 4 — sugar drifting up.
        if input.sweetDirection == .rising {
            return Output(
                headline: "this week: cut back on sugar.",
                italic: ["sugar"],
                why: "your sugar intake went up vs last week, mostly later in the day. one evening swap is usually enough",
                chatSeed: "her coaching summary picked sugar intake: up vs last week, mostly evenings. suggest one realistic swap she'd enjoy; zero shame.",
                seasonNote: seasonNote
            )
        }
        // 5 — the trend line is starving for weigh-ins.
        if let weighDays = input.weighDays14, weighDays < 2 {
            return Output(
                headline: "this week: weigh in at least once.",
                italic: ["once"],
                why: "your trend line needs data to stay accurate. one morning weigh-in is enough to restart it",
                chatSeed: "her coaching summary picked weigh cadence: under 2 weigh-ins in two weeks. pre-frame the scale as data, not judgment.",
                seasonNote: seasonNote
            )
        }
        // 6 — steady week: protect it.
        return Output(
            headline: "this week: change nothing.",
            italic: ["nothing"],
            why: "every signal is on track. your only job this week is to repeat it",
            chatSeed: "her coaching summary found a steady week across signals. tell her plainly it's working and ask what felt easiest.",
            seasonNote: seasonNote
        )
    }
}
