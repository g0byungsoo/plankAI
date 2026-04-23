import Foundation
import SwiftData

// MARK: - User

@Model
public final class UserRecord {
    @Attribute(.unique) public var id: String  // = auth.uid()
    public var name: String
    public var startDate: Date
    public var currentDay: Int
    public var coreScore: Double
    public var lastSessionDate: Date?
    public var streakCurrent: Int
    public var streakLongest: Int
    public var streakLastResetDate: Date?
    public var programPhase: String  // "foundations" | "continuous"
    public var foundationsCompletedDate: Date?

    // Onboarding data
    public var onboardingGoal: String?
    public var onboardingExperience: String?
    public var onboardingBaselineHoldSeconds: Int?
    public var onboardingBarriers: [String]?
    public var onboardingAgeRange: String?
    public var onboardingActivityLevel: String?
    public var onboardingCommitmentDaysPerWeek: Int?
    public var onboardingNotificationEnabled: Bool
    public var onboardingNotificationTime: Date?
    public var onboardingVoicePreference: String?  // "encouraging" | "balanced" | "roast"

    public init(
        id: String,
        name: String,
        startDate: Date = .now,
        currentDay: Int = 1,
        coreScore: Double = 0,
        programPhase: String = "foundations"
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.currentDay = currentDay
        self.coreScore = coreScore
        self.streakCurrent = 0
        self.streakLongest = 0
        self.programPhase = programPhase
        self.onboardingNotificationEnabled = false
    }
}

// MARK: - Session Log (append-only)

@Model
public final class SessionLogRecord {
    @Attribute(.unique) public var id: String  // client-generated UUID
    public var userId: String
    public var exerciseType: String
    public var completedAt: Date
    public var holdTime: Double
    public var targetTime: Double
    public var qualityScore: Double
    public var formFaultsCount: Int
    public var modifiedVersion: Bool
    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        exerciseType: String,
        completedAt: Date = .now,
        holdTime: Double,
        targetTime: Double,
        qualityScore: Double,
        formFaultsCount: Int = 0,
        modifiedVersion: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.exerciseType = exerciseType
        self.completedAt = completedAt
        self.holdTime = holdTime
        self.targetTime = targetTime
        self.qualityScore = qualityScore
        self.formFaultsCount = formFaultsCount
        self.modifiedVersion = modifiedVersion
        self.pendingUpsert = true
    }
}

// MARK: - Day Progress (derived, one per user per day)

@Model
public final class DayProgressRecord {
    @Attribute(.unique) public var compositeKey: String  // "userId:programDay"
    public var userId: String
    public var programDay: Int
    public var date: Date
    public var primarySessionId: String
    public var primaryQualityScore: Double
    public var primaryHoldTime: Double
    public var updatedAt: Date

    public init(
        userId: String,
        programDay: Int,
        date: Date = .now,
        primarySessionId: String,
        primaryQualityScore: Double,
        primaryHoldTime: Double
    ) {
        self.compositeKey = "\(userId):\(programDay)"
        self.userId = userId
        self.programDay = programDay
        self.date = date
        self.primarySessionId = primarySessionId
        self.primaryQualityScore = primaryQualityScore
        self.primaryHoldTime = primaryHoldTime
        self.updatedAt = .now
    }
}

// MARK: - Exercise

@Model
public final class ExerciseRecord {
    @Attribute(.unique) public var type: String
    public var unlockDay: Int
    public var isStatic: Bool

    public init(type: String, unlockDay: Int, isStatic: Bool) {
        self.type = type
        self.unlockDay = unlockDay
        self.isStatic = isStatic
    }

    /// Default exercise library for the 30-day Foundations program.
    public static let foundations: [ExerciseRecord] = [
        ExerciseRecord(type: "plank", unlockDay: 1, isStatic: true),
        ExerciseRecord(type: "deadBug", unlockDay: 8, isStatic: false),
        ExerciseRecord(type: "sidePlank", unlockDay: 15, isStatic: true),
        ExerciseRecord(type: "hollowHold", unlockDay: 22, isStatic: true),
        ExerciseRecord(type: "birdDog", unlockDay: 22, isStatic: false),
    ]
}

// MARK: - Exercise Calibration

@Model
public final class ExerciseCalibrationRecord {
    @Attribute(.unique) public var compositeKey: String  // "userId:exerciseType"
    public var userId: String
    public var exerciseType: String
    public var difficulty: String  // "regression" | "modified" | "full"
    public var calibratedAt: Date

    public init(userId: String, exerciseType: String, difficulty: String = "full") {
        self.compositeKey = "\(userId):\(exerciseType)"
        self.userId = userId
        self.exerciseType = exerciseType
        self.difficulty = difficulty
        self.calibratedAt = .now
    }
}
