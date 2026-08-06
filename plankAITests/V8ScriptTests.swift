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
        "demoIntro", "s_snapDemo", "proteinRule", "ch_evidence",
        "identity", "fears", "attribution",
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
                         "cadence", "numbersLine", "weight", "s_safetyGate",
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
                         "s_snapDemo", "ch_evidence", "fears",
                         "attribution", "ch_file", "s_hold"] {
            XCTAssertTrue(ids.contains(required), "consumer flow must keep \(required)")
        }
        XCTAssertFalse(ids.contains("clinicCode"))
        XCTAssertFalse(ids.contains("clinicWelcome"))
    }

    func testCurrentCohortSwapsProteinTeachForMuscleMath() {
        reset(door: "consumer", glp1: "current")
        let ids = Set(walk())
        XCTAssertTrue(ids.contains("muscleMath"))
        XCTAssertFalse(ids.contains("proteinRule"),
                       "current cohort already has its protein teach")

        reset(door: "consumer", glp1: "none")
        XCTAssertTrue(Set(walk()).contains("proteinRule"))
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
