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
        /// Cycle position at compose time (1…7), when honest.
        var cycleDay: Int? = nil
        /// A dose/medication change landed within ~14 days.
        var eraChangedRecently: Bool = false

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
            signals.append(.init(
                key: "protein", label: "protein floor",
                thisWeek: "\(inputs.proteinDaysMet) days",
                versus: nil, direction: 0
            ))
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
            heroLine = "\(res) of \(exp) doses carried it."
            heroItalics = []
        } else {
            heroLine = "a quiet week. the record has room."
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
                    text: "the dose landed on its day — the week kept its anchor.",
                    italics: ["anchor"]
                ))
            case .takenLate:
                observations.append(VoiceLine(
                    text: "the dose landed late and the record holds it honestly. rhythms recover.",
                    italics: ["recover"]
                ))
            case .skipped:
                observations.append(VoiceLine(
                    text: "this week's dose was a no, and a recorded no is an answer, not a gap."
                ))
            case .open:
                observations.append(VoiceLine(
                    text: "this week's dose is still open — log it late, or let it go."
                ))
            case .missed:
                observations.append(VoiceLine(
                    text: "the week ran without its dose — recorded, no debt carried."
                ))
            }
        } else if let res = inputs.dosesResolved,
                  let exp = inputs.dosesExpected, exp >= 2 {
            observations.append(VoiceLine(
                text: "\(res) of \(exp) dose slots resolved. the record stays honest either way."
            ))
        }
        // v25 E2 — an upward drift meets the water truth before she
        // can blame herself (a down week needs no commentary; the
        // band already said it without debt language).
        if inputs.weight?.band == "drifting_up" {
            observations.append(VoiceLine(
                text: "the trend drifted up a touch this week. water writes most weeks like this.",
                italics: ["water"]
            ))
        }
        // The protein observation yields when the OFFER already
        // carries the protein fact (three tellings is clutter —
        // frame-caught).
        if inputs.plateDays >= 4, !inputs.offer.key.hasPrefix("protein") {
            observations.append(VoiceLine(
                text: "protein cleared its floor \(inputs.proteinDaysMet) of \(inputs.elapsedDays) days"
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
            return "goals that move with your own weeks are the ones that keep."
        case "logging_lighten":
            return "a photo on a full day beats a perfect record that stops."
        case "protein_ease", "protein_firm":
            return "the floor works when it's reachable. protein protects what you're keeping."
        case "moves_ease":
            return "a plan your week can hold beats one it can't."
        case "weigh_soften":
            return "the trend reads the week. one check keeps it honest."
        case "intent_pick":
            return "a chosen week is easier to keep than an assigned one."
        default:
            // v25 E2 — when the offer teaches nothing, the WEEK may:
            // late-cycle normalization first (the era's voice — the
            // return of appetite named before she blames herself),
            // then the plateau truth. One line, or silence.
            guard let inputs else { return nil }
            if let cycleDay = inputs.cycleDay, cycleDay >= 6 {
                return "the last days of a dose week often run hungrier. that's the shape of the week, not a slip."
            }
            if inputs.eraChangedRecently, inputs.doseWeek != nil {
                return "the first weeks after a change often run differently. the record is how you and your prescriber see it."
            }
            if inputs.weight?.band == "holding_steady",
               inputs.weight?.sufficiency == "established" {
                return "plateaus are part of every real descent. the trend, not one morning, is the measure."
            }
            return nil
        }
    }

    private static func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
