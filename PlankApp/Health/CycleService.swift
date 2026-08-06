import Foundation
import Observation
import HealthKit

// MARK: - CycleService
//
// HealthKit-backed menstrual-flow source for the season signal
// (docs/app_v6/00_RESEARCH.md + CycleSignal in Signals.swift).
// Read-only, mirrors SleepService's shape: silent bootstrap probe,
// explicit requestAccess() from the one dismissable connect row,
// tri-state authorization inferred the same way (HealthKit hides
// read-denial by design).
//
// Register floors live in CycleSignal: the app NEVER predicts dates,
// never speaks fertility. This service only surfaces period starts.
//
// Sim note: add flow samples via Health → Browse → Cycle Tracking
// to exercise the populated states; `--uitest-force-season <phase>`
// renders without HK.

@MainActor
@Observable
final class CycleService {
    static let shared = CycleService()

    enum Authorization: Equatable {
        case unavailable
        case notDetermined
        case requesting
        case authorized
        case denied
    }

    private(set) var authStatus: Authorization
    /// Derived period starts (ascending), from cycle-start metadata
    /// where present, else the flow-day gap heuristic.
    private(set) var periodStarts: [Date] = []
    private(set) var lastSyncedAt: Date?

    private let healthStore = HKHealthStore()

    private init() {
        self.authStatus = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    }

    /// Silent probe at launch: no prompt, just a read. Data present →
    /// authorized; else stays notDetermined for the connect row.
    func bootstrap() async {
        guard case .notDetermined = authStatus else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = .unavailable
            return
        }
        await refresh()
        if !periodStarts.isEmpty {
            authStatus = .authorized
        }
    }

    /// The read type, shared so the steps/sleep connect sheets carry
    /// it (v9 P0 truth pass, W5: the season surface shipped with no
    /// requester anywhere — the read could never be granted. One
    /// system ask covers every passive stream).
    static var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        if let t = HKObjectType.categoryType(forIdentifier: .menstrualFlow) {
            set.insert(t)
        }
        return set
    }

    /// The connect row's tap. One system sheet; then one forced read
    /// to observe the post-grant state.
    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let flowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow)
        else {
            authStatus = .unavailable
            return
        }
        authStatus = .requesting
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [flowType])
        } catch {
            authStatus = .notDetermined
            return
        }
        await refresh(force: true)
        authStatus = periodStarts.isEmpty ? .denied : .authorized
    }

    /// Re-reads the trailing 120 days of flow samples. 10-minute cache.
    func refresh(force: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !force, let synced = lastSyncedAt,
           Date().timeIntervalSince(synced) < 600 { return }
        guard let flowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow)
        else { return }

        let now = Date()
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -120, to: now)
        else { return }
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart, end: now, options: .strictStartDate
        )
        let sortByStart = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: flowType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStart]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        // Flow days = samples that record actual flow ("no flow" logs
        // are cycle bookkeeping, not flow). The availability branch
        // exists for the test target's older floor; the app itself
        // never runs below iOS 26.
        let flowDays: [Date] = samples.compactMap { sample in
            if #available(iOS 18.0, *) {
                guard let value = HKCategoryValueVaginalBleeding(rawValue: sample.value),
                      value != .none
                else { return nil }
                return sample.startDate
            } else {
                return nil
            }
        }

        // Metadata starts are authoritative where the source app set
        // them; the gap heuristic fills the rest.
        let metadataStarts: [Date] = samples.compactMap { sample in
            (sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool) == true
                ? sample.startDate : nil
        }
        let derived = CycleSignal.periodStarts(flowDays: flowDays + metadataStarts)
        periodStarts = derived
        lastSyncedAt = now
    }
}
