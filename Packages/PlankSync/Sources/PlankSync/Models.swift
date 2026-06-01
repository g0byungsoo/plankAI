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
    public var onboardingFocusArea: String?  // "abs" | "obliques" | "lowerBack" | "fullCore"
    public var onboardingPlankTime: String?  // "morning" | "afternoon" | "evening" | "whenever"
    public var onboardingSessionLengthPref: Int?  // 5 | 7 | 10 (minutes)

    // Phase 4 additions. SwiftData lightweight automatic migration covers
    // these for existing rows: bodyFocus defaults to [], the weights
    // default to nil. Cross-device sync via Supabase column
    // onboarding_body_focus (text[]) and onboarding_current_weight_kg /
    // onboarding_goal_weight_kg (double precision).
    public var onboardingBodyFocus: [String]  // ["flatBelly","tonedArms","roundButt","slimLegs","fullBody"]
    public var onboardingCurrentWeightKg: Double?
    public var onboardingGoalWeightKg: Double?

    // Phase 4 remaining onboarding fields (2026-05-04 second migration).
    // String/array fields default to "" / [] so reads-before-write are
    // safe; numeric + boolean fields are optional so a NULL DB column
    // (legacy or untouched) decodes cleanly. Once OnboardingData adopts
    // optional Swift types in v1.1, the optional fields here can carry
    // a real "not answered" signal — today's writes still persist
    // OnboardingData's defaulted values verbatim, same as the weights.
    public var onboardingMotivation: String        // Part 1 "why"
    public var onboardingWorkoutLocation: String   // Part 2: home/gym/outdoor/either
    public var onboardingWorkoutStyle: [String]    // Part 2 multi: hiit/pilates/strength/yoga/dance/walking
    public var onboardingGender: String            // Part 3
    public var onboardingHeightCm: Double?
    public var onboardingBodyTypeCurrent: Int?     // Part 3 visual reference 0-5
    public var onboardingBodyTypeDesired: Int?
    public var onboardingIdentityFeeling: String   // Part 4: powerful/calm/light/strong/radiant
    public var onboardingRewardChoice: String      // Part 4: clothes/trip/photos/personal/treat
    public var onboardingRelatability1: Bool?      // Part 5 yes/no triplet
    public var onboardingRelatability2: Bool?
    public var onboardingRelatability3: Bool?

    /// 2026-05-30 (epic #1 child #7): how the user heard about JeniFit.
    /// One of "tiktok" | "instagram" | "friend" | "app_store" | "google"
    /// | "other". Optional so SwiftData lightweight migration covers
    /// legacy rows + the field can carry a real "not answered" signal.
    /// Cross-device sync via public.users.onboarding_acquisition_source
    /// (text, nullable). JeniFit is $0 CAC organic TikTok — this is the
    /// only signal we'll have for which creator/post is converting.
    public var onboardingAcquisitionSource: String?

    /// Set true by any client-side write (settings edits, onboarding-complete)
    /// and cleared on successful upsert. Drives the retry sweep on app launch
    /// so a force-quit between write + network response never silently loses
    /// the edit when the next hydrate overwrites local with stale cloud.
    /// Defaults to false — SwiftData lightweight migration covers existing
    /// rows so they're treated as already-synced (the cloud row IS them).
    public var pendingUpsert: Bool = false

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
        self.onboardingBodyFocus = []
        self.onboardingMotivation = ""
        self.onboardingWorkoutLocation = ""
        self.onboardingWorkoutStyle = []
        self.onboardingGender = ""
        self.onboardingIdentityFeeling = ""
        self.onboardingRewardChoice = ""
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

    // v2: routine session support
    public var sessionType: String          // "plank_benchmark" | "routine"
    public var presetId: String?            // WorkoutPreset.id if from a preset
    public var exerciseResults: Data?       // JSON-encoded [ExerciseResultEntry]
    public var totalDuration: Double?       // seconds, full routine duration
    public var plankHoldTime: Double?       // benchmark hold time (if closer done)
    public var plankFormScore: Double?      // benchmark form score (if closer done)

    public init(
        id: String = UUID().uuidString,
        userId: String,
        exerciseType: String,
        completedAt: Date = .now,
        holdTime: Double,
        targetTime: Double,
        qualityScore: Double,
        formFaultsCount: Int = 0,
        modifiedVersion: Bool = false,
        sessionType: String = "plank_benchmark",
        presetId: String? = nil,
        exerciseResults: Data? = nil,
        totalDuration: Double? = nil,
        plankHoldTime: Double? = nil,
        plankFormScore: Double? = nil
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
        self.sessionType = sessionType
        self.presetId = presetId
        self.exerciseResults = exerciseResults
        self.totalDuration = totalDuration
        self.plankHoldTime = plankHoldTime
        self.plankFormScore = plankFormScore
    }
}

