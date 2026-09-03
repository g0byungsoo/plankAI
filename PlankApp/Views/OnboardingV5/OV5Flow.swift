import SwiftUI
import Observation

// MARK: - The consult's answer store
//
// p70 — THE V5 SWEEP: this file used to hold the v5 typed state
// machine (OV5Step + OV5Router + the OV5Flow coordinator). The v8
// consult superseded that flow and its debug escape is gone; what
// remains here is what the shipping product actually reads —
// OnboardingContext, OV5Persona and OV5Store, the consult's answer
// store, hosted by v8.

/// v8 Stage A — the typed entry seam (docs/app_v8/06_ONBOARDING §3).
/// One machine, multiple contexts: the consumer default today; the
/// clinic door exists as a TYPE and nothing more — no UI references
/// it, nothing clinic-shaped renders, the paywall is untouched.
/// A future enrollment path constructs `.clinicEnrollment` and the
/// machine gains its org consent/protocol behaviors THEN.
enum OnboardingContext: Equatable {
    case consumer
    case clinicEnrollment(orgId: String, protocolId: String)
}

/// v7 persona law (docs/onboarding_v7/00_DIRECTION §2.1). Resolved
/// from the LIVE gender answer the moment it exists: `.her` keeps the
/// her-register brand voice + female-physiology content; `.male`
/// removes female-specific wording/questions and routes around the
/// hormonal + pregnancy beats; `.neutral` (nonbinary / private /
/// unset) speaks second-person and keeps the physiology beats, which
/// may apply and carry their own prefer-not options. Everything
/// upstream of the gender beat is persona-neutral by law — no copy
/// site may hard-code her/she/women about the user outside this.
enum OV5Persona: Equatable {
    case her, male, neutral

    /// Most copy splits her-vs-everyone; physiology sites go 3-way.
    func her(_ herLine: String, else other: String) -> String {
        self == .her ? herLine : other
    }
}



// MARK: - OV5Store
//
// Single writer for every onboarding answer. Canonical AppStorage keys
// (docs/onboarding_v5/DATA_CONTRACT.md) are written the moment an
// answer lands, so the flow is resume-safe across relaunch and every
// downstream consumer (ProgramGoalCalculator, notifications, paywall)
// reads the same values it read from v4.5. In-flow numerics persist to
// onb_v5_* mirrors and travel to their legacy homes through
// assembleData() → handleOnboardingComplete, unchanged.

@Observable
final class OV5Store {
    /// Pre-`.task` render fallback for the v8 host — one shared
    /// instance so the first frame never allocates-and-discards
    /// (the 26.2 sim's @Observable deinit abort family). The real
    /// per-session store replaces it on mount.
    static let bootFallback = OV5Store()

    private let d = UserDefaults.standard

    // Generic persistence helpers keep every property a one-liner and
    // the key strings greppable in this one file.
    private func str(_ key: String) -> String { d.string(forKey: key) ?? "" }

    // act i
    var outcome: String { didSet { d.set(outcome, forKey: "onb_v5_outcome"); mirrorLegacyGoal() } }
    var acquisitionSource: String { didSet { d.set(acquisitionSource, forKey: "onb_v5_attribution") } }
    var name: String { didSet { d.set(name, forKey: "onb_v5_name") } }

    // v8 THE CONSULT — the front door (docs/onboarding_v8 §9.3).
    // "clinic" routes the clinical-intake flow; "consumer" (or unset)
    // routes the full consult. The accepted org name feeds copy +
    // the file chapter; the connection itself is made by
    // CareConnectionService.accept at the code beat.
    var door: String { didSet { d.set(door, forKey: "onb_v8_door") } }
    var clinicOrgName: String { didSet { d.set(clinicOrgName, forKey: "onb_v8_clinic_org") } }

