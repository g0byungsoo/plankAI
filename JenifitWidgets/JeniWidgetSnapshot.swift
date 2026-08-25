import Foundation

// MARK: - JeniWidgetSnapshot (app v25 pass 58)
//
// THE CONTRACT BETWEEN THE APP AND THE HOME SCREEN. The app is the
// only writer (WidgetBridge, at the same launch/foreground chokepoint
// that refreshes cohort identity, plus record events); the widget
// extension is the only reader. Everything the widget shows is
// PRECOMPOSED here from the same engines the surfaces render from —
// the widget process never opens the store, never derives arithmetic,
// and can therefore never disagree with Home.
//
// Dual-membered into the app target and JenifitWidgets (the
// ScanActivityAttributes precedent): one file, one words law.
//
// The laws this file carries across the process boundary:
//   · the count-up grammar — the on-medication cohort NEVER reads
//     "over" (p53, Home + the reading since p57, the widget now);
//   · maintenance reads "holding", never a remainder;
//   · numeric suppression publishes NO numerals at all;
//   · the dose line follows DoseStanding's discretion — never a
//     product name, never a dose amount (the Home Screen is the most
//     public surface the product has);
//   · a snapshot speaks only for its own civil day: the reader
//     compares `dayKey` and renders the fresh-day state rather than
//     yesterday's numbers.

struct JeniWidgetSnapshot: Codable, Equatable {

    /// The civil day the numbers describe ("2026-08-25", pinned
    /// Gregorian/ASCII in the local zone — TodayStateService.dayKey's
    /// exact grammar; `dayKey(for:)` below is the one formatter both
    /// processes use).
    var dayKey: String
    var generatedAt: Date

    var proteinEatenG: Int
    /// nil = no floor on file (no weight yet) — the ring stays away.
    var proteinFloorG: Int?
    var kcalEaten: Int
    var kcalTarget: Int?
    var plateCount: Int

    var countUpOnly: Bool
    var isMaintenance: Bool
    var numericsSuppressed: Bool

    /// Already-worded standing ("shot today" / "marked today" /
    /// "next shot in 3 days") — or nil for the unmedicated and for
    /// any day the app has not spoken for.
    var doseLine: String?

    // MARK: - The store (App Group)

    static let suiteName = "group.com.bk.plankAI"
    static let storeKey = "widget.today.v1"

    static func read() -> JeniWidgetSnapshot? {
        guard let d = UserDefaults(suiteName: suiteName),
              let data = d.data(forKey: storeKey)
        else { return nil }
        return try? JSONDecoder().decode(JeniWidgetSnapshot.self, from: data)
    }

    func write() {
        guard let d = UserDefaults(suiteName: Self.suiteName),
              let data = try? JSONEncoder().encode(self)
        else { return }
        d.set(data, forKey: Self.storeKey)
    }

    static func clear() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: storeKey)
    }

    // MARK: - The day grammar (one formatter, both processes)

    /// TodayStateService.dayKey's implementation, reproduced verbatim
    /// so the widget's "is this still today?" question uses the app's
    /// own calendar law (p51: pinned Gregorian, ASCII digits, local
    /// zone). Pinned equal by WidgetSnapshotTests.
    static func dayKey(for date: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
    }

    /// The snapshot as a LATER civil day will truthfully see it:
    /// nothing eaten yet, targets standing, the dose line silent
    /// (the app has not spoken for that day).
    func freshDay(as newDayKey: String) -> JeniWidgetSnapshot {
        var s = self
        s.dayKey = newDayKey
        s.proteinEatenG = 0
        s.kcalEaten = 0
        s.plateCount = 0
        s.doseLine = nil
        return s
    }

    // MARK: - The words (mirrors HomeSections' band laws)

    /// "23 g to the floor" / "floor met" — HomeSections.proteinState's
    /// two-register read, without the tail line.
    var proteinReading: String? {
        guard !numericsSuppressed, let floor = proteinFloorG, floor > 0
        else { return nil }
        let left = floor - proteinEatenG
        return left > 0 ? "\(left) g to the floor" : "floor met"
    }

    /// "of 1,473 kcal · 187 left" — HomeSections.energyReferenceLine's
    /// law verbatim: maintenance holds, the count-up cohort never
    /// reads "over", zero is "right on it".
    var dayReference: String? {
        guard !numericsSuppressed, let kcal = kcalTarget, kcal > 0
        else { return nil }
        let base = "of \(kcal.formatted()) kcal"
        if isMaintenance { return base + " · holding" }
        let diff = kcal - kcalEaten
        if diff > 0 { return base + " · \(diff.formatted()) left" }
        if diff < 0 {
            return countUpOnly ? base : base + " · \((-diff).formatted()) over"
        }
        return base + " · right on it"
    }
}