// MARK: - Exercise Result Entry (encoded as JSON in SessionLogRecord.exerciseResults)

public struct ExerciseResultEntry: Codable {
    public let exerciseId: String
    public let duration: Int           // planned duration
    public let completedDuration: Int  // actual time spent
    public let skipped: Bool

    public init(exerciseId: String, duration: Int, completedDuration: Int, skipped: Bool) {
        self.exerciseId = exerciseId
        self.duration = duration
        self.completedDuration = completedDuration
        self.skipped = skipped
    }

    // Explicit camelCase keys lock the wire format. The Supabase SDK may
    // apply a key-encoding strategy (e.g., snake_case) at the encoder
    // level when serializing the outer upsert payload — without these
    // explicit keys, that strategy would rename `exerciseId` → `exercise_id`
    // on write, but the local SessionLogRecord round-trip uses a plain
    // JSONDecoder that expects camelCase. Locking the keys keeps both
    // sides consistent.
    enum CodingKeys: String, CodingKey {
        case exerciseId
        case duration
        case completedDuration
        case skipped
    }
}

extension SessionLogRecord {
    public var decodedExerciseResults: [ExerciseResultEntry] {
        guard let data = exerciseResults else { return [] }
        return (try? JSONDecoder().decode([ExerciseResultEntry].self, from: data)) ?? []
    }

    public func encodeExerciseResults(_ results: [ExerciseResultEntry]) -> Data? {
        try? JSONEncoder().encode(results)
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

    // v2: multiple sessions per day (routine + benchmark)
    public var sessionLogIds: [String]?

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

// MARK: - Session Rating

@Model
public final class SessionRatingRecord {
    @Attribute(.unique) public var id: String
    public var sessionLogId: String
    public var rating: Int             // 1-5 stars
    public var tags: [String]          // "too_easy", "too_hard", "loved_it", "boring"
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sessionLogId: String,
        rating: Int,
        tags: [String] = []
    ) {
        self.id = id
        self.sessionLogId = sessionLogId
        self.rating = rating
        self.tags = tags
        self.createdAt = .now
    }
}

// MARK: - Weight Log
//
// Append-only weight history. Each entry is a single weigh-in. Source tags
// the input modality so we can audit data quality later (manual entries are
// trusted differently than HealthKit pulls).
//
// See `docs/weight_loss_analytics_research.md` — weight trend (7-day EMA)
// is the load-bearing metric for the analytics surface; without history,
// the trend chart can't render.

@Model
public final class WeightLogRecord {
    @Attribute(.unique) public var id: String   // client-generated UUID
    public var userId: String
    public var weightKg: Double
    public var loggedAt: Date
    /// One of: "onboarding" | "manual" | "healthkit" | "apple_health"
    public var source: String
    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        weightKg: Double,
        loggedAt: Date = .now,
        source: String = "manual"
    ) {
        self.id = id
        self.userId = userId
        self.weightKg = weightKg
        self.loggedAt = loggedAt
        self.source = source
        self.pendingUpsert = true
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
    public nonisolated(unsafe) static let foundations: [ExerciseRecord] = [
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
