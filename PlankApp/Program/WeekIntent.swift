import Foundation

// MARK: - WeekIntent (app v4 spine)
//
// docs/app_v4/01_PROGRAM.md §0. Every week has a NAME and one
// sentence of intent in jeni's voice — the week is the program's
// narrative unit (Monday mints a fresh start; names pre-interpret
// the days; "week 4 of 15" renders small, the name carries meaning).
//
// Pure + deterministic: same (week, chapter, phase, flags, zone) →
// same intent. The rotation is positional (no RNG), so the same
// program replays identically. Table-tested in WeekIntentTests.

struct WeekIntentSpec: Equatable {
    let key: String
    /// The week's name — lowercase serif ("the protein week").
    let name: String
    /// One sentence of intent under the name.
    let line: String
    /// Which archetype the one-thing should lean toward this week
    /// (nil = no bias; the day engine's own hero stands).
    let biasArchetype: ProgramDayArchetype?
    /// Which rep lane leads this week (RepEngine pillar key).
    let repLane: String?
}

enum WeekIntent {

    struct Flags: Equatable {
        var highStress = false
        var restrictiveRisk = false
        var glp1Current = false

        static var live: Flags {
            Flags(
                highStress: CohortStore.isHighStress,
                restrictiveRisk: CohortStore.isRestrictiveRisk,
                glp1Current: CohortStore.isGLP1Current
            )
        }
    }

    /// The intent for a program week. `zone` matters only in the
    /// keeping chapter (drifting/reset override the rotation — a
    /// zone crossing OPENS a named week; the null-trial law).
    /// `pickedKey` honors a re-signing intent choice for this week.
    static func intent(
        week: Int,
        chapter: Chapter,
        phase: ArcPhase,
        flags: Flags,
        zone: BandZone? = nil,
        pickedKey: String? = nil
    ) -> WeekIntentSpec {
        if let pickedKey, let picked = spec(for: pickedKey) {
            return picked
        }
        switch chapter {
        case .losing:
            return losingIntent(week: week, phase: phase, flags: flags)
        case .onMedication:
            return medicationIntent(week: week, phase: phase)
        case .keeping:
            return keepingIntent(week: week, phase: phase, zone: zone)
        }
    }

    // MARK: - losing

    private static func losingIntent(
        week: Int, phase: ArcPhase, flags: Flags
    ) -> WeekIntentSpec {
        switch phase.key {
        case .findingSteady:
            return week <= 1 ? spec("arriving_week")! : spec("finding_steady")!
        case .earlyRead:
            return week == phase.weeks.lowerBound
                ? spec("early_read")! : spec("plan_learns")!
        case .build:
            // Positional rotation through the build lanes. High-stress
            // identities meet the stress week first (the lane most
            // likely to be load-bearing for them).
            var lanes = ["protein_week", "food_noise_week", "kitchen_week",
                         "stress_sleep_week", "movement_keep_week",
                         "real_life_week", "begin_again_week"]
            if flags.highStress,
               let idx = lanes.firstIndex(of: "stress_sleep_week") {
                lanes.remove(at: idx)
                lanes.insert("stress_sleep_week", at: 0)
            }
            let position = max(0, week - phase.weeks.lowerBound)
            return spec(lanes[position % lanes.count])!
        case .bend:
            let lanes = ["bend_named", "steady_week", "fresh_angle"]
            let position = max(0, week - phase.weeks.lowerBound)
            return spec(lanes[position % lanes.count])!
        case .lastStretch:
            return spec("last_stretch_week")!
        case .hold:
            return spec("hold_week")!
        default:
            return spec("finding_steady")!
        }
    }

    // MARK: - on-medication

    private static func medicationIntent(
        week: Int, phase: ArcPhase
    ) -> WeekIntentSpec {
        switch phase.key {
        case .arriving:
            return week <= 1 ? spec("arriving_support")! : spec("floor_first")!
        default:
            // Rolling 4-week blocks: protein → strength → rhythm →
            // the quiet, then around again. Deterministic by week.
            let blockLanes = ["protein_block", "strength_block",
                              "rhythm_block", "quiet_block"]
            let sincePractice = max(0, week - phase.weeks.lowerBound)
            let block = sincePractice / 4
            return spec(blockLanes[block % blockLanes.count])!
        }
    }

