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

    /// 2026-06-23 — cohort + clinical intake (medical-grade / GLP-1 partnership
    /// persistence P0, see docs/medical_grade_survey_audit_2026_06_23.md).
    /// These drove in-app cohort routing but were AppStorage-only and never
    /// synced — so no cohort analytics was possible. Now persisted to
    /// public.users so retention/outcomes can segment by GLP-1 status,
    /// hormonal stage, and weight trajectory. All optional/nullable so legacy
    /// rows + never-answered users decode cleanly. Self-reported, no drug
    /// brand names, no dose.
    public var onboardingGlp1Status: String?        // none/considering/past/current/prefer_not_say
    public var onboardingGlp1Phase: String?         // just_started/few_months/established/prefer_not (current only)
    public var onboardingHormonalStage: String?     // cycling/irregular/postpartum/perimenopause/postmenopause/prefer_not_say
    public var onboardingWeightTrend: String?        // climbing/stable/declining/cycling
    public var onboardingSleepHours: String?        // band key
    public var onboardingStressLevel: String?       // low/manageable/heavy/overwhelmed
    public var onboardingEatingCadence: String?     // meal-pattern key
    public var onboardingEatingWindow: String?      // eating-window key
    public var onboardingFoodRelationship: String?  // fuel/comfort/love/control/complicated

    // MARK: - Clinical baseline (Phase 1a, 2026-06-28)
    //
    // All three fields are optional so SwiftData lightweight migration covers
    // existing rows automatically - nil means "not yet computed / not answered".
    //
    // computedStartBMI: BMI at onboarding completion, derived from
    //   onboardingCurrentWeightKg + onboardingHeightCm via ClinicalBaseline.bmi().
    //   Synced to public.users.computed_start_bmi (double precision, nullable).
    //
    // targetRatePctPerWeek: loss-rate floor x 100 from
    //   ProgramGoalCalculator.Window.lossRateFloor, which already encodes the
    //   GLP-1 / perimenopause / short-sleep cohort adjustments at onboarding.
    //   Synced to public.users.target_rate_pct_per_week (double precision, nullable).
    //
    // medicalDisclaimerAckAt: set by the disclaimer acknowledgment screen
    //   (Task 8). Left nil here; nil = user has not yet seen / acked the screen.
    //   Synced to public.users.medical_disclaimer_ack_at (timestamptz, nullable).
    public var computedStartBMI: Double?
    public var targetRatePctPerWeek: Double?
    public var medicalDisclaimerAckAt: Date?

    // MARK: - Habit / activation counters (Phase 1a, 2026-06-28)
    //
    // promisesKept: cumulative count of habit completions the user has
    //   honoured (lesson read, breath session, food log, weigh-in, etc.).
    //   Consumed by Task 9 (home hero) and Task 10 (kept-promise win card).
    //   Default 0; non-optional with default is migration-safe for SwiftData
    //   lightweight migration - existing rows read 0 until first increment.
    //   Synced to public.users.promises_kept (integer not null default 0).
    public var promisesKept: Int = 0

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
    /// App v2: owner scoping for cross-account isolation + sync.
    /// Optional because pre-v2 rows were written without it (they
    /// were never synced; the write path itself was disconnected —
    /// docs/app_v2/01_AUDIT.md defect #3). Additive optional field:
    /// lightweight-migrates in place.
    public var userId: String?
    public var sessionLogId: String
    public var rating: Int             // 1-5 stars
    public var tags: [String]          // "too_easy", "too_hard", "loved_it", "boring"
    public var createdAt: Date
    /// Cloud push flag, same discipline as every synced record.
    /// Declaration default (false) is the lightweight-migration value
    /// for pre-v2 rows — they carry no userId, so there is nothing to
    /// push; fresh writes flip it true in init.
    public var pendingUpsert: Bool = false

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        sessionLogId: String,
        rating: Int,
        tags: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.sessionLogId = sessionLogId
        self.rating = rating
        self.tags = tags
        self.createdAt = .now
        self.pendingUpsert = true
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

