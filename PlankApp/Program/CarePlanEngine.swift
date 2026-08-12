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
        /// v24 — the regimen's cadence is DAILY (a pill, a daily
        /// injectable). A weekly shot is an event and LEADS its
        /// day; a daily dose is a rhythm and rides as a quiet
        /// supporting row — leading every single day would let
        /// medication dominate the product (the founder's floor).
        /// Gentle days keep the v8 law either way: the dose IS the
        /// plan.
        var doseCadenceIsDaily: Bool = false
        /// v24 — the route is oral (the row + sheet speak "pill").
        var doseRouteIsOral: Bool = false
        /// v8 — the early-titration support window is live; the
        /// hydration mark rides as an offered support.
        var titrationWindowActive: Bool = false
        /// v9 P1 — today is her scan day (anchor weekday, or the
        /// Sunday first-offer) and no scan is kept yet today. The
        /// invitation is offered — never debt, gone on gentle days.
        var isScanDay: Bool = false
        /// Whether any scan exists (the invitation's first-time line).
        var hasAnyScan: Bool = false
        /// v9 P4 — the body-outcome axis (BodyStateService/P3's
        /// preservation ladder): the WEEK ran the muscle-loss
        /// pattern (fast loss + protein under across ≥4 logged
        /// days) — outranks a single yesterday's deficit.
        var preservationAtRisk: Bool = false
        /// v9 P4 — the trend has been flat ≥14 days (WeightAnalytics
        /// stall floor). Reaches the lead's REASON as support —
        /// never a push, never a new ask.
        var isPlateauWeek: Bool = false
        /// v25 E1 — the walking action's facts (nil = no walk ever
        /// composes; the assembler supplies them only when the
        /// program owns an adaptive goal). Steps counted so far
        /// today (HealthKit).
        var stepsToday: Int? = nil
        /// The program's step goal (fact-resolved via TargetsService).
        var stepGoal: Int? = nil
        /// v25 E8 (founder steer: "in to-do list you always need to see
        /// step as to do item"). The goal INCLUDING the app's default
        /// anchor, so a standing steps row can render for someone who
        /// never consented to an adaptive goal. Distinct from
        /// `stepGoal`, which stays the consent-gated adaptive fact that
        /// E1's walking ASK is allowed to act on.
        var resolvedStepGoal: Int? = nil
        /// Local hour of day — the walk is an afternoon ask (≥14)
        /// unless a meal just made it timely.
        var hourOfDay: Int = 12
        /// An external workout (HealthKit-written, ≥10 min) already
        /// happened today — movement is absorbed, never re-asked.
        var externalWorkoutToday: Bool = false
        /// A substantial plate landed 60-120 min ago — the post-meal
        /// window (the walk's reason adapts; the hour gate lifts).
        var largeMealLoggedRecently: Bool = false
        /// The walkTiming fact's word ("afterMeals" | "anytime" |
        /// "off"); nil reads as "anytime".
        var walkTimingWord: String? = nil
        /// v25 E2 — where she is in her dose week (1…7, weekly
        /// injectors, honest positions only; nil = no cycle exists
        /// or none can honestly be claimed). The same beats compose
        /// with the cycle in mind — new copy, never new rows.
        var dayInDoseWeek: Int? = nil
        /// v25 E2 — a PAST weekly slot is still open (inside its
        /// late window, unresolved), expressed as the slot's
        /// weekday word ("tuesday"). The dose row returns as a
        /// support with the late door's language.
        var openLateSlotWeekday: String? = nil
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
        /// v9 P4 — true when a clinical promotion chose the lead
        /// (the view marks it with the dose-dot). Always false on
        /// dose days (medication never wears ornament) and gentle
        /// days (one quiet move, unadorned).
        var leadIsPromoted: Bool = false
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
        var leadIsPromoted = false
        if let promoted = promotedLead(input, day: day, careProtocol: careProtocol, voice: voice) {
            lead = promoted
            leadIsPromoted = true
        }

        // v8 — dose day: the medication mark is the day's top line
        // (first-class citizen; med + one keystone are the
        // non-negotiables, 01_RESEARCH §B8.1). The keystone the
        // prescription led with demotes to the first supporting row
        // so it stays part of the plan.
        var demotedKeystone: Move? = nil
        if input.isDoseDay, careProtocol.regimen.doseDayLeads,
           !input.doseCadenceIsDaily {
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
            leadIsPromoted = false   // medication never wears ornament
        }

        // v24 — a DAILY dose is a rhythm, not an event: it never
        // takes the lead on a standard day (medication must not
        // dominate a product that composes every single day around
        // it). It rides first among the supporting rows instead.
        // On GENTLE days the v8 law holds for every cadence — the
        // dose is the whole plan.
        var dailyDoseMove: Move? = nil
        if input.isDoseDay, input.doseCadenceIsDaily {
            let line = voice.dailyDose(oral: input.doseRouteIsOral)
            dailyDoseMove = Move(
                beat: .medication, because: line.text, becauseItalic: line.italics
            )
            if tone == .gentle {
                lead = dailyDoseMove
                leadIsPromoted = false
            }
        }

        // v9 P4 — the plateau week reaches the lead's REASON as
        // support (Linde 2004: the unaddressed plateau is the
        // dropout path). Only when nothing clinical promoted, never
        // on dose days, never over an existing reason.
        if !leadIsPromoted, !input.isDoseDay, input.isPlateauWeek,
           var held = lead, held.because == nil {
            let line = voice.plateauHold()
            held.because = line.text
            held.becauseItalic = line.italics
            lead = held
        }

        // v25 E2 — LATE CYCLE: the return of appetite is named
        // before she feels it as failure (08_E2 behavior loop).
        // Same beat, new reason — only the food lead, only when
        // nothing clinical or plateau already spoke, never a
        // prediction ("often" is the register).
        if !leadIsPromoted, !input.isDoseDay,
           let cycleDay = input.dayInDoseWeek, cycleDay >= 6,
           var meal = lead, meal.because == nil,
           case .snapMeal = meal.beat {
            let line = voice.lateCycleAppetite()
            meal.because = line.text
            meal.becauseItalic = line.italics
            lead = meal
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
                // Gentle days stay unadorned — one quiet move.
                return Plan(tone: .gentle, lead: g, supporting: [], offered: [], closing: closing)
            }
            return Plan(tone: .gentle, lead: nil, supporting: [], offered: [], closing: closing)
        }

        // Supporting: the demoted dose-day keystone first, then the
        // weigh-in when today carries one (cadence or stale) — 30
        // seconds, part of the plan. Workouts stay invitations
        // unless they lead.
        var supporting: [Move] = []
        // v25 E2 — an OPEN LATE SLOT brings the dose row back as
        // the first support ("tuesday's dose is still open") — the
        // late window finally has an in-app door, inside the cap
        // (it is a real ask, and it exists only between cycles so
        // it never collides with a due dose day).
        if !input.isDoseDay, !input.doseCadenceIsDaily,
           let weekday = input.openLateSlotWeekday {
            let line = voice.lateSlotOpen(weekdayWord: weekday)
            supporting.append(Move(
                beat: .medication,
                because: line.text, becauseItalic: line.italics
            ))
        }
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

        // v25 E1 — THE WALKING ACTION (docs/app_v25/05_E1_SPINE §3;
        // decision D5: the gap against the program's OWNED adaptive
        // goal is an ask — the raw prescription .steps beat still
        // never promotes). A behavioral support INSIDE the cap (it
        // yields on full dose days); absorbed by any external
        // workout; an afternoon ask unless a settling meal makes it
        // timely; never composed when the gap is absurd or the goal
        // is already crossed.
        if input.walkTimingWord != "off",
           !input.externalWorkoutToday,
           let goal = input.stepGoal, goal > 0,
           let steps = input.stepsToday {
            let remaining = goal - steps
            let withinReach = remaining >= 200
                && remaining <= Int(Double(goal) * 0.4)
            let timely = input.hourOfDay >= 14 || input.largeMealLoggedRecently
            if withinReach, timely {
                let line = input.largeMealLoggedRecently
                    ? voice.walkAfterMeal()
                    : voice.walkGap(remainingSteps: remaining)
                supporting.append(Move(
                    beat: .steps(goal: goal),
                    because: line.text, becauseItalic: line.italics
                ))
            }
        }

        supporting = Array(supporting.prefix(careProtocol.composition.maxSupportingMoves))

        // v24 — the daily dose sits FIRST among supports (clinical
        // precedes behavioral) and OUTSIDE the protocol's cap: it
        // is her regimen, not an ask, and it never displaces the
        // day's behavioral supports.
        if let dailyDoseMove, dailyDoseMove.beat.itemKey != lead?.beat.itemKey {
            supporting.insert(dailyDoseMove, at: 0)
        }

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
        // v25 E8 (founder steer) — STEPS ALWAYS STAND IN THE LIST.
        //
        // Until now a steps row appeared only when E1's adaptive walking
        // ASK cleared six gates at once (a consented goal, no external
        // workout, a gap between 200 and 40% of the goal, and after 2pm
        // unless a meal made it timely), so on most days the product's
        // oldest health rail was invisible on the surface that lists the
        // day.
        //
        // It joins as an OFFERED row, which matters: offered moves are
        // quiet invitations and are excluded from `actionableBeats`, so
        // a standing steps row can never become debt in the "0 of N"
        // count or read as a missed task. The adaptive ask keeps its
        // gates and its rank as a SUPPORT — this only fills the silence
        // when that ask has nothing to say, and never duplicates it.
        let walkAlreadyComposed = supporting.contains {
            if case .steps = $0.beat { return true }
            return false
        }
        if !walkAlreadyComposed,
           lead.map({ if case .steps = $0.beat { return false } else { return true } }) ?? true,
           let goal = input.resolvedStepGoal, goal > 0 {
            offered.append(Move(beat: .steps(goal: goal)))
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
            tone: .standard, lead: lead, leadIsPromoted: leadIsPromoted,
            supporting: supporting, offered: offered, closing: closing
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

        // 1.5 — the WEEK ran the muscle-loss pattern (v9 P4: the
        //       preservation ladder's daily echo — fast loss with
        //       protein under across the week outranks one
        //       yesterday).
        if input.preservationAtRisk {
            let line = voice.preservationAtRisk()
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
