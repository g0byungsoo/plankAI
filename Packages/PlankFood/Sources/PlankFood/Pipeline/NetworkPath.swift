import Foundation
import Network

// MARK: - NetworkPath (p61)
//
// One question, answered before a scan spends a second: **is there a
// network at all?**
//
// Before this, an offline scan sat inside the full machinery —
// `waitsForConnectivity` on the session, an 80s URLSession bound, the
// 90s hard deadline — because there was no reachability read anywhere
// in the pipeline. A user in airplane mode watched the dial draw for a
// minute and a half to learn something her phone knew instantly, and
// the failure card then blamed "the connection blinking" as if it had
// tried.
//
// The rule is deliberately narrow: only `.unsatisfied` — the OS's
// definitive "no path" — fails fast. `.requiresConnection` and any
// transitional state proceed to the request, where
// `waitsForConnectivity` does its job. This can only ever convert a
// guaranteed timeout into an instant, honest answer.

enum NetworkPath {

    private static let monitor: NWPathMonitor = {
        let m = NWPathMonitor()
        m.start(queue: DispatchQueue(label: "com.plankfood.networkpath"))
        return m
    }()

    /// Definitively offline right now. False during startup/unknown —
    /// never block a request on an unproven guess.
    static var isDefinitelyOffline: Bool {
        monitor.currentPath.status == .unsatisfied
    }
}
