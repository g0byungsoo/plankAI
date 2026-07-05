import Foundation
import PlankSync

// MARK: - BandModel (app v3 phase 4 — the keeping chapter's spine)
//
// The STOP Regain three-zone architecture (Wing 2006 NEJM; validated
// in women 18-35 by SNAP, JAMA Intern Med 2016), renamed into this
// brand's register: steady / drifting / reset week. Zones read the
// EMA — never the raw morning number — around her settle weight.
//
// The null-trial law (NULevel / LIMIT / NoHoW): a zone crossing must
// OPEN an action (a reading thread, a steadying plan, a conversation)
// — never an alert alone. Consumers: the reading (threads), the
// weight ritual (kept whisper), Becoming (band field), notifications
// (phase 7). Research: docs/app_v3/research/GLP1_RESEARCH_2026_07_05.md.
//
// Honesty floor: the evidence base is behavioral-loss maintenance;
// post-medication regain runs faster, so we WATCH sooner (the
// drifting zone opens at ~1.4 kg) and never claim the system is
// clinically validated for the post-medication case.

enum BandZone: String, Equatable {
    /// At or under the settle weight — holding (under is not a prize;
    /// adequacy language guards the floor).
    case steady
    /// ~3-5 lb over settle: the watch window — deploy a steadying
    /// week BEFORE the documented ~4 kg procrastination point.
    case drifting
    /// 5+ lb over settle: the supported reset arc, framed as care.
    case reset
}

enum BandModel {

    /// Zone thresholds over settle weight (kg). ~3 lb / ~5 lb —
    /// the STOP Regain lines.
    static let driftingAtKg = 1.4
    static let resetAtKg = 2.3

    static let settleKey = "band.settleWeightKg"
    static let lastZoneKey = "band.lastZone"

    /// Her settle weight: an explicit choice when she's named one,
    /// else the weight her maintenance plan was built on (the
    /// enrollment weight IS the settle weight for a keeping-chapter
    /// plan). nil = no band yet (canvas invites instead).
    static func settleWeightKg(
        plan: ProgramPlanRecord?, _ d: UserDefaults = .standard
    ) -> Double? {
        let explicit = d.double(forKey: settleKey)
        if explicit > 30 { return explicit }
        guard CohortStore.isMaintenanceMode else { return nil }
        if let kg = plan?.currentWeightKg, kg > 30 { return kg }
        return nil
    }

    /// Pure zone math over the smoothed trend. Delta rounds to
    /// centigrams so threshold comparisons never ride float error
    /// (72.3 − 70.0 must BE 2.30, not 2.2999…).
    static func zone(emaKg: Double, settleKg: Double) -> BandZone {
        let over = ((emaKg - settleKg) * 100).rounded() / 100
        if over >= resetAtKg { return .reset }
        if over >= driftingAtKg { return .drifting }
        return .steady
    }

    /// Detect a crossing (returns the new zone when it CHANGED since
    /// the last stored zone; nil when unchanged). Store-and-compare
    /// so a crossing surfaces exactly once per transition.
    static func consumeCrossing(
        newZone: BandZone, _ d: UserDefaults = .standard
    ) -> BandZone? {
        let last = d.string(forKey: lastZoneKey)
        d.set(newZone.rawValue, forKey: lastZoneKey)
        guard let last else { return nil }          // first read = baseline
        return last == newZone.rawValue ? nil : newZone
    }

    /// A kept maintenance week: she weighed at least once, showed up
    /// most days, and the trend held inside the band. Consistency is
    /// the score — never the raw number (Brockmann 2020: the weighing
    /// PATTERN predicts regain, not frequency).
    static func weekIsKept(
        weighDays: Int, presenceDays: Int, zone: BandZone
    ) -> Bool {
        weighDays >= 1 && presenceDays >= 3 && zone == .steady
    }
}
