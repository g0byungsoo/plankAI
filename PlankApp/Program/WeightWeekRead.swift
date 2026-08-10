import Foundation

// MARK: - WeightWeekRead (v25 E2 — B7)
//
// The statistically defensible weight read for THE WEEKLY READ —
// the decision doc's loudest hole ("a weight-loss app's weekly
// ritual never mentions weight") closed without manufacturing
// precision. Pure; the caller hands in dated samples (manual +
// HealthKit, onboarding rows excluded upstream).
//
// The science this encodes (research pass 2026-08-10, sources in
// 10_E2_EVIDENCE):
// - day-to-day water noise is ~0.5% of body mass (glycogen/sodium),
//   so a single weigh-in NEVER supports a direction word;
// - the trend is a TIME-AWARE exponential average (Eckner form,
//   half-life ≈ 6.6 d, the Hacker's-Diet α=0.1/day lineage) — gaps
//   decay trust instead of fabricating interpolated days;
// - an innovation clamp (±1.6% of trend per observation, ≈3σ of
//   daily noise) absorbs spikes and probable unit errors;
// - direction words need the weekly trend delta to clear a noise
//   band (±0.25% BM, floor 0.2 kg) AND enough data to be honest:
//   4 obs spanning 14 d = provisional · 10 obs spanning 28 d =
//   established · last obs >14 d old = stale (bands are withheld,
//   never extrapolated).
//
// What this deliberately does NOT do: predict, project, grade, or
// dominate — a silent record reads as silence, and "holding steady"
// is a plateau-normal fact, never a failure word.

struct WeightWeekRead: Equatable {
    enum Band: String, Equatable {
        case trendingDown = "trending_down"
        case holdingSteady = "holding_steady"
        case driftingUp = "drifting_up"
    }
    enum Sufficiency: String, Equatable {
        case insufficient   // too few samples / too short a span
        case provisional    // ≥4 obs spanning ≥14 d (last 28 d window)
        case established    // ≥10 obs spanning ≥28 d (last 60 d window)
        case stale          // last obs >14 d old — no band, ever
    }

    /// The smoothed trend at the latest observation, kg.
    let trendKg: Double?
    /// trend(now) − trend(a week before the latest obs), kg.
    let weeklyDeltaKg: Double?
    /// nil unless sufficiency is provisional/established.
    let band: Band?
    let sufficiency: Sufficiency
    /// Observations that survived sanity gates, full window.
    let sampleCount: Int
    let lastSampleDaysAgo: Int?
}

enum WeightWeekReadEngine {

    /// One observation — callers pre-reduce to one sample per
    /// calendar day (earliest of the day, the fasted-morning bias
    /// the fluctuation literature assumes).
    struct Sample: Equatable {
        let day: Date
        let kg: Double
        init(day: Date, kg: Double) {
            self.day = day
            self.kg = kg
        }
    }

    /// Half-life ≈ 6.6 days → τ = 9.5 (α = 0.1/day convention).
    static let tauDays: Double = 9.5
    /// Per-observation innovation clamp, fraction of trend (≈3σ).
    static let innovationClamp: Double = 0.016
    /// Direction band: ±0.25% BM per week, absolute floor 0.2 kg.
    static let bandFractionPerWeek: Double = 0.0025
    static let bandFloorKg: Double = 0.2

    static func read(
        samples rawSamples: [Sample],
        now: Date,
        calendar: Calendar = .current
    ) -> WeightWeekRead {
        let today = calendar.startOfDay(for: now)

        // Sanity + order: plausible humans only, oldest first, one
        // per day (first wins — callers usually pre-reduce).
        var seen = Set<Date>()
        let samples = rawSamples
            .filter { $0.kg > 25 && $0.kg < 300 && $0.day <= now }
            .sorted { $0.day < $1.day }
            .filter { seen.insert(calendar.startOfDay(for: $0.day)).inserted }

        guard let latest = samples.last else {
            return WeightWeekRead(
                trendKg: nil, weeklyDeltaKg: nil, band: nil,
                sufficiency: .insufficient, sampleCount: 0,
                lastSampleDaysAgo: nil
            )
        }

        let lastDaysAgo = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: latest.day), to: today
        ).day ?? 0

        // The time-aware EMA fold. A probable unit error (ratio to
        // the running trend ≈ ×2.2 or ≈ ÷2.2 — kg-vs-lb entry) is
        // skipped entirely; other spikes are clamped, not believed.
        func trend(upTo cutoff: Date) -> Double? {
            var trend: Double?
            var lastDay: Date?
            for s in samples where s.day <= cutoff {
                guard let prior = trend, let prev = lastDay else {
                    trend = s.kg
                    lastDay = s.day
                    continue
                }
                let ratio = s.kg / prior
                if (2.0...2.4).contains(ratio) || (0.42...0.5).contains(ratio) {
                    continue   // probable lb/kg entry error
                }
                let dt = max(1.0, Double(calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: prev),
                    to: calendar.startOfDay(for: s.day)
                ).day ?? 1))
                let k = 1 - exp(-dt / tauDays)
                let innovation = s.kg - prior
                // The clamp widens with the gap (a real month can
                // move real kilograms) but never past a week's worth
                // — a wild value after a long silence is still a
                // wild value.
                let clamp = innovationClamp * prior * min(dt, 7.0)
                trend = prior + k * min(max(innovation, -clamp), clamp)
                lastDay = s.day
            }
            return trend
        }

        let trendNow = trend(upTo: latest.day)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: latest.day)
        let trendWeekAgo = weekAgo.flatMap { trend(upTo: $0) }
        let weeklyDelta = zip2(trendNow, trendWeekAgo).map { $0 - $1 }

        // Sufficiency floors.
        let window28 = calendar.date(byAdding: .day, value: -28, to: today)!
        let window60 = calendar.date(byAdding: .day, value: -60, to: today)!
        let recent28 = samples.filter { $0.day >= window28 }
        let recent60 = samples.filter { $0.day >= window60 }
        func spanDays(_ list: [Sample]) -> Int {
            guard let f = list.first, let l = list.last else { return 0 }
            return calendar.dateComponents(
                [.day], from: f.day, to: l.day
            ).day ?? 0
        }

        let sufficiency: WeightWeekRead.Sufficiency
        if lastDaysAgo > 14 {
            sufficiency = .stale
        } else if recent60.count >= 10, spanDays(recent60) >= 28 {
            sufficiency = .established
        } else if recent28.count >= 4, spanDays(recent28) >= 14 {
            sufficiency = .provisional
        } else {
            sufficiency = .insufficient
        }

        // The band, only where honesty allows.
        var band: WeightWeekRead.Band?
        if sufficiency == .provisional || sufficiency == .established,
           let delta = weeklyDelta, let t = trendNow {
            let threshold = max(bandFractionPerWeek * t, bandFloorKg)
            if delta <= -threshold { band = .trendingDown }
            else if delta >= threshold { band = .driftingUp }
            else { band = .holdingSteady }
        }

        return WeightWeekRead(
            trendKg: trendNow,
            weeklyDeltaKg: weeklyDelta,
            band: band,
            sufficiency: sufficiency,
            sampleCount: samples.count,
            lastSampleDaysAgo: lastDaysAgo
        )
    }

    private static func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
        guard let a, let b else { return nil }
        return (a, b)
    }
}
