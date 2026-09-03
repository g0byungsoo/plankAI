import XCTest
@testable import plankAI

// Stage A (docs/app_v8/08_STAGE_A.md) — pins on the consult's ANSWER
// STORE and the completion-handoff mapping.
//
// p70 — THE V5 SWEEP: the OV5Step/OV5Router screen flow died with the
// v5 debug escape (v8 has been the shipping consult since 2026-08-06),
// and its nine routing pins died with it — a test of a flow no user
// can reach pins nothing. What stays pinned here is what still ships:
// OV5Store persistence + resume, the persona law, the ruler seeds and
// the word→ISO mapping the regimen handoff reads.

final class OnboardingStageATests: XCTestCase {

    /// OV5Store is @Observable; isolated-class deinit aborts on the
    /// iOS 26.2 sim runtime ([[reference-mainactor-class-deinit-
    /// crash]]). Tests retain every constructed store for the
    /// process lifetime — mirroring production, where the flow
    /// holds it until completion.
    private static var retainedStores: [OV5Store] = []
    private func makeStore() -> OV5Store {
        let s = OV5Store()
        Self.retainedStores.append(s)
        return s
    }

    private let touchedKeys = [
        "onboarding_glp1_status", "onboarding_glp1_phase",
        "onb_v5_appetite_rhythm", "onb_v5_shot_day", "onb_v5_supports",
        "onboarding_dietary",
        // v7 persona surface (canonical mirrors are not onb_v5_-prefixed)
        "onboardingGender", "onboardingHormonalStage",
        "onboardingHeightCm", "onboardingCurrentWeightKg",
    ]

    private func sweep() {
        let d = UserDefaults.standard
        for key in touchedKeys { d.removeObject(forKey: key) }
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("onb_v5_") {
            d.removeObject(forKey: key)
        }
    }

    override func setUp() { super.setUp(); sweep() }
    override func tearDown() { sweep(); super.tearDown() }

    // MARK: - Store writes

    func testShotDayAndSupportsPersistTheirKeys() {
        let store = makeStore()
        store.shotDay = "sun"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "onb_v5_shot_day"), "sun")
        store.shotDay = ""   // skip clears
        XCTAssertEqual(UserDefaults.standard.string(forKey: "onb_v5_shot_day"), "")

        store.supports = ["protein_powder", "vitamin_d"]
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "onb_v5_supports"),
            "protein_powder,vitamin_d"
        )
        store.supports = ["none"]
        XCTAssertEqual(UserDefaults.standard.string(forKey: "onb_v5_supports"), "none")
    }

    func testStoreResumesNewKeysAcrossRelaunch() {
        UserDefaults.standard.set("thu", forKey: "onb_v5_shot_day")
        UserDefaults.standard.set("fiber,magnesium", forKey: "onb_v5_supports")
        let store = makeStore()
        XCTAssertEqual(store.shotDay, "thu")
        XCTAssertEqual(store.supports, ["fiber", "magnesium"])
    }

    // MARK: - Word → ISO (the handoff's mapping)

    func testIsoWeekdayFromWord() {
        XCTAssertEqual(RegimenService.isoWeekday(fromWord: "mon"), 1)
        XCTAssertEqual(RegimenService.isoWeekday(fromWord: "thu"), 4)
        XCTAssertEqual(RegimenService.isoWeekday(fromWord: "sun"), 7)
        XCTAssertNil(RegimenService.isoWeekday(fromWord: ""))
        XCTAssertNil(RegimenService.isoWeekday(fromWord: nil))
        XCTAssertNil(RegimenService.isoWeekday(fromWord: "monday"))
    }

    // MARK: - v7 persona law (docs/onboarding_v7/00_DIRECTION D1-D2, D9)

    func testPersonaResolvesFromLiveGenderAnswer() {
        let store = makeStore()
        XCTAssertEqual(store.persona, .neutral)          // unset
        store.gender = "female";    XCTAssertEqual(store.persona, .her)
        store.gender = "male";      XCTAssertEqual(store.persona, .male)
        store.gender = "nonbinary"; XCTAssertEqual(store.persona, .neutral)
        store.gender = "private";   XCTAssertEqual(store.persona, .neutral)
    }

    func testMaleSeedsApplyOnlyToUntouchedRulers() {
        let store = makeStore()
        store.heightCm = 170          // she moved the ruler — persists
        store.gender = "male"
        XCTAssertEqual(store.heightCm, 170, "touched height must survive the seed")
        XCTAssertEqual(store.currentWeightKg, 88, "untouched weight takes the male seed")

        sweep()
        let fresh = makeStore()
        fresh.gender = "male"
        XCTAssertEqual(fresh.heightCm, 178)
        XCTAssertEqual(fresh.currentWeightKg, 88)

        sweep()
        let her = makeStore()
        her.gender = "female"
        XCTAssertEqual(her.heightCm, 165, "female/neutral keep the shipped seeds")
    }
}
