import XCTest
@testable import PlankSync

// MARK: - PlanWireDateTests
//
// v25 pass 51 — A CIVIL DAY IS A FACT.
//
// `start_date` means "the calendar day she enrolled, where she was".
// This file pins the boundary that carries that fact: the wire string
// is the LOCAL civil date, and reparsing it anchors the SAME civil
// date in the local calendar — in California, New York, UTC and
// Tokyo; at breakfast and at midnight; across both DST transitions;
// and idempotently, so a second sync of the same row can never move
// the day again. The old boundary (UTC out, UTC-midnight in) fails
// most of these: a 10am Los Angeles enrollment reparsed to the
// PREVIOUS local day, which read as "day 6" where she was living
// day 5.

final class PlanWireDateTests: XCTestCase {

    private func cal(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    private func instant(
        _ zone: String, _ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0
    ) -> Date {
        cal(zone).date(from: DateComponents(
            year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func civilDay(_ date: Date, in zone: String) -> DateComponents {
        cal(zone).dateComponents([.year, .month, .day], from: date)
    }

    // MARK: - Serialization writes the LOCAL civil date

    /// The exact hours the UTC formatter got wrong: an evening west of
    /// UTC (LA 18:00 = next UTC day) and a morning east of it (Tokyo
    /// 08:00 = previous UTC day).
    func testTheWireStringIsTheLocalCivilDate() {
        XCTAssertEqual(
            PlanWireDate.wireString(
                from: instant("America/Los_Angeles", 2026, 8, 1, 18),
                calendar: cal("America/Los_Angeles")),
            "2026-08-01",
            "an 6pm LA enrollment is an Aug 1 enrollment; UTC already calls it Aug 2"
        )
        XCTAssertEqual(
            PlanWireDate.wireString(
                from: instant("Asia/Tokyo", 2026, 8, 1, 8),
                calendar: cal("Asia/Tokyo")),
            "2026-08-01",
            "an 8am Tokyo enrollment is an Aug 1 enrollment; UTC still calls it Jul 31"
        )
        XCTAssertEqual(
            PlanWireDate.wireString(
                from: instant("America/New_York", 2026, 8, 1, 22),
                calendar: cal("America/New_York")),
            "2026-08-01"
        )
        XCTAssertEqual(
            PlanWireDate.wireString(
                from: instant("UTC", 2026, 8, 1, 12), calendar: cal("UTC")),
            "2026-08-01"
        )
    }

    // MARK: - Reparsing anchors the SAME civil day locally

    func testReparsingAnchorsTheNamedDayInEveryZone() throws {
        for zone in ["America/Los_Angeles", "America/New_York", "UTC",
                     "Asia/Tokyo"] {
            let anchored = try XCTUnwrap(
                PlanWireDate.localDate(fromWire: "2026-08-01",
                                       calendar: cal(zone)))
            let day = civilDay(anchored, in: zone)
            XCTAssertEqual([day.year, day.month, day.day], [2026, 8, 1],
                           "zone \(zone) re-read the civil date as a different day")
        }
    }

    /// serialize → parse → serialize is a fixed point: once a plan has
    /// round-tripped, further syncs can never move its day again.
    func testTheRoundTripIsAFixedPointThreeTimesOver() throws {
        for zone in ["America/Los_Angeles", "America/New_York", "UTC",
                     "Asia/Tokyo"] {
            let calendar = cal(zone)
            var date = instant(zone, 2026, 8, 1, 10)
            var wires: [String] = []
            for _ in 0..<3 {
                let wire = PlanWireDate.wireString(from: date, calendar: calendar)
                wires.append(wire)
                date = try XCTUnwrap(
                    PlanWireDate.localDate(fromWire: wire, calendar: calendar))
            }
            XCTAssertEqual(Set(wires).count, 1,
                           "zone \(zone) drifted across round trips: \(wires)")
        }
    }

    // MARK: - DST

    /// 2026-03-08 has no 2am in the US: the spring-forward day itself
    /// must anchor to itself, not slide to a neighbor.
    func testTheSpringForwardDayAnchorsToItself() throws {
        let anchored = try XCTUnwrap(PlanWireDate.localDate(
            fromWire: "2026-03-08", calendar: cal("America/Los_Angeles")))
        let day = civilDay(anchored, in: "America/Los_Angeles")
        XCTAssertEqual([day.year, day.month, day.day], [2026, 3, 8])
    }

    /// 2026-11-01 has 25 hours in the US: same contract.
    func testTheFallBackDayAnchorsToItself() throws {
        let anchored = try XCTUnwrap(PlanWireDate.localDate(
            fromWire: "2026-11-01", calendar: cal("America/Los_Angeles")))
        let day = civilDay(anchored, in: "America/Los_Angeles")
        XCTAssertEqual([day.year, day.month, day.day], [2026, 11, 1])
    }

    // MARK: - Wire hygiene

    /// The wire format is ASCII yyyy-MM-dd regardless of the device's
    /// locale — a locale that renders its own numerals must never
    /// reach the column.
    func testTheWireStringIsLocaleProofASCII() {
        var arabic = cal("America/Los_Angeles")
        arabic.locale = Locale(identifier: "ar_SA")
        let wire = PlanWireDate.wireString(
            from: instant("America/Los_Angeles", 2026, 8, 1, 18),
            calendar: arabic
        )
        XCTAssertEqual(wire, "2026-08-01")
        XCTAssertTrue(wire.allSatisfy { $0.isASCII })
    }

    /// A timestamp where a date was expected takes its leading day; \
    /// garbage is nil, never a guessed date.
    func testToleranceAndRefusal() {
        XCTAssertNotNil(PlanWireDate.localDate(
            fromWire: "2026-08-01T00:00:00+00:00", calendar: cal("UTC")))
        XCTAssertNil(PlanWireDate.localDate(fromWire: "not-a-date",
                                            calendar: cal("UTC")))
        XCTAssertNil(PlanWireDate.localDate(fromWire: "",
                                            calendar: cal("UTC")))
    }
}
