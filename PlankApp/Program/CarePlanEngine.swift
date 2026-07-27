import Foundation

// MARK: - CarePlanEngine
//
// App v7 (docs/app_v7/00_THESIS.md §4). The day's composer: the
// static prescription (PrescriptionEngineV2) still supplies the
// beat vocabulary and the schedule floor, but WHICH beats render,
// in what order, with what reason, and at what volume is decided
// here — from her actual state, the way CoachSummary already
// decides the week's one move.
//
// Laws:
//   - Pure + deterministic: same Input → same Plan. No I/O.
//   - Provenance: a `because` clause exists only when the fields
//     behind it are live. Absent data = absent clause, never a
//     default. The assembler leaves fields nil when unknown.
//   - ≤3 actionable moves. Gentle days compose to ONE and drop
//     every invitation — care is sometimes fewer asks, by rule.
//   - Observations are never moves: steps, the overnight window,
//     sleep are receipts (rendered elsewhere), not tasks.
//   - The method is never required (v7 verdict: trigger-matched,
//     pull-only). It may be offered on calm days.
//   - Workouts are offered, not owed (v6.4 founder law), unless
//     the archetype made one the day's lead.

enum CarePlanEngine {

    // MARK: - Input

    /// Everything compose may read. Assembled by TodayStateService
    /// from stores it already opens; every optional stays nil when
    /// the data doesn't exist (provenance rule).
    struct Input: Equatable {
        var day: PrescriptionEngineV2.Day?
        var chapter: Chapter = .losing
        var programDay: Int = 1
        /// Yesterday's evening chip ("proud" / "okay" / "tender"),
        /// when she gave one.
        var yesterdayFeeling: String? = nil
        /// Last night's asleep hours (HealthKit; nil = no data).
        var sleepHoursLastNight: Double? = nil
        /// Calendar days since she last opened the app. 0 = today.
        var daysSinceLastOpen: Int = 0
        /// Yesterday's protein, ONLY when yesterday had 2+ logged
        /// plates (an unlogged day is absence, not deficit).
        var yesterdayProteinG: Int? = nil
        var proteinTargetG: Int? = nil
        /// Sustained loss rate as a FRACTION per week (0.01 = 1%/wk,
        /// matching DailyBriefEngine.Context), only when computable.
        var lossRatePctPerWeek: Double? = nil
        var trendIsEstablished: Bool = false
        /// True when today's weigh-in exists only because the last
        /// log went stale (copy softens).
        var weighInIsStale: Bool = false
    }

    // MARK: - Output

    enum Tone: Equatable {
        /// The standard day: lead + up to two supporting + offers.
        case standard
        /// One move, zero invitations. Composed after a tender
        /// evening, a short night, or a return from days away.
        case gentle
    }

    struct Move: Equatable {
        let beat: ProgramDayPrescription
        /// The spoken reason, direct register, provenance-backed.
        /// nil = the view's standard copy carries the row.
        var because: String? = nil
        var becauseItalic: [String] = []
    }

    struct Plan: Equatable {
        let tone: Tone
        /// The day's one thing. nil on rest/permission days — the
        /// view renders the permission card.
        let lead: Move?
        /// Ringed moves under the lead (≤2). Part of today's plan;
        /// count toward the day receipt.
        let supporting: [Move]
        /// Quiet invitations (no ring, never debt, never counted).
        let offered: [Move]

        var actionableBeats: [ProgramDayPrescription] {
            (lead.map { [$0.beat] } ?? []) + supporting.map(\.beat)
        }
    }

    // MARK: - Compose

