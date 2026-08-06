import XCTest
@testable import plankAI

// MARK: - V8ScriptTests (docs/onboarding_v8)
//
// The consult's router is pure over the store, so the whole flow is
// table-testable: every door × cohort × persona walk must terminate
// at the hold, visit no node twice, and resolve every id to a
// renderable node. The clinic flow must carry ZERO conversion beats.

final class V8ScriptTests: XCTestCase {

    private func freshStore() -> OV5Store {
        let d = UserDefaults.standard
        for key in ["onb_v8_door", "onb_v8_clinic_org", "onboarding_glp1_status",
                    "onb_v5_gender", "onboardingGender", "onboarding_goal_direction"] {
            d.removeObject(forKey: key)
        }
        return OV5Store()
    }

    private let conversionBeats: Set<String> = [
        "hello", "outcome", "history", "foodRelationship", "ch_mirror",
        "demoIntro", "s_snapDemo", "proteinRule", "ch_evidence",
        "identity", "fears", "attribution",
    ]

    private func walk(_ store: OV5Store) -> [String] {
        V8Script.orderedIDs(store: store)
    }

    func testEveryDoorCohortPersonaWalkTerminatesWithoutCycles() {
        for door in ["", "consumer", "clinic"] {
            for glp1 in ["", "none", "current", "past", "considering"] {
                for gender in ["female", "male", "nonbinary"] {
                    let store = freshStore()
                    store.door = door
                    store.glp1Status = glp1
                    store.gender = gender
                    if door == "clinic" { store.clinicOrgName = "demo clinic" }
                    let ids = walk(store)
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
        let store = freshStore()
        store.door = "clinic"
        store.clinicOrgName = "demo clinic"
        let ids = Set(walk(store))
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
        let store = freshStore()
        store.door = "consumer"
        let ids = Set(walk(store))
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
        let store = freshStore()
        store.door = "consumer"
        store.glp1Status = "current"
        let ids = Set(walk(store))
        XCTAssertTrue(ids.contains("muscleMath"))
        XCTAssertFalse(ids.contains("proteinRule"),
                       "current cohort already has its protein teach")

        let general = freshStore()
        general.door = "consumer"
        general.glp1Status = "none"
        XCTAssertTrue(Set(walk(general)).contains("proteinRule"))
    }

    func testMalePersonaRoutesAroundHormonalOnBothDoors() {
        for door in ["consumer", "clinic"] {
            let store = freshStore()
            store.door = door
            if door == "clinic" { store.clinicOrgName = "demo clinic" }
            store.gender = "male"
            XCTAssertFalse(Set(walk(store)).contains("hormonal"),
                           "male persona must skip hormonal on \(door)")
        }
    }

    func testCodeSkipFallsBackToTheConsumerConsult() {
        let store = freshStore()
        store.door = "clinic"
        XCTAssertEqual(V8Script.next(after: "door", store: store), "clinicCode")
        // The code beat's skip flips the door before routing continues.
        store.door = "consumer"
        XCTAssertEqual(V8Script.next(after: "clinicCode", store: store), "hello")
    }

    func testMaintainersSkipTheGoalRuler() {
        let store = freshStore()
        store.door = "consumer"
        store.goalDirection = "maintain"
        XCTAssertEqual(V8Script.next(after: "goalDirection", store: store), "movement")
        store.goalDirection = "lose"
        XCTAssertEqual(V8Script.next(after: "goalDirection", store: store), "goalWeight")
    }

    func testProgressFractionIsMonotonic() {
        let store = freshStore()
        store.door = "consumer"
        let ids = walk(store)
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
                let store = freshStore()
                store.door = door
                if door == "clinic" { store.clinicOrgName = "demo clinic" }
                store.glp1Status = glp1
                for id in walk(store) where !id.hasPrefix("ch_") && !id.hasPrefix("s_") {
                    XCTAssertNotNil(V8Script.beat(for: id),
                                    "talk beat \(id) has no script entry")
                }
            }
        }
    }

    func testDoorAndOrgPersistAcrossStoreRelaunch() {
        let store = freshStore()
        store.door = "clinic"
        store.clinicOrgName = "Demo Clinic"
        let resumed = OV5Store()
        XCTAssertEqual(resumed.door, "clinic")
        XCTAssertEqual(resumed.clinicOrgName, "Demo Clinic")
        // Cleanup so later tests see a fresh door.
        UserDefaults.standard.removeObject(forKey: "onb_v8_door")
        UserDefaults.standard.removeObject(forKey: "onb_v8_clinic_org")
    }
}
