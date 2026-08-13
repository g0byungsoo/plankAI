import Foundation

// MARK: - MethodEngine
//
// The decision rules. Pure, table-driven, and rule-based on purpose:
// 68.6% of the JITAI weight-management literature is rule-based rather
// than machine-learned (Koh et al 2025), and what separates a working
// intervention from a wasted one is WHICH MOMENT it picks, not how the
// picking is computed.
//
// Three laws it inherits from every other engine in this product:
//
//   1. It reads the SAME inputs the surfaces render from, so a note can
//      never disagree with the screen it appears on.
//   2. Silence is a first-class return value. `note(_:)` returning nil
//      is the most common correct answer, and there is no fallback note
//      — nothing generic ever fires just to fill the slot. That single
//      decision is what separates this from the thing it replaces.
//   3. Every number it says traces to a collected field. A note whose
//      facts are incomplete is dropped, not patched.

enum MethodEngine {

    // MARK: - Input (the tailoring variables)

    /// Everything the rules are allowed to see. A plain struct so the
    /// whole engine is testable without a snapshot, a store or a view.
    ///
    /// Signals that are genuinely unavailable arrive nil/zero and their
    /// triggers simply do not fire. A trigger that cannot be grounded
    /// does not get a guess.
    struct Input: Equatable {

        // ── the food record ──
        /// Plates ever, all time.
        var plateCountEver: Int = 0
        var plateCountToday: Int = 0
        var proteinEatenTodayG: Int = 0
        /// nil when no weight is on file — E7's law: no floor, no
        /// denominator, and here, no protein note either.
        var proteinFloorG: Int? = nil
        /// Protein totals for days that HAVE a plate on them, newest
        /// first, at most 14. Days with nothing logged are absent
        /// rather than zero: an unlogged day is not a low-protein day.
        var recentLoggedDayProteins: [Int] = []
        /// Has she reached the floor on any day BEFORE today? Named
        /// precisely: "ever, including today" would make the
        /// first-time note unfireable, because today is when it fires.
        var metProteinFloorBeforeToday: Bool = false
        /// Weekday offsets (0 = today) that carry at least one plate.
        var loggedDayOffsets: Set<Int> = []
        /// Weekend-day offsets in the last 9 days that exist at all.
        var weekendDayOffsets: Set<Int> = []

        // ── weight ──
        var latestWeightKg: Double? = nil
        /// The weigh-in before the latest one.
        var previousWeightKg: Double? = nil
        /// Her smoothed line at the latest weigh-in.
        var emaKg: Double? = nil
        var emaDelta7dKg: Double? = nil
        var trendIsEstablished: Bool = false
        var weighInCount: Int = 0
        /// Consecutive recent weeks whose smoothed change was inside the
        /// flat band. 0 when unknown.
        var flatWeeks: Int = 0

        // ── movement ──
        var steps7dMean: Int? = nil
        var steps28dMean: Int? = nil
        /// HealthKit strength-shaped workouts in the last 7 days.
        var strengthSessionsLast7: Int = 0
        var daysOfWeightHistory: Int = 0

        // ── side effects (v25 E9) ──
        /// Her own word for a nausea/loose-stomach symptom logged inside
        /// `queasyRecencyDays`, or nil. The WORD rather than the case, so
        /// the note quotes the vocabulary she tapped.
        var recentQueasySymptomWord: String? = nil
        /// Constipation logged inside `constipationRecencyDays`.
        var loggedConstipationRecently: Bool = false
        /// Mean fiber across her recent LOGGED days, or nil when there
        /// are not enough of them. Absent rather than zero: a day with
        /// no plates is not a no-fiber day.
        var recentFiberGPerDay: Int? = nil

        // ── medication ──
        var doseCadenceIsWeekly: Bool = false
        /// 1..7, event-anchored to her last actual injection (E2).
        var dayInDoseWeek: Int? = nil