// MARK: - Program Plan (v1.1 program pivot)
//
// One row per program enrollment. The header row that gates whether
// PlanView's DailyChecklistCard renders + drives the IntensityProfile
// lookup. ProgramService enforces "one active per user" client-side;
// graduation transitions write (old.phase='completed', new active row)
// in one async block.
//
// Mirrors the public.program_plans schema. Client-generated id so
// crash retries idempotently upsert.

@Model
public final class ProgramPlanRecord {
    @Attribute(.unique) public var id: String   // client-generated UUID

    public var userId: String

    public var startDate: Date

    public var goalDate: Date

    public var totalDays: Int

    /// Snapshot at enrollment. May go stale if user logs new weight
    /// mid-program — that's fine; analytics/cohort recovery use these
    /// to know the starting context.
    public var currentWeightKg: Double?
    public var goalWeightKg: Double?

    /// "soft" | "medium" | "hard" (IntensityTier raw)
    public var intensityTier: String

    /// "active" | "maintenance" | "recomp" | "pause" | "completed" | "abandoned"
    public var phase: String

    public var parentPlanId: String?

    public var archivedAt: Date?

    public var completedAt: Date?

    public var createdAt: Date
    public var updatedAt: Date

    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        startDate: Date,
        goalDate: Date,
        totalDays: Int,
        currentWeightKg: Double? = nil,
        goalWeightKg: Double? = nil,
        intensityTier: String,
        phase: String = "active",
        parentPlanId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.startDate = startDate
        self.goalDate = goalDate
        self.totalDays = totalDays
        self.currentWeightKg = currentWeightKg
        self.goalWeightKg = goalWeightKg
        self.intensityTier = intensityTier
        self.phase = phase
        self.parentPlanId = parentPlanId
        self.archivedAt = nil
        self.completedAt = nil
        self.createdAt = .now
        self.updatedAt = .now
        self.pendingUpsert = true
    }
}

// MARK: - Program Day Check (v1.1 program pivot)
//
// Per-day-per-row checklist state. Auto-completed rows insert when the
// telemetry fires; self-check rows insert on user tap. UNIQUE on
// (userId, programPlanId, programDay, itemKey) prevents duplicate
// checks for the same item on the same day. Client-generated id so
// retries idempotently upsert.

@Model
public final class ProgramDayCheckRecord {
    @Attribute(.unique) public var id: String   // client-generated UUID

    public var userId: String

    public var programPlanId: String

    public var programDay: Int

    /// Matches ProgramDayPrescription.itemKey. Keep in sync.
    public var itemKey: String

    /// "empty" | "complete" | "skipped" | "autoCompleted"
    public var state: String

    public var completedAt: Date?

    /// Optional payload — caches resolved WorkoutPreset on first
    /// render of the day (Phase 2). Stored as JSON-encoded Data
    /// locally; bridges to jsonb on the server.
    public var payload: Data?

    public var createdAt: Date
    public var updatedAt: Date

    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        programPlanId: String,
        programDay: Int,
        itemKey: String,
        state: String = "empty",
        payload: Data? = nil
    ) {
        self.id = id
        self.userId = userId
        self.programPlanId = programPlanId
        self.programDay = programDay
        self.itemKey = itemKey
        self.state = state
        self.completedAt = nil
        self.payload = payload
        self.createdAt = .now
        self.updatedAt = .now
        self.pendingUpsert = true
    }
}

// MARK: - Observation (app v8 — the chart)
//
// docs/app_v8/03_ARCHITECTURE.md §3b. ONE typed, userId-scoped,
// append-only record for every subjective + derived observation the
// UserDefaults string families used to hold (day.reflection / day.sit /
// day.dose / day.note / plan.tonight) plus the new regimen + care
// events. Weight got a real store years ago; how she FELT finally
// gets the same. Records survive sign-out under their userId (like
// weight logs); delete-account removes them.
//
// Day-singular kinds use a deterministic id ("userId-kind-dayKey",
// lowercase) so a changed answer upserts idempotently; multi-per-day
// kinds append with UUID ids. `source` is first-class provenance
// (manual | derived | healthkit | photo) — the clinician-trust and
// billing-atom floor from 01_RESEARCH §A.

