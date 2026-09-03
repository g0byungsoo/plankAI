import Foundation

// MARK: - WeeklyBodyReview
//
// app v9 P3 (docs/app_v9/02_PLAN.md, closes W9's read half): ONE
// weekly read that leads with the body OUTCOME and explains it from
// the week's inputs — the unification of the two one-thing engines.
// CoachSummary keeps composing the one move (its grammar untouched);
// this engine wraps it: outcome → mechanisms → preservation → move.
//
// Laws carried: every line floor-gated and traceable to a collected
// field (the provenance audit is the test suite); timing-never-
// causality — mechanisms are observations laid beside the line,
// never verdicts; a rising week may speak PATTERN mechanisms
// (sleep, the eating window, sugar direction, the dose rhythm) but
// never a single food and never blame; no number from a photo (L3).
// The consent grammar of the re-signing is untouched — this is the
// READ, not the adjustment machinery.

enum WeeklyBodyReview {

    struct Input {
        // — the outcome (unit-aware line composed upstream by
        //   InsightEngine; scans metadata for the mirror clause)
        var trendLine: String? = nil
        var trendItalic: [String] = []
        var trendDeltaKg: Double? = nil
        var trendEstablished: Bool = false
        var scans: [BodyChangeRead.ScanMeta] = []
        // — mechanisms (each nil/zero = that fact wasn't collected)
        var loggedDays7: Int = 0
        var proteinDaysMet7: Int = 0
        /// nil = workouts never granted (the connect door's case).
        var strengthSessions7: Int? = nil
        var stepsActiveDays7: Int? = nil
        var sleepNightsCounted: Int = 0
        var shortNights7: Int = 0
        var fastAvgHours: Double? = nil
        var fastNights: Int = 0
        var sweetDirection: Sweetness.Direction? = nil
        /// Weekly medication rhythm (on-med cohort only).
        var doseScheduled7: Int? = nil
        var doseTaken7: Int = 0
        // — recovery (D5: HRV returns WITH this rendered surface)
        var hrvLatest: Int? = nil
        var hrvBaseline: Int? = nil
        /// p53 — resting HR, the v8 sheet's own recovery signal.
        var restingHRLatest: Int? = nil
        var restingHRBaseline: Int? = nil
        // — preservation
        var lossRatePctPerWeek: Double? = nil
        /// Preformatted lean-mass garnish ("your scale reads …"),
        /// provenance-labeled upstream; nil when her scale is silent.
        var leanLine: String? = nil
        // — the move (CoachSummary passthrough, grammar untouched)
        var move: CoachSummary.Output? = nil
    }

    struct Read: Equatable {
        let outcome: String
        let outcomeItalic: [String]
        /// ≤3, ordered by clinical weight; observations, never verdicts.
        let mechanisms: [String]
        let preservation: Preservation?
        let move: CoachSummary.Output?
    }

    struct Preservation: Equatable {
        enum State: String {
            case protected, watch, atRisk, unknown
        }
        let state: State
        let line: String
        /// The evidence chip (the onboarding pattern) — protein +
        /// resistance preserve lean mass during loss.
        let citation: String?
        /// True when workouts were never granted — the L5-honest
        /// place to ask (the surface that renders the data).
        let connectDoor: Bool
    }

    // MARK: - Compose

    static func compose(_ input: Input) -> Read? {
        let outcome = outcomeLead(input)
        let mechanisms = mechanismLines(input)
        let preservation = preservation(input)
        guard outcome != nil || !mechanisms.isEmpty || input.move != nil else {
            return nil
        }
        return Read(
            outcome: outcome?.text ?? "here's your week.",
            outcomeItalic: outcome?.italic ?? [],
            mechanisms: mechanisms,
            preservation: preservation,
            move: input.move
        )
    }

    private static func outcomeLead(_ input: Input) -> (text: String, italic: [String])? {
        if let line = input.trendLine {
            return (line, input.trendItalic)
        }
        // No trend yet — the mirror can still lead when scans exist.
        if let scanLine = BodyChangeRead.line(
            scans: input.scans,
            trendEstablished: input.trendEstablished,
            trendDeltaKg: input.trendDeltaKg
        ) {
            return (scanLine, [])
        }
        return nil
    }

    // MARK: - Mechanisms (observations beside the line, ≤3)