        // ── lifecycle + context ──
        var daysSinceLastOpen: Int = 0
        var programDay: Int = 0
        var isMaintenancePhase: Bool = false
        var hourOfDay: Int = 12
        var numericsSuppressed: Bool = false
        /// The medication adequacy net already speaking. Same rule the
        /// protein close obeys: two prompts about one gap, one of them
        /// counting grams, is the pile-on this cohort must not get.
        var adequacyNetShowing: Bool = false
        /// Notes already shown, with the day they were shown on
        /// (days-ago). Cooldowns and once-ever notes read this.
        var shownDaysAgoById: [String: Int] = [:]
        /// Clinician-authored notes in force right now. Empty for a
        /// consumer, and empty for a clinic that has authored nothing —
        /// in both cases Jeni's defaults stand.
        var clinicNotes: [MethodNote] = []
        /// Note ids the clinic has explicitly suppressed.
        var clinicSuppressedIds: Set<String> = []
        var now: Date = .now
    }

    // MARK: - Thresholds
    //
    // Named, in one place, so a threshold change is a reviewable diff
    // rather than a number buried in a condition.

    /// A pattern, not a day: at least this many under-floor days out of
    /// the window below.
    static let underFloorDaysNeeded = 3
    static let underFloorWindow = 5
    /// A scale jump worth explaining, in kg. Below this it is noise
    /// nobody noticed; the point is to speak to the morning that
    /// frightens someone.
    static let scaleJumpKg = 0.8
    /// Weeks inside the flat band before a plateau is a plateau.
    static let flatWeeksNeeded = 3
    /// Days away before a return is a return.
    static let gapDaysNeeded = 3
    /// The waning end of a weekly dose cycle.
    static let lateDoseWeekDays: ClosedRange<Int> = 5...7
    /// Her own movement, as a fraction of her own baseline.
    static let movementDropRatio = 0.6
    static let movementBaselineDaysNeeded = 14
    /// A real rate of loss, kg/week, before pairing protein with
    /// loading becomes the point.
    static let losingRateKgPerWeek = 0.3
    /// Weigh-ins that make a line readable, matching the trend engine.
    static let weighInsForReadableTrend = 3
    /// v25 E9 — how recently a GI symptom still describes today. Two
    /// days for the fluid note (the label's window is the episode
    /// itself), three for constipation (it does not resolve overnight).
    static let queasyRecencyDays = 2
    static let constipationRecencyDays = 3
    /// Fiber below which "add something with fiber" is worth saying.
    /// The published FDA Daily Value is 28 g; this sits well under it so
    /// the note cannot fire on someone already doing the thing.
    static let lowFiberGPerDay = 18

    // MARK: - Priority
    //
    // At most ONE note. When several states are true the most
    // time-critical wins, because the others will still be true
    // tomorrow and this one may not.

    private static let priority: [MethodTrigger] = [
        // she is here right now after being away: nothing else matters
        .returnedAfterGap,
        // v25 E9 — a body that is losing fluid outranks every teaching
        // below it. This is the only trigger in the list whose subject
        // is a named safety mechanism rather than a behaviour, and it is
        // true for a day or two at most.
        .fluidsOnAQueasyDay,
        // a frightened morning, answerable only today
        .weightJumpedAgainstTrend,
        // transitions, at the only moment they are true
        .firstPlateOnFile,
        .proteinFloorMetFirstTime,
        .trendJustReadable,
        .firstWeekClosing,
        // patterns, which keep
        .constipationWithLowFiber,
        .lateInDoseWeek,
        .proteinUnderFloorRepeatedly,
        .weekendRecordDisappears,
        .losingWithoutResistanceWork,
        .movementBelowOwnBaseline,
        .trendFlatWhileLogging,
        // A CONDITION, not a transition: maintenance stays true for
        // months, so it is silenced by its own cooldown rather than by
        // the state going false. It therefore sits last, where it can
        // never outrank something that is only true today.
        .enteringMaintenance,
    ]

    // MARK: - The decision

    /// At most one note, rendered. nil is the common and correct answer.
    static func note(_ input: Input) -> ResolvedMethodNote? {
        for trigger in priority {
            guard let facts = facts(for: trigger, input) else { continue }
            guard let resolved = resolve(trigger, facts: facts, input) else { continue }
            return resolved
        }
        return nil
    }