    // act ii
    var glp1Status: String { didSet { d.set(glp1Status, forKey: "onboarding_glp1_status") } }
    /// v8 Stage A — her shot day, offered not required ("mon"…"sun",
    /// "" = skipped). Completion routes it through RegimenService's
    /// authority-guarded setShotDay; never a clinical claim.
    var shotDay: String { didSet { d.set(shotDay, forKey: "onb_v5_shot_day") } }
    // v24 THE REGIMEN — the consult's medication beats (current
    // cohort, consumer door only). Every field has an out; the
    // completion bridge builds ONE regimen version from them.
    /// "shots" | "pills" | "not_sure" | "" (never asked).
    var medRoute: String { didSet { d.set(medRoute, forKey: "onb_med_route") } }
    /// A MedicationCatalog id, "other", "not_sure", or "".
    var medProduct: String { didSet { d.set(medProduct, forKey: "onb_med_product") } }
    /// The dose word she picked ("0.5", "7") or "not_sure"/"".
    var medDose: String { didSet { d.set(medDose, forKey: "onb_med_dose") } }
    /// "morning" | "midday" | "evening" | "none" | "".
    var medHour: String { didSet { d.set(medHour, forKey: "onb_med_hour") } }
    /// v8 Stage A — what she already takes (CSV; intake fact ONLY:
    /// no records, no daily UI, no recommendations — FR8 law).
    var supports: Set<String> { didSet { d.set(supports.sorted().joined(separator: ","), forKey: "onb_v5_supports") } }
    var glp1Phase: String { didSet { d.set(glp1Phase, forKey: "onboarding_glp1_phase") } }
    var appetiteRhythm: String { didSet { d.set(appetiteRhythm, forKey: "onb_v5_appetite_rhythm") } }
    var stopWindow: String { didSet { d.set(stopWindow, forKey: "onboarding_glp1_stop_window") } }
    var appetiteReturn: String { didSet { d.set(appetiteReturn, forKey: "onboarding_appetite_return") } }
    var foodRelationship: String { didSet { d.set(foodRelationship, forKey: "onboardingFoodRelationship") } }
    var snapDemoMeal: String { didSet { d.set(snapDemoMeal, forKey: "onb_v5_snap_demo_meal") } }
    var eatingCadence: String { didSet { d.set(eatingCadence, forKey: "onboardingEatingCadence") } }
    var cuisines: Set<String> { didSet { d.set(cuisines.sorted().joined(separator: ","), forKey: "onboardingCuisinePreference") } }
    var dietary: Set<String> { didSet { d.set(dietary.sorted().joined(separator: ","), forKey: "onboarding_dietary") } }

    // act iii
    var movementBaseline: String { didSet { d.set(movementBaseline, forKey: "onb_v4_movement_baseline") } }
    var sleepHours: String { didSet { d.set(sleepHours, forKey: "onboardingSleepHours") } }
    var stressLevel: String { didSet { d.set(stressLevel, forKey: "onboardingStressLevel") } }
    var gender: String { didSet {
        d.set(gender, forKey: "onb_v5_gender")
        // Canonical mirror (matches heightCm/currentWeightKg above):
        // TargetsService.profileInputs + the paywall/reveal/program-setup
        // all read `onboardingGender` for the Mifflin-St Jeor sex term.
        // Without this the daily calorie target defaulted to female for
        // every v5 user (harmless for the core audience, ~230 kcal/day
        // low for a male/nonbinary user).
        d.set(gender, forKey: "onboardingGender")
        applyPersonaSeeds()
    } }
    var ageYears: Int { didSet {
        d.set(ageYears, forKey: "onb_v5_age_years")
        // The relocated safety gate reads the canonical band mid-flow.
        d.set(ageRangeBucket, forKey: "onboardingAgeRange")
    } }
    var heightCm: Double { didSet {
        d.set(heightCm, forKey: "onb_v5_height_cm")
        // Mirror v4.5 finish(): the safety gate's BMI floor reads height
        // from AppStorage without a fetch.
        d.set(heightCm, forKey: "onboardingHeightCm")
    } }
    var currentWeightKg: Double { didSet {
        d.set(currentWeightKg, forKey: "onb_v5_weight_kg")
        // Canonical mirrors, written live: the mid-flow safety gate +
        // the reveal's fear-resolution read these before
        // handleOnboardingComplete re-persists them at completion.
        d.set(currentWeightKg, forKey: "onboardingCurrentWeightKg")
    } }
    var goalWeightKg: Double { didSet {
        d.set(goalWeightKg, forKey: "onb_v5_goal_kg")
        d.set(goalWeightKg, forKey: "onboardingGoalWeightKg")
    } }
    var weightTrend: String { didSet { d.set(weightTrend, forKey: "onboarding_weight_trend") } }
    var goalDirection: String { didSet { d.set(goalDirection, forKey: "onboarding_goal_direction"); applyGoalDirection() } }
    var nsvPriority: Set<String> { didSet { d.set(nsvPriority.sorted().joined(separator: ","), forKey: "onboardingNsvPriority") } }
    var medicationStatus: String { didSet { d.set(medicationStatus, forKey: "onboarding_medication_status") } }

