import Foundation

// MARK: - FoodScanActivity
//
// Closure-sink for the Dynamic Island + Lock Screen Live Activity
// that runs during a food scan. Mirrors the FoodAnalytics /
// FoodHealthKitWriter pattern: PlankFood is a leaf SPM package and
// can't import ActivityKit (would require entitlement parity with
// the main app + a widget extension target the package can't see).
//
// Instead the main app registers three closures at launch:
//   - start(displayName:) → returns an opaque handle the closure
//     stores (the actual Activity instance in main-app code).
//   - update(handle:phase:) → updates the activity's content state.
//   - end(handle:) → ends the activity.
//
// PlankFood's PhotoCaptureView calls start at scan begin and end on
// scan complete / failure. Phase strings match the
// ScanActivityAttributes.ContentState.Phase raw values
// ("reading" / "matching" / "tallying" / "ready").
//
// Nil-safe: closures fired before registration silently drop.

public enum FoodScanActivity {

    nonisolated(unsafe) private static var startClosure: (@Sendable (String) -> Any?)?
    nonisolated(unsafe) private static var updateClosure: (@Sendable (Any?, String) -> Void)?
    nonisolated(unsafe) private static var endClosure: (@Sendable (Any?) -> Void)?

    /// Called once at app launch from PlankAIApp.swift.
    public static func register(
        start: @escaping @Sendable (String) -> Any?,
        update: @escaping @Sendable (Any?, String) -> Void,
        end: @escaping @Sendable (Any?) -> Void
    ) {
        startClosure = start
        updateClosure = update
        endClosure = end
    }

    /// Fire-and-forget start. Returns an opaque handle the caller
    /// must pass back to update / end.
    public static func start(displayName: String) -> Any? {
        startClosure?(displayName)
    }

    public static func update(handle: Any?, phase: String) {
        updateClosure?(handle, phase)
    }

    public static func end(handle: Any?) {
        endClosure?(handle)
    }
}
