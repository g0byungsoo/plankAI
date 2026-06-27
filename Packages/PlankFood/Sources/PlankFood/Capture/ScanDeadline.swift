import Foundation
import os

// MARK: - ScanDeadline
//
// 2026-06-23 — the load-bearing fix for the "scanning forever" hang.
//
// The food scan's "scanning" UI is pinned by `isCapturing`, which is
// reset ONLY by `defer { isCapturing = false }` in
// PhotoCaptureView.captureTapped(). That defer runs only if the whole
// async chain settles. Several awaits in the chain can fail to settle:
//   - the AVFoundation capture continuation (resumed only from
//     didFinishProcessingPhoto, which is NOT guaranteed to fire on an
//     interrupted/errored capture),
//   - the post-vision nutrition lookup (a withTaskGroup that waits for
//     every source),
//   - a wedged socket the URLSession timeout somehow misses.
// Any one of them leaves the spinner up forever — which is exactly the
// founder's "stuck forever, even on fast wifi" report.
//
// `withScanDeadline` is the backstop that makes that class of bug
// IMPOSSIBLE: it guarantees the caller is resumed within `seconds` no
// matter what the work does.
//
// Why not `withThrowingTaskGroup`? A task group will NOT return until
// all of its children finish — so if the work child is parked on a
// non-cancellable continuation, the group hangs at cleanup and the
// timeout never frees the UI. (Cancellation does nothing to a
// continuation that doesn't honor it.) The only pattern that actually
// frees the caller is to race two *unstructured* tasks and, on
// deadline, resume the continuation + abandon the work without awaiting
// it. The stuck task may leak until its continuation is eventually
// resumed (the camera's terminal-callback safety net handles that) —
// but the user is unblocked immediately. Defense in depth: this helper
// is the universal floor; the camera continuation is also made
// cancellable + given a guaranteed terminal resume so the abandoned
// task actually dies in practice.

/// Thrown when a scan exceeds its hard deadline. Routed to the gentle
/// "let's try that again" failure card by the capture flow.
public struct ScanDeadlineExceeded: Error, Sendable {}

/// Resume-once latch. The work coordinator and the deadline coordinator
/// both try to resume the same continuation; resuming a
/// CheckedContinuation twice traps. This guarantees exactly one wins.
/// Sendable (via OSAllocatedUnfairLock) so it can be captured by the
/// @Sendable Task closures that race for it.
private final class ResumeOnce: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: false)
    /// Returns true for the first caller only; false for every caller
    /// after. The winner owns the single allowed `resume`.
    func claim() -> Bool {
        state.withLock { claimed in
            if claimed { return false }
            claimed = true
            return true
        }
    }
}

/// Run `operation`, but guarantee the caller is resumed within
/// `seconds` EVEN IF `operation` is stuck on a non-cancellable await.
/// On deadline: throws `ScanDeadlineExceeded`, best-effort cancels the
/// work task, and abandons it (never awaits a stuck child).
///
/// `operation` is `@MainActor` because the scan pipeline reads/writes
/// MainActor-isolated state (the camera manager, the dispatcher). The
/// work runs on the main actor but suspends at every real await
/// (capture, network), so the UI stays responsive throughout.
@discardableResult
public func withScanDeadline<T: Sendable>(
    _ seconds: Double,
    operation: @escaping @MainActor () async throws -> T
) async throws -> T {
    let workTask = Task { @MainActor in try await operation() }
    let timerTask = Task {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<T, Error>) in
        let latch = ResumeOnce()

        // Work coordinator — resumes the moment the scan finishes or
        // throws, and cancels the (now-pointless) deadline timer.
        Task {
            do {
                let value = try await workTask.value
                if latch.claim() {
                    timerTask.cancel()
                    cont.resume(returning: value)
                }
            } catch {
                if latch.claim() {
                    timerTask.cancel()
                    cont.resume(throwing: error)
                }
            }
        }

        // Deadline coordinator — resolves on the deadline OR when the
        // work coordinator cancels the timer (try? swallows the
        // cancellation). On a genuine deadline it claims the resume,
        // abandons the work (best-effort cancel), and frees the caller.
        Task {
            _ = try? await timerTask.value
            if latch.claim() {
                workTask.cancel()
                cont.resume(throwing: ScanDeadlineExceeded())
            }
        }
    }
}
