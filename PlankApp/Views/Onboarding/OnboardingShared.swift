import SwiftUI

// MARK: - OnboardingShared (pass 55)
//
// The two LIVE types the v4.5 `OnboardingView` still hosted when it
// was deleted: `OnboardingData` (the assembled consult record every
// onboarding generation hands to `handleOnboardingComplete`) and
// `PressFeedbackStyle` (the press-feedback wrapper the paywall, auth
// and v5 screens apply over pre-styled buttons). Everything else in
// that 9,645-line file was reachable only through the `--onboarding-v4`
// DEBUG door and is gone.

struct OnboardingData {
    // Existing fields — downstream consumers (PlankAIApp.handleOnboardingComplete,
    // UserRecord schema, WorkoutGenerator) read these by name. Don't rename.
    let goal, experience: String; let baselineHoldSeconds: Int; let barriers: [String]
    let ageRange, activityLevel, focusArea: String
    // var (not let): the reveal nudge (NudgePermissionAsk) is the live
    // notifications ask now, and it runs AFTER finish() assembles this
    // data; onRevealComplete refreshes plankTime + the two notification
    // fields from the canonical keys the nudge wrote.
    var plankTime: String
    // var (not let): the reveal PacePicker can re-pick the pace after
    // assembly, and onRevealComplete refreshes these two derived fields.
    var commitmentDaysPerWeek: Int
    var sessionLengthMinutes: Int
    var notificationsEnabled: Bool; var notificationTime: Date?; let name, voicePreference: String

    // JeniFit phase 4 additions. New onboarding question content writes
    // these in addition to the legacy fields above. Defaults make them
    // safe to read from older code paths that don't know about them yet.
    var bodyFocus: [String] = []           // Part 1 multi-select: flatBelly/tonedArms/roundButt/slimLegs
    var motivation: String = ""            // Part 1: the "why"
    var workoutLocation: String = ""       // Part 2: home/gym/either/outdoor
    var workoutStyle: [String] = []        // Part 2 multi: hiit/strength/yoga/dance/walking
    var gender: String = ""                // Part 3
    var heightCm: Double = 170             // Part 3 slider
    var currentWeightKg: Double = 65       // Part 3 slider
    var goalWeightKg: Double = 60          // Part 3 slider
    var bodyTypeCurrent: Int = 3           // Part 3 slider 0-5 (0=Cut leanest, 5=Soft heaviest, 3=Average)
    var bodyTypeDesired: Int = 3           // Part 3 slider 0-5 (defaults match current; case 135 reseeds on mount)
    var identityFeeling: String = ""       // Part 4
    var rewardChoice: String = ""          // Part 4
    var relatability1: Bool = false        // Part 5: "I struggle to stay consistent"
    var relatability2: Bool = false        // Part 5: "I get bored doing the same thing"
    var relatability3: Bool = false        // Part 5: "Results don't come fast enough"

    /// 2026-05-30 (epic #1 child #7): how the user heard about JeniFit.
    /// One of "tiktok" | "instagram" | "friend" | "app_store" | "google"
    /// | "other". Empty string = not answered. Persists to UserRecord +
    /// Supabase as `onboarding_acquisition_source`.
    var acquisitionSource: String = ""
}

// MARK: - CTA Button Style

/// Press-feedback wrapper applied on top of buttons that already paint their
/// own background. Renamed from CTAButtonStyle in JeniFit phase 2; the
/// canonical brand button style now lives in DesignSystem/Components.swift
/// as `CTAButtonStyle(variant:)`. Call sites that wrap pre-styled buttons
/// keep using PressFeedbackStyle until their containing screens are
/// retokenized in phases 4–5.
struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