    /// Display-unit preferences (US cohort defaults imperial). Shared
    /// across the weight + goal rulers so the pair reads as one ritual.
    var usesLb: Bool { didSet {
        d.set(usesLb, forKey: "onb_v5_unit_lb")
        // THE UNIT SHE CHOSE IS THE UNIT SHE SEES. The rest of the app
        // reads `weightUnit` — the weigh-in ritual, Becoming's body
        // card, Home's tile, the journey read, the visit packet — and
        // onboarding never wrote it, so it defaulted to "lb" for
        // everyone. A user who typed kilograms on the ruler met pounds
        // on every screen afterwards, with no setting to change it.
        d.set(usesLb ? "lb" : "kg", forKey: "weightUnit")
    } }
    var usesFtIn: Bool { didSet {
        d.set(usesFtIn, forKey: "onb_v5_unit_ftin")
        // Same fix, same reason, the other unit. `onb_v5_unit_ftin` is
        // swept by the `onb_v5_` prefix on sign-out and never restored,
        // so a metric user's height unit did not survive a sign-in. This
        // mirror is device-level, like `weightUnit`, so it does — and it
        // is the key the height repair door reads.
        d.set(usesFtIn ? "ftin" : "cm", forKey: "heightUnit")
    } }

    // act iv
    var identityFeeling: String { didSet { d.set(identityFeeling, forKey: "onb_v5_identity") } }
    var hormonalStage: String { didSet { d.set(hormonalStage, forKey: "onboardingHormonalStage") } }
    var priorAttempts: String { didSet { d.set(priorAttempts, forKey: "onboardingPriorAttempts") } }
    var fearQuickResults: String { didSet { d.set(fearQuickResults, forKey: "onb_fear_quickResults") } }
    var fearAnotherDiet: String { didSet { d.set(fearAnotherDiet, forKey: "onb_fear_anotherDiet") } }
    var fearPriorAttempt: String { didSet { d.set(fearPriorAttempt, forKey: "onb_fear_priorAttempt") } }
    var fearOfframp: String { didSet { d.set(fearOfframp, forKey: "onb_fear_offramp") } }
    var fearRegain: String { didSet { d.set(fearRegain, forKey: "onb_fear_regain") } }

    // act v
    var consentPersonalize: Bool { didSet { d.set(consentPersonalize, forKey: "onb_consent_personalize") } }
    var consentDay2: Bool { didSet { d.set(consentDay2, forKey: "onb_consent_day2") } }
    var disclaimerAcked: Bool { didSet { if disclaimerAcked { d.set(ISO8601DateFormatter().string(from: Date()), forKey: "medicalDisclaimerAckAtISO") } } }

