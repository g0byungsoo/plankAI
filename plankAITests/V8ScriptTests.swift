import XCTest
@testable import plankAI

// MARK: - V8ScriptTests (docs/onboarding_v8)
//
// The consult's router is pure over the store, so the whole flow is
// table-testable: every door × cohort × persona walk must terminate
// at the hold, visit no node twice, and resolve every id to a
// renderable node. The clinic flow must carry ZERO conversion beats.

final class V8ScriptTests: XCTestCase {

    // ONE store for the whole class, mutated live between tests —
    // the router reads live values by design, and the iOS 26.2 sim
    // aborts in @Observable teardown when instances deinit between
    // tests (both crash stacks landed on the previous test's store
    // deinit — the documented deinit family). A static store never
    // deinits during the run.
    private static let sharedStore = OV5Store()
    private var store: OV5Store { Self.sharedStore }

    override func setUpWithError() throws {
        let d = UserDefaults.standard
        for key in ["onb_v8_door", "onb_v8_clinic_org", "onboarding_glp1_status",
                    "onb_v5_gender", "onboardingGender", "onboarding_goal_direction"] {
            d.removeObject(forKey: key)
        }
        store.door = ""
        store.glp1Status = ""
        store.gender = ""
        store.goalDirection = ""
        store.clinicOrgName = ""
    }

    private let conversionBeats: Set<String> = [
        "hello", "outcome", "history", "foodRelationship", "ch_mirror",
        "demoIntro", "s_snapDemo", "ch_evidence", "attribution",
        "weightTrend",
    ]

    private func walk() -> [String] {
        V8Script.orderedIDs(store: store)
    }

    private func reset(door: String, glp1: String = "", gender: String = "") {
        store.door = door
        store.glp1Status = glp1
        store.gender = gender
        store.clinicOrgName = door == "clinic" ? "demo clinic" : ""
    }

    func testEveryDoorCohortPersonaWalkTerminatesWithoutCycles() {
        for door in ["", "consumer", "clinic"] {
            for glp1 in ["", "none", "current", "past", "considering"] {
                for gender in ["female", "male", "nonbinary"] {
                    reset(door: door, glp1: glp1, gender: gender)
                    let ids = walk()
                    XCTAssertEqual(ids.first, "ch_arrival")
                    XCTAssertEqual(ids.last, "s_hold",
                                   "walk for \(door)/\(glp1)/\(gender) must end at the hold")
                    XCTAssertEqual(ids.count, Set(ids).count,
                                   "cycle in \(door)/\(glp1)/\(gender): \(ids)")
                    for id in ids {
                        XCTAssertNotNil(V8Script.node(for: id, store: store),
                                        "unresolvable node \(id)")
                    }
                }
            }
        }
    }

    func testClinicFlowCarriesNoConversionBeats() {
        reset(door: "clinic")
        let ids = Set(walk())
        for beat in conversionBeats {
            XCTAssertFalse(ids.contains(beat),
                           "clinic flow must not carry \(beat)")
        }
        // The clinical spine is intact.
        for required in ["clinicCode", "clinicWelcome", "name", "glp1Status",
                         "numbersLine", "weight", "s_safetyGate",
                         "ch_file", "s_signature", "s_healthKit", "s_hold"] {
            XCTAssertTrue(ids.contains(required),
                          "clinic flow must keep \(required)")
        }
    }

    func testConsumerFlowKeepsTheConsult() {
        reset(door: "consumer")
        let ids = Set(walk())
        for required in ["hello", "name", "outcome", "history",
                         "foodRelationship", "ch_mirror", "glp1Status",
                         "s_snapDemo", "ch_evidence",
                         "attribution", "ch_file", "s_hold"] {
            XCTAssertTrue(ids.contains(required), "consumer flow must keep \(required)")
        }
        XCTAssertFalse(ids.contains("clinicCode"))
        XCTAssertFalse(ids.contains("clinicWelcome"))
    }

    func testCohortQuestionIsOneScreenOnBothDoors() {
        // Founder: frictionless — the medication ask never branches
        // into sub-questions during onboarding (regimen depth lives
        // post-purchase in RegimenSheet).
        for glp1 in ["current", "past", "considering"] {
            reset(door: "consumer", glp1: glp1)
            let ids = Set(walk())
            for dead in ["glp1Phase", "appetiteRhythm", "shotDay",
                         "muscleMath", "stopWindow", "appetiteReturn",
                         "considering"] {
                XCTAssertFalse(ids.contains(dead),
                               "cohort sub-beat \(dead) must not ride onboarding")
            }
        }
    }

    func testTheQuizIsExactlyThreeScreens() {
        // Founder's law: the quiz is 3-4 screens max. It is three:
        // outcome, history, food — between the name and the mirror.
        reset(door: "consumer")
        let ids = walk()
        guard let nameIdx = ids.firstIndex(of: "name"),
              let mirrorIdx = ids.firstIndex(of: "ch_mirror") else {
            return XCTFail("name/mirror missing from the walk")
        }
        let quiz = Array(ids[(nameIdx + 1)..<mirrorIdx])
        XCTAssertEqual(quiz, ["outcome", "history", "foodRelationship"])
    }

    func testMalePersonaRoutesAroundHormonalOnBothDoors() {
        for door in ["consumer", "clinic"] {
            reset(door: door, gender: "male")
            XCTAssertFalse(Set(walk()).contains("hormonal"),
                           "male persona must skip hormonal on \(door)")
        }
    }

