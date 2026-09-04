import Foundation

// MARK: - ExpenditureRead (p79 — THE LEARNED BURN)
//
// The record finally learns the person: observed daily energy
// expenditure back-calculated from HER OWN logged intake against the
// canonical weight trend fold. This is the compounding fact two
// passes named as the product's biggest justified build (77 §4,
// 78 §6) — a year of honest use makes it MORE accurate, and no
// shipping GLP-1 product has it (79_evidence/r1).
//
// energy out ≈ energy in − energy stored
//   expenditure = mean logged intake − (Δtrend kg × ~7,700 kcal/kg
//                 ÷ window days)
// ρ = 7,700 kcal/kg is Hall 2011's ramp approximation — approximate
// by nature, which is one reason the output is a BAND, never a point.
//
// THE LAWS (from the research, each mapped to a failure mode):
//   · BAND OUTPUT ONLY — a point numeral manufactures precision the
//     arithmetic doesn't have (±150-200 kcal is the honest width).
//   · SILENCE OVER GUESSING — every gate that fails returns a named
//     silence, never a degraded estimate. The cold start speaks the
//     plan's formula, labeled as the plan's.
//   · THE UNDER-LOGGING DEATH SPIRAL dies structurally: a computed
//     burn below ~BMR means the intake record contradicts the scale
//     (days went unlogged, or plates went unpriced) — the read goes
//     silent instead of confidently wrong. It can therefore never
//     ratchet an under-eating customer downward.
//   · A DOSE CHANGE SPLITS THE WINDOW — a window straddling a fresh
//     dose change reads a mixture of two appetites; the read holds
//     ("early to read at this dose", the p74 titration vocabulary).
//   · PARTIAL DAYS are excluded by HER OWN distribution (a logged
//     day under half her median logged day is a fragment, not a
//     day) — never by an absolute calorie judgment, because on this
//     cohort a genuinely small day is the medication working.
//   · THE READ MOVES, THE TARGET DOES NOT — targets change only
//     through the weekly read's consent grammar (bounded, explained,
//     declinable; see WeeklyReadOffers.energyRecalc).
//   · Suppressed cohort ⇒ silent. No numerals, no exceptions.
//
// Pure and deterministic; the caller assembles inputs. Pinned by
// ExpenditureReadTests.

enum ExpenditureRead {

    // MARK: - Inputs

    /// One calendar day's logged intake (caller pre-reduces plates
    /// to day totals; days with zero plates are simply absent).
    struct DayIntake: Equatable {
        let day: Date
        let kcal: Double
        let plates: Int
        init(day: Date, kcal: Double, plates: Int) {
            self.day = day
            self.kcal = kcal
            self.plates = plates
        }
    }

    struct Inputs {
        /// Logged days, any span ≥ the window (extra history sharpens
        /// the partial-day median; only the trailing window is read).
        var days: [DayIntake]
        /// The canonical trend fold (WeightWeekReadEngine.trendSeries)
        /// — the ONE fold every spoken weight sentence derives from
        /// (the p74 law; this read joins it rather than growing a
        /// second smoother).
        var trend: [WeightWeekReadEngine.TrendPoint]
        /// The same engine's sufficiency word for the same samples.
        var sufficiency: WeightWeekRead.Sufficiency
        /// Raw weigh-in days inside the trailing window (density gate).
        var weighInDaysInWindow: Int
        /// Days since the newest dose-era boundary (nil = no
        /// medication regimen on record, or no era change ever).
        var daysSinceDoseChange: Int?
        /// Mifflin BMR for her current facts — the sanity floor that
        /// kills the death spiral. nil when height/weight are absent
        /// (the rail then falls back to an absolute floor).
        var bmrKcal: Int?
        /// Safety-gate numeric suppression (CohortStore) — silent.
        var numericsSuppressed: Bool
        var now: Date
        var calendar: Calendar = .current
    }

    // MARK: - Output