    init() {
        outcome = d.string(forKey: "onb_v5_outcome") ?? ""
        acquisitionSource = d.string(forKey: "onb_v5_attribution") ?? ""
        name = d.string(forKey: "onb_v5_name") ?? ""
        door = d.string(forKey: "onb_v8_door") ?? ""
        clinicOrgName = d.string(forKey: "onb_v8_clinic_org") ?? ""
        glp1Status = d.string(forKey: "onboarding_glp1_status") ?? ""
        glp1Phase = d.string(forKey: "onboarding_glp1_phase") ?? ""
        appetiteRhythm = d.string(forKey: "onb_v5_appetite_rhythm") ?? ""
        shotDay = d.string(forKey: "onb_v5_shot_day") ?? ""
        medRoute = d.string(forKey: "onb_med_route") ?? ""
        medProduct = d.string(forKey: "onb_med_product") ?? ""
        medDose = d.string(forKey: "onb_med_dose") ?? ""
        medHour = d.string(forKey: "onb_med_hour") ?? ""
        supports = Set((d.string(forKey: "onb_v5_supports") ?? "").split(separator: ",").map(String.init))
        stopWindow = d.string(forKey: "onboarding_glp1_stop_window") ?? ""
        appetiteReturn = d.string(forKey: "onboarding_appetite_return") ?? ""
        foodRelationship = d.string(forKey: "onboardingFoodRelationship") ?? ""
        snapDemoMeal = d.string(forKey: "onb_v5_snap_demo_meal") ?? ""
        eatingCadence = d.string(forKey: "onboardingEatingCadence") ?? ""
        cuisines = Set((d.string(forKey: "onboardingCuisinePreference") ?? "").split(separator: ",").map(String.init))
        dietary = Set((d.string(forKey: "onboarding_dietary") ?? "").split(separator: ",").map(String.init))
        movementBaseline = d.string(forKey: "onb_v4_movement_baseline") ?? ""
        sleepHours = d.string(forKey: "onboardingSleepHours") ?? ""
        stressLevel = d.string(forKey: "onboardingStressLevel") ?? ""
        gender = d.string(forKey: "onb_v5_gender") ?? ""
        ageYears = d.object(forKey: "onb_v5_age_years") as? Int ?? 25
        heightCm = d.object(forKey: "onb_v5_height_cm") as? Double ?? 165
        currentWeightKg = d.object(forKey: "onb_v5_weight_kg") as? Double ?? 72
        goalWeightKg = d.object(forKey: "onb_v5_goal_kg") as? Double ?? 0
        weightTrend = d.string(forKey: "onboarding_weight_trend") ?? ""
        goalDirection = d.string(forKey: "onboarding_goal_direction") ?? ""
        nsvPriority = Set((d.string(forKey: "onboardingNsvPriority") ?? "").split(separator: ",").map(String.init))
        medicationStatus = d.string(forKey: "onboarding_medication_status") ?? ""
        usesLb = d.object(forKey: "onb_v5_unit_lb") as? Bool ?? true
        usesFtIn = d.object(forKey: "onb_v5_unit_ftin") as? Bool ?? true
        identityFeeling = d.string(forKey: "onb_v5_identity") ?? ""
        hormonalStage = d.string(forKey: "onboardingHormonalStage") ?? ""
        priorAttempts = d.string(forKey: "onboardingPriorAttempts") ?? ""
        fearQuickResults = d.string(forKey: "onb_fear_quickResults") ?? ""
        fearAnotherDiet = d.string(forKey: "onb_fear_anotherDiet") ?? ""
        fearPriorAttempt = d.string(forKey: "onb_fear_priorAttempt") ?? ""
        fearOfframp = d.string(forKey: "onb_fear_offramp") ?? ""
        fearRegain = d.string(forKey: "onb_fear_regain") ?? ""
        consentPersonalize = d.object(forKey: "onb_consent_personalize") as? Bool ?? true
        consentDay2 = d.object(forKey: "onb_consent_day2") as? Bool ?? true
        disclaimerAcked = (d.string(forKey: "medicalDisclaimerAckAtISO") ?? "").isEmpty == false
    }

    // MARK: cohort + derived reads

    /// v7 persona law — see OV5Persona. Reads the live answer, so
    /// routing and copy re-resolve if she backs up and changes it.
    var persona: OV5Persona {
        switch gender {
        case "female": return .her
        case "male":   return .male
        default:       return .neutral
        }
    }

    /// D9 — male-typical ruler seeds, applied the moment the gender
    /// answer lands and only where the value was never touched (the
    /// female-typical 165/72 seeds otherwise start a male user 13 cm
    /// and 16 kg off). A seed is the ruler's starting position — the
    /// same untouched-default semantics the 165/72 pair already has.
    private func applyPersonaSeeds() {
        guard persona == .male else { return }
        if d.object(forKey: "onb_v5_height_cm") == nil { heightCm = 178 }
        if d.object(forKey: "onb_v5_weight_kg") == nil { currentWeightKg = 88 }
    }

    var isCurrentGlp1: Bool { glp1Status == "current" }
    var isPastGlp1: Bool { glp1Status == "past" }
    var isConsidering: Bool { glp1Status == "considering" }

    /// Loss delta in kg; ≤0 means maintenance/recomp framing.
    var deltaKg: Double { currentWeightKg - goalWeightKg }

    /// Her distance, in the unit SHE picked on the ruler.
    ///
    /// The acknowledgements after the goal beat, the file summary and the
    /// close all hard-coded `lb`, so a user who typed KILOGRAMS was told
    /// "13 lb" one line after entering 56 → 50. The number she enters must
    /// be the number she recognises when it comes back.
    var deltaWords: String {
        usesLb
            ? "\(Int((deltaKg * 2.20462).rounded())) lb"
            : "\(Int(deltaKg.rounded())) kg"
    }

