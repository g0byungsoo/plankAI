import Foundation

// MARK: - WeeklyReadComposer (E1 THE SPINE — B2)
//
// docs/app_v25/05_E1_SPINE.md §2. WHAT HAPPENED → WHAT MATTERS →
// WHAT TO TRY NEXT. Pure and deterministic over assembled inputs;
// every rendered fact traces to a counted input (provenance); floors
// keep sparse weeks honest; the register is anti-shame by
// construction (a down week carries no debt).

struct WeeklyReadModel: Equatable {
    let windowStartDay: String
    let anchorKind: WeeklyReadAnchor.Kind
    let heroLine: String
    let heroItalics: [String]

    struct Signal: Equatable {
        let key: String
        let label: String
        let thisWeek: String
        let versus: String?
        /// -1 quieter · 0 steady · +1 fuller (the mark's shape,
        /// never a judgment color).
        let direction: Int
    }
    let signals: [Signal]
    let observations: [VoiceLine]
    let teaching: String?
    let offer: WeeklyReadOffer
}

enum WeeklyReadComposer {

    struct Inputs: Equatable {
        var windowStartDay: String
        var anchorKind: WeeklyReadAnchor.Kind
        var stepsThisWeek: [Int] = []
        var stepsTrailing: [Int] = []
        var plateDays: Int = 0
        var plateCount: Int = 0
        var proteinDaysMet: Int = 0
        var elapsedDays: Int = 7
        var dosesResolved: Int? = nil
        var dosesExpected: Int? = nil
        var offer: WeeklyReadOffer

        // — v25 E2: THE MEDICATED WEEK (weekly injectors only; nil
        //   everywhere = a non-medicated or daily-cadence read, zero
        //   cycle leakage by construction).

        /// How the window's ONE weekly slot resolved.
        enum DoseWeekState: String, Equatable {
            case takenOnDay = "taken_on_day"
            case takenLate = "taken_late"
            case skipped, open, missed
        }
        var doseWeek: DoseWeekState? = nil
        /// Cycle position at compose time, when honest. p54 — the day
        /// AND its rhythm's length (pass 53 made intervals real; a
        /// bare "day 6" gate read a q10d user's mid-cycle as the
        /// hungry end, the same defect the Method carried).
        var cycleDay: Int? = nil
        var cycleLength: Int? = nil
        /// A dose/medication change landed within ~14 days.
        var eraChangedRecently: Bool = false
        /// p54 — treatment tenure in months, by her account (nil when
        /// never stated). Lets the read speak the CHAPTER: a flat
        /// stretch a year into treatment is the trials' own curve.
        var treatmentMonths: Int? = nil

        // — p54: WHAT ACTUALLY MATTERED THIS WEEK (§9 of the brief).

        /// Last week's floor-met count, when a real prior week exists
        /// (≥5 elapsed days). Lets consistency speak as a DELTA.
        var priorProteinDaysMet: Int? = nil
        /// Strength sessions in the trailing week (health + her own
        /// entries — the one movement figure that decides what the
        /// loss is made of).
        var strengthSessions7: Int? = nil
        /// Weekend-vs-weekday energy shape, kcal, rounded upstream to
        /// 50 and gated upstream (≥2 logged weekend days, ≥3 logged
        /// weekdays, ≥150 kcal of shape, never under suppression or
        /// restrictive risk). nil = no honest shape to name.
        var weekendKcalDelta: Int? = nil
        /// p54 — the Method's follow-through, settled against her own
        /// record this window: how many notes had their pre-registered
        /// outcome met, of how many settled. The loop pass 53 wired
        /// into analytics finally reaches HER.
        var methodFollowUpsMet: Int? = nil
        var methodFollowUpsSettled: Int? = nil

        // — p57: THE CONSULT'S WEEK-THREE PROMISE. The prior-attempts
        //   beat answers "then you know week three is where it usually
        //   breaks. we plan for that." — and the plan that owned that
        //   sentence (the 84-lesson curriculum) died in p54 with
        //   nothing inheriting it. The read keeps it now, once, at the
        //   exact week the consult named.

        /// 1-based program week at compose time (nil = unknown).
        var programWeek: Int? = nil
        /// She told the consult she has tried before (any answer past
        /// "none"). Device-truth: the fact she stated, not an
        /// inference.
        var saidPriorAttempts: Bool = false

