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
                steps: stepsGoal(plan: plan),
                numericsSuppressed: true
            )
        }

        return Targets(
            kcal: calorieTarget(plan: plan, latestWeightKg: latestKg, careProtocol: served),
            proteinG: latestKg.map {
                proteinTargetG(weightKg: $0, careProtocol: served)
            },
            proteinNote: proteinNote,
            steps: stepsGoal(plan: plan),
            numericsSuppressed: false
        )
    }

    // MARK: - Calories

    /// Recomputes the daily calorie target against the LATEST weight
    /// (the pre-v2 defect: the target was frozen at onboarding
    /// weight forever). Rate comes from the plan itself.
    @MainActor
    static func calorieTarget(
        plan: ProgramPlanRecord?, latestWeightKg: Double?,
        careProtocol: CareProtocol = .default
    ) -> Int? {
        guard let weightKg = latestWeightKg, weightKg > 30 else { return nil }
        let profile = profileInputs()
        guard profile.heightCm > 100 else { return nil }

        let rate = planImpliedRate(
            plan: plan, fallbackWeightKg: weightKg, careProtocol: careProtocol
        )

        return CalorieTargetCalculator.dailyTarget(
            currentWeightKg: weightKg,
            heightCm: profile.heightCm,
            age: profile.age,
            sex: profile.sex,
            activityKey: profile.activityKey,
            lossRatePctPerWeek: rate
        )
    }

    /// The plan's own implied loss rate: (start − goal) / start /
    /// weeks. Maintenance / no-plan / degenerate plans → 0 (target
    /// resolves to maintenance TDEE, matching the reveal's
    /// maintenance variant).
    static func planImpliedRate(
        plan: ProgramPlanRecord?,
        fallbackWeightKg: Double,
        careProtocol: CareProtocol = .default
    ) -> Double {
        guard !CohortStore.isMaintenanceMode else { return 0 }
        guard
            let plan,
            let start = plan.currentWeightKg, start > 30,
            let goal = plan.goalWeightKg, goal > 30,
            start > goal,
            plan.totalDays >= 7
        else { return 0 }
        let weeks = Double(plan.totalDays) / 7.0
        let rate = ((start - goal) / start) / weeks
        // Clamp to the sane band: never render a target built on a
        // faster-than-ceiling rate even if plan data is corrupt.
        return min(max(rate, 0), careProtocol.maxPlanRatePctPerWeek)
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