    func testCodeSkipFallsBackToTheConsumerConsult() {
        reset(door: "clinic")
        XCTAssertEqual(V8Script.next(after: "door", store: store), "clinicCode")
        // The code beat's skip flips the door before routing continues.
        store.door = "consumer"
        XCTAssertEqual(V8Script.next(after: "clinicCode", store: store), "hello")
    }

    func testMaintainersSkipTheGoalRuler() {
        reset(door: "consumer")
        store.goalDirection = "maintain"
        XCTAssertEqual(V8Script.next(after: "goalDirection", store: store), "movement")
        store.goalDirection = "lose"
        XCTAssertEqual(V8Script.next(after: "goalDirection", store: store), "goalWeight")
    }

    // MARK: - The rulers must fit every human (founder-caught, 2026-08-07)
    //
    // The bug: a ruler's range was resolved ONCE from the store's
    // remembered unit and then reused for the OTHER tab, so switching
    // units re-read the numbers in the wrong scale — 122…214 cm
    // rendered as 10'2"…17'10", and pounds inherited the kilogram
    // ceiling (200 lb). These assert the scales per tab and that no
    // conversion or seed can land outside its own scale.

    private func rulerSpec(_ id: String) -> V8RulerSpec? {
        guard case .talk(let beat)? = V8Script.node(for: id, store: store),
              case .ruler(let spec) = beat.input(store) else { return nil }
        return spec
    }

    func testHeightRulerCarriesBothScales() {
        reset(door: "consumer")
        guard let spec = rulerSpec("height") else {
            return XCTFail("height is not a ruler")
        }
        XCTAssertEqual(spec.range(at: 0), V8Scale.heightIn)
        XCTAssertEqual(spec.range(at: 1), V8Scale.heightCm)
        // 8'11" is the tallest man ever recorded; 3'0" clears the
        // shortest adult presentations.
        XCTAssertEqual(spec.range(at: 0).lowerBound, 36)
        XCTAssertEqual(spec.range(at: 0).upperBound, 107)
        // The tabs describe the SAME span, so a switch cannot move you.
        XCTAssertEqual(spec.range(at: 0).lowerBound * 2.54,
                       spec.range(at: 1).lowerBound, accuracy: 2)
        XCTAssertEqual(spec.range(at: 0).upperBound * 2.54,
                       spec.range(at: 1).upperBound, accuracy: 2)
    }

    func testWeightRulersCarryBothScales() {
        reset(door: "consumer")
        store.goalDirection = "lose"
        for id in ["weight", "goalWeight"] {
            guard let spec = rulerSpec(id) else {
                return XCTFail("\(id) is not a ruler")
            }
            XCTAssertEqual(spec.range(at: 0), V8Scale.weightLb, "\(id) lb")
            XCTAssertEqual(spec.range(at: 1), V8Scale.weightKg, "\(id) kg")
            XCTAssertEqual(spec.range(at: 0).upperBound / 2.20462,
                           spec.range(at: 1).upperBound, accuracy: 2, "\(id) ends agree")
        }
    }

    func testSwitchingUnitsNeverLeavesTheScale() {
        reset(door: "consumer")
        for id in ["height", "weight"] {
            guard let spec = rulerSpec(id) else { return XCTFail(id) }
            for unit in [0, 1] {
                let other = 1 - unit
                for probe in [spec.range(at: unit).lowerBound,
                              spec.range(at: unit).upperBound] {
                    let moved = spec.clamped(spec.convert(probe, unit, other), at: other)
                    XCTAssertTrue(spec.range(at: other).contains(moved),
                                  "\(id): \(probe) in tab \(unit) left the scale as \(moved)")
                }
            }
        }
    }

    func testASeededValueOutsideTheScaleIsClamped() {
        reset(door: "consumer")
        guard let spec = rulerSpec("weight") else { return XCTFail("weight") }
        XCTAssertEqual(spec.clamped(5, at: 0), V8Scale.weightLb.lowerBound)
        XCTAssertEqual(spec.clamped(4000, at: 0), V8Scale.weightLb.upperBound)
        XCTAssertEqual(spec.clamped(4000, at: 1), V8Scale.weightKg.upperBound)
    }

    func testProgressFractionIsMonotonic() {
        reset(door: "consumer")
        let ids = walk()
        var last = -1.0
        for id in ids {
            let f = V8Script.fraction(at: id, store: store)
            XCTAssertGreaterThanOrEqual(f, last, "fraction regressed at \(id)")
            last = f
        }
        XCTAssertEqual(last, 1.0, accuracy: 0.0001)
    }

    func testEveryTalkBeatInEveryWalkResolvesToAScriptedBeat() {
        for door in ["consumer", "clinic"] {
            for glp1 in ["none", "current", "past", "considering"] {
                reset(door: door, glp1: glp1)
                for id in walk() where !id.hasPrefix("ch_") && !id.hasPrefix("s_") {
                    XCTAssertNotNil(V8Script.beat(for: id),
                                    "talk beat \(id) has no script entry")
                }
            }
        }
    }

    func testDoorAndOrgPersistAcrossStoreRelaunch() {
        store.door = "clinic"
        store.clinicOrgName = "Demo Clinic"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "onb_v8_door"), "clinic")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "onb_v8_clinic_org"), "Demo Clinic")
        // Cleanup so later tests see a fresh door.
        UserDefaults.standard.removeObject(forKey: "onb_v8_door")
        UserDefaults.standard.removeObject(forKey: "onb_v8_clinic_org")
    }
}