    /// The v4.5 `goal` field fed WorkoutGenerator + reveal copy. The v5
    /// outcome vocabulary maps onto the nearest legacy value so no
    /// downstream reader sees an unknown key.
    private func mirrorLegacyGoal() {
        let legacy: String
        switch outcome {
        case "noise", "clothes", "myself": legacy = "loseWeight"
        case "energy": legacy = "fullBody"
        case "keep": legacy = "loseWeight"
        default: legacy = "loseWeight"
        }
        d.set(legacy, forKey: "onb_v5_goal_legacy_mirror")
        legacyGoal = legacy
    }
    private(set) var legacyGoal: String = "loseWeight"

    /// Mirrors v4.5 case-1330 behavior exactly: maintainers pre-fill the
    /// goal to current (delta 0 → maintenance math), recomp seeds a
    /// gentle tone-up target; program_mode persists for PlanView + the
    /// post-paywall build.
    private func applyGoalDirection() {
        switch goalDirection {
        case "maintain", "maintain_kept":
            if currentWeightKg > 0 { goalWeightKg = currentWeightKg }
            d.set("maintenance", forKey: "program_mode")
        case "recomp":
            if currentWeightKg > 0 && (goalWeightKg == 0 || goalWeightKg >= currentWeightKg) {
                goalWeightKg = max(currentWeightKg * 0.97, 40)
            }
            d.set("loss", forKey: "program_mode")
        default:
            if currentWeightKg > 0 && (goalWeightKg == 0 || goalWeightKg >= currentWeightKg) {
                goalWeightKg = max(currentWeightKg * 0.90, 40)
            }
            d.set("loss", forKey: "program_mode")
        }
    }

    /// The real number of answers she gave, computed at render time
    /// (v7 provenance law — the old hard-coded "fifty-two" traced to
    /// nothing). Rulers count once each (the close act is unreachable
    /// without passing them); multi-selects count as one answer; skips
    /// don't count; the safety gate's six items (pregnancy + five
    /// SCOFF) count via its completion flag.
    var answeredCount: Int {
        var n = 0
        let strings = [outcome, acquisitionSource, name, glp1Status,
                       glp1Phase, appetiteRhythm, shotDay, stopWindow,
                       appetiteReturn, foodRelationship, eatingCadence,
                       movementBaseline, sleepHours, stressLevel,
                       gender, weightTrend, goalDirection, medicationStatus,
                       identityFeeling, hormonalStage, priorAttempts,
                       fearQuickResults, fearAnotherDiet, fearPriorAttempt,
                       fearOfframp, fearRegain]
        n += strings.filter { !$0.isEmpty }.count
        if !snapDemoMeal.isEmpty && snapDemoMeal != "skipped" { n += 1 }
        let multis = [cuisines, dietary, nsvPriority, supports]
        n += multis.filter { !$0.isEmpty }.count
        n += 4
        if d.bool(forKey: "safety_screen_completed") { n += 6 }
        return n
    }

    /// Age band mirror, identical to v4.5's bucketize(age:).
    var ageRangeBucket: String {
        switch ageYears {
        case ..<18: return "under18"
        case 18...24: return "18to24"
        case 25...34: return "25to34"
        case 35...44: return "35to44"
        case 45...54: return "45to54"
        default: return "55plus"
        }
    }

    /// Cadence derivations, identical to v4.5's applyCadenceDerivations:
    /// session length keys off movement baseline; weekly cadence keys off
    /// the picked tier (which the reveal PacePicker writes — so this is
    /// re-derived at reveal-complete before the payload persists).
    var derivedSessionMinutes: Int {
        switch movementBaseline {
        case "regular_ish": return 15
        case "very_active": return 20
        default: return 10
        }
    }
    var derivedCommitmentDays: Int {
        // onboardingPickedTier stores IntensityTier raw (soft/medium/hard);
        // cadence keys off the PACE key, exactly like v4.5's
        // applyCadenceDerivations (gentle→3, focused→5/7, steady→5).
        let tierRaw = UserDefaults.standard.string(forKey: "onboardingPickedTier") ?? "medium"
        switch ProjectionMath.paceKey(forTier: tierRaw) {
        case "gentle": return 3
        case "focused": return movementBaseline == "very_active" ? 7 : 5
        default: return 5
        }
    }