    static func compose(_ input: Input) -> Plan {
        guard let day = input.day else {
            return Plan(tone: .standard, lead: nil, supporting: [], offered: [])
        }

        let tone = tone(for: input)

        // The lead: the prescription's one-thing unless a care
        // promotion outranks it.
        var lead: Move? = day.oneThing.map { Move(beat: $0) }
        if let promoted = promotedLead(input, day: day) {
            lead = promoted
        }

        // Gentle days are one move, spoken softly, and nothing else.
        if tone == .gentle {
            if var g = lead {
                if g.because == nil {
                    g.because = gentleBecause(input)
                }
                return Plan(tone: .gentle, lead: g, supporting: [], offered: [])
            }
            return Plan(tone: .gentle, lead: nil, supporting: [], offered: [])
        }

        // Supporting: the weigh-in when today carries one (cadence
        // or stale) — 30 seconds, part of the plan. Workouts stay
        // invitations unless they lead.
        var supporting: [Move] = []
        for beat in day.beats where beat.itemKey != lead?.beat.itemKey {
            if case .weighIn = beat {
                supporting.append(Move(
                    beat: beat,
                    because: input.weighInIsStale ? "first one in a while" : nil
                ))
            }
        }
        supporting = Array(supporting.prefix(2))

        // Offered: quiet invitations. The scheduled workout first,
        // then breath; the method only on a calm, fully-standard
        // day (pull-grammar — a read, never homework).
        var offered: [Move] = []
        for beat in day.beats where beat.itemKey != lead?.beat.itemKey {
            if case .workout = beat { offered.append(Move(beat: beat)) }
        }
        for beat in day.beats where beat.itemKey != lead?.beat.itemKey {
            if case .breath = beat { offered.append(Move(beat: beat)) }
        }
        if offered.count < 2, supporting.isEmpty,
           let lessonBeat = day.beats.first(where: {
               if case .lesson = $0 { return $0.itemKey != lead?.beat.itemKey }
               return false
           }) {
            offered.append(Move(beat: lessonBeat))
        }
        offered = Array(offered.prefix(2))

        return Plan(tone: .standard, lead: lead, supporting: supporting, offered: offered)
    }

    // MARK: - Tone

    private static func tone(for input: Input) -> Tone {
        if input.yesterdayFeeling == "tender" { return .gentle }
        if let sleep = input.sleepHoursLastNight, sleep < 6 { return .gentle }
        if input.daysSinceLastOpen >= 4 { return .gentle }
        return .standard
    }

    /// The gentle lead's reason when no promotion supplied one.
    /// Speaks only facts the inputs hold.
    private static func gentleBecause(_ input: Input) -> String? {
        if input.yesterdayFeeling == "tender" {
            return "yesterday read tender. just this, nothing else"
        }
        if let sleep = input.sleepHoursLastNight, sleep < 6 {
            let h = Int(sleep)
            let m = Int((sleep - Double(h)) * 60)
            return "short night (\(h)h \(String(format: "%02d", m))m). one thing is the whole plan"
        }
        if input.daysSinceLastOpen >= 4 {
            return "back after \(input.daysSinceLastOpen) days. one small thing restarts it"
        }
        return nil
    }

    // MARK: - Lead promotions (clinical priority, top first)

    private static func promotedLead(
        _ input: Input, day: PrescriptionEngineV2.Day
    ) -> Move? {
        guard let snap = day.beats.first(where: {
            if case .snapMeal = $0 { return true } else { return false }
        }) else { return nil }

        // 1 — sustained rapid loss: protein protects muscle. The
        //     tripwire's daily echo (the reading carries the full
        //     line; the plan repeats the move, not the alarm).
        if input.trendIsEstablished,
           let rate = input.lossRatePctPerWeek, rate > 0.01 {
            return Move(
                beat: snap,
                because: "losing fast. protein first protects muscle",
                becauseItalic: ["protein first"]
            )
        }

        // 2 — yesterday's protein landed well under the floor (real
        //     logged day only — assembler guarantees provenance).
        if let y = input.yesterdayProteinG,
           let target = input.proteinTargetG,
           target - y >= 25 {
            return Move(
                beat: snap,
                because: "yesterday landed \(target - y)g under your protein floor",
                becauseItalic: []
            )
        }

        return nil
    }
}
