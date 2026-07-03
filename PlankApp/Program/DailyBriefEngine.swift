import Foundation

// MARK: - DailyBriefEngine
//
// App v2 (docs/app_v2/04_DAILY_PROGRAM.md §Brief). Jeni's line of
// the day — the single coaching sentence that opens Today and seeds
// the chat. Deterministic (seeded by dayKey so it never changes
// under her mid-day), provenance-only (every clause traces to a
// stored field), and shared with notifications so push copy and
// in-app copy never diverge.
//
// The cascade picks ONE thread per day, highest priority first.
// Copy obeys the voice contract: lowercase, italic punch words via
// the `italic` array (never markdown), ♥ terminal + sparse, no
// em-dashes, no diet-culture verbs, numbers only when live.

enum DailyBriefEngine {

    struct Brief: Equatable {
        let line: String
        let italic: [String]
        /// Optional seed forwarded to jeni when she taps the line —
        /// opens the chat with this as jeni's expanded opener.
        let chatSeed: String?
    }

    /// Everything the cascade may cite. Assemble from live services;
    /// leave fields nil when the data doesn't exist (clauses that
    /// need them are skipped — provenance rule).
    struct Context: Equatable {
        var name: String?
        var programDay: Int
        var archetype: ProgramDayArchetype
        var isWeighInDay: Bool
        var weighInIsStaleFallback: Bool
        /// 7-day EMA delta in kg (negative = down). nil under 2 logs.
        var emaDelta7dKg: Double?
        /// Sustained loss rate as %/wk when computable. nil otherwise.
        var lossRatePctPerWeek: Double?
        var showedUpCount: Int
        /// Calendar days since she last opened the app. 0 = today.
        var daysSinceLastOpen: Int
        /// Day-1 promise kept yesterday/today (kept-promise flow).
        var promiseJustKept: Bool
        var proteinTargetG: Int?
        var maintenanceMode: Bool
        var glp1Cohort: Glp1Cohort
        var dayKey: String            // "2026-07-03" — the seed
    }

    // MARK: - The cascade

    static func brief(for ctx: Context) -> Brief {
        // 1 — the kept promise (day 1-2 only; the loop's first win)
        if ctx.promiseJustKept {
            return Brief(
                line: "you did the thing you said you'd do. that's the whole *skill* \u{2665}\u{FE0E}",
                italic: ["skill"],
                chatSeed: "she kept her day-one promise. acknowledge it and set up today lightly."
            )
        }

        // 2 — comeback (2+ days away beats everything else; the
        //     return moment is where retention is won or lost)
        if ctx.daysSinceLastOpen >= 2 {
            return Brief(
                line: "back after \(ctx.daysSinceLastOpen) days. *begin again* is the strategy, not the failure \u{2665}\u{FE0E}",
                italic: ["begin again"],
                chatSeed: "she's back after \(ctx.daysSinceLastOpen) days away. no guilt. re-entry plan for today."
            )
        }

        // 3 — rapid-loss care (wires RapidLossTripwire's intent:
        //     >1%/wk sustained → protein reframe, never "slow down")
        if let rate = ctx.lossRatePctPerWeek, rate > 0.01 {
            return Brief(
                line: "you're moving quickly. a *protein-forward* week keeps it lean \u{2665}\u{FE0E}",
                italic: ["protein-forward"],
                chatSeed: "her trend shows faster than 1% per week. explain the lean-mass case for protein without alarm."
            )
        }

        // 4 — trend movement worth naming (EMA, never raw drama)
        if let delta = ctx.emaDelta7dKg {
            if delta <= -0.2 {
                return Brief(
                    line: "your trend line eased down this week. quiet, *real* movement.",
                    italic: ["real"],
                    chatSeed: "her 7-day trend is gently down. name it and connect it to what she did."
                )
            }
            if delta >= 0.4 && !ctx.maintenanceMode {
                return Brief(
                    line: "the line drifted up a little. water and rhythm do this. *the week* decides, not the day.",
                    italic: ["the week"],
                    chatSeed: "her trend ticked up ~0.4kg over 7 days. explain fluctuation science calmly, then one anchor for today."
                )
            }
        }

        // 5 — weigh-in day framing
        if ctx.isWeighInDay {
            let line = ctx.weighInIsStaleFallback
                ? "it's been a minute since the scale. one *data point*, zero verdicts."
                : (ctx.maintenanceMode
                    ? "sunday trend check. you're not chasing a number, you're *keeping* one \u{2665}\u{FE0E}"
                    : "trend-line day. thirty seconds, then it's behind you.")
            return Brief(
                line: line,
                italic: ctx.weighInIsStaleFallback ? ["data point"] : (ctx.maintenanceMode ? ["keeping"] : []),
                chatSeed: "today is her weigh-in day. pre-frame it as data, not judgment."
            )
        }

        // 6 — archetype intro (cohort-inflected), the steady default
        return archetypeBrief(ctx)
    }

    private static func archetypeBrief(_ ctx: Context) -> Brief {
        let seedIndex = stableSeed(ctx.dayKey)
        switch ctx.archetype {
        case .protein:
            if ctx.glp1Cohort == .onGlp1, let target = ctx.proteinTargetG {
                return Brief(
                    line: "a protein day. small plates count double — aim near *\(target)g* \u{2665}\u{FE0E}",
                    italic: ["\(target)g"],
                    chatSeed: "protein day on glp-1. she may have low appetite; suggest dense, gentle options."
                )
            }
            let lines = [
                ("a protein day. one *strong* plate at a time.", ["strong"]),
                ("protein leads today. it's the quiet *keeper* of muscle.", ["keeper"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(line: pick.0, italic: pick.1, chatSeed: "protein day. one concrete plate idea if she asks.")
        case .movement:
            return Brief(
                line: "a movement day. it's on the plan because *you* said yes to it.",
                italic: ["you"],
                chatSeed: "movement day. she committed to this cadence; encourage without pressure."
            )
        case .balanced:
            let lines = [
                ("a balanced day. nothing heroic, everything *counted*.", ["counted"]),
                ("today asks for *steady*, not perfect.", ["steady"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(line: pick.0, italic: pick.1, chatSeed: "balanced day. keep it light.")
        case .rest:
            if ctx.glp1Cohort == .postGlp1 {
                return Brief(
                    line: "a rest day. rest is how the *kept* version of you gets built \u{2665}\u{FE0E}",
                    italic: ["kept"],
                    chatSeed: "rest day for a post-glp-1 maintainer. reinforce that rest is part of keeping it."
                )
            }
            return Brief(
                line: "a rest day. softness is *strategy*, not slack \u{2665}\u{FE0E}",
                italic: ["strategy"],
                chatSeed: "rest day. one breath session is the whole assignment."
            )
        }
    }

    /// Stable per-day seed (FNV-1a over the dayKey) so line rotation
    /// never reshuffles within a day and never needs Date.now.
    static func stableSeed(_ dayKey: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in dayKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % 1000)
    }
}
