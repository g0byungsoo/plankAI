import Foundation
import SwiftData
import PlankSync

// MARK: - BodyStateService
//
// app v9 P0 (docs/app_v9/02_PLAN.md, closes W7): ONE typed read of
// "is their body changing" composed from the stores that already
// exist — weight logs (SwiftData), body composition (VitalsService,
// only when her scale writes it), movement (steps + workouts).
// Scans join in P1+.
//
// Laws carried: every floor is the shipped floor (trend = 3+ logs
// spanning 5+ days, the v5 trust floor; stall/rate = WeightAnalytics);
// composition numbers only from real sources with provenance (L3);
// a section with no data is nil — downstream renders nothing, never
// a fabricated state. Pure static core; `current` is the only
// store-touching entry.

struct BodyState {
    struct Weight: Equatable {
        let latestKg: Double
        let latestAt: Date
        let latestSource: String
        let lastWeighInDaysAgo: Int
        let emaSeries: [WeightTrendChart.EMAPoint]
        let emaDelta7dKg: Double?
        /// v5 trust floor: 3+ weigh-ins spanning 5+ days.
        let trendEstablished: Bool
        let isStalled: Bool
        let weeklyLossRate: Double?
        let isLosingTooFast: Bool
        /// 2026-08-13 — her EARLIEST weigh-in. `emaSeries` windows to
        /// 60 days, so its first point means "sixty days ago", never
        /// "when you started": reading a total distance off it would
        /// quietly shorten every record older than two months.
        /// `WeightJourney` needs a fixed anchor, and this is it.
        var earliestKg: Double? = nil
        var earliestAt: Date? = nil
    }

    struct Composition: Equatable {
        let bodyFatPct: Double?
        let leanMassKg: Double?
        /// L3 — a composition number never renders without its source.
        let provenance: String
    }

    struct Movement: Equatable {
        /// Mean steps across the days that recorded any (0-days are
        /// absence, not zeros — the anti-shame floor).
        let stepsWeekAvg: Int
        let activeDaysLast7: Int
        let strengthSessionsLast7: Int
        let activeEnergyTodayKcal: Int?
        let distanceTodayKm: Double?
    }

    let weight: Weight?
    let composition: Composition?
    let movement: Movement?
}

enum BodyStateService {

    /// The composed read. Fetches weight logs (desc), reads the live
    /// vitals + movement services. MainActor because the services are.
    @MainActor
    static func current(userId: String, in context: ModelContext) -> BodyState {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return BodyState(
            weight: weightRead(logs: logs),
            composition: compositionRead(from: VitalsService.shared.read),
            movement: movementRead(
                weeklySteps: StepsService.shared.weeklyCounts,
                strengthSessionsLast7: MovementService.shared.strengthSessionsLast7,
                activeEnergyTodayKcal: MovementService.shared.activeEnergyTodayKcal,
                distanceTodayKm: MovementService.shared.distanceTodayKm
            )
        )
    }

    /// Pure. `logs` newest-first (the fetch order everywhere).
    static func weightRead(logs: [WeightLogRecord], today: Date = .now) -> BodyState.Weight? {
        guard let newest = logs.first else { return nil }
        let cal = Calendar.current
        let daysAgo = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: newest.loggedAt),
            to: cal.startOfDay(for: today)
        ).day ?? 0
        let ema = WeightTrendChart.computeEMA(logs: logs)
        let established: Bool = {
            guard logs.count >= 3, let oldest = logs.last?.loggedAt else { return false }
            let span = cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: oldest),
                to: cal.startOfDay(for: newest.loggedAt)
            ).day ?? 0
            return span >= 5
        }()
        return .init(
            latestKg: newest.weightKg,
            latestAt: newest.loggedAt,
            latestSource: newest.source,
            lastWeighInDaysAgo: daysAgo,
            emaSeries: ema,
            emaDelta7dKg: emaDelta7d(ema),
            trendEstablished: established,
            isStalled: WeightAnalytics.isStalled(logs: logs, today: today),
            weeklyLossRate: WeightAnalytics.weeklyLossRate(logs: logs, today: today),
            isLosingTooFast: WeightAnalytics.isLosingTooFast(logs: logs, today: today),
            // `logs` is newest-first everywhere (the fetch order), so
            // the anchor is the last element, not the first.
            earliestKg: logs.last?.weightKg,
            earliestAt: logs.last?.loggedAt
        )
    }

    /// 7-day EMA delta (today's EMA minus the EMA 7 points back) —
    /// the canonical copy; TodayStateService delegates here.
    static func emaDelta7d(_ ema: [WeightTrendChart.EMAPoint]) -> Double? {
        guard ema.count >= 8 else { return nil }
        return ema[ema.count - 1].emaKg - ema[ema.count - 8].emaKg
    }

    /// The ledger's trend word (v9 P2, D1's whisper) — the canvas
    /// thresholds (±0.1 kg over the eased week), jeni's register.
    static func trendWord(deltaKg: Double?) -> String? {
        guard let delta = deltaKg else { return nil }
        if delta <= -0.1 { return "easing" }
        if delta >= 0.1 { return "up a little" }
        return "steady"
    }

    static func compositionRead(from vitals: VitalsService.Read) -> BodyState.Composition? {
        guard vitals.bodyFatPct != nil || vitals.leanMassKg != nil else { return nil }
        return .init(bodyFatPct: vitals.bodyFatPct,
                     leanMassKg: vitals.leanMassKg,
                     provenance: "apple health")
    }

    static func movementRead(
        weeklySteps: [Int],
        strengthSessionsLast7: Int,
        activeEnergyTodayKcal: Int?,
        distanceTodayKm: Double?
    ) -> BodyState.Movement? {
        let active = weeklySteps.filter { $0 > 0 }
        let hasAny = !active.isEmpty || strengthSessionsLast7 > 0
            || activeEnergyTodayKcal != nil || distanceTodayKm != nil
        guard hasAny else { return nil }
        let avg = active.isEmpty ? 0 : active.reduce(0, +) / active.count
        return .init(stepsWeekAvg: avg,
                     activeDaysLast7: active.count,
                     strengthSessionsLast7: strengthSessionsLast7,
                     activeEnergyTodayKcal: activeEnergyTodayKcal,
                     distanceTodayKm: distanceTodayKm)
    }
}