    // MARK: - keeping

    private static func keepingIntent(
        week: Int, phase: ArcPhase, zone: BandZone?
    ) -> WeekIntentSpec {
        // Zone overrides: the band opens named weeks.
        if zone == .drifting { return spec("steadying_week")! }
        if zone == .reset { return spec("reset_arc")! }

        switch phase.key {
        case .settle:
            let lanes = ["naming_settle", "pattern_week", "three_plates",
                         "strength_anchor", "rhythm_holds", "first_kept"]
            let position = max(0, week - phase.weeks.lowerBound)
            return spec(lanes[min(position, lanes.count - 1)])!
        default:
            let lanes = ["kept_quietly", "identity_week",
                         "satisfaction_week", "still_yours"]
            let position = max(0, week - phase.weeks.lowerBound)
            return spec(lanes[position % lanes.count])!
        }
    }

    // MARK: - The intent table

    /// Every intent the program can name. A closed set: copy is
    /// authored, never generated.
    static func spec(for key: String) -> WeekIntentSpec? { spec(key) }

    private static func spec(_ key: String) -> WeekIntentSpec? {
        switch key {
        // losing · finding steady
        case "arriving_week": return WeekIntentSpec(
            key: key, name: "the arriving week",
            line: "your plan starts today, built from your intake.",
            biasArchetype: nil, repLane: nil)
        case "finding_steady": return WeekIntentSpec(
            key: key, name: "finding steady",
            line: "same rhythm most days. that's the target.",
            biasArchetype: nil, repLane: "behavior")
        // losing · the early read
        case "early_read": return WeekIntentSpec(
            key: key, name: "the early read",
            line: "your first real data lands this week.",
            biasArchetype: nil, repLane: "behavior")
        case "plan_learns": return WeekIntentSpec(
            key: key, name: "the plan learns you",
            line: "sunday, the plan adjusts from your week.",
            biasArchetype: nil, repLane: "mindset")
        // losing · the build
        case "protein_week": return WeekIntentSpec(
            key: key, name: "the protein week",
            line: "protein first on every plate.",
            biasArchetype: .protein, repLane: "nutrition")
        case "food_noise_week": return WeekIntentSpec(
            key: key, name: "the food-noise week",
            line: "find what triggers your cravings and what quiets them.",
            biasArchetype: nil, repLane: "mindset")
        case "kitchen_week": return WeekIntentSpec(
            key: key, name: "the kitchen week",
            line: "restock so the easy choice is the right one.",
            biasArchetype: .protein, repLane: "behavior")
        case "stress_sleep_week": return WeekIntentSpec(
            key: key, name: "the stress and sleep week",
            line: "tired brains crave quick fuel. sleep is this week's lever.",
            biasArchetype: .rest, repLane: "mindset")
        case "movement_keep_week": return WeekIntentSpec(
            key: key, name: "the movement week",
            line: "short sessions you'll actually repeat.",
            biasArchetype: .movement, repLane: "behavior")
        case "real_life_week": return WeekIntentSpec(
            key: key, name: "the real-life week",
            line: "restaurants, birthdays, real plates. the plan flexes.",
            biasArchetype: nil, repLane: "behavior")
        case "begin_again_week": return WeekIntentSpec(
            key: key, name: "the begin-again week",
            line: "practice the restart: one plate, same day.",
            biasArchetype: nil, repLane: "mindset")
        // losing · the bend
        case "bend_named": return WeekIntentSpec(
            key: key, name: "the plateau week",
            line: "weight loss stalls around now for everyone. the plan expects it.",
            biasArchetype: nil, repLane: "mindset")
        case "steady_week": return WeekIntentSpec(
            key: key, name: "the steady week",
            line: "hold this week's weight steady. that's the goal.",
            biasArchetype: nil, repLane: "behavior")
        case "fresh_angle": return WeekIntentSpec(
            key: key, name: "the variety week",
            line: "same targets, new meals and moves.",
            biasArchetype: nil, repLane: "behavior")
        // losing · the end
        case "last_stretch_week": return WeekIntentSpec(
            key: key, name: "the last stretch",
            line: "we count down now, not up.",
            biasArchetype: nil, repLane: "mindset")
        case "hold_week": return WeekIntentSpec(
            key: key, name: "the hold",
            line: "hold at goal pace. maintenance starts practicing here.",
            biasArchetype: nil, repLane: "behavior")
        // on-medication
        case "arriving_support": return WeekIntentSpec(
            key: key, name: "arriving on support",
            line: "the medication lowers appetite. the plan builds the habits under it.",
            biasArchetype: .protein, repLane: "mindset")
        case "floor_first": return WeekIntentSpec(
            key: key, name: "protein first",
            line: "eat enough protein to keep strength. that's the assignment.",
            biasArchetype: .protein, repLane: "nutrition")
        case "protein_block": return WeekIntentSpec(
            key: key, name: "the protein block",
            line: "small, dense plates. hit your protein goal daily.",
            biasArchetype: .protein, repLane: "nutrition")
        case "strength_block": return WeekIntentSpec(
            key: key, name: "the strength block",
            line: "two short strength sessions protect muscle.",
            biasArchetype: .movement, repLane: "behavior")
        case "rhythm_block": return WeekIntentSpec(
            key: key, name: "the rhythm block",
            line: "low appetite? eat on schedule, not on hunger.",
            biasArchetype: .protein, repLane: "behavior")
        case "quiet_block": return WeekIntentSpec(
            key: key, name: "the quiet block",
            line: "appetite is quiet. build the routines that outlast it.",
            biasArchetype: nil, repLane: "mindset")
        // keeping · settle
        case "naming_settle": return WeekIntentSpec(
            key: key, name: "your settle weight",
            line: "pick the weight your band lives around.",
            biasArchetype: nil, repLane: "mindset")
        case "pattern_week": return WeekIntentSpec(
            key: key, name: "the pattern week",
            line: "set your weigh-in rhythm. it's the earliest drift signal.",
            biasArchetype: nil, repLane: "behavior")
        case "three_plates": return WeekIntentSpec(
            key: key, name: "three plates a week",
            line: "three logged plates a week is the maintenance floor.",
            biasArchetype: .protein, repLane: "behavior")
        case "strength_anchor": return WeekIntentSpec(
            key: key, name: "the strength anchor",
            line: "two short strength sessions a week, anchored.",
            biasArchetype: .movement, repLane: "behavior")
        case "rhythm_holds": return WeekIntentSpec(
            key: key, name: "the rhythm holds",
            line: "your weekly rhythm is the program now.",
            biasArchetype: nil, repLane: "behavior")
        case "first_kept": return WeekIntentSpec(
            key: key, name: "the first kept week",
            line: "one full week with everything in place.",
            biasArchetype: nil, repLane: "mindset")
        // keeping · kept + zones
        case "kept_quietly": return WeekIntentSpec(
            key: key, name: "the kept week",
            line: "inside your band. nothing to change.",
            biasArchetype: nil, repLane: nil)
        case "identity_week": return WeekIntentSpec(
            key: key, name: "the identity week",
            line: "maintenance is the default now, not a phase.",
            biasArchetype: nil, repLane: "mindset")
        case "satisfaction_week": return WeekIntentSpec(
            key: key, name: "the satisfaction week",
            line: "count what keeping it gives you: energy, clothes, ease.",
            biasArchetype: nil, repLane: "mindset")
        case "still_yours": return WeekIntentSpec(
            key: key, name: "holding steady",
            line: "quiet weeks keep the result. same pattern.",
            biasArchetype: nil, repLane: nil)
        case "steadying_week": return WeekIntentSpec(
            key: key, name: "the steadying week",
            line: "trend is 3-5 lb up. protein floor daily, 3 logged plates.",
            biasArchetype: .protein, repLane: "behavior")
        case "reset_arc": return WeekIntentSpec(
            key: key, name: "the reset arc",
            line: "a 2-3 week reset: protein first, gentle logging, weekly checks.",
            biasArchetype: .protein, repLane: "behavior")
        default:
            return nil
        }
    }
}
