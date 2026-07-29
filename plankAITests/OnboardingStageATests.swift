import XCTest
@testable import plankAI

// Stage A (docs/app_v8/08_STAGE_A.md) — first-ever unit coverage of
// the v5 router: the fork chains WITH the new beats, skip paths,
// the word→ISO mapping, and the completion-handoff guard shape
// (care_team safety is pinned in RegimenTests; here we pin that
// the machine routes and stores exactly as specced).

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

    // MARK: - Router chains

    func testCurrentCohortChainIncludesShotDay() {
        let store = makeStore()
        store.glp1Status = "current"
        XCTAssertEqual(OV5Router.next(after: .glp1Status, store: store), .glp1Phase)
        XCTAssertEqual(OV5Router.next(after: .glp1Phase, store: store), .appetiteRhythm)
        XCTAssertEqual(OV5Router.next(after: .appetiteRhythm, store: store), .shotDay)
        XCTAssertEqual(OV5Router.next(after: .shotDay, store: store), .muscleMath)
        XCTAssertEqual(OV5Router.next(after: .muscleMath, store: store), .foodRelationship)
    }

    func testOtherCohortsNeverRouteThroughShotDay() {
        let store = makeStore()
        for status in ["past", "considering", "none", ""] {
            store.glp1Status = status
            var step: OV5Step? = .glp1Status
            var visited: [OV5Step] = []
            var guardCount = 0
            while let s = step, guardCount < 80 {
                guardCount += 1
                let next = OV5Router.next(after: s, store: store)
                if let next { visited.append(next) }
                step = next
                if next == .receiptFood { break }
            }
            XCTAssertFalse(
                visited.contains(.shotDay),
                "cohort \(status) must never see the shot-day beat"
            )
        }
    }

    func testSupportsBeatRidesEveryBranchAfterDietary() {
        let store = makeStore()
        XCTAssertEqual(OV5Router.next(after: .dietary, store: store), .supports)
        XCTAssertEqual(OV5Router.next(after: .supports, store: store), .receiptFood)
    }

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

    // MARK: - Progress sanity (new beats join act ii)

    func testNewBeatsBelongToActII() {
        XCTAssertEqual(OV5Step.shotDay.act, 1)
        XCTAssertEqual(OV5Step.supports.act, 1)
        XCTAssertEqual(OV5Step.shotDay.archetype, .bespoke)
        XCTAssertEqual(OV5Step.supports.archetype, .multi)
    }
}
