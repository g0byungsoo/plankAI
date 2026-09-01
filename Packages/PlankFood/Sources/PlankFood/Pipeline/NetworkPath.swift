import Foundation
import Network
import os

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
// The rule is deliberately narrow, and it is narrow in BOTH
// directions: only a DELIVERED `.unsatisfied` path fails fast.
// `NWPathMonitor.currentPath` reads `.unsatisfied` between `start()`
// and the first path update, so a raw read would call a working
// network "offline" for the first milliseconds of every process — the
// unit suite caught exactly that. Until the monitor has spoken, and
// whenever the answer is anything but a definitive no-path, the
// request proceeds and `waitsForConnectivity` does its job. This can
// only ever convert a guaranteed timeout into an instant, honest
// answer.

enum NetworkPath {

    private static let state = OSAllocatedUnfairLock(
        initialState: (heard: false, offline: false)
    )

    private static let monitor: NWPathMonitor = {
        let m = NWPathMonitor()
        m.pathUpdateHandler = { path in
            state.withLock { $0 = (true, path.status == .unsatisfied) }
        }
        m.start(queue: DispatchQueue(label: "com.plankfood.networkpath"))
        return m
    }()

    /// Definitively offline right now: the monitor has delivered at
    /// least one update and the latest says there is no path. False
    /// during startup/unknown — never block a request on an unproven
    /// guess.
    static var isDefinitelyOffline: Bool {
        _ = monitor   // first touch starts it
        return state.withLock { $0.heard && $0.offline }
    }
}
