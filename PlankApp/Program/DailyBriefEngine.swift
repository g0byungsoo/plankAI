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
        /// v5 trust floor: trend language is earned at 3+ weigh-ins
        /// spanning 5+ days — two points a day apart must never claim
        /// "this week." Assembled by TodayStateService; defaults false
        /// so a missing wire fails quiet, not loud.
        var trendIsEstablished: Bool = false
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
        // v6.2 — the passive layer reaches the reading (the coach
        // synthesis: signals interpreted, not just displayed).
        /// Last night's asleep hours (HealthKit; nil = no data).
        var sleepHoursLastNight: Double? = nil
        /// "luteal" / "menstrual" when the season may speak (already
        /// cohort-gated by the assembler); nil otherwise.
        var seasonPhase: String? = nil
        // v7 phase 3 — the letter's memory.
        /// Daily step average over the away stretch (assembler passes
        /// it only for 4-13 day gaps with real counts — the watched
        /// fact).
        var gapStepsDailyAvg: Int? = nil
        /// True exactly once: the first established down-week on
        /// record (assembler owns the once-ever flag).
        var isFirstDownWeekEver: Bool = false
        // v7 — the disclosure loop closes (docs/app_v7/00_THESIS.md
        // §3): yesterday evening's "how did today feel?" chip
        /// ("proud" / "okay" / "tender") when she gave one. A
        /// check-in that is never read back teaches her it was
        /// decorative.
        var yesterdayFeeling: String? = nil
    }

    // MARK: - The cascade
    //
    // v6 register (founder 2026-07-17): direct, factual, succinct.
    // Numbers whenever the data is live; no aphorisms, no "X, not Y"
    // sermons. Warmth stays in the lowercase + the sparse ♥ — never
    // in extra clauses.

    static func brief(for ctx: Context) -> Brief {
        // 0 — on a break: quiet is the plan; everything else yields.
        if ctx.isOnBreak {
            return Brief(
                line: "you're on a break \u{2665}\u{FE0E}",
                italic: ["break"],
                chatSeed: "she's on a deliberate break. no plan talk unless she asks; warmth only.",
                second: "nothing owed. one tap brings the plan back."
            )
        }

        // 1 — the kept promise (day 1-2 only; the loop's first win)
        if ctx.promiseJustKept {
            return Brief(
                line: "you kept your day-one promise \u{2665}\u{FE0E}",
                italic: ["kept"],
                chatSeed: "she kept her day-one promise. acknowledge it and set up today lightly.",
                second: "today: one small thing again. it's on the card."
            )
        }

        // 1.5 — day one: the reading teaches the page itself. The
        //       one-thing card owns the ask; this line owns "how this
        //       works" — the only tutorial the app gets.
        if ctx.programDay == 1 {
            return Brief(
                line: "day one. one card a day, i count the rest \u{2665}\u{FE0E}",
                italic: ["one card"],
                chatSeed: "it's her first day. welcome her warmly, explain the one-thing ritual in one line, ask nothing.",
                // v6.3 — the reading's last line points at the camera:
                // her file starts with a deposit, not a lesson.
                second: "your file starts with one plate. add the last thing you ate."
            )
        }

        // 2 — comeback, in three tiers (v7 phase 3: one flat template
        //     read as app copy the second time she tripped it; a
        //     coach calibrates to the length of the silence).
        if ctx.daysSinceLastOpen >= 14 {
            return Brief(
                line: "it's been a while. this is still day \(ctx.programDay), and the plan still fits.",
                italic: ["still"],
                chatSeed: "she's back after \(ctx.daysSinceLastOpen) days away — a long gap. zero guilt, zero catch-up talk. one plate today is the whole re-entry.",
                second: "we start smaller: one plate today, nothing else."
            )
        }
        if ctx.daysSinceLastOpen >= 4 {
            // The watched fact: her phone kept counting while she was
            // away — proof she was held, not monitored. Provenance:
            // spoken only when steps actually accrued.
            let watched: String? = ctx.gapStepsDailyAvg.map {
                "your steps averaged \($0.formatted()) a day while you were away."
            }
            return Brief(
                line: "back after \(ctx.daysSinceLastOpen) days. this is day \(ctx.programDay), not day zero.",
                italic: ["day \(ctx.programDay)"],
                chatSeed: "she's back after \(ctx.daysSinceLastOpen) days away. no guilt. re-entry plan for today.",
                second: watched.map { "\($0) your plan held its place." }
                    ?? "your plan held its place. one small thing today."
            )
        }
        if ctx.daysSinceLastOpen >= 2 {
            return Brief(
                line: "weekends happen. this is day \(ctx.programDay) \u{2665}\u{FE0E}",
                italic: ["day \(ctx.programDay)"],
                chatSeed: "she's back after a \(ctx.daysSinceLastOpen)-day gap — a light one. normal tone, today's plan.",
                second: "one small thing today and the week carries on."
            )
        }

        // 2.5 — yesterday read tender: the morning receives it (v7
        //       feeling loop). Outranks every logistics thread; the
        //       care-plan tone runs gentle in parallel, so the line
        //       and the day agree. "proud" seasons other lines via
        //       the second sentence rather than claiming the day.
        if ctx.yesterdayFeeling == "tender" {
            return Brief(
                line: "yesterday read tender. today asks for one small thing, nothing else \u{2665}\u{FE0E}",
                italic: ["one small thing"],
                chatSeed: "last evening she marked the day 'tender'. open softly, ask how she's arriving today, no plan talk unless she asks.",
                second: "the plan is lighter on purpose."
            )
        }

        // 3 — rapid-loss care (wires RapidLossTripwire's intent:
        //     >1%/wk sustained → protein reframe, never "slow down")
        if let rate = ctx.lossRatePctPerWeek, rate > 0.01, ctx.trendIsEstablished {
            return Brief(
                line: "you're losing faster than 1% a week. protein protects muscle \u{2665}\u{FE0E}",
                italic: ["protein"],
                chatSeed: "her trend shows faster than 1% per week. explain the lean-mass case for protein without alarm.",
                mechanism: ctx.proteinTargetG.map { "hit your \($0)g floor daily this week. that's the whole adjustment." }
                    ?? "hit your protein floor daily this week. that's the whole adjustment."
            )
        }

        // 3.5 — the keeping chapter's band (zones OPEN actions; an
        //       alert alone is the null-trial mistake)
        if ctx.chapter == .keeping, let zone = ctx.bandZone {
            if zone == BandZone.reset.rawValue {
                return Brief(
                    line: "your trend is about 5 lb over your band. this week gets a reset plan.",
                    italic: ["reset plan"],
                    chatSeed: "her trend crossed the reset line (~5 lb over settle). open a supported multi-week reset: protein-first days, gentle logging, weekly trend checks. care register, zero alarm. regain pressure is biology.",
                    second: "a reset is 2-3 supported weeks. jeni has the plan when you want it.",
                    mechanism: "drift caught at 5 lb takes weeks. caught at 15, months."
                )
            }
            if zone == BandZone.drifting.rawValue {
                return Brief(
                    line: "your trend is drifting 3-5 lb over your band.",
                    italic: ["drifting"],
                    chatSeed: "her trend entered the watch window (~3-5 lb over settle). offer ONE steadying move for this week: protein floor daily, three logged plates, one extra walk. warm, specific, no alarm.",
                    second: "one steadying week: protein floor daily, 3 logged plates, one extra walk."
                )
            }
        }

        // 3.7 — THE NAMED WIN (v7 celebration ladder, tier 2): the
        //       first established down-week on record speaks once,
        //       by name. Routine wins stay quiet receipts so this
        //       one can actually land.
        if ctx.isFirstDownWeekEver {
            return Brief(
                line: "your first down week on record \u{2665}\u{FE0E}",
                italic: ["first"],
                chatSeed: "her trend just posted its first established down week ever. name it warmly, once; ask nothing today.",
                second: "the trend line bent your way. same plan this week."
            )
        }

        // 4 — trend movement worth naming (EMA, never raw drama;
        //     v5: only once the trend has earned a voice; v6: the
        //     number itself, in her unit)
        if let delta = ctx.emaDelta7dKg, ctx.trendIsEstablished {
            if delta <= -0.2 {
                return Brief(
                    line: "your trend is down \(deltaWord(delta)) this week \u{2665}\u{FE0E}",
                    italic: [deltaWord(delta)],
                    chatSeed: "her 7-day trend is down. name the number and connect it to what she did.",
                    mechanism: ctx.proteinDays7 >= 3
                        ? "protein landed \(ctx.proteinDays7) of 7 days."
                        : (ctx.loggedDays7 >= 3
                            ? "\(ctx.loggedDays7) logged days this week."
                            : nil)
                )
            }
            if delta >= 0.4 && !ctx.maintenanceMode {
                return Brief(
                    line: "your trend is up \(deltaWord(delta)). usually water, not fat.",
                    italic: ["water"],
                    chatSeed: "her trend ticked up ~0.4kg over 7 days. explain fluctuation science calmly, then one anchor for today.",
                    mechanism: ctx.weekday == 2
                        ? "monday numbers carry weekend salt. they clear in days."
                        : "day swings are fluid shifts. the 7-day line is the real read."
                )
            }
            // keeping chapter: the band held — say so (satisfaction is
            // the maintenance fuel; research/UX_PATTERNS §Q4).
            if ctx.chapter == .keeping, abs(delta) <= 0.3 {
                return Brief(
                    line: "another week inside your band \u{2665}\u{FE0E}",
                    italic: ["inside"],
                    chatSeed: "maintenance week held steady. reinforce what holding proves about her, no new asks.",
                    second: "nothing to fix. same rhythm."
                )
            }
        }

        // 5 — weigh-in day framing
        if ctx.isWeighInDay {
            let line = ctx.weighInIsStaleFallback
                ? "no weigh-in in a while. one number restarts your line."
                : (ctx.maintenanceMode
                    ? "sunday check-in. one number keeps your band honest \u{2665}\u{FE0E}"
                    : "weigh-in day. 30 seconds, then done.")
            return Brief(
                line: line,
                italic: ctx.weighInIsStaleFallback ? ["one number"] : (ctx.maintenanceMode ? ["band"] : ["30 seconds"]),
                chatSeed: "today is her weigh-in day. pre-frame it as data, not judgment."
            )
        }

        // 5.2 — a short night, named before it becomes a verdict
        //       (Tasali: sleep debt reads as hunger; the coach names
        //       the chemistry so she doesn't name herself).
        if let sleep = ctx.sleepHoursLastNight, sleep < 6 {
            let h = Int(sleep)
            let m = Int((sleep - Double(h)) * 60)
            return Brief(
                line: "you slept \(h)h \(m)m. expect stronger hunger today \u{2665}\u{FE0E}",
                italic: ["stronger"],
                chatSeed: "she slept under 6 hours. frame today's appetite as sleep chemistry, keep the plan gentle, no homework.",
                second: "protein first and no verdicts today."
            )
        }

        // 5.3 — her season, spoken by the coach (alternate days so
        //       the luteal stretch doesn't repeat one opener).
        if let phase = ctx.seasonPhase, stableSeed(ctx.dayKey) % 2 == 0 {
            if phase == "luteal" {
                return Brief(
                    line: "the hungrier week of your cycle is here. it passes \u{2665}\u{FE0E}",
                    italic: ["hungrier"],
                    chatSeed: "she's in her luteal stretch: appetite and water weight both run higher. normalize it, protein first, never predict dates.",
                    second: "protein first helps. the scale may drift up; that's water."
                )
            }
            if phase == "menstrual" {
                return Brief(
                    line: "period days. smaller plates are fine \u{2665}\u{FE0E}",
                    italic: ["fine"],
                    chatSeed: "she's on her period. extra gentleness; appetite settles as it passes; protein still anchors the day.",
                    second: "protein still first, everything else can soften."
                )
            }
        }

        // 5.4 — the synthesis line: two signals strong on the same
        //       morning is the coach's favorite sentence.
        if let window = ctx.overnightQuietHours, window >= 12, window < 16,
           let sleep = ctx.sleepHoursLastNight, sleep >= 7,
           stableSeed(ctx.dayKey) % 2 == 1 {
            let sh = Int(sleep)
            let sm = Int((sleep - Double(sh)) * 60)
            return Brief(
                line: "a \(Int(window.rounded()))h overnight fast and \(sh)h \(sm)m of sleep \u{2665}\u{FE0E}",
                italic: ["fast"],
                chatSeed: "her overnight window held ~\(Int(window.rounded()))h and she slept \(sh)h\(sm)m. name the good ground; one small ask only.",
                second: "today starts on your side."
            )
        }

        // 5.5 — the easiest lever, acknowledged (steps are the one
        //       behavior this cohort already believes in)
        if ctx.yesterdayStepsHitGoal, stableSeed(ctx.dayKey) % 3 == 0 {
            return Brief(
                line: "you passed your step goal yesterday \u{2665}\u{FE0E}",
                italic: ["passed"],
                chatSeed: "she hit her step goal yesterday. connect walking to the plan without turning it into a fitness thing."
            )
        }

        // 5.6 — a new program week opens (Monday-of-her-week mints
        //       the fresh start; the name pre-interprets the days)
        if let name = ctx.weekOpensName, ctx.weekOrdinal > 1 {
            return Brief(
                line: "week \(ctx.weekOrdinal): \(name).",
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
                line: "last night's plan: \(plan) \u{2665}\u{FE0E}",
                italic: [plan],
                chatSeed: "she set an if-then plan for last night ('\(plan)'). acknowledge the planning habit itself; don't grade whether it held.",
                second: "tonight can have one too."
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
                    line: "protein day. aim near \(target)g \u{2665}\u{FE0E}",
                    italic: ["\(target)g"],
                    chatSeed: "protein day on glp-1. she may have low appetite; suggest dense, gentle options.",
                    second: "small, dense plates work best on a low appetite.",
                    mechanism: {
                        // Her own sit-note from last evening, reflected
                        // back — HER pattern, never an asserted cycle.
                        switch ctx.yesterdaySat {
                        case "heavy": return "yesterday sat heavy. today's plates run smaller."
                        case "queasy": return "yesterday sat queasy. mild plates, fluids first."
                        default: return nil
                        }
                    }()
                )
            }
            let target = ctx.proteinTargetG
            let lines: [(String, [String])] = [
                (target.map { "protein day. aim near \($0)g." } ?? "protein day. one strong plate at a time.",
                 target.map { ["\($0)g"] } ?? ["strong"]),
                ("protein day. it holds muscle while weight drops.", ["muscle"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(line: pick.0, italic: pick.1, chatSeed: "protein day. one concrete plate idea if she asks.")
        case .movement:
            return Brief(
                line: "movement day. a short session, your pace.",
                italic: ["your pace"],
                chatSeed: "movement day. she committed to this cadence; encourage without pressure."
            )
        case .balanced:
            let lines: [(String, [String])] = [
                ("a balanced day. every row counts once.", ["once"]),
                ("a balanced day. nothing big, just the rows.", ["the rows"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(
                line: pick.0, italic: pick.1,
                chatSeed: "balanced day. keep it light.",
                mechanism: ctx.overnightQuietHours.flatMap { hours in
                    hours >= 12
                        ? "a \(Int(hours.rounded()))h overnight fast, without trying."
                        : nil
                }
            )
        case .rest:
            if ctx.glp1Cohort == .postGlp1 {
                return Brief(
                    line: "rest day. recovery is part of keeping it \u{2665}\u{FE0E}",
                    italic: ["keeping"],
                    chatSeed: "rest day for a post-glp-1 maintainer. reinforce that rest is part of keeping it."
                )
            }
            return Brief(
                line: "rest day. one minute of breath is the only ask \u{2665}\u{FE0E}",
                italic: ["breath"],
                chatSeed: "rest day. one breath session is the whole assignment."
            )
        }
    }

    /// "0.4 kg" / "0.9 lb" — the 7-day delta in her display unit.
    /// Clamped at 0.1 so an established trend never prints "0.0".
    private static func deltaWord(_ deltaKg: Double) -> String {
        let unit = WeightUnit.current
        let display = max(0.1, unit.display(fromKg: abs(deltaKg)))
        return String(format: "%.1f %@", display, unit.label)
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
