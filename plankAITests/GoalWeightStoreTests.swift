import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - GoalWeightStoreTests
//
// EDITABILITY, which was category-basic and entirely absent.
//
// Before this: `EditProfileView` is titled "your pace." and edits ONE
// value — `workoutLevel`. There was no surface anywhere in the app
// that could change the goal weight, the height, or the start weight.
// A user who mis-set her goal in onboarding had exactly one repair:
// delete the account.
//
// The write must repair the PLAN too, or the edit is cosmetic — the
// energy target reads the plan, not the stored answer.
//
// And it must not reset her program. A re-enroll mints a fresh plan
// with `startDate = .now`, which is the documented incident that ate
// the founder's day count (AppSync:520). Editing a goal keeps the
// plan she is living in and moves its horizon.

@MainActor
final class GoalWeightStoreTests: XCTestCase {

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "goal-store-tests"

    private static let keys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "onb_v4_movement_baseline",
    ]

    override func setUpWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
        d.set(124 / 2.20462, forKey: "onboardingCurrentWeightKg")
        d.set(160.02, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set("medium", forKey: "onboardingPickedTier")
        d.set("lose", forKey: "onboarding_goal_direction")
        d.set("loss", forKey: "program_mode")
        d.set("walks", forKey: "onb_v4_movement_baseline")
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == "goal-store-tests" })
    }

    override func tearDownWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == "goal-store-tests" })
    }

    @discardableResult
    private func seedPlan(goalKg: Double, startedDaysAgo: Int = 12)
        -> ProgramPlanRecord {
        let start = Calendar.current.date(
            byAdding: .day, value: -startedDaysAgo, to: .now) ?? .now
        let plan = ProgramPlanRecord(
            userId: userId,
            startDate: start,
            goalDate: start.addingTimeInterval(119 * 86_400),
            totalDays: 119,
            currentWeightKg: 124 / 2.20462,
            goalWeightKg: goalKg,
            intensityTier: "medium"
        )
        context.insert(plan)
        try? context.save()
        return plan
    }

    // MARK: - The write

    func testSettingAGoalPersistsItWhereEverySurfaceReadsIt() {
        GoalWeightStore.setGoalWeightKg(105 / 2.20462, userId: userId,
                                        in: context, defaults: d)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"),
                       105 / 2.20462, accuracy: 0.001)
    }

    func testSettingAGoalMovesThePlanSheIsLivingIn() {
        let plan = seedPlan(goalKg: 110 / 2.20462)
        let daysBefore = plan.totalDays

        GoalWeightStore.setGoalWeightKg(106 / 2.20462, userId: userId,
                                        in: context, defaults: d)

        XCTAssertEqual(plan.goalWeightKg ?? 0, 106 / 2.20462, accuracy: 0.001)
        XCTAssertGreaterThan(plan.totalDays, daysBefore,
            "a further goal is a longer horizon, not the same one")
        XCTAssertTrue(plan.pendingUpsert, "the change must reach the cloud")
    }

    /// The incident this must never repeat: a re-enroll resets the day
    /// count. An edit is not an enrollment.
    func testEditingTheGoalNeverRestartsHerProgram() {
        let plan = seedPlan(goalKg: 110 / 2.20462, startedDaysAgo: 12)
        let startBefore = plan.startDate
        let planId = plan.id

        GoalWeightStore.setGoalWeightKg(106 / 2.20462, userId: userId,
                                        in: context, defaults: d)

        XCTAssertEqual(plan.startDate, startBefore)
        XCTAssertNil(plan.archivedAt)
        XCTAssertEqual(plan.id, planId)
        let all = (try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == "goal-store-tests" }))) ?? []
        XCTAssertEqual(all.count, 1, "an edit must not mint a second plan")
    }

    /// Goal and start weight are different facts. Editing one must not
    /// touch the other — the whole customer report is these two
    /// collapsing into each other.
    func testEditingTheGoalNeverTouchesTheStartWeight() {
        let plan = seedPlan(goalKg: 110 / 2.20462)
        let startWeight = plan.currentWeightKg

        GoalWeightStore.setGoalWeightKg(106 / 2.20462, userId: userId,
                                        in: context, defaults: d)

        XCTAssertEqual(plan.currentWeightKg ?? 0, startWeight ?? -1, accuracy: 0.0001)
        XCTAssertEqual(d.double(forKey: "onboardingCurrentWeightKg"),
                       124 / 2.20462, accuracy: 0.0001)
    }

    // MARK: - Safety

    /// The BMI-18.5 floor is the same one the program build enforces.
    /// A goal under it is clamped, and the caller is told.
    func testAGoalBelowTheHealthyFloorIsClampedToIt() {
        let floor = ProgramGoalCalculator.weightForBMI(18.5, heightCm: 160.02)
        let result = GoalWeightStore.setGoalWeightKg(
            floor - 6, userId: userId, in: context, defaults: d)

        XCTAssertEqual(result.storedKg, floor, accuracy: 0.001)
        XCTAssertTrue(result.wasClampedToHealthyFloor)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), floor, accuracy: 0.001)
    }

    /// A goal at or above the current weight is a maintenance
    /// statement, not a loss goal — and it is recorded as one, so no
    /// downstream reader has to guess.
    func testAGoalAtOrAboveCurrentRecordsMaintenanceExplicitly() {
        GoalWeightStore.setGoalWeightKg(124 / 2.20462, userId: userId,
                                        in: context, defaults: d)
        XCTAssertEqual(d.string(forKey: "onboarding_goal_direction"), "maintain")
        XCTAssertEqual(d.string(forKey: "program_mode"), "maintenance")
    }

    /// …and setting a real loss goal takes her back out of maintenance.
    func testSettingALossGoalLeavesMaintenance() {
        GoalWeightStore.setGoalWeightKg(124 / 2.20462, userId: userId,
                                        in: context, defaults: d)
        GoalWeightStore.setGoalWeightKg(110 / 2.20462, userId: userId,
                                        in: context, defaults: d)
        XCTAssertEqual(d.string(forKey: "onboarding_goal_direction"), "lose")
        XCTAssertEqual(d.string(forKey: "program_mode"), "loss")
    }

    // MARK: - The consequence

    /// The point of the edit: the number she eats to must move.
    func testTheEnergyTargetFollowsTheGoal() {
        let gentle = GoalWeightStore.setGoalWeightKg(
            120 / 2.20462, userId: userId, in: context, defaults: d)
        let gentleKcal = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: 124 / 2.20462, defaults: d)

        _ = gentle
        GoalWeightStore.setGoalWeightKg(106 / 2.20462, userId: userId,
                                        in: context, defaults: d)
        let steeperKcal = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: 124 / 2.20462, defaults: d)

        XCTAssertNotNil(gentleKcal)
        XCTAssertNotNil(steeperKcal)
        XCTAssertNotEqual(gentleKcal, steeperKcal,
            "a different goal must produce a different daily target")
    }
}