    /// Every trigger currently true, most important first. Used by the
    /// chat tool (so Jeni can answer "why did you tell me that") and by
    /// the tests; the surface only ever shows the head.
    static func activeTriggers(_ input: Input) -> [MethodTrigger] {
        priority.filter { facts(for: $0, input) != nil }
    }

    // MARK: - Selection

    private static func resolve(
        _ trigger: MethodTrigger, facts: MethodFacts, _ input: Input
    ) -> ResolvedMethodNote? {
        let candidates = MethodCatalog.candidates(
            for: trigger, clinicNotes: input.clinicNotes, now: input.now
        )
        for note in candidates {
            // A clinic can suppress a Jeni default outright. It cannot
            // suppress its own — that would be authoring a hole.
            if !note.authority.isCareTeam,
               input.clinicSuppressedIds.contains(note.id) { continue }
            // Cooldown, and once-ever notes, both read the same ledger.
            if let shown = input.shownDaysAgoById[note.id],
               shown < note.cooldownDays { continue }
            // Suppression: words only, or nothing at all.
            let template = input.numericsSuppressed
                ? note.suppressedForm
                : note.noticed
            guard let template else { continue }
            guard let line = MethodNote.render(template, facts: facts) else { continue }
            let italic = input.numericsSuppressed
                ? []
                : note.noticedItalic.compactMap { MethodNote.render($0, facts: facts) }
            return ResolvedMethodNote(note: note, line: line, italic: italic)
        }
        return nil
    }

    // MARK: - Triggers
    //
    // Each returns the facts its notes may quote, or nil when the state
    // is not true. Returning facts and truth together is deliberate: a
    // trigger cannot fire without supplying the numbers that justify it.

