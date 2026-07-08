import XCTest
@testable import plankAI

// MARK: - WeekIntentTests
//
// docs/app_v4/01_PROGRAM.md — week intents are deterministic,
// zone-aware in keeping, flag-aware in the build, and honor a
// re-signing pick. The table is a closed set: every key resolves.

final class WeekIntentTests: XCTestCase {

    private func phase(_ chapter: Chapter, week: Int, totalWeeks: Int = 20) -> ArcPhase {
        ProgramArc.phase(week: week, totalWeeks: totalWeeks, chapter: chapter)
    }

    func testDeterministicAcrossCalls() {
        let a = WeekIntent.intent(
            week: 6, chapter: .losing, phase: phase(.losing, week: 6),
            flags: .init()
        )
        let b = WeekIntent.intent(
            week: 6, chapter: .losing, phase: phase(.losing, week: 6),
            flags: .init()
        )
        XCTAssertEqual(a, b)
    }

    func testBuildRotationAdvancesWeekByWeek() {
        let w5 = WeekIntent.intent(week: 5, chapter: .losing,
                                   phase: phase(.losing, week: 5), flags: .init())
        let w6 = WeekIntent.intent(week: 6, chapter: .losing,
                                   phase: phase(.losing, week: 6), flags: .init())
        XCTAssertEqual(w5.key, "protein_week")
        XCTAssertEqual(w6.key, "food_noise_week")
        XCTAssertNotEqual(w5, w6)
    }

    func testHighStressMeetsTheStressWeekFirst() {
        let first = WeekIntent.intent(
            week: 5, chapter: .losing, phase: phase(.losing, week: 5),
            flags: .init(highStress: true)
        )
        XCTAssertEqual(first.key, "stress_sleep_week")
    }

    func testKeepingZonesOverrideTheRotation() {
        let drifting = WeekIntent.intent(
            week: 9, chapter: .keeping, phase: phase(.keeping, week: 9),
            flags: .init(), zone: .drifting
        )
        XCTAssertEqual(drifting.key, "steadying_week")

        let reset = WeekIntent.intent(
            week: 9, chapter: .keeping, phase: phase(.keeping, week: 9),
            flags: .init(), zone: .reset
        )
        XCTAssertEqual(reset.key, "reset_arc")

        // Steady zone falls through to the kept rotation (positional:
        // week 7 = the rotation's first slot).
        let steady = WeekIntent.intent(
            week: 7, chapter: .keeping, phase: phase(.keeping, week: 7),
            flags: .init(), zone: .steady
        )
        XCTAssertEqual(steady.key, "kept_quietly")
    }

    func testKeepingSettleWeeksAreNamedInOrder() {
        let names = (1...6).map {
            WeekIntent.intent(
                week: $0, chapter: .keeping,
                phase: phase(.keeping, week: $0), flags: .init()
            ).key
        }
        XCTAssertEqual(names, ["naming_settle", "pattern_week", "three_plates",
                               "strength_anchor", "rhythm_holds", "first_kept"])
    }

    func testMedicationBlocksRotateEveryFourWeeks() {
        // Practice starts week 3; weeks 3-6 = protein block,
        // 7-10 = strength block.
        let w3 = WeekIntent.intent(week: 3, chapter: .onMedication,
                                   phase: phase(.onMedication, week: 3), flags: .init())
        let w6 = WeekIntent.intent(week: 6, chapter: .onMedication,
                                   phase: phase(.onMedication, week: 6), flags: .init())
        let w7 = WeekIntent.intent(week: 7, chapter: .onMedication,
                                   phase: phase(.onMedication, week: 7), flags: .init())
        XCTAssertEqual(w3.key, "protein_block")
        XCTAssertEqual(w6.key, "protein_block")
        XCTAssertEqual(w7.key, "strength_block")
    }

    func testPickedKeyWinsOverRotation() {
        let picked = WeekIntent.intent(
            week: 5, chapter: .losing, phase: phase(.losing, week: 5),
            flags: .init(), pickedKey: "steady_week"
        )
        XCTAssertEqual(picked.key, "steady_week")
    }

    func testEveryNamedKeyResolves() {
        let keys = [
            "arriving_week", "finding_steady", "early_read", "plan_learns",
            "protein_week", "food_noise_week", "kitchen_week",
            "stress_sleep_week", "movement_keep_week", "real_life_week",
            "begin_again_week", "bend_named", "steady_week", "fresh_angle",
            "last_stretch_week", "hold_week", "arriving_support",
            "floor_first", "protein_block", "strength_block", "rhythm_block",
            "quiet_block", "naming_settle", "pattern_week", "three_plates",
            "strength_anchor", "rhythm_holds", "first_kept", "kept_quietly",
            "identity_week", "satisfaction_week", "still_yours",
            "steadying_week", "reset_arc",
        ]
        for key in keys {
            let spec = WeekIntent.spec(for: key)
            XCTAssertNotNil(spec, "unresolvable intent key \(key)")
            XCTAssertFalse(spec!.name.isEmpty)
            XCTAssertFalse(spec!.line.isEmpty)
            // Voice contract: lowercase, no em-dashes between words.
            XCTAssertEqual(spec!.name, spec!.name.lowercased())
            XCTAssertFalse(spec!.line.contains("—"))
            XCTAssertFalse(spec!.line.contains("--"))
        }
    }
}
