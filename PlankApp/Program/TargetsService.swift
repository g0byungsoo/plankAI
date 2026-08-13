import Foundation
import SwiftData
import PlankSync

// MARK: - TargetsService
//
// App v2 (docs/app_v2/04_DAILY_PROGRAM.md §Targets). ONE source of
// truth for the three numbers the daily loop runs on: calories,
// protein, steps. Before v2 three protein formulas coexisted
// (1.0 g/kg on snap results, 1.2 on Becoming, 1.6 at the reveal) and
// the calorie target was stamped once at onboarding and never
// recomputed. Every surface — Today, Becoming, snap results, chat
// context, briefs — reads THESE functions.
//
// Design: a pure core (`compute*` — unit-testable, no I/O) plus a
// thin resolver that pulls the live inputs (latest weight, active
// plan, profile keys). Numbers derive from the plan the user
// actually holds (provenance), not from re-run onboarding math:
// the plan's own implied %/wk = (start − goal) / start / weeks.

enum TargetsService {

    // MARK: - Resolved bundle

    struct Targets: Equatable {
        /// Daily calorie target. nil = suppressed (safety gate) or
        /// insufficient data (no plan weights). Maintenance mode
        /// resolves to TDEE (a "steady" number, zero deficit).
        let kcal: Int?
        /// Daily protein floor in grams. nil only when no weight is
        /// known at all.
        let proteinG: Int?
        /// Cohort note attached to the protein number ("lean-mass
        /// first" for GLP-1). nil when no note applies.
        let proteinNote: String?
        /// Daily steps goal from the plan tier (7,500 default).
        let steps: Int
        /// True when the safety gate suppressed all numerics — render
        /// non-numeric variants everywhere.
        let numericsSuppressed: Bool
    }

    // MARK: - Live resolver

    /// The one entry point. Reads the active plan + latest weight +
    /// profile keys and returns today's targets. Cheap enough to call
    /// per-render (two fetches, no network).
    @MainActor
    static func current(userId: String, in context: ModelContext) -> Targets {
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let latestKg = latestWeightKg(userId: userId, in: context)
            ?? plan?.currentWeightKg
            ?? UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg").nilIfZero

        // v8 S2 — the live resolver reads the SERVED protocol; the
        // pure compute funcs keep their .default parameter for
        // callers and tests.
        let served = CareProtocolStore.current

        if CohortStore.isNumericSuppressed {
            return Targets(
                kcal: nil,
                proteinG: latestKg.map {
                    proteinTargetG(weightKg: $0, careProtocol: served)
                },
                proteinNote: proteinNote,
                steps: stepGoalResolved(userId: userId, plan: plan, in: context),
                numericsSuppressed: true
            )
        }

        return Targets(
            kcal: calorieTarget(plan: plan, latestWeightKg: latestKg, careProtocol: served),
            proteinG: latestKg.map {
                proteinTargetG(weightKg: $0, careProtocol: served)
            },
            proteinNote: proteinNote,
            steps: stepGoalResolved(userId: userId, plan: plan, in: context),
            numericsSuppressed: false
        )
    }

    // MARK: - Steps (v25 E1 — facts-first)

    /// The ONE steps resolver: the program-fact head (authority-
    /// resolved: prescribed › preferred › recommended) when a fact
    /// is in force, else the legacy plan-tier default. No fact ever
    /// written = behavior-identical to pre-E1 (equivalence-pinned).
    @MainActor
    static func stepGoalResolved(
        userId: String, plan: ProgramPlanRecord?, in context: ModelContext
    ) -> Int {
        ProgramFactStore.headValue(.stepGoal, userId: userId, in: context)?.intValue
            ?? stepsGoal(plan: plan)
    }

    // MARK: - Calories