    static func mechanismLines(_ input: Input) -> [String] {
        var lines: [String] = []

        // The mirror clause — only when BodyChangeRead's full floors
        // pass AND the trend agrees (the same gate as the body page).
        if input.trendEstablished, let delta = input.trendDeltaKg, delta <= -0.1,
           let scanLine = BodyChangeRead.line(
               scans: input.scans, trendEstablished: true, trendDeltaKg: delta
           ),
           scanLine.hasSuffix("the line and the mirror agree.") {
            lines.append("the mirror agrees · your scans show it too")
        }

        // Protein presence (≥4 logged days or the count misleads) —
        // and ≥4 MET days, InsightEngine's own floor for this ratio
        // (p71): a mechanism line explains what worked; "protein
        // landed 1 of 7" explains nothing and reads as a grade to a
        // low-appetite reader. Under the floor, the preservation
        // ladder carries the protein story with evidence and a move.
        if input.loggedDays7 >= 4, input.proteinDaysMet7 >= 4 {
            lines.append("protein landed \(input.proteinDaysMet7) of \(input.loggedDays7) logged days")
        }

        // Movement: strength when known, feet otherwise.
        if let strength = input.strengthSessions7, strength >= 1 {
            lines.append(strength == 1
                ? "1 strength session kept"
                : "\(strength) strength sessions kept")
        } else if let active = input.stepsActiveDays7, active >= 5 {
            lines.append("\(active) days on your feet")
        }

        // Sleep pattern (≥3 counted nights; allowed on rising weeks —
        // a pattern, not a verdict).
        if input.sleepNightsCounted >= 3, input.shortNights7 >= 3 {
            lines.append("\(input.shortNights7) short nights rode beside the line")
        }

        // The eating window's late drift (pattern; never a food).
        if let avg = input.fastAvgHours, input.fastNights >= 4, avg < 11 {
            lines.append("the eating window ran late most nights")
        }

        // Sugar direction (weekly aggregate only — never a single food).
        if input.sweetDirection == .rising {
            lines.append("sugar intake rose vs last week")
        }

        // The dose rhythm (on-med cohort; a fact, zero reward words).
        if let scheduled = input.doseScheduled7, scheduled > 0 {
            lines.append("your dose landed \(min(input.doseTaken7, scheduled)) of \(scheduled)")
        }

        // Recovery (D5 — HRV's rendered surface).
        if let word = recoveryWord(latest: input.hrvLatest, baseline: input.hrvBaseline) {
            lines.append("recovery \(word) (heart-rate variability)")
        } else if let word = restingHeartWord(
            latest: input.restingHRLatest, baseline: input.restingHRBaseline
        ) {
            // p53 — resting heart rate finally renders (it was
            // requested on the LIVE consult sheet with the on-screen
            // promise "the recovery signal" and reached no surface):
            // the same own-baseline stance, used when HRV is absent —
            // which is exactly the v8-sheet population, since that
            // sheet asks for RHR and not HRV.
            lines.append("recovery \(word) (resting heart rate)")
        }

        return Array(lines.prefix(3))
    }

    /// Her own 30-day baseline is the only reference (the resting-
    /// heart stance): ±7ms reads steady; higher HRV reads better.
    static func recoveryWord(latest: Int?, baseline: Int?) -> String? {
        guard let latest, let baseline, baseline > 0 else { return nil }
        let delta = latest - baseline
        if delta >= 8 { return "improving" }
        if delta <= -8 { return "dipped" }
        return "held steady"
    }

    /// p53 — the RHR twin: her own 30-day baseline, ±3 bpm reads
    /// steady; LOWER resting heart reads better. Words only, her own
    /// reference, never a population number.
    static func restingHeartWord(latest: Int?, baseline: Int?) -> String? {
        guard let latest, let baseline, baseline > 0 else { return nil }
        let delta = latest - baseline
        if delta <= -3 { return "improving" }
        if delta >= 3 { return "dipped" }
        return "held steady"
    }

    // MARK: - Preservation (protein × resistance × rate; honest floors)

    static func preservation(_ input: Input) -> Preservation? {
        let connectDoor = input.strengthSessions7 == nil

        guard input.loggedDays7 >= 4, let rate = input.lossRatePctPerWeek else {
            return Preservation(
                state: .unknown,
                line: "the preservation read needs 4 logged days and an established trend",
                citation: nil,
                connectDoor: connectDoor
            )
        }

        let proteinHolds = input.proteinDaysMet7 >= 4
        let movementHolds = (input.strengthSessions7 ?? 0) >= 1
            || (input.stepsActiveDays7 ?? 0) >= 5
        let rateSafe = rate <= 0.01   // the ACSM 1%/wk guard

        let state: Preservation.State
        let line: String
        if !rateSafe && !proteinHolds {
            state = .atRisk
            // v11: the em-dash died app-wide (voice law); the interpunct
            // is the house pause.
            line = "losing fast with protein under the floor · the muscle-loss pattern"
        } else if proteinHolds && movementHolds && rateSafe {
            state = .protected
            line = "protein held, movement held, pace safe · muscle protected"
        } else {
            state = .watch
            line = proteinHolds
                ? "protein held · movement is the missing pillar"
                : "pace is safe. protein is the missing pillar"
        }

        var full = line
        if let lean = input.leanLine { full += " · " + lean }

        return Preservation(
            state: state,
            line: full,
            citation: "wycherley 2012 · ajcn",
            connectDoor: connectDoor
        )
    }
}
