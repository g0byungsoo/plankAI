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
// the `italic` array (never markdown), terminal + sparse, no
// em-dashes, no diet-culture verbs, numbers only when live.

enum DailyBriefEngine {

    /// v25 E4 — yesterday, receipted. The typed ledger of what she
    /// actually gave the product yesterday; every field provenance-
    /// gated at assembly (absence = nil/0, never a fabricated zero).
    /// Rendered as one quiet line under the letter, reused verbatim
    /// by the day-anchor push so in-app and push never diverge.
    struct YesterdayReceipt: Equatable {
        var plateCount: Int = 0
        /// Summed protein when yesterday had ≥1 plate. nil = no record
        /// or numeric suppression.
        var proteinG: Int? = nil
        /// Summed kcal, same gates. Never rendered in the letter (a
        /// morning total reads as a verdict); the recap may use it.
        var kcal: Int? = nil
        var weighedIn: Bool = false
        var keptBeats: Int = 0
        /// Her evening word, verbatim ("proud" / "okay" / "tender").
        var feeling: String? = nil

        /// The letter's one-line render: "2 plates · 76g protein ·
        /// weighed in · closed proud". Empty string when nothing is
        /// on record (callers hide the row).
        var ledgerLine: String {
            var parts: [String] = []
            if plateCount == 1 { parts.append("one plate") }
            if plateCount > 1 { parts.append("\(plateCount) plates") }
            if let p = proteinG, plateCount > 0 { parts.append("\(p)g protein") }
            if weighedIn { parts.append("weighed in") }
            if let feeling { parts.append("closed \(feeling)") }
            return parts.joined(separator: " · ")
        }
    }

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
        /// v25 E4 — stable id of the cascade clause that claimed the
        /// day (analytics + tests + push payload selection).
        var clause: String = ""
        /// v25 E4 — yesterday's receipt; nil when yesterday left no
        /// record (an unlogged day is absence, not zero).
        var receipt: YesterdayReceipt? = nil
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
        /// E8.2 — the tomorrow intention she SET in last night's close
        /// (its drafted text, verbatim). An intention that never reads
        /// back is theater; this is the payout half of the loop.
        var morningIntention: String? = nil
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
        // v25 E4 — DAY TWO: yesterday at n=1 scale. Assembled from
        // the device-local food store + the weight record + the
        // check records; every default is "no record".
        /// Plates logged yesterday (0 = nothing on file).
        var yesterdayPlateCount: Int = 0
        /// Summed protein over yesterday's plates when ≥1 plate.
        /// (Distinct from CarePlanEngine's ≥2-plate promotion gate —
        /// a RECEIPT states what's on file; a JUDGMENT needs more.)
        var yesterdayProteinG: Int? = nil
        /// Summed kcal over yesterday's plates when ≥1 plate.
        var yesterdayKcal: Int? = nil
        /// A manual weigh-in landed yesterday (onboarding seed never
        /// counts — it isn't a morning she gave the product).
        var yesterdayWeighedIn: Bool = false
        /// Checklist beats completed yesterday.
        var yesterdayKeptBeats: Int = 0
        /// Manual weigh-ins on record (for "your line is forming"
        /// honesty before the trend earns a voice).
        var weighInCount: Int = 0
        /// Safety-gate numeric suppression (ED / pregnancy outputs):
        /// the receipt drops its numbers, words stay.
        var numericSuppressed: Bool = false
    }

    // MARK: - The cascade
    //
    // v6 register (founder 2026-07-17): direct, factual, succinct.
    // Numbers whenever the data is live; no aphorisms, no "X, not Y"
    // sermons. Warmth stays in the lowercase + the sparse — never
    // in extra clauses.

    static func brief(for ctx: Context) -> Brief {
        var brief = cascade(for: ctx)
        brief.receipt = receipt(for: ctx)
        // De-dup (frame-caught): when the clause itself reads the
        // plates back ("your file started. 5 plates yesterday…"),
        // the ledger row repeats the same two numbers directly
        // beneath the prose. On those mornings the row keeps only
        // what the prose didn't say (weigh-in · her word).
        if brief.clause == "day_two" || brief.clause == "yesterday_read" {
            brief.receipt?.plateCount = 0
            brief.receipt?.proteinG = nil
            brief.receipt?.kcal = nil
        }
        // E8.2 — the intention set in last night's close reads back
        // FIRST: it is the one sentence with something to do in the
        // next hour, and an intention that never resurfaces is theater
        // (the implementation-intention effect assumes the plan meets
        // the moment it names).
        if let intention = ctx.morningIntention, brief.second == nil,
           !ctx.isOnBreak {
            brief.second = "you set this last night: \(intention)"
            brief.secondItalic = ["last night:"]
        }
        // v25 E4 — the proud seasoning: the v7 comment promised that
        // "proud" seasons other lines via the second sentence. Now it
        // does. (Tender claims the day upstream; "okay" stays a quiet
        // receipt word — neutrality read back as prose would grade it.)
        if ctx.yesterdayFeeling == "proud", brief.second == nil,
           !ctx.isOnBreak, ctx.programDay > 1 {
            brief.second = "you closed yesterday proud. that carries."
            brief.secondItalic = ["proud"]
        }
        return brief
    }

    /// The receipt exists whenever yesterday left ANY record — and
    /// never before day 2 (day one has no yesterday in-program).
    static func receipt(for ctx: Context) -> YesterdayReceipt? {
        guard ctx.programDay >= 2 else { return nil }
        let hasRecord = ctx.yesterdayPlateCount > 0 || ctx.yesterdayWeighedIn
            || ctx.yesterdayKeptBeats > 0 || ctx.yesterdayFeeling != nil
        guard hasRecord else { return nil }
        return YesterdayReceipt(
            plateCount: ctx.yesterdayPlateCount,
            proteinG: ctx.numericSuppressed ? nil : ctx.yesterdayProteinG,
            kcal: ctx.numericSuppressed ? nil : ctx.yesterdayKcal,
            weighedIn: ctx.yesterdayWeighedIn,
            keptBeats: ctx.yesterdayKeptBeats,
            feeling: ctx.yesterdayFeeling
        )
    }

    private static func cascade(for ctx: Context) -> Brief {
        // 0 — on a break: quiet is the plan; everything else yields.
        if ctx.isOnBreak {
            return Brief(
                line: "you're on a break",
                italic: ["break"],
                chatSeed: "they're on a deliberate break. no plan talk unless they ask; warmth only.",
                second: "nothing owed. one tap brings the plan back.",
                clause: "break"
            )
        }

        // 1 — the kept promise (day 1-2 only; the loop's first win)
        if ctx.promiseJustKept {
            return Brief(
                line: "you kept your day-one promise",
                italic: ["kept"],
                chatSeed: "they kept their day-one promise. acknowledge it and set up today lightly.",
                second: "today: one small thing again. it's on the card.",
                clause: "promise_kept"
            )
        }

        // 1.5 — day one: the reading teaches the page itself. The
        //       one-thing card owns the ask; this line owns "how this
        //       works" — the only tutorial the app gets.
        if ctx.programDay == 1 {
            return Brief(
                line: "day one. one card a day, i count the rest",
                italic: ["one card"],
                chatSeed: "it's their first day. welcome their warmly, explain the one-thing ritual in one line, ask nothing.",
                // v6.3 — the reading's last line points at the camera:
                // her file starts with a deposit, not a lesson.
                second: "your file starts with one plate. add the last thing you ate.",
                clause: "day_one"
            )
        }

        // 2 — comeback, in three tiers (v7 phase 3: one flat template
        //     read as app copy the second time she tripped it; a
        //     coach calibrates to the length of the silence).
        if ctx.daysSinceLastOpen >= 14 {
            return Brief(
                line: "it's been a while. this is still day \(ctx.programDay), and the plan still fits.",
                italic: ["still"],
                chatSeed: "they're back after \(ctx.daysSinceLastOpen) days away. a long gap. zero guilt, zero catch-up talk. one plate today is the whole re-entry.",
                second: "we start smaller: one plate today, nothing else.",
                clause: "comeback_long"
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
                chatSeed: "they're back after \(ctx.daysSinceLastOpen) days away. no guilt. re-entry plan for today.",
                second: watched.map { "\($0) your plan held its place." }
                    ?? "your plan held its place. one small thing today.",
                clause: "comeback_mid"
            )
        }
        if ctx.daysSinceLastOpen >= 2 {
            return Brief(
                line: "weekends happen. this is day \(ctx.programDay)",
                italic: ["day \(ctx.programDay)"],
                chatSeed: "they're back after a \(ctx.daysSinceLastOpen)-day gap. a light one. normal tone, today's plan.",
                second: "one small thing today and the week carries on.",
                clause: "comeback_short"
            )
        }

        // 2.5 — yesterday read tender: the morning receives it (v7
        //       feeling loop). Outranks every logistics thread; the
        //       care-plan tone runs gentle in parallel, so the line
        //       and the day agree. "proud" seasons other lines via
        //       the second sentence rather than claiming the day.
        if ctx.yesterdayFeeling == "tender" {
            return Brief(
                line: "yesterday read tender. today asks for one small thing, nothing else",
                italic: ["one small thing"],
                chatSeed: "last evening they marked the day 'tender'. open softly, ask how they're arriving today, no plan talk unless they ask.",
                second: "the plan is lighter on purpose.",
                clause: "tender"
            )
        }

        // 2.7 — DAY TWO (v25 E4): the first week's mornings read
        //       yesterday back at n=1 scale. This is the product's
        //       promise ("i count the rest") kept on the first
        //       morning it can be. Self-retires after week 1 — from
        //       week 2 the trend and week clauses own the line, and
        //       the receipt row keeps carrying the ledger.
        if ctx.programDay >= 2, ctx.programDay <= 7,
           ctx.daysSinceLastOpen <= 1,
           ctx.yesterdayPlateCount >= 1, !ctx.numericSuppressed {
            let plateWord = ctx.yesterdayPlateCount == 1
                ? "one plate" : "\(ctx.yesterdayPlateCount) plates"
            // The forming line: a weigh-in acknowledged before the
            // trend can speak — honesty as the reward (L5 closed).
            let forming: String? = (ctx.yesterdayWeighedIn && !ctx.trendIsEstablished)
                ? "your weight line is forming. a direction takes a few more mornings."
                : nil
            if ctx.programDay == 2 {
                return Brief(
                    line: "your file started. \(plateWord) yesterday.",
                    italic: [plateWord],
                    chatSeed: "day two, and yesterday is on file (\(plateWord)). read it back warmly in one line, then today's one thing.",
                    second: ctx.yesterdayProteinG.flatMap { p in
                        guard p > 0 else { return nil }
                        return ctx.proteinTargetG.map {
                            "about \(p)g protein on record. today's floor is \($0)g."
                        } ?? "about \(p)g protein on record."
                    },
                    mechanism: forming,
                    clause: "day_two"
                )
            }
            if let p = ctx.yesterdayProteinG, let target = ctx.proteinTargetG,
               p >= target {
                return Brief(
                    line: "yesterday held your protein floor",
                    italic: ["held"],
                    chatSeed: "yesterday cleared their protein floor (\(p)g of \(target)g). name it once, then today's one thing.",
                    second: "\(p)g against your \(target)g floor.",
                    mechanism: forming,
                    clause: "yesterday_read"
                )
            }
            let proteinPart = ctx.yesterdayProteinG.flatMap { p in
                p > 0 ? ", about \(p)g protein" : nil
            } ?? ""
            return Brief(
                line: "yesterday's on file: \(plateWord)\(proteinPart)",
                italic: ["on file"],
                chatSeed: "yesterday had \(plateWord)\(proteinPart). read the day back in one warm line; one concrete idea for today if they ask.",
                second: ctx.proteinTargetG.map { "today's floor is \($0)g." },
                mechanism: forming,
                clause: "yesterday_read"
            )
        }

        // 3 — rapid-loss care (wires RapidLossTripwire's intent:
        //     >1%/wk sustained → protein reframe, never "slow down")
        if let rate = ctx.lossRatePctPerWeek, rate > 0.01, ctx.trendIsEstablished {
            return Brief(
                line: "you're losing faster than 1% a week. protein protects muscle",
                italic: ["protein"],
                chatSeed: "their trend shows faster than 1% per week. explain the lean-mass case for protein without alarm.",
                mechanism: ctx.proteinTargetG.map { "hit your \($0)g floor daily this week. that's the whole adjustment." }
                    ?? "hit your protein floor daily this week. that's the whole adjustment.",
                clause: "rapid_loss"
            )
        }

        // 3.5 — the keeping chapter's band (zones OPEN actions; an
        //       alert alone is the null-trial mistake)
        if ctx.chapter == .keeping, let zone = ctx.bandZone {
            if zone == BandZone.reset.rawValue {
                return Brief(
                    line: "your trend is about 5 lb over your band. this week gets a reset plan.",
                    italic: ["reset plan"],
                    chatSeed: "their trend crossed the reset line (~5 lb over settle). open a supported multi-week reset: protein-first days, gentle logging, weekly trend checks. care register, zero alarm. regain pressure is biology.",
                    second: "a reset is 2-3 supported weeks. jeni has the plan when you want it.",
                    mechanism: "drift caught at 5 lb takes weeks. caught at 15, months.",
                    clause: "band_reset"
                )
            }
            if zone == BandZone.drifting.rawValue {
                return Brief(
                    line: "your trend is drifting 3-5 lb over your band.",
                    italic: ["drifting"],
                    chatSeed: "their trend entered the watch window (~3-5 lb over settle). offer ONE steadying move for this week: protein floor daily, three logged plates, one extra walk. warm, specific, no alarm.",
                    second: "one steadying week: protein floor daily, 3 logged plates, one extra walk.",
                    clause: "band_drifting"
                )
            }
        }

        // 3.7 — THE NAMED WIN (v7 celebration ladder, tier 2): the
        //       first established down-week on record speaks once,
        //       by name. Routine wins stay quiet receipts so this
        //       one can actually land.
        if ctx.isFirstDownWeekEver {
            return Brief(
                line: "your first down week on record",
                italic: ["first"],
                chatSeed: "their trend just posted its first established down week ever. name it warmly, once; ask nothing today.",
                second: "the trend line bent your way. same plan this week.",
                clause: "first_down_week"
            )
        }

        // 4 — trend movement worth naming (EMA, never raw drama;
        //     v5: only once the trend has earned a voice; v6: the
        //     number itself, in her unit)
        if let delta = ctx.emaDelta7dKg, ctx.trendIsEstablished {
            if delta <= -0.2 {
                return Brief(
                    line: "your trend is down \(deltaWord(delta)) this week",
                    italic: [deltaWord(delta)],
                    chatSeed: "them 7-day trend is down. name the number and connect it to what they did.",
                    mechanism: ctx.proteinDays7 >= 3
                        ? "protein landed \(ctx.proteinDays7) of 7 days."
                        : (ctx.loggedDays7 >= 3
                            ? "\(ctx.loggedDays7) logged days this week."
                            : nil),
                    clause: "trend_down"
                )
            }
            if delta >= 0.4 && !ctx.maintenanceMode {
                return Brief(
                    line: "your trend is up \(deltaWord(delta)). usually water, not fat.",
                    italic: ["water"],
                    chatSeed: "their trend ticked up ~0.4kg over 7 days. explain fluctuation science calmly, then one anchor for today.",
                    mechanism: ctx.weekday == 2
                        ? "monday numbers carry weekend salt. they clear in days."
                        : "day swings are fluid shifts. the 7-day line is the real read.",
                    clause: "trend_up"
                )
            }
            // keeping chapter: the band held — say so (satisfaction is
            // the maintenance fuel; research/UX_PATTERNS §Q4).
            if ctx.chapter == .keeping, abs(delta) <= 0.3 {
                return Brief(
                    line: "another week inside your band",
                    italic: ["inside"],
                    chatSeed: "maintenance week held steady. reinforce what holding proves about them, no new asks.",
                    second: "nothing to fix. same rhythm.",
                    clause: "band_held"
                )
            }
        }

        // 5 — weigh-in day framing
        if ctx.isWeighInDay {
            let line = ctx.weighInIsStaleFallback
                ? "no weigh-in in a while. one number restarts your line."
                : (ctx.maintenanceMode
                    ? "sunday check-in. one number keeps your band honest"
                    : "weigh-in day. 30 seconds, then done.")
            return Brief(
                line: line,
                italic: ctx.weighInIsStaleFallback ? ["one number"] : (ctx.maintenanceMode ? ["band"] : ["30 seconds"]),
                chatSeed: "today is their weigh-in day. pre-frame it as data, not judgment.",
                clause: "weigh_day"
            )
        }

        // 5.2 — a short night, named before it becomes a verdict
        //       (Tasali: sleep debt reads as hunger; the coach names
        //       the chemistry so she doesn't name herself).
        if let sleep = ctx.sleepHoursLastNight, sleep < 6 {
            let h = Int(sleep)
            let m = Int((sleep - Double(h)) * 60)
            return Brief(
                line: "you slept \(h)h \(m)m. expect stronger hunger today",
                italic: ["stronger"],
                chatSeed: "they slept under 6 hours. frame today's appetite as sleep chemistry, keep the plan gentle, no homework.",
                second: "protein first and no verdicts today.",
                clause: "short_sleep"
            )
        }

        // 5.3 — her season, spoken by the coach (alternate days so
        //       the luteal stretch doesn't repeat one opener).
        if let phase = ctx.seasonPhase, stableSeed(ctx.dayKey) % 2 == 0 {
            if phase == "luteal" {
                return Brief(
                    line: "the hungrier week of your cycle is here. it passes",
                    italic: ["hungrier"],
                    chatSeed: "they're in their luteal stretch: appetite and water weight both run higher. normalize it, protein first, never predict dates.",
                    second: "protein first helps. the scale may drift up; that's water.",
                    clause: "season_luteal"
                )
            }
            if phase == "menstrual" {
                return Brief(
                    line: "period days. smaller plates are fine",
                    italic: ["fine"],
                    chatSeed: "they're on their period. extra gentleness; appetite settles as it passes; protein still anchors the day.",
                    second: "protein still first, everything else can soften.",
                    clause: "season_menstrual"
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
                line: "a \(Int(window.rounded()))h overnight fast and \(sh)h \(sm)m of sleep",
                italic: ["fast"],
                chatSeed: "their overnight window held ~\(Int(window.rounded()))h and they slept \(sh)h\(sm)m. name the good ground; one small ask only.",
                second: "today starts on your side.",
                clause: "synthesis"
            )
        }

        // 5.5 — the easiest lever, acknowledged (steps are the one
        //       behavior this cohort already believes in)
        if ctx.yesterdayStepsHitGoal, stableSeed(ctx.dayKey) % 3 == 0 {
            return Brief(
                line: "you passed your step goal yesterday",
                italic: ["passed"],
                chatSeed: "they hit their step goal yesterday. connect walking to the plan without turning it into a fitness thing.",
                clause: "steps_passed"
            )
        }

        // 5.6 — a new program week opens (Monday-of-her-week mints
        //       the fresh start; the name pre-interprets the days)
        if let name = ctx.weekOpensName, ctx.weekOrdinal > 1 {
            return Brief(
                line: "week \(ctx.weekOrdinal): \(name).",
                italic: [name],
                chatSeed: "their program week \(ctx.weekOrdinal) ('\(name)') begins today. set the week's intent in one warm line; one small first move.",
                second: ctx.weekOpensLine,
                clause: "week_opens"
            )
        }

        // 5.7 — the tonight plan, named back (every plan earns its
        //       morning receipt; alternate days so nightly planners
        //       don't hear the same opener forever)
        if let plan = ctx.lastNightPlan, stableSeed(ctx.dayKey) % 2 == 0 {
            return Brief(
                line: "last night's plan: \(plan)",
                italic: [plan],
                chatSeed: "they set an if-then plan for last night ('\(plan)'). acknowledge the planning habit itself; don't grade whether it held.",
                second: "tonight can have one too.",
                clause: "tonight_plan"
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
                    line: "protein day. aim near \(target)g",
                    italic: ["\(target)g"],
                    chatSeed: "protein day on glp-1. they may have low appetite; suggest dense, gentle options.",
                    second: "small, dense plates work best on a low appetite.",
                    mechanism: {
                        // Her own sit-note from last evening, reflected
                        // back — HER pattern, never an asserted cycle.
                        switch ctx.yesterdaySat {
                        case "heavy": return "yesterday sat heavy. today's plates run smaller."
                        case "queasy": return "yesterday sat queasy. mild plates, fluids first."
                        default: return nil
                        }
                    }(),
                    clause: "archetype"
                )
            }
            let target = ctx.proteinTargetG
            let lines: [(String, [String])] = [
                (target.map { "protein day. aim near \($0)g." } ?? "protein day. one strong plate at a time.",
                 target.map { ["\($0)g"] } ?? ["strong"]),
                ("protein day. it holds muscle while weight drops.", ["muscle"]),
            ]
            let pick = lines[seedIndex % lines.count]
            return Brief(line: pick.0, italic: pick.1, chatSeed: "protein day. one concrete plate idea if they ask.", clause: "archetype")
        case .movement:
            return Brief(
                line: "movement day. a short session, your pace.",
                italic: ["your pace"],
                chatSeed: "movement day. they committed to this cadence; encourage without pressure.",
                clause: "archetype"
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
                },
                clause: "archetype"
            )
        case .rest:
            if ctx.glp1Cohort == .postGlp1 {
                return Brief(
                    line: "rest day. recovery is part of keeping it",
                    italic: ["keeping"],
                    chatSeed: "rest day for a post-glp-1 maintainer. reinforce that rest is part of keeping it.",
                    clause: "archetype"
                )
            }
            return Brief(
                line: "rest day. one minute of breath is the only ask",
                italic: ["breath"],
                chatSeed: "rest day. one breath session is the whole assignment.",
                clause: "archetype"
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
