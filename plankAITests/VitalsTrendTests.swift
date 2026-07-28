import XCTest
@testable import plankAI

// VitalsTrend (docs/app_v7/04_CLINICAL_CHECKLIST.md §4 #2) — the
// resting-heart trend word. Pinned law: her own 30-day baseline is
// the ONLY reference (never population norms), ±2 bpm reads steady,
// 3+ under eases, 3+ over climbs, and a missing baseline shows the
// bare number (no fabricated trend — data-provenance rule).

final class VitalsTrendTests: XCTestCase {

    func testWithinTwoOfBaselineReadsSteady() {
        XCTAssertEqual(VitalsTrend.word(current: 64, baseline: 64), "steady")
        XCTAssertEqual(VitalsTrend.word(current: 66, baseline: 64), "steady")
        XCTAssertEqual(VitalsTrend.word(current: 62, baseline: 64), "steady")
    }

    func testThreeUnderReadsEasing() {
        XCTAssertEqual(VitalsTrend.word(current: 61, baseline: 64), "easing")
        XCTAssertEqual(VitalsTrend.word(current: 50, baseline: 64), "easing")
    }

    func testThreeOverReadsClimbing() {
        // The GLP-1 class effect (+1-4 bpm) surfaces here — as an
        // observation word, never an alert.
        XCTAssertEqual(VitalsTrend.word(current: 67, baseline: 64), "climbing")
        XCTAssertEqual(VitalsTrend.word(current: 80, baseline: 64), "climbing")
    }

    func testLedgerValueCarriesTrendWordWithBaseline() {
        XCTAssertEqual(VitalsTrend.ledgerValue(current: 62, baseline: 64), "62 · steady")
        XCTAssertEqual(VitalsTrend.ledgerValue(current: 58, baseline: 64), "58 · easing")
    }

    func testFormingBaselineShowsBareNumber() {
        XCTAssertEqual(VitalsTrend.ledgerValue(current: 62, baseline: nil), "62")
        XCTAssertEqual(VitalsTrend.ledgerValue(current: 62, baseline: 0), "62")
    }
}