    /// Assemble the v4.5-shaped completion payload. Field names + value
    /// spaces are load-bearing (PlankAIApp.handleOnboardingComplete).
    /// Legacy-only fields carry the same defaults v4.5 shipped when its
    /// collecting screens were cut (bodyType 3, focusArea fullCore).
    func assembleData() -> OnboardingData {
        let d = UserDefaults.standard
        let notifsOn = d.bool(forKey: "notificationsEnabled")
        let bucket = d.string(forKey: "plankTime") ?? "morning"
        var data = OnboardingData(
            goal: legacyGoal,
            experience: movementBaseline == "very_active" ? "advanced"
                : movementBaseline == "regular_ish" ? "intermediate" : "beginner",
            baselineHoldSeconds: WorkoutGenerator.baselineSeconds(forMovementBaseline: movementBaseline),
            barriers: derivedBarriers,
            ageRange: ageRangeBucket,
            // THE ALIAS THAT HAS TO SURVIVE A SIGN-OUT.
            //
            // This is the only activity value `UserRecord` carries, so it
            // is the only one hydrate can give back — the raw
            // `onb_v4_movement_baseline` is swept as identity-scoped body
            // data and there is no column for it.
            //
            // It used to collapse "walks here and there" AND "regular-ish"
            // into "moderate", which meant a walker signed back in on the
            // 1.55 factor instead of her own 1.375: +215 kcal for the
            // 5'3" persona, in the surplus direction, silently. "walks"
            // carries the same meaning to `activityFactor` (1.375) and is
            // treated identically by every other reader of this field —
            // `WorkoutGenerator.startingTier` (unrecognised == "moderate",
            // score +0), `HardTierGate` via `mappedActivity` (both unlock)
            // and the goal-date nudge (both fall to the default). Pinned
            // by ActivityAliasRoundTripTests.
            activityLevel: movementBaseline == "very_active" ? "athlete"
                : movementBaseline == "barely" ? "sedentary"
                : movementBaseline == "walks" ? "walks" : "moderate",
            focusArea: "fullCore",
            plankTime: bucket,
            commitmentDaysPerWeek: derivedCommitmentDays,
            sessionLengthMinutes: derivedSessionMinutes,
            notificationsEnabled: notifsOn,
            notificationTime: notifsOn ? Self.reminderTime(fromBucket: bucket) : nil,
            name: name,
            voicePreference: "encouraging"
        )
        data.motivation = outcome
        data.gender = gender
        data.heightCm = heightCm
        data.currentWeightKg = currentWeightKg
        // NEVER `?? currentWeightKg`. An absent goal published as the
        // current weight is indistinguishable from a deliberate
        // "maintain where I am", and every downstream reader treats
        // goal == current as a zero-deficit instruction. That is the
        // 2026-08-13 customer report exactly: "the goal is set at 124,
        // my current weight" AND "it has me in a caloric surplus".
        // Zero means UNKNOWN, and the surfaces now ask instead of
        // inventing (see TargetsService.EnergyBasis.unknown).
        data.goalWeightKg = goalWeightKg
        data.identityFeeling = identityFeeling
        data.acquisitionSource = acquisitionSource
        data.relatability1 = fearQuickResults == "yes"
        data.relatability2 = fearAnotherDiet == "yes"
        data.relatability3 = fearPriorAttempt == "yes" || fearOfframp == "yes" || fearRegain == "yes"
        return data
    }

    /// Legacy barrier derivation (v4.5 finish()): fear yeses map to the
    /// barrier vocabulary UserRecord + notifications already read.
    private var derivedBarriers: [String] {
        var out: [String] = []
        if fearQuickResults == "yes" { out.append("motivation") }
        if fearAnotherDiet == "yes" { out.append("boring") }
        if fearPriorAttempt == "yes" || fearOfframp == "yes" || fearRegain == "yes" {
            out.append("dontKnow")
        }
        return out
    }

    static func reminderTime(fromBucket bucket: String) -> Date {
        let hour: Int
        switch bucket {
        case "morning": hour = 7
        case "afternoon": hour = 13
        case "evening": hour = 19
        default: hour = 9
        }
        return Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
    }
}
