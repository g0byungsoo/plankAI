import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - WidgetSnapshotTests (app v25 pass 58)
//
// The widget renders in a separate process from every law it must
// obey, so the laws cross the boundary as a precomposed snapshot
// (JeniWidgetSnapshot, dual-membered). These tests hold the two
// sides together:
//
//   · the words the widget composes must EQUAL the band's own
//     grammar (HomeNutritionSummary.energyReferenceLine) input for
//     input — the count-up cohort never reads "over" on the Home
//     Screen either, maintenance holds, suppression publishes no
//     numerals;
//   · the widget's civil-day question uses the app's own dayKey
//     grammar, pinned equal;
//   · a later day renders the fresh-day state — yesterday's numbers
//     are never presented as today's;
//   · the dose line keeps DoseStanding's discretion (no product, no
//     amount) and a skipped day stays HER business.
//
// New law at a new seam — pinned at birth, stated as such.

@MainActor
final class WidgetSnapshotTests: XCTestCase {

    private func snap(
        eaten: Int = 1660, target: Int? = 1473,
        countUp: Bool = false, maintenance: Bool = false,
        suppressed: Bool = false,
        protein: Int = 96, floor: Int? = 120,
        dose: String? = nil
    ) -> JeniWidgetSnapshot {
        JeniWidgetSnapshot(
            dayKey: JeniWidgetSnapshot.dayKey(),
            generatedAt: .now,
            proteinEatenG: protein,
            proteinFloorG: floor,
            kcalEaten: eaten,
            kcalTarget: target,
            plateCount: 3,
            countUpOnly: countUp,
            isMaintenance: maintenance,
            numericsSuppressed: suppressed,
            doseLine: dose
        )
    }

    // MARK: - One grammar on both sides of the process boundary

    func testTheDayReferenceEqualsTheBandsOwnGrammar() {
        let grid: [(eaten: Int, target: Int?, maintenance: Bool, countUp: Bool)] = [
            (1660, 1473, false, false),   // over, weight-loss
            (1660, 1473, false, true),    // over, on-medication
            (900, 1473, false, false),    // left
            (1473, 1473, false, false),   // right on it
            (1660, 1473, true, false),    // maintenance holds
            (1660, nil, false, false),    // no target
            (0, 0, false, false),         // degenerate target
        ]
        for row in grid {
            let widget = snap(
                eaten: row.eaten, target: row.target,
                countUp: row.countUp, maintenance: row.maintenance
            ).dayReference
            let band = HomeNutritionSummary.energyReferenceLine(
                targetKcal: row.target, eatenKcal: row.eaten,
                isMaintenance: row.maintenance, countUpOnly: row.countUp
            )
            XCTAssertEqual(
                widget, band,
                "the Home Screen and Home must speak identically for eaten=\(row.eaten) target=\(String(describing: row.target)) maintenance=\(row.maintenance) countUp=\(row.countUp)"
            )
        }
    }

    func testTheCountUpCohortNeverReadsOverOnTheHomeScreen() {
        let line = snap(eaten: 2010, target: 1473, countUp: true).dayReference
        XCTAssertEqual(line, "of 1,473 kcal")
        XCTAssertFalse((line ?? "").contains("over"))
    }

    func testSuppressionPublishesNoNumerals() {
        let s = snap(suppressed: true)
        XCTAssertNil(s.proteinReading)
        XCTAssertNil(s.dayReference)
    }

    func testTheProteinReadingSpeaksTheFloorGrammar() {
        XCTAssertEqual(snap(protein: 96, floor: 120).proteinReading, "24 g to the floor")
        XCTAssertEqual(snap(protein: 123, floor: 120).proteinReading, "floor met")
        XCTAssertNil(snap(floor: nil).proteinReading)
    }

    // MARK: - The civil day

    func testTheDayKeyGrammarIsTheAppsOwn() {
        let dates = [Date.now, Date.now.addingTimeInterval(86_400 * 30),
                     Date(timeIntervalSince1970: 1_700_000_000)]
        for d in dates {
            XCTAssertEqual(
                JeniWidgetSnapshot.dayKey(for: d), TodayStateService.dayKey(for: d),
                "two dayKey grammars would fork the widget's midnight"
            )
        }
    }

    func testALaterDayRendersFreshNotYesterday() {
        let yesterday = snap(eaten: 1660, protein: 96, dose: "shot today")
        let fresh = yesterday.freshDay(as: "2026-08-26")
        XCTAssertEqual(fresh.dayKey, "2026-08-26")
        XCTAssertEqual(fresh.kcalEaten, 0)
        XCTAssertEqual(fresh.proteinEatenG, 0)
        XCTAssertEqual(fresh.plateCount, 0)
        XCTAssertNil(fresh.doseLine, "the app has not spoken for the new day")
        XCTAssertEqual(fresh.proteinFloorG, 120, "targets stand")
        XCTAssertEqual(fresh.kcalTarget, 1473, "targets stand")
    }

    // MARK: - The dose line's discretion

    func testTheDoseLineKeepsItsDiscretion() {
        XCTAssertEqual(WidgetBridge.doseLine(.dueToday), "shot today")
        XCTAssertEqual(WidgetBridge.doseLine(.doneToday(site: "left thigh")), "shot · done")
        XCTAssertEqual(
            WidgetBridge.doseLine(.upcoming(days: 3, weekday: "thursday")),
            "next shot thursday"
        )
        XCTAssertEqual(WidgetBridge.doseLine(.upcoming(days: 1, weekday: "wednesday")),
                       "shot tomorrow")
        XCTAssertNil(WidgetBridge.doseLine(.skippedToday),
                     "a skipped day stays her business on the most public surface")
        XCTAssertNil(WidgetBridge.doseLine(nil))
        // The site never travels — the words above are the whole
        // vocabulary; no case can emit a product name or an amount
        // because no case receives one.
    }

    // MARK: - Round trip

    func testTheSnapshotRoundTripsThroughItsStore() throws {
        let original = snap(dose: "shot today")
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(JeniWidgetSnapshot.self, from: data)
        XCTAssertEqual(back, original)
    }
}