@Model
public final class ObservationRecord {
    @Attribute(.unique) public var id: String

    public var userId: String

    /// ObservationKind.rawValue (app layer owns the enum).
    public var kind: String

    /// "yyyy-MM-dd" local day key.
    public var dayKey: String

    public var effectiveAt: Date

    public var valueText: String?
    public var valueNum: Double?
    public var unit: String?

    /// Structured extras (JSON) — regimen refs, care-event severity,
    /// the sealed day's asked-set. Bridges to jsonb.
    public var payload: Data?

    /// "manual" | "derived" | "healthkit" | "photo"
    public var source: String

    public var createdAt: Date
    public var updatedAt: Date
    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        kind: String,
        dayKey: String,
        effectiveAt: Date = .now,
        valueText: String? = nil,
        valueNum: Double? = nil,
        unit: String? = nil,
        payload: Data? = nil,
        source: String = "manual"
    ) {
        self.id = id
        self.userId = userId
        self.kind = kind
        self.dayKey = dayKey
        self.effectiveAt = effectiveAt
        self.valueText = valueText
        self.valueNum = valueNum
        self.unit = unit
        self.payload = payload
        self.source = source
        self.createdAt = .now
        self.updatedAt = .now
        self.pendingUpsert = true
    }
}

// MARK: - Consent grant (app v8 S3 — the sharing seam)
//
// docs/app_v8/09_S3_PACKET.md. Explicit, scoped, revocable,
// auditable, inactive by default. One row per grant lifecycle:
// grantedAt + revokedAt on the same record IS the audit pair.
// Nothing is delivered anywhere in S3 — consent gates FUTURE
// connected sharing only; the share sheet is her act on a file.

@Model
public final class ConsentGrantRecord {
    @Attribute(.unique) public var id: String
    public var userId: String
    /// "visit_packet_sharing" (the S3 scope; future scopes append).
    public var scope: String
    public var purpose: String
    public var grantedAt: Date
    public var revokedAt: Date?
    /// nil until a real clinic connection exists.
    public var orgId: String?
    public var createdAt: Date
    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        scope: String,
        purpose: String
    ) {
        self.id = id
        self.userId = userId
        self.scope = scope
        self.purpose = purpose
        self.grantedAt = .now
        self.revokedAt = nil
        self.orgId = nil
        self.createdAt = .now
        self.pendingUpsert = true
    }
}

// MARK: - Regimen plan (app v8 — medication + supplements)
//
// docs/app_v8/03_ARCHITECTURE.md §3c. Her medication / supplement
// plans as records. `displayName` is HER OWN words (sensitive —
// never rendered on app-authored surfaces, never in notification
// payloads, never in analytics; 01_RESEARCH §A4 stigma floor).
// `anchorWeekday` (ISO 1 = Monday … 7 = Sunday) is the shot-day
// anchor every engine reads. `doseStageLabel` is her label for the
// current titration step — the app NEVER authors dosing content.
// `sourceProtocolId` / `orgId` stay nil for self-created consumer
// plans (the tenancy seam, unexposed).

@Model
public final class RegimenPlanRecord {
    @Attribute(.unique) public var id: String

    public var userId: String

    /// "medication" | "supplement"
    public var kind: String

    /// Her words. Sensitive; display-only where SHE reads it.
    public var displayName: String

    /// "weeklyAnchor" | "daily" | "asNeeded"
    public var scheduleRule: String

    /// ISO weekday 1-7 when scheduleRule == weeklyAnchor.
    public var anchorWeekday: Int?

    /// Minutes from midnight, when she anchored a time.
    public var timeOfDayMinutes: Int?

    /// Her label for the current step ("2.5", "starting dose"…).
    public var doseStageLabel: String?

    /// v8 S4 — the clinic's short patient-facing instruction on an
    /// ASSIGNED (care_team) plan ("evening, thigh or abdomen ok").
    /// Never authored by the app for a self plan; nil otherwise.
    /// Lightweight-migrates (optional).
    public var instruction: String?

    public var startedAt: Date
    public var endedAt: Date?

    public var reminderEnabled: Bool

