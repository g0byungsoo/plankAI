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
    case becoming

    var id: String { rawValue }
    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sparkles"
        case .jeni: "bubble"
        case .becoming: "book.closed"
        }
    }
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
    }

    func open(_ route: Route) {
        switch route {
        case .snap, .weighIn, .lesson, .breath:
            tab = .today
            pendingRoute = route
        case .trend:
            tab = .becoming
            pendingRoute = route
        }
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
        default: break
        }
    }
}
