import Foundation
import HealthKit

// MARK: - HealthKitDietaryEnergyWriter
//
// Writes a single food log entry's kcal value to Apple Health as
// Dietary Energy. Built per sprint W4-T4 to back the FoodSettingsView
// "write to apple health" toggle — without this, the toggle is a
// no-op and the user trusts it for nothing.
//
// Hooks into PlankFood's FoodHealthKitWriter closure-sink at app
// launch (PlankAIApp.swift registers it). PlankFood's FoodLogPersister
// calls FoodHealthKitWriter.writeIfRegistered after every successful
// persist; this writer's closure inspects the toggle + auth state and
// either writes or no-ops.
//
// Design:
//   - HKHealthStore reused across calls (HK docs: a single store per
//     process; cheap to keep around).
//   - Write authorization requested explicitly when the toggle flips
//     to true (called from FoodSettingsView's onChange).
//   - Per-sample write (HKQuantitySample) rather than daily-total
//     accumulation — Apple Health expects per-meal granularity for
//     Dietary Energy. Today's "total" is the sum of samples for the
//     day, computed by Health on demand.
//   - Toggle off → writes silently drop. Past samples in Apple Health
//     stay where they are (toggling off doesn't retroactively delete);
//     the user can delete them via the Health app if they want.
//
// Privacy posture: only the kcal value + timestamp are written. No
// food names, no item-level macros, no source attribution beyond
// the standard HK `metadata[.wasUserEntered]` flag.

@MainActor
final class HealthKitDietaryEnergyWriter {

    static let shared = HealthKitDietaryEnergyWriter()

    private let healthStore = HKHealthStore()
    private let dietaryEnergyType = HKQuantityType(.dietaryEnergyConsumed)

    private init() {}

    // MARK: - Public API

    /// Surfaces the iOS HealthKit share-data sheet for Dietary Energy
    /// write permission. Called from FoodSettingsView when the user
    /// flips the toggle to true.
    ///
    /// Returns `true` if the system reports a positive authorization
    /// signal (the user tapped "Allow"). Returns `false` on denial or
    /// HK-unavailable hardware. The system sheet UI only shows when
    /// `.notDetermined` — repeated calls after the user already
    /// decided are no-ops (HK handles dedup).
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await healthStore.requestAuthorization(
                toShare: [dietaryEnergyType],
                read: []
            )
        } catch {
            #if DEBUG
            print("[HealthKitDietaryEnergyWriter] requestAuthorization failed: \(error)")
            #endif
            return false
        }
        // HK's API returns authorization status, not raw bool. Map:
        //   .sharingAuthorized → true
        //   .sharingDenied / .notDetermined → false
        return healthStore.authorizationStatus(for: dietaryEnergyType) == .sharingAuthorized
    }

    /// Writes one kcal sample to Apple Health. Called from PlankFood's
    /// FoodHealthKitWriter sink registration. Gated on the
    /// AppStorage toggle — if off, returns immediately without
    /// touching HK. If on, attempts the save and silently absorbs
    /// errors (no UI surface — the failure is post-hoc to the user's
    /// log action and surfacing it would feel punishing).
    func write(kcal: Double, at date: Date) {
        // Toggle gate — read straight from UserDefaults so we don't
        // hold a @AppStorage subscription on a singleton.
        let enabled = UserDefaults.standard.bool(forKey: "foodHealthKitWriteEnabled")
        guard enabled else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard healthStore.authorizationStatus(for: dietaryEnergyType) == .sharingAuthorized else {
            #if DEBUG
            print("[HealthKitDietaryEnergyWriter] write skipped — not authorized")
            #endif
            return
        }
        guard kcal > 0, kcal.isFinite else { return }

        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        let sample = HKQuantitySample(
            type: dietaryEnergyType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )

        Task.detached {
            do {
                try await self.healthStore.save(sample)
                #if DEBUG
                print("[HealthKitDietaryEnergyWriter] wrote \(Int(kcal)) kcal at \(date)")
                #endif
            } catch {
                #if DEBUG
                print("[HealthKitDietaryEnergyWriter] save failed: \(error)")
                #endif
            }
        }
    }
}
