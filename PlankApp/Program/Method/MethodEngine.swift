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
        /// p55 — lightheadedness logged inside the same window. Beside
        /// a GI-loss symptom it is the labels' own volume-depletion
        /// warning sign, and the routing note reads the pair.
        var recentDizzyLogged: Bool = false
        /// Constipation logged inside `constipationRecencyDays`.
        var loggedConstipationRecently: Bool = false
        /// Mean fiber across her recent LOGGED days, or nil when there
        /// are not enough of them. Absent rather than zero: a day with
        /// no plates is not a no-fiber day.
        var recentFiberGPerDay: Int? = nil

        // ── medication ──
        /// Where she is between doses, event-anchored to her last
        /// actual injection (E2, generalized to intervals in p53).
        /// BOTH present or BOTH absent, by the engine's own law:
        /// `cyclePosition` returns nil for daily, as-needed and split
        /// rhythms, so an invalid "day without a rhythm" cannot be
        /// constructed here. p54 — the pair replaced a weekly-only
        /// boolean that pass 53's interval rhythms had silently made
        /// a lie ("not daily" is not "weekly").
        var doseCycleDay: Int? = nil
        var doseCycleLength: Int? = nil
        /// p54 — her self-managed medication plan was deliberately
        /// ended this many days ago (endReason "ended", no successor
        /// plan). nil when nothing ended, when it was merely paused,
        /// when a new plan exists, or when a care team owns the plan.
        var selfMedicationEndedDaysAgo: Int? = nil

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
        /// p53 — the note already shown TODAY, if one was. The day's
        /// note is THE day's note: re-opening the door re-renders it
        /// rather than falling through the cooldown to a second,
        /// different note (the one-per-day design, finally enforced).
        var shownTodayNoteId: String? = nil
        /// p53 — recent logged days (≤7) that MISSED the floor while
        /// their before-noon protein was near zero (the breakfast gap).
        var morningLowProteinDays: Int = 0
        /// p53 — mean floor shortfall on those days, her own number.
        var typicalDayGapG: Int? = nil
        /// p53 — yesterday's sodium total, when plates carried one.
        var yesterdaySodiumMg: Int? = nil
        /// p54 — how many PRIOR times her own record has paired a
        /// salty day with a next-morning bump (today's pairing not
        /// counted). At 2+ the note may speak the pattern as HERS —
        /// the N-of-1 layer: population evidence says "often", her
        /// record says "the third time".
        var saltyBumpPriorInstances: Int = 0
        /// p54 — CycleSignal's read is `.menstrual` (first days of
        /// flow, from HER OWN recorded starts, after the irregularity
        /// stand-downs). false when the signal is unreliable — an
        /// unreliable cycle produces silence, never a guess.
        var cycleSeasonIsMenstrual: Bool = false
        /// p53 — days since the latest weigh-in (0 = today).
        var lastWeighInDaysAgo: Int? = nil
        /// p54 — her display unit. The bump notes quoted "up 0.6 kg"
        /// at lb users since E8.1 (the film caught it; no test looked
        /// at the unit): the engine is pure, so the unit is an input,
        /// and the v5 law — the story speaks HER unit — finally
        /// reaches the Method.
        var weightUnitIsLb: Bool = false
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
    /// p54 — how long after a deliberate end the transition note may
    /// still speak. Past a month the moment has passed; the note does
    /// not haunt.
    static let endedNoteWindowDays = 28
    /// Her own movement, as a fraction of her own baseline.
    static let movementDropRatio = 0.6
    static let movementBaselineDaysNeeded = 14
    /// A real rate of loss, kg/week, before pairing protein with
    /// loading becomes the point.
    static let losingRateKgPerWeek = 0.3
    /// p55 — the "just readable" window. The old gate was
    /// `weighInCount == 3`, fed by a mislabeled input (fast-fold
    /// POINTS, not weigh-ins) — and even correctly counted, a band
    /// needs ≥4 obs spanning ≥14 d, so `== 3 && established` was
    /// unsatisfiable and the note could never fire. The crossing is
    /// a moment in TIME: the band exists while the whole record is
    /// still young. Daily and sparse weighers both cross inside
    /// three weeks; a reinstalled rich record (months of history)
    /// skips the note honestly; the 3650-day cooldown holds it to
    /// once ever.
    static let trendJustReadableWindowDays = 21
    /// v25 E9 — how recently a GI symptom still describes today. Two
    /// days for the fluid note (the label's window is the episode
    /// itself), three for constipation (it does not resolve overnight).
    static let queasyRecencyDays = 2
    static let constipationRecencyDays = 3
    /// p53 — a day whose plates carried at least this much sodium is
    /// a salty day (the FDA DV is 2,300 mg; the note only speaks
    /// comfortably past it, never at the margin).
    static let saltyDayMg = 2800
    /// p54 — the next-morning rise that counts as a bump worth
    /// explaining, shared by the salty trigger, the cycle trigger and
    /// the N-of-1 instance counter, so "the third time" counts the
    /// same thing the notes fire on.
    static let bumpWorthExplainingKg = 0.4
    /// Fiber below which "add something with fiber" is worth saying.
    /// The published FDA Daily Value is 28 g; this sits well under it so
    /// the note cannot fire on someone already doing the thing.
    static let lowFiberGPerDay = 18

    // MARK: - Priority
    //
    // At most ONE note. When several states are true the most
    // time-critical wins, because the others will still be true
    // tomorrow and this one may not.

    /// Internal (not private) since p54: the priority ORDER is pinned
    /// by `MethodSpineTests` — a trigger absent from this list can
    /// never fire, and a silent reorder is a behavior change.
    static let priority: [MethodTrigger] = [
        // she is here right now after being away: nothing else matters
        .returnedAfterGap,
        // p55 — the ROUTING note outranks the teaching below it: a
        // lightheaded day beside a GI-loss day is the labels' own
        // volume-depletion warning sign, and "tell your prescriber"
        // must never lose to "sip fluids".
        .dizzyOnAFluidLossDay,
        // v25 E9 — a body that is losing fluid outranks every teaching
        // below it. It is
        // true for a day or two at most.
        .fluidsOnAQueasyDay,
        // a frightened morning, answerable only today — the specific
        // explanation outranks the generic one, and yesterday's salt is
        // more specific than a cycle phase that lasts days (p53/p54)
        .saltyDinnerScaleBump,
        .mensesOnsetScaleBump,
        .weightJumpedAgainstTrend,
        // a plan she ended: true for weeks, but the first days after
        // are when the support lands, so it sits above the transitions
        .medicationRecentlyEnded,
        // transitions, at the only moment they are true
        .firstPlateOnFile,
        .proteinFloorMetFirstTime,
        .trendJustReadable,
        .firstWeekClosing,
        // patterns, which keep
        .constipationWithLowFiber,
        .lateInDoseWeek,
        // the breakfast gap locates what the floor note only counts,
        // so it goes first (p53)
        .morningProteinGap,
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
    ///
    /// p53 — ONE NOTE PER DAY, enforced: once a note has been shown
    /// today, re-opening the door re-renders THAT note (its cooldown
    /// starts tomorrow); it never falls through to a second, different
    /// teaching. If today's note can no longer render (its facts
    /// moved), the answer is silence, not a substitute.
    static func note(_ input: Input) -> ResolvedMethodNote? {
        if let todayId = input.shownTodayNoteId {
            for trigger in priority {
                guard let facts = facts(for: trigger, input) else { continue }
                let candidates = MethodCatalog.candidates(
                    for: trigger, clinicNotes: input.clinicNotes, now: input.now
                )
                guard let note = candidates.first(where: { $0.id == todayId })
                else { continue }
                return render(note, facts: facts, input: input)
            }
            return nil
        }
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
            guard let resolved = render(note, facts: facts, input: input)
            else { continue }
            return resolved
        }
        return nil
    }

    /// Suppression-aware rendering of one candidate (p53 — shared by
    /// the fresh pick and the same-day re-render).
    private static func render(
        _ note: MethodNote, facts: MethodFacts, input: Input
    ) -> ResolvedMethodNote? {
        let template = input.numericsSuppressed
            ? note.suppressedForm
            : note.noticed
        guard let template else { return nil }
        guard let line = MethodNote.render(template, facts: facts) else { return nil }
        let italic = input.numericsSuppressed
            ? []
            : note.noticedItalic.compactMap { MethodNote.render($0, facts: facts) }
        return ResolvedMethodNote(
            note: note, line: line, italic: italic,
            // p54 — evidence lines carry population numerals; under
            // suppression the words-only law covers them too.
            evidenceLine: input.numericsSuppressed ? nil : note.evidence
        )
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
                "jump": Self.weightDelta(jump, lb: i.weightUnitIsLb),
                "direction": delta < -0.05 ? "coming down" : "flat",
            ]

        case .dizzyOnAFluidLossDay:
            // p55 — BOTH halves, her own record: lightheadedness AND a
            // GI-loss symptom inside the same recency window. Dizzy
            // alone has too many ordinary causes; the GI half alone is
            // the teaching below. NO adequacy-net stand-down — a
            // routing note is not a teaching, and the label's warning
            // outranks the one-voice law.
            guard i.recentDizzyLogged,
                  let symptom = i.recentQueasySymptomWord else { return nil }
            return ["gi_symptom": symptom]

        case .fluidsOnAQueasyDay:
            // Her own logged symptom, named back to her in her own word
            // ("queasy", "loose stomach") — the gentle vocabulary the
            // logger uses, not a clinical one she never chose.
            // p53 — the catalog promised "never fires on a day the
            // adequacy net is already speaking" and nothing enforced
            // it; two prompts about one hard day is the pile-on this
            // cohort must not get.
            guard !i.adequacyNetShowing else { return nil }
            guard let symptom = i.recentQueasySymptomWord else { return nil }
            return ["symptom": symptom]

        case .morningProteinGap:
            // p53 — the gap has an address. Several recent logged days
            // missed the floor with near-empty mornings; the number is
            // the mean shortfall of HER OWN missed days.
            guard i.proteinFloorG ?? 0 > 0 else { return nil }
            guard !i.adequacyNetShowing else { return nil }
            guard i.hourOfDay < AppClock.eveningHour else { return nil }
            guard i.morningLowProteinDays >= 3,
                  let gap = i.typicalDayGapG, gap >= 10 else { return nil }
            return ["gap": "\(gap)"]

        case .saltyDinnerScaleBump:
            // p53 — a bump the morning after a salty day, named as
            // fluid before it reads as failure. Facts only: yesterday's
            // sodium ON FILE, a weigh-in THIS morning, and a trend that
            // is not clearly rising (else the reassurance could hide a
            // real change).
            guard !i.adequacyNetShowing else { return nil }
            guard let sodium = i.yesterdaySodiumMg, sodium >= saltyDayMg
            else { return nil }
            guard i.lastWeighInDaysAgo == 0,
                  let latest = i.latestWeightKg,
                  let previous = i.previousWeightKg else { return nil }
            let bump = latest - previous
            guard bump >= bumpWorthExplainingKg else { return nil }
            guard (i.emaDelta7dKg ?? 0) <= 0.1 else { return nil }
            var facts: MethodFacts = [
                "bump": Self.weightDelta(bump, lb: i.weightUnitIsLb),
            ]
            // p54 — the N-of-1 layer: at 2+ PRIOR pairings the record
            // itself owns the claim, and the pattern note (which needs
            // the {nth} token) becomes renderable. Below that the
            // token is absent, the pattern note drops, and the base
            // note speaks the population mechanism instead.
            if i.saltyBumpPriorInstances >= 2,
               let nth = Self.ordinalWord(i.saltyBumpPriorInstances + 1) {
                facts["nth"] = nth
            }
            return facts

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
            // JUST readable — the crossing itself is the moment (the
            // once-ever cooldown holds it to one firing; the window
            // keeps a reinstalled rich record from being congratulated
            // on a line it has had for months).
            guard i.trendIsEstablished,
                  i.daysOfWeightHistory <= trendJustReadableWindowDays
            else { return nil }
            return [:]

        case .firstWeekClosing:
            guard (6...8).contains(i.programDay), i.plateCountEver > 0 else { return nil }
            return ["plates": "\(i.plateCountEver)"]

        case .enteringMaintenance:
            guard i.isMaintenancePhase else { return nil }
            return [:]

        case .lateInDoseWeek:
            // p54 — the gate is the schedule engine's OWN band law
            // (edge = ceil(2·length/7): waning is 6-7 of a week, 8-10
            // of a ten-day rhythm), replacing a hardcoded 5...7 that
            // pass 53's interval rhythms had quietly made wrong in
            // both directions — "the hungry end" mid-cycle, silence
            // when the end actually arrived. One authority; the
            // Method never re-derives the arc.
            guard let day = i.doseCycleDay, let length = i.doseCycleLength
            else { return nil }
            let position = MedicationScheduleEngine.CyclePosition(
                day: day, length: length, basis: .takenDose
            )
            guard position.band == .waning else { return nil }
            // The adequacy net owns the very-light day with a gentler
            // line; never speak over it.
            guard !i.adequacyNetShowing else { return nil }
            return [
                "cycle_day": "\(day)",
                "cycle_word": length == 7
                    ? "your dose week" : "your \(length)-day rhythm",
            ]

        case .mensesOnsetScaleBump:
            // p54 — the cycle explanation for a frightening morning.
            // Fires only from HER OWN recorded starts (the flag is
            // false whenever CycleSignal's irregularity stand-downs
            // refuse a phase), only on a real same-morning bump, and
            // never against a clearly rising trend — reassurance must
            // not hide a real change. Salt outranks it by priority:
            // yesterday's dinner is the more specific fact.
            guard !i.adequacyNetShowing else { return nil }
            guard i.cycleSeasonIsMenstrual else { return nil }
            guard i.lastWeighInDaysAgo == 0,
                  let latest = i.latestWeightKg,
                  let previous = i.previousWeightKg else { return nil }
            let bump = latest - previous
            guard bump >= bumpWorthExplainingKg else { return nil }
            guard (i.emaDelta7dKg ?? 0) <= 0.1 else { return nil }
            return ["bump": Self.weightDelta(bump, lb: i.weightUnitIsLb)]

        case .medicationRecentlyEnded:
            // p54 — a deliberate end, recently. The builder already
            // filtered pauses, era changes, care-team plans and any
            // active successor into nil; the engine adds only the
            // window. No number is supplied: the days since are never
            // counted out loud.
            guard let ended = i.selfMedicationEndedDaysAgo,
                  ended <= endedNoteWindowDays else { return nil }
            return [:]

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

    /// One decimal — what a consumer scale reports — in HER unit.
    static func weightDelta(_ kg: Double, lb: Bool) -> String {
        lb
            ? String(format: "%.1f lb", kg * 2.20462)
            : String(format: "%.1f kg", kg)
    }

    /// p54 — the pattern note counts occurrences in words, never
    /// digits ("the third time", not "3x"). Beyond "sixth" a wrong
    /// ordinal would be a small lie, so the word runs out, the token
    /// stays unfilled, and the BASE note fires instead — the pattern
    /// was already taught by then.
    static func ordinalWord(_ n: Int) -> String? {
        switch n {
        case 3: return "third"
        case 4: return "fourth"
        case 5: return "fifth"
        case 6: return "sixth"
        default: return nil
        }
    }
}

private extension MethodEngine.Input {
    /// Days of step history available. Derived rather than passed: the
    /// 28-day baseline is either filled or it is not, and a baseline
    /// built from three days is not a baseline.
    var stepHistoryDays: Int { steps28dMean == nil ? 0 : 28 }
}
