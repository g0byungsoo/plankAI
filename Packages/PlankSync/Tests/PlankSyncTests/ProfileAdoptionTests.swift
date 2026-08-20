import XCTest
import SwiftData
@testable import PlankSync

// MARK: - ProfileAdoptionTests
//
// v25 pass 51 — AN ABSENT SERVER VALUE IS NEVER ADOPTED.
//
// The layer's own stated law (AppSync's defaults mirror has carried it
// since the restore work): a NULL server column means the server never
// learned the fact, not that she gave it up. `hydrateUser`'s column
// copy did not honor it — a legacy row with NULL `onboardingGender`
// blanked the BMR's sex input to "", NULL `onboardingHeightCm` erased
// the height the energy math needs, and `promisesKept ?? 0` zeroed the
// activation counter. Worse, the erased values then rode the next
// `upsertUser` back to the server, converting one missing column into
// a durable loss loop.

@MainActor
final class ProfileAdoptionTests: XCTestCase {

    private var context: ModelContext {
        HydrationNormalizationTests.container.mainContext
    }

    private let userId = "AAAA1111-BBBB-2222-CCCC-P51PROFILE00"

    override func setUpWithError() throws { wipe() }
    override func tearDownWithError() throws { wipe() }

    private func wipe() {
        let uid = userId
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == uid })
        try? context.save()
    }

    /// A wire row shaped like a LEGACY server row: the non-optional
    /// core columns present, every later-era column NULL.
    private func legacyRow(
        gender: String? = nil,
        heightCm: Double? = nil,
        currentWeightKg: Double? = nil,
        goalWeightKg: Double? = nil,
        motivation: String? = nil,
        promisesKept: Int? = nil
    ) -> SupabaseUserRow {
        SupabaseUserRow(
            id: userId.lowercased(), name: "maya",
            startDate: Date(timeIntervalSince1970: 1_780_000_000),
            currentDay: 12, coreScore: 0.8,
            lastSessionDate: nil, streakCurrent: 3, streakLongest: 5,
            streakLastResetDate: nil, programPhase: "active",
            foundationsCompletedDate: nil,
            onboardingGoal: nil, onboardingExperience: nil,
            onboardingBaselineHoldSeconds: nil, onboardingBarriers: nil,
            onboardingAgeRange: nil, onboardingActivityLevel: nil,
            onboardingCommitmentDaysPerWeek: nil,
            onboardingNotificationEnabled: false,
            onboardingNotificationTime: nil, onboardingVoicePreference: nil,
            onboardingFocusArea: nil, onboardingPlankTime: nil,
            onboardingSessionLengthPref: nil,
            onboardingBodyFocus: nil,
            onboardingCurrentWeightKg: currentWeightKg,
            onboardingGoalWeightKg: goalWeightKg,
            onboardingMotivation: motivation,
            onboardingWorkoutLocation: nil, onboardingWorkoutStyle: nil,
            onboardingGender: gender,
            onboardingHeightCm: heightCm,
            onboardingBodyTypeCurrent: nil, onboardingBodyTypeDesired: nil,
            onboardingIdentityFeeling: nil, onboardingRewardChoice: nil,
            onboardingRelatability1: nil, onboardingRelatability2: nil,
            onboardingRelatability3: nil, onboardingAcquisitionSource: nil,
            onboardingGlp1Status: nil, onboardingGlp1Phase: nil,
            onboardingHormonalStage: nil, onboardingWeightTrend: nil,
            onboardingSleepHours: nil, onboardingStressLevel: nil,
            onboardingEatingCadence: nil, onboardingEatingWindow: nil,
            onboardingFoodRelationship: nil,
            computedStartBMI: nil, targetRatePctPerWeek: nil,
            medicalDisclaimerAckAt: nil,
            promisesKept: promisesKept
        )
    }

    private func populatedLocal() -> UserRecord {
        let target = UserRecord(id: userId, name: "maya")
        target.onboardingGender = "female"
        target.onboardingHeightCm = 160.02
        target.onboardingCurrentWeightKg = 56.2
        target.onboardingGoalWeightKg = 49.9
        target.onboardingMotivation = "health"
        target.promisesKept = 7
        context.insert(target)
        try? context.save()
        return target
    }

    func testANullServerColumnNeverErasesALocalFact() {
        let target = populatedLocal()
        SyncService.applyHydratedUser(legacyRow(), to: target)

        XCTAssertEqual(target.onboardingGender, "female",
                       "a NULL gender column blanked the BMR's sex input")
        XCTAssertEqual(target.onboardingHeightCm, 160.02,
                       "a NULL height column erased the energy math's input")
        XCTAssertEqual(target.onboardingCurrentWeightKg, 56.2)
        XCTAssertEqual(target.onboardingGoalWeightKg, 49.9)
        XCTAssertEqual(target.onboardingMotivation, "health")
        XCTAssertEqual(target.promisesKept, 7,
                       "a NULL promises column zeroed the activation counter")
    }

    /// Control — a PRESENT server value is adopted (the recovery
    /// contract: a support repair must land on a clean device).
    func testAPresentServerValueIsAdopted() {
        let target = populatedLocal()
        SyncService.applyHydratedUser(
            legacyRow(gender: "female", heightCm: 162.5,
                      currentWeightKg: 55.0, goalWeightKg: 50.0,
                      motivation: "energy", promisesKept: 9),
            to: target
        )
        XCTAssertEqual(target.onboardingHeightCm, 162.5)
        XCTAssertEqual(target.onboardingCurrentWeightKg, 55.0)
        XCTAssertEqual(target.onboardingMotivation, "energy")
        XCTAssertEqual(target.promisesKept, 9)
    }

    /// Control — the non-optional core columns adopt unconditionally
    /// (the server always has a value for them).
    func testCoreColumnsAlwaysAdopt() {
        let target = populatedLocal()
        SyncService.applyHydratedUser(legacyRow(), to: target)
        XCTAssertEqual(target.currentDay, 12)
        XCTAssertEqual(target.programPhase, "active")
    }
}