    // swiftlint:disable:next cyclomatic_complexity
    private static func facts(
        for trigger: MethodTrigger, _ i: Input
    ) -> MethodFacts? {
        switch trigger {

        case .returnedAfterGap:
            guard i.daysSinceLastOpen >= gapDaysNeeded else { return nil }
            // Deliberately supplies NO number. The gap is never counted
            // out loud, so there is nothing for the note to quote.
            return [:]

        case .weightJumpedAgainstTrend:
            // The note's whole point is that the LINE disagrees with the
            // dot, so it needs a line. Without an established trend
            // there is no direction to name and nothing honest to say.
            guard i.trendIsEstablished else { return nil }
            guard let latest = i.latestWeightKg,
                  let previous = i.previousWeightKg,
                  let delta = i.emaDelta7dKg else { return nil }
            let jump = latest - previous
            guard jump >= scaleJumpKg else { return nil }
            // The line must actually disagree with the dot, or this note
            // would be telling her something false.
            guard delta <= 0 else { return nil }
            return [
                "jump": Self.kg(jump),
                "direction": delta < -0.05 ? "coming down" : "flat",
            ]

        case .fluidsOnAQueasyDay:
            // Her own logged symptom, named back to her in her own word
            // ("queasy", "loose stomach") — the gentle vocabulary the
            // logger uses, not a clinical one she never chose.
            guard let symptom = i.recentQueasySymptomWord else { return nil }
            return ["symptom": symptom]

        case .constipationWithLowFiber:
            guard i.loggedConstipationRecently else { return nil }
            // Her OWN fiber has to be the low half of the pair, or the
            // note is telling someone eating 35 g a day to eat more
            // fiber — which is how a note stops being believed.
            guard let fiber = i.recentFiberGPerDay, fiber < lowFiberGPerDay
            else { return nil }
            return ["fiber": "\(fiber)"]

        case .firstPlateOnFile:
            guard i.plateCountEver == 1 else { return nil }
            return [:]

        case .proteinFloorMetFirstTime:
            guard let floor = i.proteinFloorG, floor > 0,
                  i.proteinEatenTodayG >= floor else { return nil }
            // FIRST time, which means the state is a TRANSITION and not a
            // condition. Enforcing "once" through a 3,650-day cooldown
            // alone was the bug the tests found: a wiped ledger, or a
            // reinstall, would re-congratulate someone in her ninth week.
            guard !i.metProteinFloorBeforeToday else { return nil }
            return ["protein": "\(i.proteinEatenTodayG)"]

        case .trendJustReadable:
            // JUST readable. `>= threshold` is permanently true after the
            // third weigh-in, so it fired forever and outranked genuinely
            // urgent states — caught by the tests, which is exactly what
            // they are for. The crossing itself is the moment.
            guard i.trendIsEstablished,
                  i.weighInCount == weighInsForReadableTrend else { return nil }
            return [:]

        case .firstWeekClosing:
            guard (6...8).contains(i.programDay), i.plateCountEver > 0 else { return nil }
            return ["plates": "\(i.plateCountEver)"]

        case .enteringMaintenance:
            guard i.isMaintenancePhase else { return nil }
            return [:]

        case .lateInDoseWeek:
            guard i.doseCadenceIsWeekly,
                  let day = i.dayInDoseWeek,
                  lateDoseWeekDays.contains(day) else { return nil }
            // The adequacy net owns the very-light day with a gentler
            // line; never speak over it.
            guard !i.adequacyNetShowing else { return nil }
            return ["cycle_day": "\(day)"]

        case .proteinUnderFloorRepeatedly:
            guard let floor = i.proteinFloorG, floor > 0 else { return nil }
            guard !i.adequacyNetShowing else { return nil }
            // The evening close already speaks to TODAY's gap. This note
            // is about the week, so it stays out of the evening.
            guard i.hourOfDay < AppClock.eveningHour else { return nil }
            let window = Array(i.recentLoggedDayProteins.prefix(underFloorWindow))
            guard window.count >= underFloorDaysNeeded else { return nil }
            let under = window.filter { $0 < floor }.count
            guard under >= underFloorDaysNeeded else { return nil }
            return [
                "days": "\(under)", "window": "\(window.count)", "floor": "\(floor)",
            ]

        case .weekendRecordDisappears:
            // Needs a weekday habit to contrast with, and weekend days
            // that actually happened and are actually empty.
            let weekdayLogs = i.loggedDayOffsets.subtracting(i.weekendDayOffsets)
            guard weekdayLogs.count >= 3 else { return nil }
            guard !i.weekendDayOffsets.isEmpty else { return nil }
            let weekendLogs = i.loggedDayOffsets.intersection(i.weekendDayOffsets)
            guard weekendLogs.isEmpty else { return nil }
            return [:]

        case .losingWithoutResistanceWork:
            guard let delta = i.emaDelta7dKg,
                  delta <= -losingRateKgPerWeek,
                  i.daysOfWeightHistory >= 14,
                  i.strengthSessionsLast7 == 0 else { return nil }
            return [:]

        case .movementBelowOwnBaseline:
            guard let week = i.steps7dMean,
                  let baseline = i.steps28dMean,
                  // A baseline under 1,000 steps/day is a phone in a
                  // drawer, not a habit to compare against.
                  baseline >= 1_000,
                  i.stepHistoryDays >= movementBaselineDaysNeeded else { return nil }
            let ratio = Double(week) / Double(baseline)
            guard ratio <= movementDropRatio else { return nil }
            return ["pct": "\(Int((ratio * 100).rounded()))"]

        case .trendFlatWhileLogging:
            guard i.trendIsEstablished,
                  i.flatWeeks >= flatWeeksNeeded else { return nil }
            // A flat line with an empty record is an unlogged fortnight,
            // not a plateau. Calling it one would teach her something
            // false about her own body.
            guard i.loggedDayOffsets.count >= 5 else { return nil }
            return ["weeks": "\(i.flatWeeks)"]
        }
    }

    // MARK: - Formatting

    private static func kg(_ value: Double) -> String {
        // Never a fabricated precision: one decimal, which is what a
        // consumer scale reports.
        String(format: "%.1f kg", value)
    }
}

private extension MethodEngine.Input {
    /// Days of step history available. Derived rather than passed: the
    /// 28-day baseline is either filled or it is not, and a baseline
    /// built from three days is not a baseline.
    var stepHistoryDays: Int { steps28dMean == nil ? 0 : 28 }
}