    /// What the daily energy number MEANS for this user. Three
    /// states, and they must never be confused — the 2026-08-13
    /// customer report is what happens when they are.
    ///
    /// Before this type, `planImpliedRate` returned `0` for all of:
    /// "she chose maintenance", "her plan hasn't been built yet",
    /// "her plan is corrupt", and "she has no goal on file". A rate
    /// of 0 means TDEE, so every one of those users was handed a
    /// MAINTENANCE target labelled as her daily target — which is a
    /// surplus for anyone whose real expenditure sits below the
    /// activity factor we assumed. A weight-loss product must not be
    /// able to do that by omission.
    enum EnergyBasis: Equatable {
        /// A real loss plan, at this weekly rate (fraction of body
        /// mass per week).
        case deficit(ratePctPerWeek: Double)
        /// She asked to hold steady, or a safety rule requires it.
        /// The number IS her maintenance estimate, and says so.
        case maintenance
        /// We do not know what she is aiming at. Publish NO number.
        case unknown
    }

    /// Recomputes the daily calorie target against the LATEST weight
    /// (the pre-v2 defect: the target was frozen at onboarding
    /// weight forever). Returns nil when the basis is `.unknown` —
    /// silence is the honest output when the goal is missing.
    @MainActor
    static func calorieTarget(
        plan: ProgramPlanRecord?, latestWeightKg: Double?,
        careProtocol: CareProtocol = .default,
        defaults: UserDefaults = .standard
    ) -> Int? {
        guard let weightKg = latestWeightKg, weightKg > 30 else { return nil }
        let profile = profileInputs(defaults)
        guard profile.heightCm > 100 else { return nil }

        let rate: Double
        switch energyBasis(plan: plan, fallbackWeightKg: weightKg,
                           careProtocol: careProtocol, defaults: defaults) {
        case .deficit(let r): rate = r
        case .maintenance:    rate = 0
        case .unknown:        return nil
        }

        return CalorieTargetCalculator.dailyTarget(
            currentWeightKg: weightKg,
            heightCm: profile.heightCm,
            age: profile.age,
            sex: profile.sex,
            activityKey: profile.activityKey,
            lossRatePctPerWeek: rate
        )
    }

    /// The resolution order, most-authoritative first:
    ///
    /// 1. **Maintenance was asked for** — her own goal direction, a
    ///    persisted maintenance program mode, or a safety pace cap of
    ///    zero (pregnancy / low BMI). Clinical instruction outranks a
    ///    loss goal still sitting in storage.
    /// 2. **The plan she holds**, when it describes a real loss.
    /// 3. **Her own onboarding numbers**, when the plan is missing or
    ///    degenerate. This is not an invented target: it re-derives
    ///    the pace from the SAME `ProgramGoalCalculator` inputs and
    ///    the SAME picked tier the reveal already showed her before
    ///    she paid. The post-purchase onramp is two taps she may not
    ///    have taken yet, and food logging does not wait for it.
    /// 4. **Unknown.** No goal, no maintenance choice — no number.
    static func energyBasis(
        plan: ProgramPlanRecord?,
        fallbackWeightKg: Double,
        careProtocol: CareProtocol = .default,
        defaults d: UserDefaults = .standard
    ) -> EnergyBasis {
        if isMaintenanceRequested(d) { return .maintenance }

        let cap = safetyRateCap(d)

        if let plan,
           let start = plan.currentWeightKg, start > 30,
           let goal = plan.goalWeightKg, goal > 30,
           start > goal,
           plan.totalDays >= 7,
           planAgreesWithHer(goal: goal, d) {
            let weeks = Double(plan.totalDays) / 7.0
            let raw = ((start - goal) / start) / weeks
            return .deficit(ratePctPerWeek: clampRate(raw, careProtocol, cap))
        }

        // The plan is missing or says nothing. Fall back to what she
        // told onboarding — the numbers the reveal computed from.
        guard
            let raw = onboardingImpliedRate(d),
            raw > 0
        else { return .unknown }
        return .deficit(ratePctPerWeek: clampRate(raw, careProtocol, cap))
    }

    /// Legacy shape, kept for call sites that only want a number.
    /// `.maintenance` and `.unknown` both read as 0 here, so NEVER
    /// use this to decide whether to publish a target — use
    /// `energyBasis` or `calorieTarget`.
    static func planImpliedRate(
        plan: ProgramPlanRecord?,
        fallbackWeightKg: Double,
        careProtocol: CareProtocol = .default
    ) -> Double {
        if case .deficit(let r) = energyBasis(
            plan: plan, fallbackWeightKg: fallbackWeightKg,
            careProtocol: careProtocol
        ) { return r }
        return 0
    }

