import SwiftUI

/// Shared state bridge between the phone's `RoutineSessionView` and the
/// external-display scene (`ExternalDisplaySceneDelegate`). Required
/// because the two scenes are independent UIScene instances that can't
/// reach each other through SwiftUI environment — they share data via
/// this @Observable singleton instead.
///
/// The phone session view writes the active VM here on appear; the
/// external scene reads it to render the cinema view. `isMirroring`
/// flips when iOS connects/disconnects the external scene, driving the
/// "TV connected" affordance on the AirPlay button.
@MainActor
@Observable
final class SessionBridge {
    static let shared = SessionBridge()
    private init() {}

    /// The active routine VM, set by the phone session view. The external
    /// scene's hosting view observes this and renders the cinema layout
    /// while non-nil. Cleared on session disappear so the TV view drops
    /// back to the idle placeholder when the workout ends.
    var vm: RoutineSessionViewModel?

    /// True between `scene(_:willConnectTo:options:)` and
    /// `sceneDidDisconnect(_:)` on the external scene delegate. The
    /// AirPlay button reads this to surface the green "TV connected" dot.
    var isMirroring: Bool = false
}
