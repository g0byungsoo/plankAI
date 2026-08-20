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
        // ONE LADDER for "the weight we are computing against", and this
        // used to be the only reader that disagreed with it.
        //
        // 2026-08-14: `plan?.currentWeightKg` sat in the MIDDLE of this
        // ladder, ahead of her own answer. `PlanSummary`,
        // `proteinTargetLight`, `GoalWeightStore` and `ProfileHubView`
        // all resolve `latestWeightKg ?? onboardingCurrentWeightKg` — so
        // four readers said one thing and Home said another. Filmed: a
        // 124 lb persona holding a hydrated plan whose start weight was
        // 75 kg got `of 1,419 kcal` on Home and `about 1,282 kcal` on
        // the plan screen, in the same launch, 137 kcal apart.
        //
        // The plan's `currentWeightKg` is her START weight, copied at
        // enrollment. It is a fine last resort and a bad second opinion:
        // start and current are different facts, and a plan hydrated
        // from an older era of the account describes a body she may not
        // have any more. Her own stored answer outranks it.
        let latestKg = resolvedWeightKg(userId: userId, plan: plan, in: context)

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

    /// THE ONE LADDER, as a function so there cannot be two of it.
    /// Latest logged weigh-in › her own stored answer › the plan's start
    /// weight, last, because start and current are different facts.
    @MainActor
    static func resolvedWeightKg(
        userId: String, plan: ProgramPlanRecord?, in context: ModelContext
    ) -> Double? {
        latestWeightKg(userId: userId, in: context)
            ?? UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg").nilIfZero
            ?? plan?.currentWeightKg
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

    /// WHY THERE IS NO NUMBER — the honest inverse of `calorieTarget`'s
    /// refusals, so a surface can say which fact is missing and open the
    /// door to exactly that one.
    ///
    /// `calorieTarget` returning nil is correct behaviour and was still
    /// a dead end: Home rendered `860 kcal` with no denominator, no
    /// reason and nowhere to go, and Settings → goal weight was the only
    /// repair — for a user who had no way of knowing that. Silence is
    /// the honest output; silence with no door is a shrug.
    ///
    /// nil = a target IS publishable (including a maintenance target,
    /// which is a real number and not a missing one).
    enum MissingEnergyInput: String, Equatable {
        case weight
        case height
        case goal
        /// 2026-08-14. Her plan says HOLD and we cannot tell whether that
        /// was a safety decision or a goal the app lost. See
        /// `planHoldsWithUnknownDirection`.
        case direction

        /// The repair, in her words. Never "invalid", never "error".
        var word: String {
            switch self {
            case .weight:    return "a weight"
            case .height:    return "your height"
            case .goal:      return "a goal weight"
            case .direction: return "to know if this plan is losing or holding"
            }
        }

        /// The tappable line under the day's number. The other three are
        /// facts she can ADD; this one is a question only she can answer.
        var doorLine: String {
            switch self {
            case .direction: return "losing or holding?"
            default:         return "add \(word)"
            }
        }

        /// The second line of the fuller repair card.
        var repairSubline: String {
            switch self {
            case .direction: return "say if you're losing or holding and it arrives"
            default:         return "add \(word) and it arrives"
            }
        }
    }

    static func missingEnergyInput(
        plan: ProgramPlanRecord?,
        latestWeightKg: Double?,
        careProtocol: CareProtocol = .default,
        defaults d: UserDefaults = .standard
    ) -> MissingEnergyInput? {
        guard let weightKg = latestWeightKg, weightKg > 30 else { return .weight }
        guard profileInputs(d).heightCm > 100 else { return .height }
        switch energyBasis(plan: plan, fallbackWeightKg: weightKg,
                           careProtocol: careProtocol, defaults: d) {
        case .deficit, .maintenance: return nil
        case .unknown:
            // NAME THE FACT THAT IS ACTUALLY MISSING. Pointing a woman
            // who already gave us a goal weight at "add a goal weight"
            // is the dead end `31` §8 found: she taps it, re-enters the
            // same number, and nothing changes.
            return planHoldsWithUnknownDirection(plan, d) ? .direction : .goal
        }
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
        // THE SAFETY CAP, resolved once: the gate's own output when this
        // device still holds it, else the part of its arithmetic that
        // survives an account transition (§`resolvedSafetyCap`).
        let resolvedCap = resolvedSafetyCap(currentWeightKg: fallbackWeightKg, d)
        if isMaintenanceRequested(d, cap: resolvedCap) { return .maintenance }

        let cap = resolvedCap.flatMap { $0 > 0 ? $0 : nil }

        if let plan,
           let start = plan.currentWeightKg, start > 30,
           let goal = plan.goalWeightKg, goal > 30,
           start > goal,
           plan.totalDays >= 7,
           planAgreesWithHer(goal: goal, currentWeightKg: fallbackWeightKg, d) {
            let weeks = Double(plan.totalDays) / 7.0
            let raw = ((start - goal) / start) / weeks
            return .deficit(ratePctPerWeek: clampRate(raw, careProtocol, cap))
        }

        // SHE ARRIVED — and ONLY that.
        //
        // 2026-08-14: a user who had reached her goal fell through to
        // `.unknown`, so she lost her daily number AND was shown "add a
        // goal weight", pointing at the exact fact she had already given
        // us. Tapping it and re-entering the same number changed nothing.
        // A state the app could not explain and she could not repair.
        //
        // The guard is narrow on purpose. `goal >= current` alone is NOT
        // arrival: `goal == current == start` is the signature of the
        // 2026-08-13 fabrication (`assembleData` published an absent goal
        // AS the current weight), and reading that as "she chose to hold"
        // is the original customer bug — a maintenance number labelled a
        // daily target — coming back through a new door. Arrival requires
        // that the goal was a REAL LOSS DESTINATION when it was set:
        // strictly below the weight she started from.
        //
        // Holding is still only ever an instruction or an arrival, never
        // a fallback (`PlanSummary`'s law). The branch above is untouched:
        // a plan that still describes a real loss keeps its rate, which is
        // the call `docs/app_v25/30` §17 made and this does not reopen.
        let storedGoal = d.double(forKey: "onboardingGoalWeightKg")
        let startedFrom = d.double(forKey: "onboardingCurrentWeightKg")
        if storedGoal > 30, fallbackWeightKg > 30,
           startedFrom > storedGoal + 0.01,
           fallbackWeightKg <= storedGoal + 0.01 {
            return .maintenance
        }

        // A PLAN THAT HOLDS IS A HOLD, AND WE MAY NOT GUESS WHY.
        //
        // 2026-08-14. The fallback below exists for a user whose plan is
        // MISSING (`29` §4 rule 3 — the onramp is two taps she may not
        // have taken, and food logging does not wait for it). It was
        // written as "whenever rule 2 did not fire", which is not the
        // same thing: a plan whose goal equals its start weight is not
        // missing, it is a plan that SAYS something, and what it says is
        // hold.
        //
        // That row is how the pre-paywall safety gate's zero-deficit
        // instruction reaches the server at all — `ProgramSetupSubflow
        // .safetyAdjustedGoalWeightKg` collapses the goal onto the start
        // weight for pregnancy, a positive eating-pattern screen and
        // BMI < 18.5. And `safety_pace_cap`, `program_mode` and
        // `onboarding_goal_direction` are all swept on sign-out with
        // nothing to restore them, so after any account transition the
        // fallback re-derived a rate from the loss goal she gave the
        // consult BEFORE the gate ran, and published a deficit.
        //
        // The same row is also the signature of the 2026-08-13
        // fabrication, and NOTHING ON THE SERVER DISTINGUISHES THEM. So
        // the client does not choose: it refuses the deficit, names the
        // fact that is missing, and asks. Unknown is not permission.
        if planHoldsWithUnknownDirection(plan, d) { return .unknown }

        // The plan is missing or says nothing. Fall back to what she
        // told onboarding — the numbers the reveal computed from.
        guard
            let raw = onboardingImpliedRate(d),
            raw > 0
        else { return .unknown }
        return .deficit(ratePctPerWeek: clampRate(raw, careProtocol, cap))
    }

    /// **THE DIRECTION RULE.** True when a live plan states a hold AND
    /// this device cannot say whether the hold was asked for.
    ///
    /// `program_mode` is written on EVERY branch of the consult — the
    /// safety gate's `route` writes it for all five assessment modes,
    /// `OV5Store.applyGoalDirection` writes it for the direction beat,
    /// and `GoalWeightStore` writes it on every goal edit. It is swept
    /// by name on sign-out and no restore path puts it back. **Its
    /// absence is therefore a precise signal: this device has been
    /// through an account transition, or predates the key.** A woman
    /// still holding her own answer never reaches this branch, so
    /// nothing about an ordinary customer's number moves.
    static func planHoldsWithUnknownDirection(
        _ plan: ProgramPlanRecord?, _ d: UserDefaults = .standard
    ) -> Bool {
        guard let plan,
              let start = plan.currentWeightKg, start > 30,
              let goal = plan.goalWeightKg, goal > 30,
              goal >= start - 0.05
        else { return false }
        // SHE MUST HAVE A LOSS GOAL ON FILE FOR THE TWO MEANINGS TO
        // COLLIDE. Without one there is nothing for the hold to
        // contradict: the missing fact really is the goal, the product
        // already says so, and `AutymRecoveryTests` holds that line —
        // her stored goal was fabricated to equal her weight, so
        // "add a goal weight" is the honest ask, not "losing or
        // holding?".
        //
        // This is byte-identical to the census's row 13 predicate
        // ("maintenance-SHAPED plan for a loss-shaped profile"), so the
        // production count and the client rule are the same rule.
        let storedGoal = d.double(forKey: "onboardingGoalWeightKg")
        let storedStart = d.double(forKey: "onboardingCurrentWeightKg")
        guard storedGoal > 30, storedStart > storedGoal + 0.01 else { return false }
        return directionIsUnknown(d)
    }

    /// Neither of the two keys that record what she is aiming at is on
    /// file. Both are swept on sign-out; neither is on `UserRecord`.
    static func directionIsUnknown(_ d: UserDefaults = .standard) -> Bool {
        (d.string(forKey: "program_mode") ?? "").isEmpty
            && (d.string(forKey: "onboarding_goal_direction") ?? "").isEmpty
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
    /// then the only statement there is — **but it must still be a
    /// statement about HER.**
    ///
    /// 2026-08-14: this returned a bare `true` on an absent stored goal,
    /// which reopened the exact defect the 2026-08-13 pass was written
    /// to close, one branch over. Filmed: a 124 lb persona with NO goal
    /// on file, holding a hydrated plan that aimed at 65 kg, was shown
    /// `124 lb → 143.3 lb`, the words *"you reached your goal"*, and a
    /// 1,281 kcal DEFICIT target — three mutually contradictory
    /// statements built on a destination that is ABOVE her body and
    /// appears on no screen she ever saw.
    ///
    /// A goal at or above the weight we are computing for is not a loss
    /// destination. A deficit toward it is a number aimed at nobody, so
    /// the basis falls through and the surfaces ask.
    private static func planAgreesWithHer(
        goal: Double, currentWeightKg: Double, _ d: UserDefaults
    ) -> Bool {
        let stored = d.double(forKey: "onboardingGoalWeightKg")
        guard stored > 30 else {
            return currentWeightKg > 30 && goal < currentWeightKg
        }
        return abs(stored - goal) <= 0.5
    }

    private static func isMaintenanceRequested(_ d: UserDefaults, cap: Double?) -> Bool {
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
        return cap == 0
    }

    /// **THE SAFETY CAP, RESOLVED.** nil = uncapped. 0 = zero deficit.
    ///
    /// The gate's own output when this device still holds it. When it
    /// does not — after a sign-out, a reinstall or on a new phone, where
    /// the whole `safety_` family is swept and nothing restores it —
    /// **the part of the gate's own arithmetic that survives is re-run.**
    ///
    /// Two of `ProgramGoalCalculator.safetyAssessment`'s five reasons are
    /// pure functions of facts the server carries and `restoreBodyDefaults`
    /// brings home:
    ///
    ///   * `under18` → 0.25%/wk, from `onboarding_age_range`;
    ///   * `bmi_low` → zero deficit, from height and the freshest weight.
    ///
    /// The other three (`pregnant`, `ed_screen`, `med_hypo`) are NOT
    /// derivable and are NEVER inferred — no proxy, no heuristic, no
    /// "she looks like". They are handled by refusing the deficit and
    /// asking (`planHoldsWithUnknownDirection`).
    ///
    /// This can only ever ADD protection: it is consulted solely when
    /// the stored answer is absent, so a device that still holds the
    /// gate's output behaves exactly as it did yesterday.
    ///
    /// One honest difference from the stored cap, stated rather than
    /// hidden: the derived `bmi_low` cap follows her CURRENT weight, so
    /// it lifts if she climbs back above BMI 18.5. That is the gate's
    /// own rule applied to the body in front of us, and it is the
    /// conservative direction of the two.
    static func resolvedSafetyCap(
        currentWeightKg: Double?, _ d: UserDefaults = .standard
    ) -> Double? {
        if d.object(forKey: "safety_pace_cap") != nil {
            let stored = d.double(forKey: "safety_pace_cap")
            return stored >= 0 ? stored : nil     // -1 is the "clean pass" sentinel
        }
        return derivedSafetyCap(currentWeightKg: currentWeightKg, d)
    }

    static func derivedSafetyCap(
        currentWeightKg: Double?, _ d: UserDefaults = .standard
    ) -> Double? {
        // Most-protective first, exactly as `safetyAssessment` orders it.
        if ageBandOnFile(d) == "under18" { return 0.0025 }
        let heightCm = d.double(forKey: "onboardingHeightCm")
        let weightKg = currentWeightKg
            ?? d.double(forKey: "onboardingCurrentWeightKg").nilIfZero
        guard heightCm > 100, let weightKg, weightKg > 30 else { return nil }
        let m = heightCm / 100.0
        return weightKg / (m * m) < 18.5 ? 0 : nil
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

        // v5 stores the exact age; earlier flows only the band. The band
        // lives under two keys — the consult writes `onboardingAgeRange`,
        // the cloud restore writes `ageRange` — and reading only one of
        // them handed the 32-year-old cohort default to anyone holding
        // the other.
        let exactAge = d.integer(forKey: "onb_v5_age_years")
        let age = exactAge > 0 ? exactAge : representativeAge(band: ageBandOnFile(d))

        let sex: ProgramGoalCalculator.Inputs.Sex = {
            switch (d.string(forKey: "onboardingGender") ?? "").lowercased() {
            case "male": return .male
            case "female": return .female
            default: return .unspecified
            }
        }()

        return ProfileInputs(
            heightCm: height,
            age: age,
            sex: sex,
            activityKey: activityKey(d)
        )
    }

    /// THE ONE ACTIVITY RESOLVER.
    ///
    /// Her raw answer (`onb_v4_movement_baseline`: barely · walks ·
    /// regular_ish · very_active) when the device still holds it, else
    /// the lossy alias that survives a sign-out (`activityLevel`, written
    /// at completion and restored from `UserRecord` on hydrate — the raw
    /// key is swept as identity-scoped body data and the record has no
    /// column for it).
    ///
    /// 2026-08-14: `ProgramSetupSubflow` — the screen that builds every
    /// user's plan — read `onboardingActivityLevel` instead, **a key with
    /// zero writers in the app**. It is in the sign-out sweep list, which
    /// is how it looked written. So `HardTierGate` saw `.light` for every
    /// human being, and the activity dimension of a documented safety
    /// gate had never fired.
    static func activityKey(_ d: UserDefaults = .standard) -> String {
        d.string(forKey: "onb_v4_movement_baseline")?.nilIfEmpty
            ?? d.string(forKey: "activityLevel")?.nilIfEmpty
            ?? ""
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

    /// The age we actually HOLD, or nil. `profileInputs().age` always
    /// returns a number because the arithmetic needs one (32 is the
    /// documented cohort-median fallback); a SAFETY GATE must be able to
    /// tell "she is 29" from "we are guessing 32", because
    /// `HardTierGate`'s contract is that a missing signal locks Hard.
    static func knownAge(_ d: UserDefaults = .standard) -> Int? {
        let exact = d.integer(forKey: "onb_v5_age_years")
        if exact > 0 { return exact }
        let band = ageBandOnFile(d)
        return band.isEmpty ? nil : representativeAge(band: band)
    }

    /// True when the age on screen came from a BAND, not from the number
    /// she typed — the state a sign-out leaves, because `onb_v5_age_years`
    /// is swept with the `onb_v5_` prefix and `UserRecord` carries only
    /// the band. The surface says "approximate" rather than pretending.
    static func ageIsApproximate(_ d: UserDefaults = .standard) -> Bool {
        d.integer(forKey: "onb_v5_age_years") <= 0 && !ageBandOnFile(d).isEmpty
    }

    /// Two keys hold the band and both are real: the consult writes
    /// `onboardingAgeRange`, the cloud restore writes `ageRange`.
    static func ageBandOnFile(_ d: UserDefaults = .standard) -> String {
        let restored = d.string(forKey: "ageRange") ?? ""
        if !restored.isEmpty, representativeBandIsKnown(restored) { return restored }
        let onboarding = d.string(forKey: "onboardingAgeRange") ?? ""
        return representativeBandIsKnown(onboarding) ? onboarding : ""
    }

    private static func representativeBandIsKnown(_ band: String) -> Bool {
        ["under18", "18to24", "25to34", "35to44", "45to54", "55plus"].contains(band)
    }

    /// The band an exact age falls in. Mirrors `OV5Store.ageRangeBucket`,
    /// kept here so the editor and the consult cannot drift.
    static func ageBand(forYears years: Int) -> String {
        switch years {
        case ..<18: return "under18"
        case 18...24: return "18to24"
        case 25...34: return "25to34"
        case 35...44: return "35to44"
        case 45...54: return "45to54"
        default: return "55plus"
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
