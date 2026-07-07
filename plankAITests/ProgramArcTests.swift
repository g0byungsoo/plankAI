import XCTest
@testable import plankAI

// MARK: - ProgramArcTests
//
// docs/app_v4/01_PROGRAM.md — the arc is pure math; these tables pin
// it. Laws: every week 1...totalWeeks belongs to exactly one phase;
// phases appear in canonical order; fixed clocks hold (steady = wks
// 1-2, early read = 3-4 on full plans); end phases anchor to the end;
// open-ended chapters extend forever; the data-bend overlays only
// the build.

final class ProgramArcTests: XCTestCase {

    // MARK: - Coverage law (losing)

    func testLosingPhasesCoverEveryWeekExactlyOnce() {
        for totalDays in [7, 14, 21, 28, 35, 49, 56, 70, 84, 105, 126, 140, 180] {
            let weeks = ProgramArc.totalWeeks(totalDays: totalDays)
            let phases = ProgramArc.phases(totalWeeks: weeks, chapter: .losing)
            for week in 1...weeks {
                let owning = phases.filter { $0.weeks.contains(week) }
                XCTAssertEqual(
                    owning.count, 1,
                    "week \(week) of \(weeks) owned by \(owning.count) phases"
                )
            }
            // Contiguous + ordered.
            var expectedNext = 1
            for phase in phases {
                XCTAssertEqual(phase.weeks.lowerBound, expectedNext,
                               "gap before \(phase.key) at \(weeks) weeks")
                expectedNext = phase.weeks.upperBound + 1
            }
            XCTAssertEqual(expectedNext - 1, weeks,
                           "phases end at week \(expectedNext - 1), plan has \(weeks)")
        }
    }

    func testLosingFullSkeletonAt20Weeks() {
        let phases = ProgramArc.phases(totalWeeks: 20, chapter: .losing)
        XCTAssertEqual(phases.map(\.key), [
            .findingSteady, .earlyRead, .build, .bend, .lastStretch, .hold,
        ])
        XCTAssertEqual(phases[0].weeks, 1...2)
        XCTAssertEqual(phases[1].weeks, 3...4)
        // Hold anchors to the end, two weeks on long plans.
        XCTAssertEqual(phases.last?.weeks, 19...20)
    }

    func testLosingShortPlansKeepTheGrammar() {
        // 8 weeks: no bend (the clock never reaches it) — but steady,
        // read, build, stretch, hold all present.
        let eight = ProgramArc.phases(totalWeeks: 8, chapter: .losing)
        XCTAssertFalse(eight.contains { $0.key == .bend })
        XCTAssertEqual(eight.first?.key, .findingSteady)
        XCTAssertEqual(eight.last?.key, .hold)

        // 4 weeks: compressed single-week phases.
        let four = ProgramArc.phases(totalWeeks: 4, chapter: .losing)
        XCTAssertEqual(four.map(\.key), [.findingSteady, .earlyRead, .build, .hold])
    }

    // MARK: - The data bend

    func testEmaFlatOverlaysBendOnlyDuringBuild() {
        // Week 6 of 20 sits in the build.
        let flat = ProgramArc.phase(week: 6, totalWeeks: 20, chapter: .losing, emaFlatWeeks: 3)
        XCTAssertEqual(flat.key, .bend)

        let notFlat = ProgramArc.phase(week: 6, totalWeeks: 20, chapter: .losing, emaFlatWeeks: 2)
        XCTAssertEqual(notFlat.key, .build)

        // The hold never becomes a bend.
        let hold = ProgramArc.phase(week: 20, totalWeeks: 20, chapter: .losing, emaFlatWeeks: 5)
        XCTAssertEqual(hold.key, .hold)
    }

    // MARK: - Open-ended chapters

    func testOnMedicationRunsOpenEnded() {
        let phases = ProgramArc.phases(totalWeeks: 20, chapter: .onMedication)
        XCTAssertEqual(phases.map(\.key), [.arriving, .practice])
        XCTAssertTrue(phases.last!.isOpenEnded)
        // Week 999 still resolves.
        XCTAssertEqual(
            ProgramArc.phase(week: 999, totalWeeks: 20, chapter: .onMedication).key,
            .practice
        )
    }

    func testKeepingSettlesThenKeeps() {
        let phases = ProgramArc.phases(totalWeeks: 52, chapter: .keeping)
        XCTAssertEqual(phases.map(\.key), [.settle, .kept])
        XCTAssertEqual(phases[0].weeks, 1...6)
        XCTAssertEqual(
            ProgramArc.phase(week: 7, totalWeeks: 52, chapter: .keeping).key, .kept
        )
    }

    // MARK: - Position language

    func testLeadLineFlipsAtMidpoint() {
        // Day 12 of 140 — pre-midpoint leads with presence.
        XCTAssertEqual(
            ProgramArc.leadLine(programDay: 12, totalDays: 140, chapter: .losing, keptDays: 9),
            "9 kept"
        )
        // Day 71 of 140 — past midpoint leads with distance.
        XCTAssertEqual(
            ProgramArc.leadLine(programDay: 71, totalDays: 140, chapter: .losing, keptDays: 60),
            "69 to go"
        )
        // Open-ended chapters always lead with presence.
        XCTAssertEqual(
            ProgramArc.leadLine(programDay: 200, totalDays: 140, chapter: .keeping, keptDays: 150),
            "150 kept"
        )
    }

    func testOrdinalLinePerChapter() {
        XCTAssertEqual(
            ProgramArc.ordinalLine(week: 2, totalWeeks: 15, chapter: .losing),
            "week 2 of 15"
        )
        XCTAssertEqual(
            ProgramArc.ordinalLine(week: 9, totalWeeks: 15, chapter: .keeping),
            "week 9"
        )
    }
}
