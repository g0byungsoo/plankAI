import Foundation

// MARK: - NotificationTimeBucket
//
// Single source of truth for "what hour should this push fire?" Reads
// the user's preferred-time answer from onboarding Q11 (the `plankTime`
// AppStorage key — values: "morning" / "afternoon" / "evening" /
// "whenever" / empty) and returns an hour appropriate for the push's
// INTENT.
//
// Why this exists: prior to v1.2, only the canonical daily reminder
// respected the user's bucket. Every other push (Day 0 anchor, Day 2
// engagement, milestone celebration, win-back, affirmations, evening
// plate review) used hardcoded global times. A morning person seeing
// the 10am Day-2 push lands in her productive window; a night-shift
// nurse who picked `evening` sees that same push while she's sleeping.
// Bucket-anchoring is a free 10-15% lift on every existing push before
// any copy work compounds.
//
// Why this is an enum-based helper rather than per-call lookups:
//   - Centralizes the bucket→hour mapping so a future Settings change
//     ("let me pick a different time per category") changes one file.
//   - PushIntent is the seam: pushes declare their semantic purpose
//     (engagement / reflection / milestone / etc.) rather than a clock
//     hour, and the helper picks the right slot.
//   - Some intents are TIME-ANCHORED (trial-end fires T-2h before
//     billing regardless of bucket); the helper makes that explicit
//     via `nil` returns rather than burying the logic at each call site.
//
// Coverage:
//   - Tier-1 personal anchors (reminder, engagement, value spotlight,
//     win-back, milestone, affirmation, weekly summary, paid-lapsed)
//     all respect the user's bucket.
//   - Tier-2 semantic anchors (eveningReflection) honor the user's
//     bucket where it preserves the meaning, but stay evening-ish even
//     for morning users (post-dinner reflection has to be post-dinner).
//   - Tier-3 billing-anchored (trialEnd, postCharge) return nil from
//     `hour(for:)` — the caller computes from the entitlement
//     expirationDate.

public enum NotificationTimeBucket: String {
    case morning
    case afternoon
    case evening
    case whenever

    /// Reads the user's onboarding Q11 answer (`plankTime`). Returns
    /// `.whenever` when the value is missing or unrecognized — used as
    /// the safe default for users who installed before Q11 shipped.
    public static var userPreferred: NotificationTimeBucket {
        guard let raw = UserDefaults.standard.string(forKey: "plankTime"),
              let bucket = NotificationTimeBucket(rawValue: raw) else {
            return .whenever
        }
        return bucket
    }

    /// Returns the hour-of-day (0-23) for a given push intent, anchored
    /// to the user's bucket where appropriate. Returns nil for intents
    /// that are NOT bucket-anchored (trialEnd is billing-time-anchored,
    /// caller computes from expirationDate).
    public func hour(for intent: PushIntent) -> Int? {
        switch intent {
        // ── Bucket-anchored ─────────────────────────────────────────
        // These pushes pick the user's chosen window. Morning person
        // gets morning, evening person gets evening. The slot exists
        // to land in *her* productive moment.
        case .reminder, .engagement, .valueSpotlight, .winback,
             .milestone, .affirmation, .weeklySummary, .paidLapsed:
            return bucketHour

        // ── Evening-semantic ────────────────────────────────────────
        // Evening reflection is meaningfully evening — a "look back at
        // today's plate" push at 8am is nonsense. We honor the user's
        // bucket *within evening*: morning users get 7pm (earlier
        // wind-down), everyone else gets 8pm. Only "evening" bucket
        // gets the canonical late slot (9pm).
        case .eveningReflection:
            switch self {
            case .morning:   return 19  // 7pm — earlier wind-down
            case .afternoon: return 20  // 8pm — standard
            case .evening:   return 21  // 9pm — they're up later
            case .whenever:  return 20
            }

        // ── Billing-anchored (caller computes) ──────────────────────
        case .trialEnd, .postCharge:
            return nil
        }
    }

    /// The user's chosen "primary" hour. This is the canonical slot
    /// the daily reminder lands in, and the anchor for every other
    /// bucket-anchored intent. Tuned slightly later than the legacy
    /// `reminderTimeFromBucket` values (which used 7am/1pm/7pm/9am)
    /// because that earlier mapping was tuned for a single push slot;
    /// when MULTIPLE pushes share a bucket, a slightly later anchor
    /// gives breathing room to subsequent bucket-anchored events
    /// that need to fire after this one (e.g., milestone-next-morning).
    private var bucketHour: Int {
        switch self {
        case .morning:   return 8   // 8am — an hour past typical wake
        case .afternoon: return 14  // 2pm — post-lunch valley
        case .evening:   return 19  // 7pm — pre-dinner gather
        case .whenever:  return 10  // 10am — neutral mid-morning default
        }
    }
}

// MARK: - PushIntent

/// The semantic purpose of a push, used to drive the bucket→hour
/// mapping in `NotificationTimeBucket.hour(for:)`. Add new intents
/// here (NOT new hardcoded hours at call sites) so the bucket logic
/// stays the single source of truth.
public enum PushIntent {
    /// The canonical daily check-in reminder.
    case reminder
    /// Day-2 trial-week engagement push or its steady-state analog.
    case engagement
    /// Day-1 trial-week behaviorally-targeted feature spotlight.
    case valueSpotlight
    /// Lapse-recovery push for free / trial users.
    case winback
    /// Distinct-shown-up-day celebration (Day 3/7/14/30/50/100).
    case milestone
    /// Tue/Sat 1pm-ish affirmation drops (post-week-1).
    case affirmation
    /// Sunday weekly Becoming-tab summary push.
    case weeklySummary
    /// 4-beat reactivation cadence for paid-but-lapsed subscribers.
    case paidLapsed
    /// Evening "today's plate" reflection — semantically tied to
    /// after-dinner regardless of bucket (with some flex).
    case eveningReflection
    /// Trial-end reminder anchored to the entitlement's
    /// expirationDate. Caller computes from RC entitlement state.
    case trialEnd
    /// Post-charge "welcome / week-one" anchored to the purchase date.
    /// Caller computes from RC entitlement purchaseDate.
    case postCharge
}
