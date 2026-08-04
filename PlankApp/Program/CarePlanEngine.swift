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
        /// Mission 3 — a named win fired today (first down week etc.);
        /// the closing opens with the celebration.
        var isCelebrationDay: Bool = false
        /// v8 — today is her dose day (RegimenService anchor). The
        /// medication mark composes as the day's top line
        /// (CareProtocol.regimen.doseDayLeads) and survives gentle
        /// days — it is her own regimen's anchor, not an ask.
        var isDoseDay: Bool = false
        /// v8 — the early-titration support window is live; the
        /// hydration mark rides as an offered support.
        var titrationWindowActive: Bool = false
        /// v9 P1 — today is her scan day (anchor weekday, or the
        /// Sunday first-offer) and no scan is kept yet today. The
        /// invitation is offered — never debt, gone on gentle days.
        var isScanDay: Bool = false
        /// Whether any scan exists (the invitation's first-time line).
        var hasAnyScan: Bool = false
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

    /// Mission 3 (founder law): "completion should unlock reflection.
    /// recovery. celebration. preparation. there should always be
    /// something meaningful left." The closing acts are the day's
    /// second act — revealed when every actionable move is signed.
    enum CareAct: String, Equatable, CaseIterable {
        /// "close the day in one line" — the feeling + her words.
        case reflect
        /// "tomorrow, prepared" — the if-then tonight plan.
        case prepare
        /// "two quiet minutes" — the wind-down breath.
        case recover
        /// The named win, presented — pre-signed, a gift.
        case celebrate
    }

    struct Plan: Equatable {
        let tone: Tone
        /// The day's one thing. nil only when no day exists (not
        /// enrolled) — an enrolled day ALWAYS has a purpose
        /// (founder law: the checklist never disappears).
        let lead: Move?
        /// Ringed moves under the lead (≤2). Part of today's plan;
        /// count toward the day receipt.
        let supporting: [Move]
        /// Quiet invitations (no ring, never debt, never counted).
        let offered: [Move]
        /// The second act (founder law): what completion unlocks.
        /// Ordered; revealed by the view when the actionable moves
        /// are all signed. Never empty for an enrolled day.
        let closing: [CareAct]

        var actionableBeats: [ProgramDayPrescription] {
            (lead.map { [$0.beat] } ?? []) + supporting.map(\.beat)
        }
    }

    // MARK: - Compose

    static func compose(
        _ input: Input,
        careProtocol: CareProtocol = .default,
        voice: any BrandVoice = JeniVoice()
    ) -> Plan {
        guard let day = input.day else {
            return Plan(tone: .standard, lead: nil, supporting: [], offered: [], closing: [])
        }

        let tone = tone(for: input, careProtocol: careProtocol)
        let closing = closingActs(input, tone: tone)

        // The lead: the prescription's one-thing unless a care
        // promotion outranks it. An enrolled day ALWAYS leads with
        // something (founder law) — the breath is the floor ask.
        var lead: Move? = day.oneThing.map { Move(beat: $0) }
        if lead == nil {
            lead = Move(beat: .breath(minutes: 1, style: .calming))
        }
        if let promoted = promotedLead(input, day: day, careProtocol: careProtocol, voice: voice) {
            lead = promoted
        }

        // v8 — dose day: the medication mark is the day's top line
        // (first-class citizen; med + one keystone are the
        // non-negotiables, 01_RESEARCH §B8.1). The keystone the
        // prescription led with demotes to the first supporting row
        // so it stays part of the plan.
        var demotedKeystone: Move? = nil
        if input.isDoseDay, careProtocol.regimen.doseDayLeads {
            demotedKeystone = lead
            // The demoted food anchor keeps its reason under the
            // medication lead (every ringed row answers "why is
            // this here today" — founder refinement).
            if var keystone = demotedKeystone, keystone.because == nil,
               case .snapMeal = keystone.beat {
                let line = voice.keystoneProteinAnchor()
                keystone.because = line.text
                keystone.becauseItalic = line.italics
                demotedKeystone = keystone
            }
            let line = voice.doseDay()
            lead = Move(beat: .medication, because: line.text, becauseItalic: line.italics)
        }

        // Gentle days are one move, spoken softly, and nothing else.
        // A gentle dose day composes to the medication mark alone —
        // the dose IS the whole plan.
        if tone == .gentle {
            if var g = lead {
                if g.because == nil, let line = gentleBecause(input, careProtocol: careProtocol, voice: voice) {
                    g.because = line.text
                    g.becauseItalic = line.italics
                }
                return Plan(tone: .gentle, lead: g, supporting: [], offered: [], closing: closing)
            }
            return Plan(tone: .gentle, lead: nil, supporting: [], offered: [], closing: closing)
        }

        // Supporting: the demoted dose-day keystone first, then the
        // weigh-in when today carries one (cadence or stale) — 30
        // seconds, part of the plan. Workouts stay invitations
        // unless they lead.
        var supporting: [Move] = []
        if let demotedKeystone,
           demotedKeystone.beat.itemKey != lead?.beat.itemKey {
            supporting.append(demotedKeystone)
        }
        for beat in day.beats where beat.itemKey != lead?.beat.itemKey {
            if case .weighIn = beat {
                let line = input.weighInIsStale
                    ? voice.weighInStale()
                    : voice.weighInCadence(keeping: input.chapter == .keeping)
                supporting.append(Move(
                    beat: beat, because: line.text, becauseItalic: line.italics
                ))
            }
        }
        supporting = Array(supporting.prefix(careProtocol.composition.maxSupportingMoves))

        // Offered: quiet invitations. Hydration leads them during
        // the titration window (fluids sit easier than food in the
        // escalation weeks — 04_CLINICAL_CHECKLIST §1.5); then the
        // scheduled workout, then breath; the method only on a
        // calm, fully-standard day (pull-grammar — a read, never
        // homework).
        var offered: [Move] = []
        if input.titrationWindowActive, careProtocol.regimen.hydrationDuringTitration {
            let line = voice.hydrationTitration()
            offered.append(Move(
                beat: .water(ml: careProtocol.regimen.hydrationMlDuringTitration),
                because: line.text,
                becauseItalic: line.italics
            ))
        }
        // v9 P1 — the weekly scan invitation rides scan day (after
        // hydration's clinical priority, ahead of movement). Gone on
        // gentle days with the rest of the offers, by construction.
        if input.isScanDay {
            let line = voice.bodyScanInvitation(first: !input.hasAnyScan)
            offered.append(Move(
                beat: .bodyScan,
                because: line.text,
                becauseItalic: line.italics
            ))
        }
        for beat in day.beats where beat.itemKey != lead?.beat.itemKey {
            if case .workout = beat { offered.append(Move(beat: beat)) }
        }
        for beat in day.beats where beat.itemKey != lead?.beat.itemKey {
            if case .breath = beat { offered.append(Move(beat: beat)) }
        }
        if offered.count < careProtocol.composition.maxOfferedMoves, supporting.isEmpty,
           let lessonBeat = day.beats.first(where: {
               if case .lesson = $0 { return $0.itemKey != lead?.beat.itemKey }
               return false
           }) {
            offered.append(Move(beat: lessonBeat))
        }
        offered = Array(offered.prefix(careProtocol.composition.maxOfferedMoves))

        return Plan(
            tone: .standard, lead: lead, supporting: supporting,
            offered: offered, closing: closing
        )
    }

    /// The second act, composed by tone: a celebration leads when a
    /// named win fired; every day closes in one line; standard days
    /// prepare tomorrow, gentle days wind down instead.
    private static func closingActs(_ input: Input, tone: Tone) -> [CareAct] {
        var acts: [CareAct] = []
        if input.isCelebrationDay { acts.append(.celebrate) }
        acts.append(.reflect)
        acts.append(tone == .gentle ? .recover : .prepare)
        return acts
    }

    // MARK: - Tone

    private static func tone(for input: Input, careProtocol: CareProtocol) -> Tone {
        if input.yesterdayFeeling == "tender" { return .gentle }
        if let sleep = input.sleepHoursLastNight,
           sleep < careProtocol.composition.shortNightHours { return .gentle }
        if input.daysSinceLastOpen >= careProtocol.composition.gentleReturnDays { return .gentle }
        return .standard
    }

    /// The gentle lead's reason when no promotion supplied one.
    /// Speaks only facts the inputs hold; the words are the
    /// voice layer's (rules/voice split).
    private static func gentleBecause(
        _ input: Input, careProtocol: CareProtocol, voice: any BrandVoice
    ) -> VoiceLine? {
        if input.yesterdayFeeling == "tender" {
            return voice.gentleTender()
        }
        if let sleep = input.sleepHoursLastNight,
           sleep < careProtocol.composition.shortNightHours {
            let h = Int(sleep)
            let m = Int((sleep - Double(h)) * 60)
            return voice.gentleShortNight(hours: h, minutes: m)
        }
        if input.daysSinceLastOpen >= careProtocol.composition.gentleReturnDays {
            return voice.gentleReturn(daysAway: input.daysSinceLastOpen)
        }
        return nil
    }

    // MARK: - Lead promotions (clinical priority, top first)

    private static func promotedLead(
        _ input: Input,
        day: PrescriptionEngineV2.Day,
        careProtocol: CareProtocol,
        voice: any BrandVoice
    ) -> Move? {
        guard let snap = day.beats.first(where: {
            if case .snapMeal = $0 { return true } else { return false }
        }) else { return nil }

        // 1 — sustained rapid loss: protein protects muscle. The
        //     tripwire's daily echo (the reading carries the full
        //     line; the plan repeats the move, not the alarm).
        if input.trendIsEstablished,
           let rate = input.lossRatePctPerWeek,
           rate > careProtocol.composition.rapidLossRatePctPerWeek {
            let line = voice.rapidLossProteinFirst()
            return Move(beat: snap, because: line.text, becauseItalic: line.italics)
        }

        // 2 — yesterday's protein landed well under the floor (real
        //     logged day only — assembler guarantees provenance).
        if let y = input.yesterdayProteinG,
           let target = input.proteinTargetG,
           target - y >= careProtocol.composition.proteinDeficitPromoteG {
            let line = voice.proteinDeficit(gapG: target - y)
            return Move(beat: snap, because: line.text, becauseItalic: line.italics)
        }

        return nil
    }
}
