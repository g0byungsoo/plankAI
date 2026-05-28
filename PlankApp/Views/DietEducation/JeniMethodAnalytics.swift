import Foundation

/// Analytics facade for The JeniFit Method (Phase 6 of
/// docs/diet_education_plan.md). Centralizes property assembly so every
/// event has a consistent shape and so the §5.3 invariant — no numeric
/// body data on any event — is enforced in one place.
///
/// Property contract per plan §7:
///   - `diet_education_started`         : user_goal, experience, paid_status
///   - `diet_education_lesson_viewed`   : + lesson_id, lesson_topic
///   - `diet_education_action_completed`: + action_kind (no paid_status)
///   - `diet_education_skipped`         : + screen (no paid_status)
///   - `diet_education_completed`       : lessons_completed, lessons_skipped,
///                                        days_elapsed, user_goal, experience
///
/// `paid_status` is reported as `"entitled"` / `"not_entitled"` (binary)
/// rather than the plan §7 spec of `"trial"` / `"subscribed"`. Reason:
/// the trial-vs-subscribed split would require modifying PaymentService
/// to expose `customerInfo.entitlements[…].periodType`, which violates
/// the observe-only contract. v1.1 can refine the split when PaymentService
/// gains an observable trial flag; the funnel analysis question
/// (did the event fire in a paid state?) is fully answered by `entitled`.
enum JeniMethodAnalytics {

    // MARK: - Reading paid_status (observe-only on PaymentService)

    /// Read PaymentService's existing public state — no new APIs added.
    /// Synchronous; safe to call from any thread (Bool read from a
    /// nonisolated Published).
    static var paidStatus: String {
        PaymentService.shared.hasProAccess ? "entitled" : "not_entitled"
    }

    // MARK: - Property builders

    /// Base property set: user_goal, experience, paid_status. Used by
    /// every event except `diet_education_completed` (which carries
    /// cohort totals instead of per-lesson context).
    /// Test-friendly form takes explicit `paidStatus`; the convenience
    /// overload below reads the live value.
    static func baseProps(
        user: JeniMethodUserContext,
        paidStatus: String
    ) -> [String: Any] {
        [
            "user_goal":   user.goal,
            "experience":  user.experience,
            "paid_status": paidStatus,
        ]
    }

    static func baseProps(user: JeniMethodUserContext) -> [String: Any] {
        baseProps(user: user, paidStatus: paidStatus)
    }

    /// Per-lesson properties for the viewed/action events. Adds
    /// lesson_id + lesson_topic to the base props.
    static func lessonProps(
        lesson: ResolvedLesson,
        user: JeniMethodUserContext,
        paidStatus: String
    ) -> [String: Any] {
        var p = baseProps(user: user, paidStatus: paidStatus)
        p["lesson_id"]    = lesson.id
        p["lesson_topic"] = lesson.topic
        return p
    }

    static func lessonProps(lesson: ResolvedLesson, user: JeniMethodUserContext) -> [String: Any] {
        lessonProps(lesson: lesson, user: user, paidStatus: paidStatus)
    }

    /// Skip-event properties. `screen` is one of "learn" / "action" /
    /// "complete" / "preview" — matching the lesson view's internal
    /// `Screen` enum. paid_status intentionally omitted per plan §7.
    static func skipProps(
        lesson: ResolvedLesson,
        user: JeniMethodUserContext,
        screen: String
    ) -> [String: Any] {
        [
            "lesson_id":    lesson.id,
            "lesson_topic": lesson.topic,
            "screen":       screen,
            "user_goal":    user.goal,
            "experience":   user.experience,
        ]
    }

    /// Terminal completion event properties. Carries cohort totals so a
    /// funnel query can split by completion rate / skip rate / time-to-
    /// complete without joining against per-lesson events.
    static func completedProps(
        user: JeniMethodUserContext,
        lessonsCompleted: Int,
        lessonsSkipped: Int,
        daysElapsed: Int
    ) -> [String: Any] {
        [
            "lessons_completed": lessonsCompleted,
            "lessons_skipped":   lessonsSkipped,
            "days_elapsed":      daysElapsed,
            "user_goal":         user.goal,
            "experience":        user.experience,
        ]
    }

}
