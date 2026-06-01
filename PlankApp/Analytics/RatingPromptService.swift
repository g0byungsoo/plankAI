import Foundation
import StoreKit
import UIKit
import Observation

// MARK: - RatingPromptService
//
// Centralizes JeniFit's App Store review prompt strategy across the 3
// peak-end moments (epic #1 child #6). Replaces the inline single-shot
// `requestAppStoreReview()` in OnboardingView with a per-trigger
// eligibility check so the full 3-per-365-day Apple quota is spent on
// the moments most likely to produce 5-star ratings:
//
//   1. postPlanReveal  — case 215 onboarding sentiment gate ("love your plan?")
//   2. sessionThreePR  — first PR session of ≥45s, post-celebration
//   3. dayStreakSeven  — first time current streak == 7
//
// Each trigger fires AT MOST ONCE per install (UserDefaults flag) so
// existing users updating to v1.0.7 don't get spammed. Apple's
// SKStoreReviewController.requestReview(in:) enforces the global quota
// regardless, but the per-trigger flag closes the "every PR session
// re-fires the prompt" failure mode.
//
// Existing-user safety:
//   - sessionThreePR uses `sessionCount == 3` (transition), so existing
//     users with 100+ sessions won't retroactively trigger via the
//     session count alone; the "first PR after install" path catches
//     them once.
//   - dayStreakSeven uses `streak == 7` (transition), so existing users
//     with current streak > 7 will not trigger.
//   - postPlanReveal only fires during onboarding (case 215); existing
//     users who already onboarded are past it.
//
// The sentiment pre-prompt (Headspace pattern, lifts star avg ~0.5)
// lives in PreReviewSentimentSheet — "yes" fires the system sheet,
// "not yet" routes to feedback without burning a quota slot.

@MainActor
@Observable
final class RatingPromptService {
    static let shared = RatingPromptService()

    /// Persistence keys. One per trigger so each trigger fires at most
    /// once per install lifetime. NOT synced to Supabase or cross-device;
    /// each install gets its own slots since Apple's quota is per-install
    /// too. The keys are intentionally explicit (not enum.rawValue) so a
    /// future trigger rename doesn't silently reset existing flags.
    private let postPlanRevealKey  = "ratingPrompt.postPlanReveal.shown"
    private let sessionThreePRKey  = "ratingPrompt.sessionThreePR.shown"
    private let dayStreakSevenKey  = "ratingPrompt.dayStreakSeven.shown"

    /// Last time ANY rating prompt fired (across all triggers). Used by
    /// the soft-cooldown check so we don't ask twice within 30 days even
    /// if two triggers happen to land back-to-back. Apple's quota is the
    /// hard ceiling; this is the politeness layer.
    private let lastPromptDateKey = "ratingPrompt.lastDate"
    private let cooldownSeconds: TimeInterval = 30 * 24 * 3600

    private init() {}

    enum Trigger: String, CaseIterable {
        case postPlanReveal  // case 215 onboarding sentiment gate
        case sessionThreePR  // first PR session of ≥45s
        case dayStreakSeven  // first time current streak == 7

        var flagKey: String {
            switch self {
            case .postPlanReveal: return "ratingPrompt.postPlanReveal.shown"
            case .sessionThreePR: return "ratingPrompt.sessionThreePR.shown"
            case .dayStreakSeven: return "ratingPrompt.dayStreakSeven.shown"
            }
        }
    }

    /// Legacy @AppStorage key from the v1.0.6-and-earlier onboarding
    /// review prompt. Read at .postPlanReveal eligibility check so
    /// existing users who already saw the legacy prompt don't get re-
    /// prompted on v1.0.7 upgrade. Safe to read directly — @AppStorage
    /// is UserDefaults under the hood.
    private let legacyOnboardingReviewKey = "onboardingReviewPromptShown"

    /// Whether the trigger is eligible to fire right now. Caller checks
    /// this BEFORE presenting the sentiment sheet. Returns false if:
    ///   - this trigger has already fired this install, OR
    ///   - any rating prompt fired in the last 30 days, OR
    ///   - (postPlanReveal only) the legacy onboarding review flag is set
    /// Does NOT check Apple's 3/365 quota — that's enforced silently by
    /// SKStoreReviewController itself.
    func isEligible(for trigger: Trigger) -> Bool {
        // Per-trigger lifetime flag
        if UserDefaults.standard.bool(forKey: trigger.flagKey) {
            return false
        }
        // Backward-compat for existing v1.0.6 users who already saw the
        // legacy inline onboarding prompt. Without this they'd get re-
        // prompted on the postPlanReveal trigger when they update.
        if trigger == .postPlanReveal,
           UserDefaults.standard.bool(forKey: legacyOnboardingReviewKey) {
            return false
        }
        // 30-day soft cooldown across triggers
        if let last = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date,
           Date().timeIntervalSince(last) < cooldownSeconds {
            return false
        }
        return true
    }

    /// Mark a trigger as having shown its sentiment gate. Call this once
    /// the gate appears (regardless of yes/no answer) so retries don't
    /// re-fire the same gate. Sets both the per-trigger flag AND the
    /// global last-date for the cooldown check.
    func markShown(_ trigger: Trigger) {
        UserDefaults.standard.set(true, forKey: trigger.flagKey)
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
    }

    /// Fire the actual Apple system review sheet. Caller invokes this on
    /// "yes" from the sentiment gate. Walks UIScene to find a foreground
    /// active windowScene per iOS 14+ API requirements. iOS silently
    /// suppresses if the 3/365 quota is exhausted.
    func presentSystemReviewSheet() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// Convenience: track that the sentiment gate fired + the user's
    /// answer. Used by all 3 trigger sites for consistency. Property
    /// matches the v1.0.7 spec schema exactly.
    func trackSentimentResult(trigger: Trigger, sentimentYes: Bool) {
        Analytics.track(.ratingPromptShown, properties: [
            "trigger": trigger.rawValue,
            "sentiment_yes": sentimentYes
        ])
    }
}