        // — v25 E2: THE WEIGHT SIGNAL (formatted upstream in her
        //   display unit; nil = no record or suppressed).
        struct WeightSignal: Equatable {
            /// trending_down | holding_steady | drifting_up ·
            /// nil = insufficient/stale (the signal stays silent).
            var band: String? = nil
            var sufficiency: String = "insufficient"
            /// "0.8 lb" — the absolute weekly trend delta.
            var deltaText: String? = nil
        }
        var weight: WeightSignal? = nil
    }

    static func compose(_ inputs: Inputs) -> WeeklyReadModel {
        let recordedThis = inputs.stepsThisWeek.filter { $0 > 500 }
        let recordedTrailing = inputs.stepsTrailing.filter { $0 > 500 }
        let stepsAvg: Int? = recordedThis.isEmpty
            ? nil : recordedThis.reduce(0, +) / recordedThis.count
        // The comparison needs real history — ≥5 recorded trailing
        // days or the "usual" is an invention.
        let trailingAvg: Int? = recordedTrailing.count >= 5
            ? recordedTrailing.reduce(0, +) / recordedTrailing.count : nil

        // — WHAT HAPPENED: the signals (data-present only, ≤3).
        var signals: [WeeklyReadModel.Signal] = []
        if let stepsAvg {
            let direction: Int = {
                guard let t = trailingAvg, t > 0 else { return 0 }
                let ratio = Double(stepsAvg) / Double(t)
                if ratio >= 1.15 { return 1 }
                if ratio <= 0.85 { return -1 }
                return 0
            }()
            signals.append(.init(
                key: "steps", label: "steps a day",
                thisWeek: fmt(stepsAvg),
                versus: trailingAvg.map { "vs \(fmt($0)) your usual" },
                direction: direction
            ))
        }
        // v25 E2 — the weight signal joins the band (a weight-loss
        // app's ritual finally reads weight). Bands render only past
        // the engine's honesty floors; provisional reads say so.
        if let weight = inputs.weight, let band = weight.band {
            let value: String
            let direction: Int
            switch band {
            case "trending_down":
                value = weight.deltaText.map { "−\($0)" } ?? "down"
                direction = -1
            case "drifting_up":
                value = weight.deltaText.map { "+\($0)" } ?? "up"
                direction = 1
            default:
                value = "steady"
                direction = 0
            }
            signals.append(.init(
                key: "weight", label: "the weight trend",
                thisWeek: value,
                versus: weight.sufficiency == "provisional"
                    ? "an early read" : nil,
                direction: direction
            ))
        }
        if inputs.plateCount > 0 {
            signals.append(.init(
                key: "plates", label: "days logged",
                thisWeek: "\(inputs.plateDays)",
                versus: nil, direction: 0
            ))
            // Pass 77 — "protein goal · 0 days" is a grade in a
            // fact's clothing (the p74 zero-grade class, still
            // standing in this one stat band). A zero renders as
            // silence; when the floor was out of reach the proposal
            // beneath already carries that story as a change, not a
            // score.
            if inputs.proteinDaysMet >= 1 {
                signals.append(.init(
                    key: "protein", label: "protein goal",
                    thisWeek: "\(inputs.proteinDaysMet) days",
                    versus: nil, direction: 0
                ))
            }
        }
        signals = Array(signals.prefix(3))

        // — the hero line: ONE short clause (the signals band
        // carries the numbers; a stacked hero truncates —
        // frame-caught craft law).
        let heroLine: String
        let heroItalics: [String]
        if inputs.plateDays > 0 {
            heroLine = inputs.plateDays == 1
                ? "one day logged." : "\(inputs.plateDays) days logged."
            heroItalics = []
        } else if let stepsAvg {
            heroLine = "steps near \(fmt(stepsAvg))."
            heroItalics = []
        } else if let res = inputs.dosesResolved,
                  let exp = inputs.dosesExpected, exp >= 1 {
            heroLine = "\(res) of \(exp) doses logged."
            heroItalics = []
        } else {
            heroLine = "a quiet week. not much logged, and that's fine."
            heroItalics = ["quiet"]
        }

        // — WHAT MATTERS: ≤2 floor-gated observations, clinical
        // first, anti-shame always.
        var observations: [VoiceLine] = []
        // v25 E2 — the dose finally enters "your dose week": the
        // weekly slot's own story leads (the old exp≥2 gate meant a
        // weekly injector never saw a dose line — recon correction 3).
        if let doseWeek = inputs.doseWeek {
            switch doseWeek {
            case .takenOnDay:
                observations.append(VoiceLine(
                    text: "your dose landed on its day.",
                    italics: ["on its day"]
                ))
            case .takenLate:
                observations.append(VoiceLine(
                    text: "your dose landed late. logged, and the rhythm recovers from here.",
                    italics: ["logged,"]
                ))
            case .skipped:
                observations.append(VoiceLine(
                    text: "this week's dose was a no. recorded, not a gap."
                ))
            case .open:
                observations.append(VoiceLine(
                    text: "this week's dose is still open. log it late, or let it go."
                ))
            case .missed:
                observations.append(VoiceLine(
                    text: "no dose this week. recorded, no debt."
                ))
            }
        } else if let res = inputs.dosesResolved,
                  let exp = inputs.dosesExpected, exp >= 2 {
            observations.append(VoiceLine(
                text: "\(res) of \(exp) doses recorded this week."
            ))
        }
        // v25 E2 — an upward drift meets the water truth before she
        // can blame herself (a down week needs no commentary; the
        // band already said it without debt language).
        if inputs.weight?.band == "drifting_up" {
            observations.append(VoiceLine(
                text: "the trend drifted up a touch. that's usually water, not fat.",
                italics: ["water,"]
            ))
        }
        // p54 — the Method's follow-through reaches HER (the loop that
        // reported only to analytics): what jeni said this week, and
        // whether the record answered. Never a scold — zero-met weeks
        // simply don't spend the slot.
        if let met = inputs.methodFollowUpsMet,
           let settled = inputs.methodFollowUpsSettled,
           settled >= 1, met >= 1 {
            let text = settled == 1
                ? "the note jeni left this week was followed by the move it named."
                : "\(met) of \(settled) notes jeni left this week were followed by the move they named."
            observations.append(VoiceLine(text: text, italics: ["followed"]))
        }
        // p54 — the week's energy SHAPE, attributed to its days (§9:
        // "most of the extra came from saturday"). Named as a rhythm,
        // never a problem: the weekday-compensation literature says a
        // planned weekend surplus is compatible with losing.
        if let delta = inputs.weekendKcalDelta {
            // p79 — "the week's shape:" was a designer's label on a
            // sentence that already said everything (founder steer:
            // everyday words only on this surface).
            observations.append(VoiceLine(
                text: "weekends ran about \(fmt(delta)) kcal above your weekdays. your weekdays stayed steady.",
                italics: ["weekends"]
            ))
        }
        // The protein observation yields when the OFFER already
        // carries the protein fact (three tellings is clutter —
        // frame-caught).
        // p77 — met >= 1: "hit 0 of 7 days" is the same zero-grade;
        // a week that never reached the floor speaks through the
        // proposal, not a score line.
        if inputs.plateDays >= 4, inputs.proteinDaysMet >= 1,
           !inputs.offer.key.hasPrefix("protein") {
            // p54 — consistency speaks as a DELTA when a real prior
            // week exists and the direction is up; a softer week
            // states this week only (information, never debt).
            let delta: String = {
                guard let prior = inputs.priorProteinDaysMet,
                      inputs.proteinDaysMet > prior else { return "" }
                return " \u{00B7} up from \(prior) last week"
            }()
            observations.append(VoiceLine(
                text: "protein goal hit \(inputs.proteinDaysMet) of \(inputs.elapsedDays) days\(delta)"
            ))
        }
        // p54 — movement held: the strength floor is the week's third
        // pillar (§9), and it was invisible to the read.
        if let strength = inputs.strengthSessions7, strength >= 2 {
            observations.append(VoiceLine(
                text: "strength: \(strength) sessions. that's what keeps muscle.",
                italics: ["\(strength) sessions."]
            ))
        }
        if let stepsAvg, let t = trailingAvg, t > 0 {
            let ratio = Double(stepsAvg) / Double(t)
            if ratio >= 1.15 {
                let pct = Int(((ratio - 1) * 100).rounded())
                observations.append(VoiceLine(
                    text: "your steps ran about \(pct)% fuller than your usual",
                    italics: ["fuller"]
                ))
            } else if ratio <= 0.85 {
                // A down week is information, never debt.
                observations.append(VoiceLine(
                    text: "your steps ran quieter than usual. no debt in that.",
                    italics: ["quieter"]
                ))
            }
        }
        observations = Array(observations.prefix(2))

        return WeeklyReadModel(
            windowStartDay: inputs.windowStartDay,
            anchorKind: inputs.anchorKind,
            heroLine: heroLine,
            heroItalics: heroItalics,
            signals: signals,
            observations: observations,
            teaching: teaching(for: inputs.offer, inputs: inputs),
            offer: inputs.offer
        )
    }