    struct Estimate: Equatable {
        /// The band, rounded to 25s. Presentation renders THE BAND;
        /// `centerKcal` exists for the weekly read's arithmetic only.
        let bandLowKcal: Int
        let bandHighKcal: Int
        let centerKcal: Int
        /// The derivation, for the trust sentence ("learned from 16
        /// logged days against your weigh-ins").
        let usableDays: Int
        let windowDays: Int
        let weighInsInWindow: Int
        /// Mean intake over usable days (under-fueling honesty).
        let intakeMeanKcal: Int
        /// Observed mass rate inside the window, kg/week (negative =
        /// losing). For the faster-than-plan proposal arithmetic.
        let weeklyMassDeltaKg: Double
    }

    enum Hold: Equatable {
        /// Era boundary younger than the titration floor — the p74
        /// vocabulary: "early to read at this dose."
        case doseChangeFresh(daysAtDose: Int)
        /// Last weigh-in too old for the fold to speak (>14 d).
        case trendStale
    }

    enum Silence: Equatable {
        case suppressed
        /// The trend fold cannot carry the window (insufficient /
        /// provisional sufficiency, or the series starts mid-window).
        case trendNotEstablished
        /// Fewer than `minWeighInsInWindow` weigh-in days in-window.
        case weighInsTooSparse(count: Int)
        /// Fewer than `minUsableDays` usable logged days, or a week
        /// inside the window with more than 3 missing days.
        case loggingTooSparse(usable: Int)
        /// The arithmetic contradicts itself (computed burn below
        /// ~BMR or implausibly high): days went unlogged or plates
        /// unpriced. Named so the surface can ask, never infer.
        case intakeInconsistent
    }

    enum Read: Equatable {
        case silent(Silence)
        case holding(Hold)
        case read(Estimate)
    }

    // MARK: - Parameters

    /// Trailing window. 21 days: long enough to average water noise
    /// (≤2-week regimes), short enough to track a real change.
    static let windowDays = 21
    /// Hall 2011 ramp approximation, kcal per kg of tissue change.
    static let kcalPerKg: Double = 7_700
    /// Usable-day floor across the window (⅔ of it).
    static let minUsableDays = 14
    /// Per-rolling-week floor (≤3 unlogged of any 7 — r1's gate).
    static let minUsablePerWeek = 4
    /// Weigh-in-day floor in-window (≈3 per week).
    static let minWeighInsInWindow = 9
    /// The titration floor (p74): a younger era never gets a rate.
    static let doseChangeFloorDays = 14
    /// A logged day under this fraction of her own median logged
    /// day is a fragment (excluded AND counted as a gap).
    static let partialDayFraction = 0.5
    /// Absolute fragment floor, for records too thin for a median.
    static let partialDayFloorKcal: Double = 400
    /// Band half-widths (kcal): tight at ≥18 usable days.
    static let bandHalfTight = 150
    static let bandHalfLoose = 200
    static let bandTightDays = 18
    /// Output rails: outside these the data is contradicting itself.
    static let railLowFractionOfBmr = 0.9
    static let railAbsoluteLow: Double = 1_000
    static let railAbsoluteHigh: Double = 4_500

    // MARK: - The read

