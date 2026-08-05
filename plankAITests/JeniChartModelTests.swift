import XCTest
@testable import plankAI

// v11 T2 — the pure geometry core of JeniChart
// (docs/app_v11/00_REBIRTH.md §5, 01_PLAN.md Task 2).
final class JeniChartModelTests: XCTestCase {

    private let size = CGSize(width: 300, height: 100)

    // MARK: - emptiness

    func testEmptyModelFlagsEmpty() {
        let m = JeniChartModel(form: .line, series: [])
        XCTAssertTrue(m.isEmpty)

        let allNil = JeniChartModel(form: .line, series: [
            .init(values: [nil, nil, nil], role: .ink)
        ])
        XCTAssertTrue(allNil.isEmpty)
    }

    // MARK: - flat + single values never explode

    func testFlatSeriesCentersVertically() {
        let m = JeniChartModel(form: .line, series: [
            .init(values: [5, 5, 5, 5], role: .ink)
        ])
        let segs = m.points(seriesIndex: 0, in: size)
        XCTAssertEqual(segs.count, 1)
        for p in segs[0] {
            XCTAssertEqual(p.y, size.height / 2, accuracy: 0.5)
            XCTAssertFalse(p.y.isNaN)
        }
    }

    func testSingleValueRendersOnePointWithoutNaN() {
        let m = JeniChartModel(form: .line, series: [
            .init(values: [162.4], role: .ink)
        ])
        let segs = m.points(seriesIndex: 0, in: size)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs[0].count, 1)
        XCTAssertFalse(segs[0][0].x.isNaN)
        XCTAssertFalse(segs[0][0].y.isNaN)
    }

    // MARK: - gaps are honest (L8): nil splits, never bridges

    func testNilGapSplitsLineIntoSegments() {
        let m = JeniChartModel(form: .line, series: [
            .init(values: [1, 2, nil, 4, 5], role: .ink)
        ])
        let segs = m.points(seriesIndex: 0, in: size)
        XCTAssertEqual(segs.count, 2, "a gap must split the stroke, never be interpolated across")
        XCTAssertEqual(segs[0].count, 2)
        XCTAssertEqual(segs[1].count, 2)
    }

    func testBarRectsPreserveNilSlots() {
        let m = JeniChartModel(form: .bars, series: [
            .init(values: [10, nil, 30], role: .ink)
        ])
        let rects = m.barRects(in: size, gap: 2)
        XCTAssertEqual(rects.count, 3)
        XCTAssertNotNil(rects[0])
        XCTAssertNil(rects[1], "an unlogged day is a gap, not a zero bar")
        XCTAssertNotNil(rects[2])
    }

    // MARK: - y domain padding

    func testValuesNeverTouchTheEdges() {
        let m = JeniChartModel(form: .line, series: [
            .init(values: [0, 10], role: .ink)
        ])
        let seg = m.points(seriesIndex: 0, in: size)[0]
        let ys = seg.map(\.y)
        XCTAssertGreaterThan(ys.min()!, 0, "top padding")
        XCTAssertLessThan(ys.max()!, size.height, "bottom padding")
    }

    // MARK: - detents clamp

    func testDetentClampsAtBothEdges() {
        let m = JeniChartModel(form: .line, series: [
            .init(values: [1, 2, 3, 4, 5], role: .ink)
        ])
        XCTAssertEqual(m.detent(forX: -50, width: size.width), 0)
        XCTAssertEqual(m.detent(forX: 0, width: size.width), 0)
        XCTAssertEqual(m.detent(forX: size.width + 50, width: size.width), 4)
        XCTAssertEqual(m.detent(forX: size.width / 2, width: size.width), 2)
    }

    // MARK: - staged reveal is monotonic and completes

    func testRevealCountMonotonicAndComplete() {
        let m = JeniChartModel(form: .bars, series: [
            .init(values: [1, 2, 3, 4, 5, 6, 7], role: .ink)
        ])
        var last = -1
        for phase in stride(from: 0.0, through: 1.0, by: 0.05) {
            let c = m.revealCount(phase: phase, total: 7)
            XCTAssertGreaterThanOrEqual(c, last, "reveal must never retreat")
            XCTAssertLessThanOrEqual(c, 7)
            last = c
        }
        XCTAssertEqual(m.revealCount(phase: 1.0, total: 7), 7, "phase 1.0 lands every bar")
        XCTAssertEqual(m.revealCount(phase: 0.0, total: 7), 0)
    }

    // MARK: - context series share the ink series' scale

    func testSharedYDomainAcrossSeries() {
        // context (EMA) at 0-10, ink (raw) at 0-20: both scale to the
        // union so they are comparable on the same canvas.
        let m = JeniChartModel(form: .line, series: [
            .init(values: [0, 20], role: .ink),
            .init(values: [10, 10], role: .context),
        ])
        let ink = m.points(seriesIndex: 0, in: size)[0]
        let ctx = m.points(seriesIndex: 1, in: size)[0]
        // context's 10 sits midway between ink's 0 and 20
        let inkMidY = (ink[0].y + ink[1].y) / 2
        XCTAssertEqual(ctx[0].y, inkMidY, accuracy: 0.5)
    }
}
