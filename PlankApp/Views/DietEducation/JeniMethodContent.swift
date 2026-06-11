import Foundation

// MARK: - Lesson identifiers

/// The fourteen lessons of The JeniFit Method, in order. Numeric raw
/// values 1-14 double as the user-visible "day N of 14" index. Phase 10
/// extended the arc from 5 → 14 days (tight "daily drop" rewrite). The
/// `.generic` case (rawValue 15) is the Day 15+ daily check-in ritual
/// that loops forever after the arc completes. Use `LessonID.dailyLessons`
/// when you want the 1-14 arc specifically (analytics counts, progress
/// bars, etc); `.allCases` includes the generic.
enum LessonID: Int, CaseIterable {
    case day1 = 1
    case day2 = 2
    case day3 = 3
    case day4 = 4
    case day5 = 5
    case day6 = 6
    case day7 = 7
    case day8 = 8
    case day9 = 9
    case day10 = 10
    case day11 = 11
    case day12 = 12
    case day13 = 13
    case day14 = 14
    case generic = 15

    /// Stable slug used in analytics properties (lesson_topic). Never
    /// shown to users.
    // v1.1 content arc (2026-06-11) — slugs follow the diet-first
    // rewrite so lesson_topic analytics segment by the new curriculum.
    var topicSlug: String {
        switch self {
        case .day1:    return "muscle_changes_the_math"
        case .day2:    return "snap_dont_count"
        case .day3:    return "protein_first"
        case .day4:    return "cant_outmove_the_plate"
        case .day5:    return "scale_is_moody"
        case .day6:    return "walk_after_you_eat"
        case .day7:    return "lighter_days"
        case .day8:    return "the_comeback"
        case .day9:    return "food_noise"
        case .day10:   return "sleep_is_the_multiplier"
        case .day11:   return "the_quiet_7500"
        case .day12:   return "small_beats_heroic"
        case .day13:   return "sixty_six_days"
        case .day14:   return "begin_again"
        case .generic: return "daily_check_in"
        }
    }

    /// The fourteen-day numbered arc (Day 1..14). Use this instead of
    /// `allCases` for anything that should NOT count the generic
    /// ritual — analytics totals, progress %, day-of-N copy.
    static let dailyLessons: [LessonID] = [
        .day1, .day2, .day3, .day4, .day5, .day6, .day7,
        .day8, .day9, .day10, .day11, .day12, .day13, .day14,
    ]

    /// Per-lesson card illustration. **Currently points at the existing
    /// ritual paper-craft assets as placeholders** — these read as "too
    /// small" on the card because the figure sits inside generous
    /// whitespace, so the actual subject is ~40% of the frame at the 72pt
    /// card crop. Generate new card-specific assets and either replace
    /// these imagesets or remap the switch below to `method_card_d1`…
    /// `method_card_d14`.
    ///
    /// **Spec for new card art (so it reads bigger at 72pt):**
    /// - 216×216@3x asset (72pt × 3x), square 1:1.
    /// - **Subject fills the frame edge-to-edge** — no margin, no white
    ///   background padding. Crop tight to the figure or object.
    /// - Paper-craft style matching the rest of the Method (consistency).
    /// - Transparent or cream background (sits cleanly on the pink card).
    /// - Per-lesson semantic, see comments per case below.
    var coverIllustration: String {
        switch self {
        case .day1:    return "lesson_d1_science"       // muscle changes the math
        case .day2:    return "lesson_d2_paradox"       // can't out-burn the machine
        case .day3:    return "lesson_d3_neat"          // your day burns more than workout
        case .day4:    return "lesson_d4_plank"         // the boring hold wins
        case .day5:    return "lesson_d5_walk"          // walk right after you eat
        case .day6:    return "lesson_d2_consistency"   // small beats heroic
        case .day7:    return "lesson_d7_habit"         // sixty-six days
        case .day8:    return "lesson_d8_return"        // one slip doesn't undo you
        case .day9:    return "lesson_d9_kindness"      // kindness gets you back on track
        case .day10:   return "lesson_d4_protein"       // protein at every meal
        case .day11:   return "lesson_d11_enjoy"        // workout you'll repeat
        case .day12:   return "lesson_d12_snack"        // one-minute bursts
        case .day13:   return "lesson_d5_sleep"         // sleep is the multiplier
        case .day14:   return "lesson_d14_freshstart"   // you can always begin again
        case .generic: return "lesson_d14_freshstart"
        }
    }

    /// Phase 9.22 — short teaser headline per lesson. Used by the
    /// HomeView card + JeniMethodReReadView index so they don't have
    /// to resolve a full ritual just to display one line. Matches the
    /// dominant promise of each day's ritual content.
    var headline: String {
        switch self {
        case .day1:    return "muscle changes the math."
        case .day2:    return "you can't out-burn the machine."
        case .day3:    return "your day burns more than your workout."
        case .day4:    return "the boring hold wins."
        case .day5:    return "walk right after you eat."
        case .day6:    return "small you'll do beats heroic you won't."
        case .day7:    return "it takes about sixty-six days."
        case .day8:    return "one slip doesn't undo you."
        case .day9:    return "kindness gets you back on track."
        case .day10:   return "protein at every meal. that's it."
        case .day11:   return "the workout you'll repeat wins."
        case .day12:   return "a few one-minute bursts count."
        case .day13:   return "sleep is where the change happens."
        case .day14:   return "you can always begin again."
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
