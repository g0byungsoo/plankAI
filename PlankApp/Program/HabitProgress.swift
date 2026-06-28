import Foundation

/// Behaviour-completion status for the arrival hero. NEVER references weight or a
/// deadline — adherence is the metric, per the on-track-is-habits constraint.
enum HabitProgress {
    static func weeklyStatus(actionsThisWeek: Int, target: Int) -> String {
        "you're showing up, \(actionsThisWeek) of \(max(target, 1)) this week"
    }
}
