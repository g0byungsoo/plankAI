import Foundation
import UserNotifications

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
        /// p54 — the morning read's anchor rungs: a consented daily
        /// cadence (the day-one contract's own offer), not an
        /// interruption. Exempt from the budget and never stamped,
        /// like medication — a standing rhythm that stamped the
        /// ledger daily was the arithmetic that saturated the budget
        /// forever (see `admit`).
        case morningRead = "morning_read"
        case weeklyRead = "weekly_read"
        case support
        case reengagement
    }

    /// p54 — THE CONSENTED-CADENCE CLASS. These are rhythms she said
    /// yes to (the dose reminder, the morning read, the week's one
    /// ritual): they pass without spending budget and without
    /// stamping it. The ≤5/week law governs INTERRUPTIONS — the
    /// event-driven sends — which is what it was written for. Before
    /// this pass the standing rhythms re-stamped the 7-day ledger
    /// every single day, so `stamps.count` sat at 5 permanently and
    /// the budget's only remaining power was to veto whichever fresh
    /// send arrived — in production that was exactly one id family,
    /// and it was the kindest one.
    static let consentedCadence: Set<Category> = [
        .medication, .morningRead, .weeklyRead,
    ]

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
        // Consented cadence: always. Exempt from budget, silence,
        // holdouts — a rhythm she said yes to is not engagement, and
        // it never stamps the ledger it is exempt from.
        if consentedCadence.contains(candidate.category) { return true }

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
        if stamps[candidate.id] != nil {
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

// MARK: - NotificationGate (p54)
//
// THE one door to `UNUserNotificationCenter.add` for every send the
// brain governs. The census that forced this found seventeen schedule
// paths and FOUR admit calls: both daily-repeating pushes, the whole
// retention family and the three JITAI one-shots bypassed the arbiter
// entirely, so the ≤5/week law governed almost nothing. A law with
// voluntary call sites is a comment — `testEverySendPassesThroughTheGate`
// sweeps the sources so a new scheduler cannot ship around this door.
// Medication keeps its own lane (exempt BY DESIGN and never budgeted);
// everything else comes through here.

enum NotificationGate {

    /// Admit-then-add. A veto is silent: the request simply never
    /// reaches the center, and the brain's analytics carry the why.
    static func schedule(
        _ request: UNNotificationRequest,
        category: NotificationBrain.Category,
        center: UNUserNotificationCenter = .current(),
        now: Date = .now
    ) {
        guard NotificationBrain.admit(
            .init(category: category, id: request.identifier), now: now
        ) else { return }
        center.add(request)
    }
}

// MARK: - NotificationCensus (p54)
//
// Every non-medication identifier the app has EVER scheduled, in one
// place, so the master toggle's sweep and the launch cleanup cannot
// silently miss a family again (the census found the master toggle
// clearing six families while seven others survived it — including a
// daily repeat).

enum NotificationCensus {

    /// Live ids (or prefixes) the current build can schedule.
    static let liveIds: [String] = [
        "anchor_d1", "anchor_d2", "anchor_d3",
        "resigning_knock",
        "keeping_zone", "keeping_line_quiet", "lapse_support",
        "evening_plate_review",
        "day1_promise", "day1_morning", "day5_anti_refund",
        "winback_lapse",
    ]

    /// Ids retired by p54 (the presumption-of-deletion set) plus the
    /// pre-v25 legacy ids. Swept at launch and by the master toggle so
    /// a pending request from an OLD install cannot keep firing a
    /// family the product no longer ships: the affirmation drops
    /// (motivational filler, two clock-fired sends a week), the
    /// milestone family (identity-praise pushes on a day count), the
    /// recap (a service with zero callers), and the standalone daily
    /// reminder (workout-era copy, redundant beside the morning read,
    /// and a daily nag for anyone who never enrolled).
    static let retiredIds: [String] = [
        "daily_reminder", "daily-plank",
        "affirmation_drop_0", "affirmation_drop_1", "affirmation_drop_2",
        "affirmation_drop_3", "affirmation_drop_4", "affirmation_drop_5",
        "milestone_3", "milestone_7", "milestone_14",
        "milestone_30", "milestone_50", "milestone_100",
        "becoming.sunday.recap",
        "food_first_log_nudge",
    ]

    /// The master toggle's whole non-medication surface.
    static var allNonMedicationIds: [String] { liveIds + retiredIds }
}
