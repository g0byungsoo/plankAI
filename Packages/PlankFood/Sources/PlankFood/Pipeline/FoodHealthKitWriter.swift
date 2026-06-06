import Foundation

// MARK: - FoodHealthKitWriter
//
// Closure-based HealthKit write hook for the food rail. PlankFood
// is a leaf SPM package and can't import the main-app HealthKit
// implementation (would create a cycle and require HealthKit
// entitlement in the package). Instead, the main app registers a
// single write closure at launch via FoodHealthKitWriter.register.
// FoodLogPersister calls FoodHealthKitWriter.writeIfRegistered after
// every successful persist; the main app's closure inspects the
// user's toggle state and writes to HealthKit when enabled.
//
// Mirrors the FoodAnalytics pattern so PlankFood's leaf-package
// invariant stays clean: zero hard dependencies on HKHealthStore,
// no entitlement plumbing in the package, no per-call-site
// awareness of where the data goes.

public enum FoodHealthKitWriter {

    /// Registered by the main app at launch. Receives the kcal value
    /// for a single food log entry and its timestamp. The closure
    /// is responsible for:
    ///   1. Checking the user's AppStorage toggle is on
    ///   2. Confirming HK write authorization
    ///   3. Building + saving the HKQuantitySample
    /// Nil-safe: writes fired before registration are silently
    /// dropped (intentional — onboarding/launch ordering).
    nonisolated(unsafe) private static var sink: (@Sendable (Double, Date) -> Void)?

    /// Called once at app launch from PlankAIApp.swift. Idempotent —
    /// repeated calls just replace the closure.
    public static func register(_ handler: @escaping @Sendable (Double, Date) -> Void) {
        sink = handler
    }

    /// Fire-and-forget write. Called from FoodLogPersister after a
    /// successful in-memory append (and after the SwiftData @Model
    /// integration lands in v1.0.8).
    public static func writeIfRegistered(kcal: Double, at date: Date) {
        sink?(kcal, date)
    }
}
