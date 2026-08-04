import XCTest
@testable import plankAI

// BodyChangeRead (v9 P2) — the floor-gated change language + the
// internal compare transform. Pinned laws: ≥2 scans, ≥28-day span,
// quality ≥0.5 at both ends, established trend agreement; a rising
// trend never blames the mirror; no number ever surfaces from a
// photo (the lines are words, the transform is internal).

final class BodyChangeReadTests: XCTestCase {

    private func scan(daysAgo: Int, quality: Double = 0.9) -> BodyChangeRead.ScanMeta {
        .init(
            capturedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            poseQuality: quality
        )
    }

    func testNoScansNoLine() {
        XCTAssertNil(BodyChangeRead.line(
            scans: [], trendEstablished: false, trendDeltaKg: nil))
    }

    func testOneScanInvitesTheSecond() {
        XCTAssertEqual(
            BodyChangeRead.line(scans: [scan(daysAgo: 0)],
                                trendEstablished: true, trendDeltaKg: -0.4),
            "one scan kept. the next one starts the comparison."
        )
    }

    func testShortSpanNamesTheWeek() {
        let line = BodyChangeRead.line(
            scans: [scan(daysAgo: 0), scan(daysAgo: 10)],
            trendEstablished: true, trendDeltaKg: -0.4
        )
        XCTAssertEqual(line, "week 1 of your record. four weeks apart draws real change.")
    }

    func testLowQualityEndFailsTheFloorHonestly() {
        let line = BodyChangeRead.line(
            scans: [scan(daysAgo: 0, quality: 0.2), scan(daysAgo: 30)],
            trendEstablished: true, trendDeltaKg: -0.4
        )
        XCTAssertEqual(line, "keep scans full-figure — the record compares best that way.")
    }

    func testAgreementNeedsTheEstablishedEasingTrend() {
        let scans = [scan(daysAgo: 0), scan(daysAgo: 30)]
        XCTAssertEqual(
            BodyChangeRead.line(scans: scans, trendEstablished: true, trendDeltaKg: -0.4),
            "4 weeks in — the line and the mirror agree."
        )
        XCTAssertEqual(
            BodyChangeRead.line(scans: scans, trendEstablished: false, trendDeltaKg: -0.4),
            "4 weeks of evidence, kept."
        )
    }

    func testClimbingTrendNeverBlamesTheMirror() {
        let line = BodyChangeRead.line(
            scans: [scan(daysAgo: 0), scan(daysAgo: 35)],
            trendEstablished: true, trendDeltaKg: 0.5
        )
        XCTAssertEqual(line, "5 weeks of record. the mirror holds what the scale can't say.")
    }

    // MARK: - Transform

    func testMissingAnchorsYieldIdentity() {
        XCTAssertEqual(
            BodyChangeRead.transform(then: nil, now: nil),
            .identity
        )
    }

    func testEqualAnchorsYieldIdentity() {
        let a = BodyChangeRead.Anchors(top: 0.9, bottom: 0.1, centerX: 0.5)
        let t = BodyChangeRead.transform(then: a, now: a)
        XCTAssertEqual(t.scale, 1, accuracy: 0.001)
        XCTAssertEqual(t.offsetXNorm, 0, accuracy: 0.001)
        XCTAssertEqual(t.offsetYNorm, 0, accuracy: 0.001)
    }

    func testSmallerThenScalesUpToMatch() {
        let then = BodyChangeRead.Anchors(top: 0.85, bottom: 0.15, centerX: 0.5)
        let now = BodyChangeRead.Anchors(top: 0.9, bottom: 0.1, centerX: 0.5)
        let t = BodyChangeRead.transform(then: then, now: now)
        XCTAssertEqual(t.scale, CGFloat(0.8 / 0.7), accuracy: 0.001)
    }

    func testExtremeScaleClamps() {
        let tiny = BodyChangeRead.Anchors(top: 0.55, bottom: 0.45, centerX: 0.5)
        let full = BodyChangeRead.Anchors(top: 0.95, bottom: 0.05, centerX: 0.5)
        XCTAssertEqual(BodyChangeRead.transform(then: tiny, now: full).scale, 1.25)
        XCTAssertEqual(BodyChangeRead.transform(then: full, now: tiny).scale, 0.8)
    }
}
