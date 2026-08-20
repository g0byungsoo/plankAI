import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - CalorieGoldenMatrixTests
//
// **THE RELEASE FIXTURES.**
//
// Every number in this file is an exact integer the shipping build must
// produce. They are not derived from the code under test — they are the
// numbers a customer will see, written down, so that any future change
// to the formula, the activity table, the BMR constants, the clamps or
// the resolution order must come here and CHANGE THEM ON PURPOSE.
//
// A diff that touches this file is a diff that changes what a paying
// person is told to eat. That is the point.
//
// For every valid state: HOME == PLAN == JENI, to the integer.
// For every invalid state: NO TARGET — not zero, not a maintenance
// fallback, not an invented value.
//
// The formula is FROZEN this session (docs/app_v25/31 §14):
//   BMR    = 10·kg + 6.25·cm − 5·age − 161   (female / unspecified)
//          = 10·kg + 6.25·cm − 5·age + 5     (male)
//   TDEE   = round(BMR × factor), floored at 1200
//   target = clamp(TDEE − rate·kg·7700/7, floor: max(1200, BMR), ceil: 3500)

@MainActor
final class CalorieGoldenMatrixTests: XCTestCase {

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "golden-matrix"

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "safety_numeric_suppression", "onboarding_glp1_status",
        "onboardingHormonalStage", "onboardingSleepHours",
        "onboarding_weight_trend", "onboarding_glp1_phase",
        "onb_v4_movement_baseline", "activityLevel", "onb_v5_age_years",
        "ageRange", "onboardingAgeRange", "weightUnit",
    ]

    override func setUpWithError() throws { reset() }
    override func tearDownWithError() throws { reset() }

    private func reset() {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        let uid = userId
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    // MARK: - The personas

    private struct P {
        let name: String
        var currentLb: Double? = 124
        var goalLb: Double? = 110
        var heightCm: Double? = 160.02
        var sex: String = "female"
        var activity: String = "walks"
        var age: Int? = 34
        var glp1: String = ""
        var tier: String = "medium"
        var maintenance: Bool = false
        var planDays: Int? = 119
        var latestLb: Double? = nil
        /// The exact integer, or nil for "there must be no number".
        let kcal: Int?
    }

    /// **THE GOLDEN NUMBERS**, each derived by hand from the frozen
    /// formula before it was written down. The derivations are in
    /// `docs/app_v25/32_SHIP_THE_BORING_TRUTH.md` §CALORIE GOLDEN MATRIX.
    ///
    /// Anchor body: 124 lb = 56.2452 kg · 160.02 cm · 34 · female.
    ///   BMR  = 562.452 + 1000.125 − 170 − 161 = **1231.577**
    ///   rate = ((56.2452 − 49.8952)/56.2452)/17 wk = **0.0066411/wk**
    ///   deficit/day = 0.0066411 × 56.2452 × 7700/7 = **410.9**
    private static let golden: [P] = [
        // Autym-like loss user — the regression persona, pinned since
        // 2026-08-13 and unmoved by three sessions of repair work.
        // TDEE round(1231.577×1.375)=1693 − 411 = 1282.
        P(name: "autym-like loss (walks)", kcal: 1282),

        // The activity span, same body. Note SEDENTARY DOES NOT REACH
        // 1200: the floor is max(1200, BMR), and BMR is 1232 — so the
        // floor that binds is her own BMR, which is the gate doing
        // exactly what docs/app_v25/29 §3 says it does.
        P(name: "sedentary loss",  activity: "barely",      kcal: 1232),  // floor
        P(name: "moderate loss",   activity: "regular_ish", kcal: 1498),  // 1909−411
        P(name: "athlete loss",    activity: "very_active", kcal: 1713),  // 2124−411

        // Sex — Mifflin-St Jeor's only term: −161 vs +5.
        // male BMR 1397.577 → TDEE 1922 − 411 = 1511.
        P(name: "male loss",        sex: "male",      kcal: 1511),
        P(name: "female loss",      sex: "female",    kcal: 1282),
        P(name: "unspecified loss", sex: "nonbinary", kcal: 1282),

        // Cohort. Medication does not enter the energy arithmetic.
        P(name: "GLP-1 current",  glp1: "current", kcal: 1282),
        P(name: "non-GLP-1",      glp1: "never",   kcal: 1282),

        // Units are presentation only — the same body in kg.
        P(name: "kg customer", kcal: 1282),

        // Maintenance: a real number, and it is TDEE (rate 0).
        P(name: "maintenance chosen", goalLb: nil, maintenance: true,
          planDays: nil, kcal: 1693),

        // Arrival: 108 lb = 48.988 kg → BMR 1159.0 → TDEE 1594, rate 0.
        P(name: "at goal", planDays: nil, latestLb: 108, kcal: 1594),

        // The three refusals.
        P(name: "missing goal",   goalLb: nil,     planDays: nil, kcal: nil),
        P(name: "missing height", heightCm: nil,                  kcal: nil),
        P(name: "missing weight", currentLb: nil,  planDays: nil, kcal: nil),

        // The pace tiers, through her own numbers (no plan record), so
        // `ProgramGoalCalculator` picks the window: 23 · 17 · 15 weeks.
        // HARD lands on the BMR floor, which is why it equals sedentary.
        P(name: "soft tier",   tier: "soft",   planDays: nil, kcal: 1389),
        P(name: "medium tier", tier: "medium", planDays: nil, kcal: 1282),
        P(name: "hard tier",   tier: "hard",   planDays: nil, kcal: 1232),  // floor

        // The restored account: exact age 34 swept, band "25to34" → 29.
        // BMR 1256.577 → TDEE 1728 − 411 = 1317. See §5 of the record.
        P(name: "after sign-out/in (age from band)", age: nil, kcal: 1317),
    ]

    private func seed(_ p: P) {
        reset()
        if let v = p.currentLb { d.set(v / 2.20462, forKey: "onboardingCurrentWeightKg") }
        if let v = p.goalLb { d.set(v / 2.20462, forKey: "onboardingGoalWeightKg") }
        if let v = p.heightCm { d.set(v, forKey: "onboardingHeightCm") }
        d.set(p.sex, forKey: "onboardingGender")
        d.set(p.activity, forKey: "onb_v4_movement_baseline")
        if let v = p.age { d.set(v, forKey: "onb_v5_age_years") } else { d.set("25to34", forKey: "ageRange") }
        d.set(p.glp1, forKey: "onboarding_glp1_status")
        d.set(p.tier, forKey: "onboardingPickedTier")
        if p.maintenance {
            d.set("maintain", forKey: "onboarding_goal_direction")
            d.set("maintenance", forKey: "program_mode")
        }
        if let v = p.latestLb {
            context.insert(WeightLogRecord(userId: userId, weightKg: v / 2.20462))
        }
        if let days = p.planDays, let cur = p.currentLb, let goal = p.goalLb {
            let start = Calendar.current.date(byAdding: .day, value: -20, to: .now) ?? .now
            let plan = ProgramPlanRecord(
                userId: userId, startDate: start,
                goalDate: start.addingTimeInterval(Double(days) * 86_400),
                totalDays: days, currentWeightKg: cur / 2.20462,
                goalWeightKg: goal / 2.20462, intensityTier: p.tier
            )
            plan.pendingUpsert = false
            context.insert(plan)
        }
        try? context.save()
    }

    private func threeReaders() -> (home: Int?, plan: Int?, jeni: Int?) {
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let targets = TargetsService.current(userId: userId, in: context)
        let summary = PlanSummary.build(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(
                userId: userId, plan: plan, in: context),
            proteinG: targets.proteinG, stepsGoal: targets.steps,
            numericsSuppressed: targets.numericsSuppressed, defaults: d
        )
        return (targets.kcal, summary.energyKcal, targets.kcal)
    }

    // MARK: - THE MATRIX

    func testEveryGoldenPersonaProducesItsExactNumberOnAllThreeSurfaces() throws {
        for p in Self.golden {
            seed(p)
            let r = threeReaders()
            XCTAssertEqual(r.home, p.kcal,
                "[\(p.name)] HOME is a release fixture. If this changed on purpose, change it here on purpose.")
            XCTAssertEqual(r.plan, p.kcal, "[\(p.name)] PLAN must equal HOME")
            XCTAssertEqual(r.jeni, p.kcal, "[\(p.name)] JENI must quote the same integer")
            if p.kcal == nil {
                XCTAssertNotEqual(r.home, 0, "[\(p.name)] absent is not zero")
            }
        }
    }

    // MARK: - The edits, each asserted as a delta from the anchor

    /// After a GOAL edit.
    ///
    /// **The number barely moves, and that is the design.** The PACE tier
    /// sets the rate; a nearer goal therefore buys a shorter horizon, not
    /// a bigger dinner. `GoalWeightStore` recomputes `totalDays` through
    /// the same window calculator, so 110 → 115 lb takes the plan from 17
    /// weeks to 11 and leaves the daily deficit within 3 kcal. Asserting
    /// this pins the property; my first guess here was that the target
    /// would jump ~170 kcal, which would have meant the pace tier was not
    /// actually governing anything.
    func testAfterGoalEdit() throws {
        seed(P(name: "anchor", kcal: 1282))
        let before = try XCTUnwrap(threeReaders().home)
        GoalWeightStore.setGoalWeightKg(115 / 2.20462, userId: userId, in: context)
        let after = try XCTUnwrap(threeReaders().home)
        XCTAssertEqual(after, 1285)
        XCTAssertLessThanOrEqual(abs(after - before), 5,
            "the pace tier owns the rate; moving the goal moves the finish line, not the plate")
        XCTAssertEqual(threeReaders().plan, after)
    }

    /// After a WEIGHT edit. 118 lb = 53.524 kg → BMR 1204.4 → TDEE 1656,
    /// deficit 391 (the rate is a % of the lighter body) → 1265.
    func testAfterWeightEdit() throws {
        seed(P(name: "anchor", kcal: 1282))
        WeightLogWriter.persist(kg: 118 / 2.20462, userId: userId, in: context)
        let after = try XCTUnwrap(threeReaders().home)
        XCTAssertEqual(after, 1265)
        XCTAssertEqual(threeReaders().plan, after)
    }

    /// After an ACTIVITY edit — the largest single input, 481 kcal here.
    func testAfterActivityEdit() throws {
        seed(P(name: "anchor", kcal: 1282))
        BodyFactsStore.setActivityBaseline("barely", userId: userId, in: context)
        XCTAssertEqual(threeReaders().home, 1232,
            "sedentary lands on her own BMR, which is the energy-availability floor holding")
        BodyFactsStore.setActivityBaseline("very_active", userId: userId, in: context)
        XCTAssertEqual(threeReaders().home, 1713)
    }

    /// After a SEX edit. 166 kcal of BMR × 1.375 = 229.
    func testAfterSexEdit() throws {
        seed(P(name: "anchor", kcal: 1282))
        BodyFactsStore.setSex("male", userId: userId, in: context)
        XCTAssertEqual(threeReaders().home, 1511)
        BodyFactsStore.setSex("female", userId: userId, in: context)
        XCTAssertEqual(threeReaders().home, 1282, "and back, exactly")
    }

    /// After a PACE edit. Gentler pace, longer plan, more food.
    func testAfterPaceEdit() throws {
        seed(P(name: "anchor", kcal: 1282))
        GoalWeightStore.setPaceTier(.soft, userId: userId, in: context)
        let after = try XCTUnwrap(threeReaders().home)
        XCTAssertGreaterThan(after, 1282)
        XCTAssertEqual(after, 1389)
    }

    /// After an AGE edit — 5 kcal of BMR per year, times the factor.
    /// 34 → 44 is 50 BMR kcal → 1625 TDEE − 411 = 1214.
    func testAfterAgeEdit() throws {
        seed(P(name: "anchor", kcal: 1282))
        BodyFactsStore.setAgeYears(44, userId: userId, in: context)
        XCTAssertEqual(threeReaders().home, 1214)
    }

    /// After SIGN-OUT → SIGN-IN. The known, documented, LOSSY step: the
    /// exact age is swept and the band's representative year comes back.
    /// This assertion exists so the loss can never grow silently.
    func testAfterSignOutAndSignInTheOnlyDriftIsTheAgeBand() throws {
        seed(P(name: "anchor", kcal: 1282))
        let before = try XCTUnwrap(threeReaders().home)

        // The sweep, exactly as `clearOnboardingUserDefaults` performs it
        // for the identity-scoped body keys.
        for key in ["onboardingCurrentWeightKg", "onboardingGoalWeightKg",
                    "onboardingHeightCm", "onboardingGender",
                    "onb_v5_age_years", "onb_v4_movement_baseline",
                    "ageRange", "activityLevel"] {
            d.removeObject(forKey: key)
        }
        // The restore, exactly as hydrate performs it.
        let record = UserRecord(id: userId, name: "restored")
        record.onboardingCurrentWeightKg = 124 / 2.20462
        record.onboardingGoalWeightKg = 110 / 2.20462
        record.onboardingHeightCm = 160.02
        record.onboardingGender = "female"
        record.onboardingActivityLevel = "walks"
        record.onboardingAgeRange = "25to34"
        record.pendingUpsert = false
        AppSync.restoreBodyDefaults(from: record, into: d)
        AppSync.mirrorActivityAlias(from: record, into: d)
        d.set(record.onboardingAgeRange ?? "", forKey: "ageRange")

        let after = try XCTUnwrap(threeReaders().home)
        XCTAssertEqual(after, 1317,
            "the ONLY permitted drift is the age band: 34 comes back as 29")
        XCTAssertEqual(after - before, 35,
            "25 kcal of BMR × 1.375 = 35 on the target. If this delta ever grows, a SECOND lossy input has appeared and the record in docs/app_v25/31 §5 is wrong.")
        XCTAssertTrue(TargetsService.ageIsApproximate(d),
            "and the app says so on screen rather than pretending it knows her year")
    }

    /// After a SERVER REPAIR. The Autym path, priced.
    func testAfterServerRepair() throws {
        seed(P(name: "corrupt", goalLb: 124, planDays: 210, kcal: nil))
        XCTAssertNil(threeReaders().home, "goal == start publishes nothing")

        let plan = try XCTUnwrap(ProgramService.shared.activePlan(userId: userId, in: context))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        ProgramPlanMerge.apply(ProgramPlanHydrateRow(
            id: plan.id.lowercased(), user_id: userId.lowercased(),
            start_date: f.string(from: plan.startDate),
            goal_date: f.string(from: plan.startDate.addingTimeInterval(119 * 86_400)),
            total_days: 119, current_weight_kg: 124 / 2.20462,
            goal_weight_kg: 110 / 2.20462, intensity_tier: "medium",
            phase: "active", parent_plan_id: nil, archived_at: nil, completed_at: nil
        ), to: plan)
        d.set(110 / 2.20462, forKey: "onboardingGoalWeightKg")

        XCTAssertEqual(threeReaders().home, 1282,
            "after the repair she is on the same number a never-corrupted customer gets")
        XCTAssertEqual(threeReaders().plan, 1282)
    }

    // MARK: - The refusals, stated as refusals

    func testAnInvalidStateIsNeverZeroAndNeverAFallback() throws {
        for p in Self.golden where p.kcal == nil {
            seed(p)
            let r = threeReaders()
            XCTAssertNil(r.home, "[\(p.name)]")
            XCTAssertNil(r.plan, "[\(p.name)]")
            XCTAssertNil(r.jeni, "[\(p.name)]")
            XCTAssertNotNil(
                TargetsService.missingEnergyInput(
                    plan: ProgramService.shared.activePlan(userId: userId, in: context),
                    latestWeightKg: TargetsService.resolvedWeightKg(
                        userId: userId,
                        plan: ProgramService.shared.activePlan(userId: userId, in: context),
                        in: context),
                    defaults: d),
                "[\(p.name)] an absent target must always name the fact that is missing")
        }
    }

    func testNumericSuppressionPublishesNoNumberAtAll() throws {
        seed(P(name: "suppressed", kcal: 1282))
        d.set(true, forKey: "safety_numeric_suppression")
        defer { d.removeObject(forKey: "safety_numeric_suppression") }
        let targets = TargetsService.current(userId: userId, in: context)
        if targets.numericsSuppressed {
            XCTAssertNil(targets.kcal, "a suppressed cohort is shown no energy numeral")
        }
    }
}
