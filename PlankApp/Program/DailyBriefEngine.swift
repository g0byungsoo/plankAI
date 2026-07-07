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
        /// v3 reading: an optional second sentence that continues the
        /// thread (never previews tasks — the one-thing card owns the
        /// ask). Same determinism + provenance rules as `line`.
        var second: String? = nil
        var secondItalic: [String] = []
        /// v3 reading: the quiet mechanism caption under the reading
        /// ("protein landed 5 of 7 days. that's the mechanism.") —
        /// rendered only when the data behind it is real.
        var mechanism: String? = nil
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
        /// Yesterday's steps vs goal — the easiest-lever thread.
        var yesterdayStepsHitGoal: Bool
        var maintenanceMode: Bool
        var glp1Cohort: Glp1Cohort
        var dayKey: String            // "2026-07-03" — the seed
        // v3 reading fields (all optional/defaulted so existing call
        // sites and tests stay valid; absent = the clause is skipped)
        var chapter: Chapter = .losing
        var isOnBreak: Bool = false
        /// Days in the trailing 7 with at least one logged plate.
        var loggedDays7: Int = 0
        /// Days in the trailing 7 where protein reached ~the target.
        var proteinDays7: Int = 0
        /// 1 = Sunday … 7 = Saturday (Calendar weekday numbering).
        var weekday: Int = 0
        /// Keeping chapter only: today's band zone (BandZone.rawValue).
        var bandZone: String? = nil
        /// On-medication: yesterday's "how did today sit?" answer
        /// (fine / heavy / queasy) when she gave one.
        var yesterdaySat: String? = nil
        /// The quiet hours — last night's plate-to-plate stretch
        /// (nil when unnarratable or hard-gated; QuietHours).
        var overnightQuietHours: Double? = nil
        /// v4 — yesterday evening's tonight-plan label ("ride the
        /// wave") when she set one; the morning names it back so the
        /// 15-second plan gets its receipt (the loop closes without
        /// grading whether it held).
        var lastNightPlan: String? = nil
        /// v4 — the named week, on its opening day only (nil on days
        /// 2-7): the reading announces the fresh page.
        var weekOpensName: String? = nil
        var weekOpensLine: String? = nil
        var weekOrdinal: Int = 0
    }

    // MARK: - The cascade

    static func brief(for ctx: Context) -> Brief {
        // 0 — on a break: quiet is the plan; everything else yields.
        if ctx.isOnBreak {
            return Brief(
                line: "you're on a break. your place is kept \u{2665}\u{FE0E}",
                italic: ["kept"],
                chatSeed: "she's on a deliberate break. no plan talk unless she asks; warmth only.",
                second: "nothing owed today. come back when you're ready."
            )
        }

        // 1 — the kept promise (day 1-2 only; the loop's first win)
        if ctx.promiseJustKept {
            return Brief(
                line: "you did the thing you said you'd do. that's the whole skill \u{2665}\u{FE0E}",
                italic: ["skill"],
                chatSeed: "she kept her day-one promise. acknowledge it and set up today lightly.",
                second: "today asks for one small thing again. that's the whole pattern."
            )
        }

        // 2 — comeback (2+ days away beats everything else; the
        //     return moment is where retention is won or lost)
        if ctx.daysSinceLastOpen >= 2 {
            return Brief(
                line: "back after \(ctx.daysSinceLastOpen) days. begin again is the strategy, not the failure \u{2665}\u{FE0E}",
                italic: ["begin again"],
                chatSeed: "she's back after \(ctx.daysSinceLastOpen) days away. no guilt. re-entry plan for today.",
                second: "the plan kept your place. today is day \(ctx.programDay), not day zero."
            )
        }

        // 3 — rapid-loss care (wires RapidLossTripwire's intent:
        //     >1%/wk sustained → protein reframe, never "slow down")
        if let rate = ctx.lossRatePctPerWeek, rate > 0.01 {
            return Brief(
                line: "you're moving quickly. a protein-forward week keeps it lean \u{2665}\u{FE0E}",
                italic: ["protein-forward"],
                chatSeed: "her trend shows faster than 1% per week. explain the lean-mass case for protein without alarm.",
                mechanism: "fast weeks can spend muscle. protein first tells your body what to keep."
            )
        }

        // 3.5 — the keeping chapter's band (zones OPEN actions; an
        //       alert alone is the null-trial mistake)
        if ctx.chapter == .keeping, let zone = ctx.bandZone {
            if zone == BandZone.reset.rawValue {
                return Brief(
                    line: "the line has drifted past your band. that's physiology asking for a plan, not a verdict \u{2665}\u{FE0E}",
                    italic: ["a plan"],
                    chatSeed: "her trend crossed the reset line (~5 lb over settle). open a supported multi-week reset: protein-first days, gentle logging, weekly trend checks. care register, zero alarm. regain pressure is biology.",
                    second: "a reset is a few supported weeks, not a confession. jeni holds the plan.",
                    mechanism: "catching drift early is the whole trick. most people wait twice as long."
                )
            }
            if zone == BandZone.drifting.rawValue {
                return Brief(
                    line: "the line is drifting a little. this is the exact week to steady it, gently.",
                    italic: ["steady"],
                    chatSeed: "her trend entered the watch window (~3-5 lb over settle). offer ONE steadying move for this week: protein floor daily, three logged plates, one extra walk. warm, specific, no alarm.",
                    second: "one steadying week usually settles the line. protein first, nothing dramatic.",
                    mechanism: "drift caught at a few pounds is a week's work. that's why we watch the line."
                )
            }
        }

        // 4 — trend movement worth naming (EMA, never raw drama)
        if let delta = ctx.emaDelta7dKg {
            if delta <= -0.2 {
                return Brief(
                    line: "your trend line eased down this week. quiet, real movement.",
                    italic: ["real"],
                    chatSeed: "her 7-day trend is gently down. name it and connect it to what she did.",
                    mechanism: ctx.proteinDays7 >= 3
                        ? "protein landed \(ctx.proteinDays7) of 7 days. that's the mechanism, not magic."
                        : (ctx.loggedDays7 >= 3
                            ? "\(ctx.loggedDays7) logged days this week did that. quiet math."
                            : nil)
                )
            }
            if delta >= 0.4 && !ctx.maintenanceMode {
                return Brief(
                    line: "the line drifted up a little. water and rhythm do this. the week decides, not the day.",
                    italic: ["the week"],
                    chatSeed: "her trend ticked up ~0.4kg over 7 days. explain fluctuation science calmly, then one anchor for today.",
                    mechanism: ctx.weekday == 2
                        ? "monday numbers carry the weekend's salt. they clear on their own."
                        : "day-to-day swings are chemistry, not verdicts. the line reads the week."
                )
            }
            // keeping chapter: the band held — say so (satisfaction is
            // the maintenance fuel; research/UX_PATTERNS §Q4).
            if ctx.chapter == .keeping, abs(delta) <= 0.3 {
                return Brief(
                    line: "another week inside your band. holding is the win \u{2665}\u{FE0E}",
                    italic: ["holding"],
                    chatSeed: "maintenance week held steady. reinforce what holding proves about her, no new asks.",
                    second: "nothing to fix today. rhythm over rescue."
                )
            }
        }

        // 5 — weigh-in day framing
        if ctx.isWeighInDay {
            let line = ctx.weighInIsStaleFallback
                ? "it's been a minute since the scale. one data point, zero verdicts."
                : (ctx.maintenanceMode
                    ? "sunday trend check. you're not chasing a number, you're keeping one \u{2665}\u{FE0E}"
                    : "trend-line day. thirty seconds, then it's behind you.")
            return Brief(
                line: line,
                italic: ctx.weighInIsStaleFallback ? ["data point"] : (ctx.maintenanceMode ? ["keeping"] : []),
                chatSeed: "today is her weigh-in day. pre-frame it as data, not judgment."
            )
        }

        // 5.5 — the easiest lever, acknowledged (steps are the one
        //       behavior this cohort already believes in)
        if ctx.yesterdayStepsHitGoal, stableSeed(ctx.dayKey) % 3 == 0 {
            return Brief(
                line: "your legs hit the goal yesterday. the easiest lever is already moving \u{2665}\u{FE0E}",
                italic: ["easiest lever"],
                chatSeed: "she hit her step goal yesterday. connect walking to the plan without turning it into a fitness thing."
            )
        }

        // 5.6 — a new program week opens (Monday-of-her-week mints
        //       the fresh start; the name pre-interprets the days)
        if let name = ctx.weekOpensName, ctx.weekOrdinal > 1 {
            return Brief(
                line: "week \(ctx.weekOrdinal) opens: \(name).",
                italic: [name],
                chatSeed: "her program week \(ctx.weekOrdinal) ('\(name)') begins today. set the week's intent in one warm line; one small first move.",
                second: ctx.weekOpensLine
            )
        }

        // 5.7 — the tonight plan, named back (every plan earns its
        //       morning receipt; alternate days so nightly planners
        //       don't hear the same opener forever)
        if let plan = ctx.lastNightPlan, stableSeed(ctx.dayKey) % 2 == 0 {
            return Brief(
                line: "last night had a plan: \(plan). making the plan is the practice \u{2665}\u{FE0E}",
                italic: [plan],
                chatSeed: "she set an if-then plan for last night ('\(plan)'). acknowledge the planning habit itself; don't grade whether it held.",
                second: "tonight can have one too. the close will ask."
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
                    line: "a protein day. small plates count double. aim near \(target)g \u{2665}\u{FE0E}",
                    italic: ["\(target)g"],
                    chatSeed: "protein day on glp-1. she may have low appetite; suggest dense, gentle options.",
                    mechanism: {
                        // Her own sit-note from last evening, reflected
                        // back — HER pattern, never an asserted cycle.
                        switch ctx.yesterdaySat {
                        case "heavy": return "yesterday sat heavy. today's plates run smaller and gentler on purpose."
                        case "queasy": return "yesterday sat queasy. slow bites, mild plates, fluids first today."
                        default: return nil
                        }
                    }()
                )
            }
            let lines = [
                ("a protein day. one strong plate at a time.", ["strong"]),
                ("protein leads today. it's the quiet keeper of muscle.", ["keeper"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(line: pick.0, italic: pick.1, chatSeed: "protein day. one concrete plate idea if she asks.")
        case .movement:
            return Brief(
                line: "a movement day. it's on the plan because you said yes to it.",
                italic: ["you"],
                chatSeed: "movement day. she committed to this cadence; encourage without pressure."
            )
        case .balanced:
            let lines = [
                ("a balanced day. nothing heroic, everything counted.", ["counted"]),
                ("today asks for steady, not perfect.", ["steady"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(
                line: pick.0, italic: pick.1,
                chatSeed: "balanced day. keep it light.",
                mechanism: ctx.overnightQuietHours.flatMap { hours in
                    hours >= 12
                        ? "about \(Int(hours.rounded())) quiet hours overnight, without trying. that rhythm does real work."
                        : nil
                }
            )
        case .rest:
            if ctx.glp1Cohort == .postGlp1 {
                return Brief(
                    line: "a rest day. rest is how the kept version of you gets built \u{2665}\u{FE0E}",
                    italic: ["kept"],
                    chatSeed: "rest day for a post-glp-1 maintainer. reinforce that rest is part of keeping it."
                )
            }
            return Brief(
                line: "a rest day. softness is strategy, not slack \u{2665}\u{FE0E}",
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
