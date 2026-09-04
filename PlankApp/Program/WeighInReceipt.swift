import Foundation

// MARK: - WeighInReceipt (pass 77 — the morning verdict)
//
// The kept beat used to close every weigh-in with the same aphorism
// ("single days bounce. the 7-day trend is what counts.") while the
// verdict that sentence points at sat one engine away. The research
// record (77_evidence) ranks "what does my trend say, right now,
// about the number I just saw" as the category's most repeated daily
// job — and the morning the scale jumps is the exact moment the
// answer matters, not a weekly review later.
//
// Laws carried:
// - the spoken delta derives from the SAME fold the pages draw
//   (WeightWeekReadEngine), so the whisper can never disagree with
//   Becoming;
// - deltas only, never the smoothed absolute — a second numeral
//   beside the one she just typed reads as a contradiction
//   (Happy Scale's own documented confusion tax);
// - an up trend is stated plainly: never scolded, and never wrapped
//   in water reassurance a week-scale fact doesn't support (the
//   day-scale water sentence belongs to the day-scale surfaces);
// - a young trend speaks direction without numerals ("an early
//   read"), the provisional grammar every other surface keeps;
// - no band → nil, numeric suppression → nil (the ritual keeps its
//   own standing copy).

enum WeighInReceipt {

    /// A saved number this far above the fold reads as a spike worth
    /// answering (≈1 lb — inside the fluctuation literature's normal
    /// daily water range, above its typical morning grain).
    static let spikeAboveTrendKg = 0.45

    /// The kept beat's sub-line. `steadyContextLine` is
    /// BecomingStory.steadyContext's sentence when the caller has one
    /// (the flat-week-inside-a-moving-month reassurance, spoken at
    /// the anxious moment instead of a tab away).
    /// `savedKg` is THIS MORNING's committed number and gates the
    /// spike grammar ("this morning sits above your line"). Pass nil
    /// when the save is a correction to a past day — the sentence
    /// would name a morning that isn't the one being edited (p78).
    static func whisper(
        read: WeightWeekRead,
        savedKg: Double?,
        unit: WeightUnit,
        steadyContextLine: String? = nil,
        numericsSuppressed: Bool = false
    ) -> String? {
        guard !numericsSuppressed else { return nil }
        guard let band = read.band else { return nil }

        if read.sufficiency == .provisional {
            switch band {
            case .trendingDown: return "an early read: trending down."
            case .holdingSteady: return "an early read: holding about steady."
            case .driftingUp: return "an early read. the line needs a few more days."
            }
        }

        guard let deltaKg = read.weeklyDeltaKg else { return nil }
        let amount =
            "\(WeightLedger.number(abs(unit.display(fromKg: deltaKg)))) \(unit.label)"
        let isSpike = savedKg.flatMap { saved in
            read.trendKg.map { saved >= $0 + spikeAboveTrendKg }
        } ?? false

        switch band {
        case .trendingDown:
            return isSpike
                ? "this morning sits above your line. the trend still reads down about \(amount) this week."
                : "your trend reads down about \(amount) this week."
        case .holdingSteady:
            if let context = steadyContextLine { return context }
            return isSpike
                ? "this morning sits above your line. your trend is holding steady this week."
                : "your trend is holding steady this week."
        case .driftingUp:
            return "your trend reads up about \(amount) this week."
        }
    }

    /// The coach envelope's quotable form of the same verdict —
    /// sentence-shaped because the model quotes sentences and skips
    /// opaque keys (pass 77: "why is my weight up today?" came back
    /// as generic chatbot copy with `ema_delta_7d_kg` sitting unread
    /// in context). Speaks basis and instructs the read; numerals
    /// ride only what the band already earned.
    static func modelLine(read: WeightWeekRead, unit: WeightUnit) -> String? {
        switch read.sufficiency {
        case .insufficient:
            return nil
        case .stale:
            guard let ago = read.lastSampleDaysAgo else { return nil }
            return "their last weigh-in was \(ago) days ago, so the trend is stale. invite a weigh-in before speaking any direction."
        case .provisional, .established:
            guard let band = read.band, let deltaKg = read.weeklyDeltaKg
            else { return nil }
            let amount =
                "\(WeightLedger.number(abs(unit.display(fromKg: deltaKg)))) \(unit.label)"
            let direction: String
            switch band {
            case .trendingDown: direction = "down about \(amount) over the last week"
            case .holdingSteady: direction = "holding about steady over the last week"
            case .driftingUp: direction = "up about \(amount) over the last week"
            }
            let basis = "\(read.sampleCount) weigh-ins"
            let early = read.sufficiency == .provisional
                ? " it is an early read; speak it gently." : ""
            return "their smoothed weight trend reads \(direction), resting on \(basis).\(early) quote this fold for 'am i losing' and 'why is my weight up', never a single day's number."
        }
    }
}