    // MARK: - Basis helpers

    /// THE NUMBER SHE SEES IS THE NUMBER THE MATH USES.
    ///
    /// A plan record can carry a goal she never chose — one hydrated
    /// from an older era of the account, or built before she changed
    /// her mind. When the plan and her stated goal disagree, the plan
    /// used to win silently: the app computed a deficit toward a
    /// destination that appeared on no screen. Her answer is the one
    /// she can see and edit, so it is the one that decides; the plan
    /// keeps its authority over the horizon she committed to, but only
    /// while it is aiming at the same place.
    ///
    /// No stored goal at all = nothing to disagree with; the plan is
    /// then the only statement there is.
    private static func planAgreesWithHer(goal: Double, _ d: UserDefaults) -> Bool {
        let stored = d.double(forKey: "onboardingGoalWeightKg")
        guard stored > 30 else { return true }
        return abs(stored - goal) <= 0.5
    }

    private static func isMaintenanceRequested(_ d: UserDefaults) -> Bool {
        if d === UserDefaults.standard, CohortStore.isMaintenanceMode { return true }
        if d !== UserDefaults.standard {
            let mode = d.string(forKey: "program_mode") ?? ""
            let direction = d.string(forKey: "onboarding_goal_direction") ?? ""
            if mode == "maintenance" || direction == "maintain"
                || direction == "maintain_kept" { return true }
        }
        // A zero pace cap is the safety gate's zero-deficit
        // instruction (pregnant / ED-screen / BMI < 18.5). It is
        // written as -1 when absent, so 0 is never a default.
        return d.object(forKey: "safety_pace_cap") != nil
            && d.double(forKey: "safety_pace_cap") == 0
    }

    /// A positive safety cap clamps every rate, exactly as it clamps
    /// the tiers at program build.
    private static func safetyRateCap(_ d: UserDefaults) -> Double? {
        let cap = d.double(forKey: "safety_pace_cap")
        return cap > 0 ? cap : nil
    }

    private static func clampRate(
        _ raw: Double, _ careProtocol: CareProtocol, _ safetyCap: Double?
    ) -> Double {
        let ceiling = min(careProtocol.maxPlanRatePctPerWeek,
                          safetyCap ?? careProtocol.maxPlanRatePctPerWeek)
        return min(max(raw, 0), ceiling)
    }