    static func read(_ inputs: Inputs) -> Read {
        if inputs.numericsSuppressed { return .silent(.suppressed) }

        let cal = inputs.calendar
        let today = cal.startOfDay(for: inputs.now)

        // The trend must be able to speak at all…
        switch inputs.sufficiency {
        case .stale: return .holding(.trendStale)
        case .insufficient, .provisional: return .silent(.trendNotEstablished)
        case .established: break
        }
        // …and a fresh dose change splits the window.
        if let sinceChange = inputs.daysSinceDoseChange,
           sinceChange < doseChangeFloorDays {
            return .holding(.doseChangeFresh(daysAtDose: sinceChange))
        }
        guard inputs.weighInDaysInWindow >= minWeighInsInWindow else {
            return .silent(.weighInsTooSparse(count: inputs.weighInDaysInWindow))
        }

        guard let windowStart = cal.date(
            byAdding: .day, value: -(windowDays - 1), to: today
        ) else { return .silent(.trendNotEstablished) }

        // The fold must carry BOTH edges of the window (a series that
        // starts mid-window would read a shorter span as the whole).
        let trendByDay = Dictionary(
            inputs.trend.map { (cal.startOfDay(for: $0.day), $0.trendKg) },
            uniquingKeysWith: { first, _ in first }
        )
        guard let trendStart = trendByDay[windowStart],
              let trendEnd = trendByDay[today]
        else { return .silent(.trendNotEstablished) }

        // Day reduction: one row per calendar day, in-window.
        var byDay: [Date: DayIntake] = [:]
        for d in inputs.days {
            let day = cal.startOfDay(for: d.day)
            guard d.plates > 0, d.kcal > 0 else { continue }
            if let existing = byDay[day] {
                byDay[day] = DayIntake(
                    day: day, kcal: existing.kcal + d.kcal,
                    plates: existing.plates + d.plates
                )
            } else {
                byDay[day] = DayIntake(day: day, kcal: d.kcal, plates: d.plates)
            }
        }

        // HER OWN distribution decides what a fragment is — median
        // over every provided logged day (history included).
        let allKcal = byDay.values.map(\.kcal).sorted()
        let median: Double = allKcal.isEmpty ? 0 : allKcal[allKcal.count / 2]
        let fragmentFloor = max(partialDayFloorKcal, partialDayFraction * median)

        let windowDaysList: [Date] = (0..<windowDays).compactMap {
            cal.date(byAdding: .day, value: $0, to: windowStart)
        }
        let usable = windowDaysList.compactMap { day -> DayIntake? in
            guard let row = byDay[day], row.kcal >= fragmentFloor else { return nil }
            return row
        }

        // The per-week gap gate: any rolling third of the window with
        // more than 3 missing days poisons the mean (r1's ≤3-of-7).
        for weekIndex in 0..<(windowDays / 7) {
            let weekDays = windowDaysList
                .dropFirst(weekIndex * 7).prefix(7)
            let usableInWeek = weekDays.filter { day in
                guard let row = byDay[day] else { return false }
                return row.kcal >= fragmentFloor
            }.count
            if usableInWeek < minUsablePerWeek {
                return .silent(.loggingTooSparse(usable: usable.count))
            }
        }
        guard usable.count >= minUsableDays else {
            return .silent(.loggingTooSparse(usable: usable.count))
        }

        // The arithmetic.
        let meanIntake = usable.map(\.kcal).reduce(0, +) / Double(usable.count)
        let deltaKg = trendEnd - trendStart
        let dailyStorage = deltaKg * kcalPerKg / Double(windowDays - 1)
        let center = meanIntake - dailyStorage

        // The rails — outside them the record is contradicting the
        // scale, and silence beats a confident wrong number.
        let bmrRail = inputs.bmrKcal.map { Double($0) * railLowFractionOfBmr }
        let lowRail = max(railAbsoluteLow, bmrRail ?? railAbsoluteLow)
        guard center >= lowRail, center <= railAbsoluteHigh else {
            return .silent(.intakeInconsistent)
        }

        let half = usable.count >= bandTightDays ? bandHalfTight : bandHalfLoose
        func round25(_ v: Double) -> Int { Int((v / 25).rounded()) * 25 }

        return .read(Estimate(
            bandLowKcal: round25(center - Double(half)),
            bandHighKcal: round25(center + Double(half)),
            centerKcal: round25(center),
            usableDays: usable.count,
            windowDays: windowDays,
            weighInsInWindow: inputs.weighInDaysInWindow,
            intakeMeanKcal: round25(meanIntake),
            weeklyMassDeltaKg: (deltaKg / Double(windowDays - 1)) * 7
        ))
    }
}
