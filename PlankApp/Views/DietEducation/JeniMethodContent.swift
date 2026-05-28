import Foundation

// MARK: - Lesson identifiers

/// The five lessons of The JeniFit Method, in order. Numeric raw values
/// 1-5 double as the user-visible "day N of 5" index. Phase 9.21 adds
/// `.generic` (rawValue 6) for the Day 6+ daily check-in ritual that
/// loops forever after the 5-day arc completes. Use `LessonID.dailyLessons`
/// when you want the 1-5 arc specifically (analytics counts, progress
/// bars, etc); `.allCases` includes the generic.
enum LessonID: Int, CaseIterable {
    case day1 = 1
    case day2 = 2
    case day3 = 3
    case day4 = 4
    case day5 = 5
    case generic = 6

    /// Stable slug used in analytics properties (lesson_topic). Never
    /// shown to users.
    var topicSlug: String {
        switch self {
        case .day1:    return "why_this_works"
        case .day2:    return "dont_lose_the_good_stuff"
        case .day3:    return "workouts_are_the_protection"
        case .day4:    return "eat_to_fuel"
        case .day5:    return "trust_the_trend"
        case .generic: return "daily_check_in"
        }
    }

    /// The five-day numbered arc (Day 1..5). Use this instead of
    /// `allCases` for anything that should NOT count the generic
    /// ritual — analytics totals, progress %, day-of-N copy.
    static let dailyLessons: [LessonID] = [.day1, .day2, .day3, .day4, .day5]

    /// Phase 9.22 — short teaser headline per lesson. Used by the
    /// HomeView card + JeniMethodReReadView index so they don't have
    /// to resolve a full ritual just to display one line. Matches the
    /// dominant promise of each day's ritual content.
    var headline: String {
        switch self {
        case .day1:    return "muscle changes the math."
        case .day2:    return "small you do beats heroic you can't."
        case .day3:    return "your steps add up to more than your workout."
        case .day4:    return "protein at every meal. that's it."
        case .day5:    return "rest is offensive, not optional."
        case .generic: return "good to see you."
        }
    }
}

extension LessonID: Identifiable {
    /// Identifiable conformance lets HomeView present the lesson via
    /// `.sheet(item: $pendingLesson)` — the cleanest binding for
    /// "present this lesson when set, dismiss when cleared."
    var id: Int { rawValue }
}

// MARK: - User context

/// Snapshot of the personalization-relevant fields read from UserRecord
/// at lesson-open time. Decoupled from SwiftData so the resolver is
/// trivially testable. Every field has a safe default — a nil-user or
/// fresh-install context resolves to universal copy.
struct JeniMethodUserContext {
    let name: String              // may be ""
    let voicePreference: String   // "encouraging" | "balanced" | "roast" (raw, pre-override)
    let experience: String        // "neverTried" | "triedFailed" | "sometimes" | "regularly"
    let goal: String              // "loseWeight" | "fullBody" | "toneCore" | "growGlutes" | "slimLegs"
    let bodyFocus: [String]       // multi
    let identityFeeling: String   // may be ""

    static let empty = JeniMethodUserContext(
        name: "",
        voicePreference: "encouraging",
        experience: "",
        goal: "",
        bodyFocus: [],
        identityFeeling: ""
    )

    /// Build the personalization snapshot from @AppStorage mirrors. Used
    /// by both the post-purchase trigger (Phase 2) and the HomeView card
    /// (Phase 3).
    ///
    /// Note: `userMotivation` is the @AppStorage key that mirrors
    /// `UserRecord.onboardingGoal` (canonical "loseWeight" / "fullBody" /
    /// etc), despite its misleading name (see investigation §5).
    static func fromAppStorage(_ defaults: UserDefaults = .standard) -> JeniMethodUserContext {
        let bodyFocusFirst = defaults.string(forKey: "bodyFocus") ?? ""
        return JeniMethodUserContext(
            name: defaults.string(forKey: "userName") ?? "",
            voicePreference: defaults.string(forKey: "voicePreference") ?? "encouraging",
            experience: defaults.string(forKey: "userExperience") ?? "",
            goal: defaults.string(forKey: "userMotivation") ?? "",
            bodyFocus: bodyFocusFirst.isEmpty ? [] : [bodyFocusFirst],
            // Phase 9.20 — persisted in handleOnboardingComplete.
            // Values: "powerful" | "calm" | "light" | "strong" | "radiant".
            identityFeeling: defaults.string(forKey: "identityFeeling") ?? ""
        )
    }
}

// MARK: - Resolved lesson

/// Analytics-shaped view of a lesson. Used by `JeniMethodAnalytics`
/// to fill out event properties; the ritual view assembles one
/// inline as a shim. The card-based viewer that consumed a `cards`
/// list was deleted in Phase 9.22 — see JeniMethodRitual.swift for
/// the live content.
struct ResolvedLesson: Equatable {
    let id: Int
    let topic: String              // slug for analytics, not display
    let standingSafetyLine: String // shown subtly in lesson footer
    let voice: String              // post-override: "encouraging" | "balanced"
}

// MARK: - Content + resolver

enum JeniMethodContent {

    // MARK: - Voice override (locked decision: roast → balanced for diet)

    /// Diet-content voice override per docs/diet_education_plan.md §4.3:
    /// "roast" is replaced with "balanced" for all education copy. The
    /// brand voice does not roast users about food. Workout-cue voice
    /// elsewhere in the app is unchanged.
    static func voiceForDietContent(_ raw: String) -> String {
        raw == "roast" ? "balanced" : raw
    }

    // MARK: - Branching axes

    /// Two-frame split of `onboardingGoal`. `loseWeight` is the only
    /// explicit fat-loss-primary goal; the other allowlisted goals
    /// (slimLegs, toneCore, fullBody) read as recomp-primary because they
    /// describe a shape change rather than a number change. Unknown or
    /// empty goals fall to recompPrimary — the more neutral frame.
    enum GoalFrame { case fatLossPrimary, recompPrimary }

    static func goalFrame(for goal: String) -> GoalFrame {
        goal == "loseWeight" ? .fatLossPrimary : .recompPrimary
    }

    /// Three-bucket collapse of `onboardingExperience`. Empty / unknown
    /// → beginner (gentler is never wrong).
    enum ExperienceBucket { case beginner, casual, experienced }

    static func experienceBucket(for experience: String) -> ExperienceBucket {
        switch experience {
        case "sometimes":             return .casual
        case "regularly":             return .experienced
        case "neverTried",
             "triedFailed":           return .beginner
        default:                      return .beginner
        }
    }

}
