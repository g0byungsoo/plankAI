import Foundation
import SwiftUI

// MARK: - AppRouter
//
// App v2 (docs/app_v2/03_IA.md). One owner for tab selection + deep
// links. Notification taps and Jeni tool calls both route through
// here; routes queue until the shell is mounted so a push tapped by
// an expired user resolves at the wall, never inside the app.
//
// URL grammar:
//   jenifit://today · ://snap · ://jeni?seed=… · ://becoming
//   ://weigh-in · ://lesson · ://breath · ://trend

/// The three places. Lowercase proper nouns she learns once; the
/// native tab bar (Liquid Glass on iOS 26) renders them with their
/// marks — sparkles for the ritual, the heart bubble for jeni, the
/// closed book for her story.
enum JKTab: String, CaseIterable, Identifiable {
    case today
    case jeni
    /// v11.5 N — not a destination: selecting it opens THE CHOOSER
    /// (body or plate) and the bar springs back to where she was.
    case scan
    case becoming

    var id: String { rawValue }
    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sparkles"
        case .jeni: "bubble"
        case .scan: "viewfinder"
        case .becoming: "book.closed"
        }
    }

    /// True for the action item — it never hosts content.
    var isAction: Bool { self == .scan }
}

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var tab: JKTab = .today

    /// One-shot module route consumed by the Today host (covers) or
    /// Becoming (trend focus). Set → shell reacts → clears.
    var pendingRoute: Route?

    /// Seed text forwarded into the chat composer context when the
    /// jeni tab opens from a coach line / notification.
    var pendingChatSeed: String?

    /// Quiet unread marker for the jeni tab dot.
    var jeniHasUnread = false

    enum Route: Equatable {
        case snap
        case weighIn
        case lesson
        case breath
        case trend
        /// v11.5 N — the chooser's body door.
        case bodyScan
        /// Chat plan-card rows (1.1.6): the day's workout / steps
        /// modules, openable from outside the Today tab.
        case workout
        case steps
        /// v25 E3 — the food describe path, opened with words jeni
        /// already has. The user still sees and confirms the reading.
        case foodDescribe(text: String)
        /// v25 E3 — the dose sheet (where a dose is marked and where
        /// the label facts about a late dose live). Jeni routes here;
        /// she never marks a dose.
        case doseSheet
        /// v25 E3 — the weekly read, when the whole week is the
        /// answer rather than one fact.
        case weeklyRead
        /// v25 E4 — the plate's memory: the one-tap relog rail
        /// (RecentMealsSheet), promoted out of its debug harness.
        case foodAgain
        /// v25 E4 — THE BOOK, directly (the evening review's push
        /// finally lands ON the look-back surface it promises).
        case plates
    }

    func open(_ route: Route) {
        switch route {
        case .snap, .weighIn, .lesson, .breath, .workout, .steps, .bodyScan,
             .foodDescribe, .doseSheet, .foodAgain:
            tab = .today
            pendingRoute = route
        case .trend, .weeklyRead, .plates:
            tab = .becoming
            pendingRoute = route
        }
    }

    /// v25 E3 — jeni hands the describe path her user's own words.
    func openFoodDescribe(text: String) {
        open(.foodDescribe(text: text))
    }

    func openChat(seed: String? = nil) {
        pendingChatSeed = seed
        tab = .jeni
    }

    /// jenifit:// deep links (notifications, tool calls, widgets later).
    func handle(url: URL) {
        guard url.scheme == "jenifit" else { return }
        switch url.host {
        case "today": tab = .today
        case "becoming": tab = .becoming
        case "jeni":
            let seed = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "seed" })?.value
            openChat(seed: seed)
        case "snap": open(.snap)
        case "weigh-in": open(.weighIn)
        case "lesson": open(.lesson)
        case "breath": open(.breath)
        case "trend": open(.trend)
        case "plates": open(.plates)
        default: break
        }
    }
}
