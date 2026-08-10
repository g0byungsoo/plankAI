import Foundation

// MARK: - NotificationBrain (E1 THE SPINE — B4)
//
// docs/app_v25/05_E1_SPINE.md §4. ONE attention policy over every
// scheduler. The brain VETOES — it never schedules; the working
// per-category infrastructure (v24 medication reminders above all)
// stays exactly as shipped and consults `admit` before arming a
// user-facing send. Laws:
//   - HARD budget: ≤5 non-medication sends per rolling week
//     (>6/week = 3.4× uninstall risk — r6). The quieter posture
//     halves it.
//   - Lanes: medication is EXEMPT and never silenced (medical
//     rhythm ≠ engagement — the v24 carve-out, now explicit law);
//     the weekly read outranks support at the margin (one slot
//     reserved).
//   - Auto-silence: 6 consecutive ignores put a category to sleep
//     until she re-engages (in-app card speaks; never a push about
//     pushes).
//   - Holdouts: a stable per-user-per-category MRT lane so the
//     system can see its own effect (never medication).

enum NotificationBrain {

    enum Category: String, CaseIterable {
        case medication
        case weeklyRead = "weekly_read"
        case support
        case reengagement
    }

    struct Candidate {
        let category: Category
        let id: String
    }

    private static let ledgerKey = "brain.ledger.v1"
    private static func streakKey(_ c: Category) -> String { "brain.ignores.\(c.rawValue)" }
    private static func silencedKey(_ c: Category) -> String { "brain.silenced.\(c.rawValue)" }
    private static let silenceThreshold = 6

    static func admit(
        _ candidate: Candidate,
        now: Date = .now,
        posture: String? = nil,
        defaults: UserDefaults = .standard
    ) -> Bool {
        // Medication: always. Exempt from budget, silence, holdouts —
        // medical rhythm is not engagement.
        if candidate.category == .medication { return true }

        if isSilenced(candidate.category, defaults: defaults) {
            Analytics.track(.notifCandidate, properties: [
                "category": candidate.category.rawValue, "admitted": false,
                "why": "silenced",
            ])
            return false
        }

        let weekAgo = now.addingTimeInterval(-7 * 86_400).timeIntervalSince1970
        var stamps = ((defaults.dictionary(forKey: ledgerKey) as? [String: Double]) ?? [:])
            .filter { $0.value > weekAgo }
        let budget = posture == "quieter" ? 2 : 5

        let admitted: Bool
        if candidate.category == .weeklyRead {
            // The week's one ritual passes even at the margin —
            // logged, never multiplied (one read per week by
            // construction upstream).
            admitted = true
        } else if stamps[candidate.id] != nil {
            // A same-id re-admit within the window is a REPLACE
            // (planners replace-never-stack daily) — free.
            admitted = true
        } else {
            admitted = stamps.count < budget
        }
        if admitted {
            stamps[candidate.id] = now.timeIntervalSince1970
            defaults.set(stamps, forKey: ledgerKey)
        }
        Analytics.track(.notifCandidate, properties: [
            "category": candidate.category.rawValue, "admitted": admitted,
            "why": admitted ? "ok" : "budget",
        ])
        return admitted
    }

    static func recordIgnored(
        _ category: Category, defaults: UserDefaults = .standard
    ) {
        let streak = defaults.integer(forKey: streakKey(category)) + 1
        defaults.set(streak, forKey: streakKey(category))
        if streak >= silenceThreshold, category != .medication,
           !defaults.bool(forKey: silencedKey(category)) {
            defaults.set(true, forKey: silencedKey(category))
            Analytics.track(.notifSilenced, properties: [
                "category": category.rawValue,
            ])
        }
    }

    static func recordEngaged(
        _ category: Category, defaults: UserDefaults = .standard
    ) {
        defaults.set(0, forKey: streakKey(category))
        defaults.set(false, forKey: silencedKey(category))
    }

    static func isSilenced(
        _ category: Category, defaults: UserDefaults = .standard
    ) -> Bool {
        category != .medication && defaults.bool(forKey: silencedKey(category))
    }

    /// Stable 10% MRT holdout per (user, category) — FNV-1a so the
    /// lane survives relaunches and processes. Never medication.
    static func isHoldout(userId: String, category: Category) -> Bool {
        guard category != .medication else { return false }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in "\(userId)|\(category.rawValue)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash % 10 == 0
    }
}
