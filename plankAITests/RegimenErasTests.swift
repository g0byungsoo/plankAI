import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - RegimenErasTests (app v25 pass 58)
//
// One era arithmetic for the version chain. Three consumers derived
// eras independently and all three miscounted a SCHEDULE-only change
// as a dose change (schedule versions inherit startedAt by
// RegimenService's own rule, so the old `previousPlanId != nil`
// filter also minted two "eras" at one strength sharing one start).
//
// RED: testAScheduleChangeIsNotADoseEraInTheEnvelope ran against the
// shipped read_dose_history (era_count == history.count) and failed
// with 2 where the truth is 1. The pure-engine table is new law,
// pinned at birth and stated as such.

@MainActor
final class RegimenErasTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func v(
        start: Date, end: Date? = nil, mg: Double?, created: Date? = nil
    ) -> RegimenEras.Version {
        .init(startedAt: start, endedAt: end, strengthValue: mg,
              strengthUnit: mg == nil ? nil : "mg", createdAt: created)
    }

    // MARK: - The real consumer (RED against the shipped envelope)

    func testAScheduleChangeIsNotADoseEraInTheEnvelope() {
        let context = TestModelContainer.shared.mainContext
        let userId = "p58-era-\(UUID().uuidString)"

        // aug 1: ozempic 1 mg, weekly (wednesdays).
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "ozempic"
        spec.displayName = "ozempic"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = 4
        spec.doseValue = 1.0
        _ = RegimenService.applySelfRegimen(
            spec, userId: userId, now: day(2026, 8, 1), in: context
        )

        // aug 10: same 1 mg, but the rhythm becomes every 10 days —
        // a schedule change, not a dose change.
        spec.scheduleRule = "intervalDays"
        spec.anchorWeekday = nil
        spec.intervalDays = 10
        spec.anchorDayKey = "2026-08-10"
        _ = RegimenService.applySelfRegimen(
            spec, userId: userId, now: day(2026, 8, 10), in: context
        )

        let result = JeniReadTools.execute(
            .init(id: "t", name: "read_dose_history", arguments: [:]),
            userId: userId, in: context
        )

        XCTAssertEqual(
            result["era_count"] as? Int, 1,
            "two versions at ONE strength are one dose era; a schedule change must not read as a dose change to the model"
        )
    }

    // MARK: - The engine table (new law, pinned at birth)

    func testConsecutiveSameStrengthVersionsMergeIntoOneEra() {
        let versions = [
            v(start: day(2026, 8, 1), end: day(2026, 8, 10), mg: 1.0),
            v(start: day(2026, 8, 1), end: nil, mg: 1.0, created: day(2026, 8, 10)),
        ]
        let eras = RegimenEras.eras(versions)
        XCTAssertEqual(eras.count, 1)
        XCTAssertEqual(eras[0].startedAt, day(2026, 8, 1))
        XCTAssertNil(eras[0].endedAt, "the merged era is current")
        XCTAssertEqual(RegimenEras.doseChangeDays(versions, calendar: cal), [])
    }

    func testARealStrengthMoveOpensANewEra() {
        let versions = [
            v(start: day(2026, 8, 1), end: day(2026, 9, 1), mg: 0.5),
            v(start: day(2026, 9, 1), end: nil, mg: 1.0),
        ]
        let eras = RegimenEras.eras(versions)
        XCTAssertEqual(eras.count, 2)
        XCTAssertEqual(eras[1].strengthValue, 1.0)
        XCTAssertEqual(
            RegimenEras.doseChangeDays(versions, calendar: cal),
            ["2026-09-01"]
        )
    }

    func testAReturnToAnEarlierDoseIsItsOwnEra() {
        // 0.5 → 1.0 → 0.5: three eras, two changes. Non-adjacent
        // same-strength spans never merge — she really went back.
        let versions = [
            v(start: day(2026, 6, 1), end: day(2026, 7, 1), mg: 0.5),
            v(start: day(2026, 7, 1), end: day(2026, 8, 1), mg: 1.0),
            v(start: day(2026, 8, 1), end: nil, mg: 0.5),
        ]
        XCTAssertEqual(RegimenEras.eras(versions).count, 3)
        XCTAssertEqual(
            RegimenEras.doseChangeDays(versions, calendar: cal),
            ["2026-07-01", "2026-08-01"]
        )
    }

    func testAnUnknownStrengthNeverClaimsAChange() {
        // A version with no stated dose breaks the run but is not a
        // "change" in either direction — unknown is never a fact.
        let versions = [
            v(start: day(2026, 8, 1), end: day(2026, 8, 15), mg: 1.0),
            v(start: day(2026, 8, 15), end: day(2026, 9, 1), mg: nil),
            v(start: day(2026, 9, 1), end: nil, mg: 1.0),
        ]
        XCTAssertEqual(RegimenEras.eras(versions).count, 3)
        XCTAssertEqual(RegimenEras.doseChangeDays(versions, calendar: cal), [])
    }

    func testInputOrderDoesNotMatter() {
        // medicationHistory hands versions newest-first; the engine
        // orders by the chain itself.
        let newestFirst = [
            v(start: day(2026, 9, 1), end: nil, mg: 1.0),
            v(start: day(2026, 8, 1), end: day(2026, 9, 1), mg: 0.5),
        ]
        XCTAssertEqual(
            RegimenEras.doseChangeDays(newestFirst, calendar: cal),
            ["2026-09-01"]
        )
    }
}