    /// Founder refinement 2026-07-28 — the authority enum (FHIR
    /// reported[x] + US Core requester, collapsed): "self" |
    /// "care_team". The iOS app only ever writes "self";
    /// "care_team" is written exclusively by the future clinician
    /// seam server-side. One field today deletes the migration
    /// later.
    public var authority: String = "self"

    /// Reconciliation seams — populated ONLY by the future clinic
    /// bridge, never by consumer UI (her words stay the forever
    /// render label; codes match underneath).
    public var rxnormCode: String?
    public var strengthValue: Double?
    public var strengthUnit: String?

    /// Tenancy seam — nil for self-created (org-null tenant).
    public var sourceProtocolId: String?
    public var orgId: String?

    public var createdAt: Date
    public var updatedAt: Date
    public var pendingUpsert: Bool

    public init(
        id: String = UUID().uuidString,
        userId: String,
        kind: String,
        displayName: String,
        scheduleRule: String,
        anchorWeekday: Int? = nil,
        timeOfDayMinutes: Int? = nil,
        doseStageLabel: String? = nil,
        startedAt: Date = .now,
        reminderEnabled: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.kind = kind
        self.displayName = displayName
        self.scheduleRule = scheduleRule
        self.anchorWeekday = anchorWeekday
        self.timeOfDayMinutes = timeOfDayMinutes
        self.doseStageLabel = doseStageLabel
        self.instruction = nil
        self.startedAt = startedAt
        self.endedAt = nil
        self.reminderEnabled = reminderEnabled
        self.authority = "self"
        self.rxnormCode = nil
        self.strengthValue = nil
        self.strengthUnit = nil
        self.sourceProtocolId = nil
        self.orgId = nil
        self.createdAt = .now
        self.updatedAt = .now
        self.pendingUpsert = true
    }
}

// MARK: - BodyScanRecord (app v9 P1 — Body Vision)
//
// One guided body scan: the record is metadata ONLY — images live in
// the on-device BodyScanPhotoStore keyed by this id, and no pixel
// ever reaches this table. DELIBERATELY LOCAL-ONLY today (registered
// in the container, no Supabase sync): the record and its photos
// leave the device together or not at all, and backup is an explicit
// opt-in seam (docs/app_v9 D3, laws L3/L4). Survives sign-out like
// weight logs (userId-scoped reads); delete-account purges records +
// photos together.

@Model
public final class BodyScanRecord {
    @Attribute(.unique) public var id: String
    public var userId: String
    public var capturedAt: Date
    /// Local-calendar day key ("2026-08-03") — one scan per day is
    /// the ritual's grain; re-scans replace within the day at the
    /// store layer, history across days is never rewritten.
    public var dayKey: String
    /// Fraction of pose joints confidently seen at capture (0-1).
    /// A capture-quality gate for P2's compare floors — NEVER a
    /// body measurement (L3: no number is derived from a photo).
    public var poseQuality: Double
    /// "silhouette" | "photo" — which face SHE chose for surfaces.
    /// Both derivatives exist on device either way; this is a
    /// render preference, not a storage fact.
    public var renderMode: String
    public var notes: String?
    /// Backup seam (D3, default OFF): flipped only by the opt-in
    /// backup path when her private-bucket mirror confirms.
    public var backedUp: Bool

    /// v9 P2 — the pose gate's figure bounds at capture (Vision-
    /// normalized, bottom-left origin). INTERNAL alignment anchors
    /// for the compare crossfade — a mechanism, never a measurement
    /// (L3); nil on manual/sim/restored captures.
    public var figureTopY: Double?
    public var figureBottomY: Double?
    public var figureCenterX: Double?

    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        userId: String,
        capturedAt: Date = .now,
        dayKey: String,
        poseQuality: Double,
        renderMode: String
    ) {
        self.id = id
        self.userId = userId
        self.capturedAt = capturedAt
        self.dayKey = dayKey
        self.poseQuality = poseQuality
        self.renderMode = renderMode
        self.notes = nil
        self.backedUp = false
        self.figureTopY = nil
        self.figureBottomY = nil
        self.figureCenterX = nil
        self.createdAt = .now
    }
}