    /// The pace her own answers imply, through the same calculator
    /// the pre-purchase reveal used. nil when she has no loss goal.
    private static func onboardingImpliedRate(_ d: UserDefaults) -> Double? {
        let start = d.double(forKey: "onboardingCurrentWeightKg")
        let goal  = d.double(forKey: "onboardingGoalWeightKg")
        guard start > 30, goal > 30, start > goal else { return nil }

        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: start,
            goalWeightKg: goal,
            sex: ProgramGoalCalculator.sex(
                fromGenderKey: d.string(forKey: "onboardingGender") ?? ""),
            age: nil,
            isGLP1User: ProgramGoalCalculator.isGLP1User(
                from: d.string(forKey: "onboarding_glp1_status") ?? ""),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(
                from: d.string(forKey: "onboardingHormonalStage") ?? ""),
            isShortSleeper: ProgramGoalCalculator.isShortSleeper(
                from: d.string(forKey: "onboardingSleepHours") ?? ""),
            weightTrendKey: d.string(forKey: "onboarding_weight_trend") ?? "",
            glp1PhaseKey: d.string(forKey: "onboarding_glp1_phase") ?? ""
        ))
        guard !window.isMaintenance else { return nil }

        let tier = IntensityTier(rawValue: d.string(forKey: "onboardingPickedTier") ?? "")
            ?? .medium
        let weeks = Double(window.weeks(for: tier))
        guard weeks > 0 else { return nil }
        return ((start - goal) / start) / weeks
    }

    // MARK: - Protein

    /// The ONE protein formula (SCIENCE.md §1): 1.6 g/kg for the
    /// GLP-1-current cohort (lean-mass preservation during
    /// pharmacotherapy — 4-society advisory band 1.2-1.6), 1.2 g/kg
    /// default. Rounded to 5g so the number reads as guidance, not
    /// false precision.
    ///
    /// v4: the re-signing's consented adjustment (±10g max) applies
    /// BEFORE the advisory clamp, so an eased floor can never leave
    /// the safe band (docs/app_v4/01_PROGRAM.md §0).
    static func proteinTargetG(
        weightKg: Double,
        adjustG: Int? = nil,
        careProtocol: CareProtocol = .default
    ) -> Int {
        let adj = Double(adjustG
            ?? UserDefaults.standard.integer(forKey: WeeklyReview.proteinAdjustKey))
        let p = careProtocol.protein
        let glp1 = CohortStore.isGLP1Current
        let perKg = glp1 ? p.perKgGLP1Current : p.perKgDefault
        // v8 honesty fix (04_DECISIONS): the GLP-1 floor may never
        // push a small body ABOVE the cited advisory band — at 50kg
        // a flat 90g floor is 1.8 g/kg. The floor caps at the band
        // value itself; larger bodies bind on the flat floor as
        // before. Default cohort keeps its flat adequacy floor.
        let lo = glp1 ? min(p.floorGLP1G, weightKg * perKg) : p.floorDefaultG
        let hi = glp1 ? p.capGLP1G : p.capDefaultG
        let raw = min(hi, max(lo, weightKg * perKg + adj))
        return Int((raw / p.roundToG).rounded() * p.roundToG)
    }

    /// v8 S3 — the protein target from the freshest weight the app
    /// holds (visit-packet nutrition line; served config applied).
    @MainActor
    static func proteinTargetLight(userId: String, in context: ModelContext) -> Int? {
        guard let kg = latestWeightKg(userId: userId, in: context)
            ?? UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg").nilIfZero
        else { return nil }
        return proteinTargetG(weightKg: kg, careProtocol: CareProtocolStore.current)
    }

    static var proteinNote: String? {
        if CohortStore.isGLP1Current { return "lean-mass first" }
        if CohortStore.isPostGLP1 { return "keeps the loss kept" }
        return nil
    }

    // MARK: - Steps

    @MainActor
    static func stepsGoal(plan: ProgramPlanRecord?) -> Int {
        guard
            let tierRaw = plan?.intensityTier,
            let tier = IntensityTier(rawValue: tierRaw)
        else { return 7_500 }
        return IntensityProfile.from(tier: tier).stepsDailyGoal
    }

    // MARK: - Profile inputs

    struct ProfileInputs {
        let heightCm: Double
        let age: Int
        let sex: ProgramGoalCalculator.Inputs.Sex
        let activityKey: String
    }

    static func profileInputs(_ d: UserDefaults = .standard) -> ProfileInputs {
        let height = d.double(forKey: "onboardingHeightCm")

        // v5 stores the exact age; earlier flows only the band.
        let exactAge = d.integer(forKey: "onb_v5_age_years")
        let age = exactAge > 0 ? exactAge : representativeAge(
            band: d.string(forKey: "ageRange") ?? ""
        )

        let sex: ProgramGoalCalculator.Inputs.Sex = {
            switch (d.string(forKey: "onboardingGender") ?? "").lowercased() {
            case "male": return .male
            case "female": return .female
            default: return .unspecified
            }
        }()

        let activity = d.string(forKey: "onb_v4_movement_baseline")
            ?? d.string(forKey: "activityLevel")
            ?? ""

        return ProfileInputs(
            heightCm: height,
            age: age,
            sex: sex,
            activityKey: activity
        )
    }

    static func representativeAge(band: String) -> Int {
        switch band {
        case "under18": return 17
        case "18to24": return 21
        case "25to34": return 29
        case "35to44": return 39
        case "45to54": return 49
        case "55plus": return 58
        default: return 32   // cohort median; conservative BMR
        }
    }

    // MARK: - Latest weight

    @MainActor
    static func latestWeightKg(userId: String, in context: ModelContext) -> Double? {
        var descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.weightKg
    }
}

private extension Double {
    var nilIfZero: Double? { self > 0 ? self : nil }
}