    /// The authored v1 teaching set — one line, keyed by the offer
    /// (the atom engine arrives in E5; these twelve-ish lines are
    /// founder-voice-pass gated). hold_steady teaches nothing:
    /// calm over lecture.
    private static func teaching(
        for offer: WeeklyReadOffer, inputs: Inputs? = nil
    ) -> String? {
        switch offer.key {
        case "step_goal_recalc":
            return "your step goal now follows your own real weeks."
        case "logging_lighten":
            return "a quick photo counts. don't aim for perfect."
        case "protein_ease", "protein_firm":
            return "your protein goal is set where you can actually reach it. protein keeps muscle."
        case "moves_ease":
            return "a lighter plan you can do beats a bigger one you can't."
        case "weigh_soften":
            return "one weigh-in a week is enough to keep the trend honest."
        case "intent_pick":
            return "you picked this week's focus. that makes it easier to keep."
        default:
            // v25 E2 — when the offer teaches nothing, the WEEK may:
            // late-cycle normalization first (the era's voice — the
            // return of appetite named before she blames herself),
            // then the plateau truth. One line, or silence.
            guard let inputs else { return nil }
            // p54 — the waning gate is the schedule engine's own band
            // (a bare `day >= 6` read a q10d user's mid-cycle as the
            // hungry end — the Method's exact defect, here too).
            if let day = inputs.cycleDay, let length = inputs.cycleLength,
               MedicationScheduleEngine.CyclePosition(
                   day: day, length: length, basis: .takenDose
               ).band == .waning {
                return "the last days of a dose rhythm often run hungrier. that's the shape of the rhythm, not a slip."
            }
            if inputs.eraChangedRecently, inputs.doseWeek != nil {
                return "the first weeks after a change often run differently. the record is how you and your prescriber see it."
            }
            // p57 — the consult's own promise, kept at the exact week
            // it named. The prior-attempts ack says "then you know
            // week three is where it usually breaks. we plan for
            // that." — and the plan that owned the sentence (the
            // curriculum) died in p54 with nothing inheriting it.
            // Spoken once, in week three, only to someone who told us
            // she'd been here; the medicated clauses above keep their
            // precedence (a truth about her body this week outranks a
            // calendar sentence).
            if inputs.saidPriorAttempts, inputs.programWeek == 3 {
                return "week three. the one that usually breaks a fresh start. this one is planned for. nothing to win back, the week just continues."
            }
            if inputs.weight?.band == "holding_steady",
               inputs.weight?.sufficiency == "established" {
                // p54 — the CHAPTER speaks when it can: around a year
                // of treatment the trials' own curves flatten (STEP-1
                // nadir ~week 60; SURMOUNT ~48-72), so a hold here is
                // the medicine's shape, not a stall. Tenure is her own
                // stated fact, month resolution.
                if let months = inputs.treatmentMonths, months >= 10,
                   inputs.doseWeek != nil {
                    return "about a year in, the trials' own curves flatten. holding here is the medicine's shape, not a stall."
                }
                return "plateaus are part of every real weight loss. watch the trend, not one morning."
            }
            // p79 — "nothing needs a reset." is GONE (founder steer):
            // it fired only on hold_steady, whose proposal block says
            // "nothing needs to change this week." directly beneath —
            // the same sentence twice, the second time in poetry. The
            // close now speaks only when it adds a fact (the clauses
            // above); a steady week's reassurance lives in the offer.
            return nil
        }
    }

    private static func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
