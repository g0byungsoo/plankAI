import XCTest
@testable import plankAI

// CareProtocol (app v8, docs/app_v8/03_ARCHITECTURE.md §3a) — the
// platform seam. These tables pin two guarantees: (1) `.default`
// reproduces shipped behavior (the existing engine suites are the
// byte-equality half; here the numeric half), and (2) an injected
// variant actually steers every seam — a clinic config is a data
// change, not a fork.

final class CareProtocolTests: XCTestCase {

    // MARK: - Fixtures

    private func day(beats: [ProgramDayPrescription]) -> PrescriptionEngineV2.Day {
        PrescriptionEngineV2.Day(
            archetype: .protein, beats: beats,
            weighInIsStaleFallback: false, programDay: 12
        )
    }

    private let fullBeats: [ProgramDayPrescription] = [
        .snapMeal,
        .workout(tier: .medium, minutes: 10, bodyFocus: nil),
        .lesson(lessonId: nil),
        .steps(goal: 7_500),
        .weighIn,
    ]

    private var variant: CareProtocol {
        var p = CareProtocol.default
        p.id = "test.variant"
        return p
    }

    // MARK: - Codable (S2 served-row readiness)

    func testDefaultSurvivesCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(CareProtocol.default)
        let back = try JSONDecoder().decode(CareProtocol.self, from: data)
        XCTAssertEqual(back, CareProtocol.default)
    }

    // MARK: - Composition seams

    func testShortNightThresholdIsInjected() {
        var p = variant
        p.composition.shortNightHours = 8   // a stricter clinic
        let plan = CarePlanEngine.compose(
            .init(day: day(beats: fullBeats), sleepHoursLastNight: 7.0),
            careProtocol: p
        )
        XCTAssertEqual(plan.tone, .gentle)
        // Default keeps 7h standard (equivalence).
        let def = CarePlanEngine.compose(
            .init(day: day(beats: fullBeats), sleepHoursLastNight: 7.0)
        )
        XCTAssertEqual(def.tone, .standard)
    }

    func testGentleReturnThresholdIsInjected() {
        var p = variant
        p.composition.gentleReturnDays = 2
        let plan = CarePlanEngine.compose(
            .init(day: day(beats: fullBeats), daysSinceLastOpen: 2),
            careProtocol: p
        )
        XCTAssertEqual(plan.tone, .gentle)
    }

    func testRapidLossThresholdIsInjected() {
        var p = variant
        p.composition.rapidLossRatePctPerWeek = 0.005
        let plan = CarePlanEngine.compose(
            .init(
                day: day(beats: fullBeats),
                lossRatePctPerWeek: 0.007, trendIsEstablished: true
            ),
            careProtocol: p
        )
        XCTAssertTrue(plan.lead?.because?.contains("protein") ?? false)
        // Same rate under the default threshold stays quiet.
        let def = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            lossRatePctPerWeek: 0.007, trendIsEstablished: true
        ))
        XCTAssertNil(def.lead?.because)
    }

    func testOfferedCapIsInjected() {
        var p = variant
        p.composition.maxOfferedMoves = 1
        let plan = CarePlanEngine.compose(
            .init(day: day(beats: fullBeats)), careProtocol: p
        )
        XCTAssertLessThanOrEqual(plan.offered.count, 1)
    }

    // MARK: - Voice seam (rules/voice split)

    func testJeniVoiceMatchesShippedStrings() {
        // The byte-equality half of the equivalence guarantee: the
        // moved strings render identically through the voice layer.
        let voice = JeniVoice()
        XCTAssertEqual(
            voice.gentleTender().text,
            "yesterday read tender. just this, nothing else"
        )
        XCTAssertEqual(
            voice.gentleShortNight(hours: 5, minutes: 24).text,
            "short night (5h 24m). one thing is the whole plan"
        )
        XCTAssertEqual(
            voice.gentleReturn(daysAway: 6).text,
            "back after 6 days. one small thing restarts it"
        )
        XCTAssertEqual(voice.weighInStale().text, "first one in a while")
        XCTAssertEqual(
            voice.rapidLossProteinFirst().text,
            "losing fast. protein first protects muscle"
        )
        XCTAssertEqual(voice.rapidLossProteinFirst().italics, ["protein first"])
        XCTAssertEqual(
            voice.proteinDeficit(gapG: 50).text,
            "yesterday landed 50g under your protein floor"
        )
    }

    func testAlternateVoiceRewordsWithoutTouchingRules() {
        struct ClinicVoice: BrandVoice {
            func gentleTender() -> VoiceLine { VoiceLine(text: "a lighter day is scheduled.") }
            func gentleShortNight(hours: Int, minutes: Int) -> VoiceLine {
                VoiceLine(text: "sleep was short; today is reduced.")
            }
            func gentleReturn(daysAway: Int) -> VoiceLine { VoiceLine(text: "welcome back.") }
            func weighInStale() -> VoiceLine { VoiceLine(text: "a check-in is due.") }
            func weighInCadence(keeping: Bool) -> VoiceLine {
                VoiceLine(text: "scheduled weight check.")
            }
            func keystoneProteinAnchor() -> VoiceLine {
                VoiceLine(text: "protein target remains today.")
            }
            func rapidLossProteinFirst() -> VoiceLine { VoiceLine(text: "prioritize protein today.") }
            func proteinDeficit(gapG: Int) -> VoiceLine {
                VoiceLine(text: "protein was \(gapG)g under target yesterday.")
            }
            func doseDay() -> VoiceLine { VoiceLine(text: "medication is scheduled today.") }
            func dailyDose(oral: Bool) -> VoiceLine { VoiceLine(text: "daily medication is scheduled.") }
            func hydrationTitration() -> VoiceLine { VoiceLine(text: "prioritize fluids.") }
            func bodyScanInvitation(first: Bool) -> VoiceLine { VoiceLine(text: "a scan is scheduled.") }
            func preservationAtRisk() -> VoiceLine { VoiceLine(text: "protein adherence is indicated.") }
            func plateauHold() -> VoiceLine { VoiceLine(text: "a plateau phase is expected.") }
            func walkGap(remainingSteps: Int) -> VoiceLine { VoiceLine(text: "\(remainingSteps) steps remain today.") }
            func walkAfterMeal() -> VoiceLine { VoiceLine(text: "a short post-meal walk is scheduled.") }
        }
        let plan = CarePlanEngine.compose(
            .init(day: day(beats: fullBeats), yesterdayFeeling: "tender"),
            voice: ClinicVoice()
        )
        XCTAssertEqual(plan.tone, .gentle)                 // rule unchanged
        XCTAssertEqual(plan.lead?.because, "a lighter day is scheduled.")
    }

    // MARK: - Cadence seam

    func testWeighSlotsAreInjected() {
        var p = variant
        p.cadence.weighSlotsDefault = [2]   // a Wednesday-only clinic
        let ctx = PrescriptionEngineV2.Context(
            glp1Status: "", restrictiveRisk: false, maintenanceMode: false,
            highStress: false, lastWeighInDaysAgo: 1, lastSnapDaysAgo: nil
        )
        XCTAssertEqual(
            PrescriptionEngineV2.weighInSlots(context: ctx, careProtocol: p), [2]
        )
        XCTAssertEqual(PrescriptionEngineV2.weighInSlots(context: ctx), [0, 3])
    }

    // MARK: - Band seam

    func testBandZonesAreInjected() {
        var p = variant
        p.band.driftingAtKg = 1.0
        p.band.resetAtKg = 1.8
        XCTAssertEqual(
            BandModel.zone(emaKg: 71.1, settleKg: 70, careProtocol: p), .drifting
        )
        XCTAssertEqual(BandModel.zone(emaKg: 71.1, settleKg: 70), .steady)
        XCTAssertEqual(
            BandModel.zone(emaKg: 71.9, settleKg: 70, careProtocol: p), .reset
        )
    }

    // MARK: - The sanity gate + the served store (S2)

    func testDefaultIsClinicallySane() {
        XCTAssertTrue(CareProtocol.default.isClinicallySane)
    }

    func testInsanePayloadsFailTheGateWhole() {
        var p = variant
        p.protein.perKgGLP1Current = 5.0
        XCTAssertFalse(p.isClinicallySane)
        var q = variant
        q.band.resetAtKg = q.band.driftingAtKg - 0.1
        XCTAssertFalse(q.isClinicallySane)
        var r = variant
        r.maxPlanRatePctPerWeek = 0.05
        XCTAssertFalse(r.isClinicallySane)
        var s = variant
        s.cadence.weighSlotsDefault = [9]
        XCTAssertFalse(s.isClinicallySane)
    }

    @MainActor
    func testServedStoreAppliesSaneRejectsInsaneAndCaches() {
        let name = "cp-store-test"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        CareProtocolStore.resetForTesting()
        defer { CareProtocolStore.resetForTesting() }

        var served = variant
        served.version = 2
        served.composition.shortNightHours = 7
        XCTAssertTrue(CareProtocolStore.apply(served, defaults: suite))
        XCTAssertEqual(CareProtocolStore.current.composition.shortNightHours, 7)

        var bad = variant
        bad.protein.floorGLP1G = 999
        XCTAssertFalse(CareProtocolStore.apply(bad, defaults: suite))
        XCTAssertEqual(CareProtocolStore.current.version, 2)   // last sane holds

        // Cold-start cache: a reset store re-adopts the last sane
        // payload from the suite.
        CareProtocolStore.resetForTesting()
        CareProtocolStore.bootstrapFromCacheIfNeeded(defaults: suite)
        XCTAssertEqual(CareProtocolStore.current.composition.shortNightHours, 7)
        suite.removePersistentDomain(forName: name)
    }

    func testDecodeToleratesMissingSupports() throws {
        // S2 contract: an older served row without the newer
        // `supports` key decodes with the default, never fails whole.
        var encoded = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(CareProtocol.default)
        ) as! [String: Any]
        encoded.removeValue(forKey: "supports")
        let data = try JSONSerialization.data(withJSONObject: encoded)
        let decoded = try JSONDecoder().decode(CareProtocol.self, from: data)
        XCTAssertTrue(decoded.supports.isEmpty)
        XCTAssertTrue(decoded.isClinicallySane)
    }

    @MainActor
    func testServerResponseDecodePath() {
        let name = "cp-store-net"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        CareProtocolStore.resetForTesting()
        defer { CareProtocolStore.resetForTesting() }

        var served = variant
        served.version = 3
        let row = try! JSONEncoder().encode(served)
        let body = "[{\"payload\":" + String(data: row, encoding: .utf8)! + "}]"
        XCTAssertTrue(CareProtocolStore.applyServerResponse(Data(body.utf8), defaults: suite))
        XCTAssertEqual(CareProtocolStore.current.version, 3)

        XCTAssertFalse(CareProtocolStore.applyServerResponse(Data("not json".utf8), defaults: suite))
        XCTAssertEqual(CareProtocolStore.current.version, 3)
        suite.removePersistentDomain(forName: name)
    }

    // MARK: - Protein policy (incl. the small-body honesty fix)

    private let glp1Key = "onboarding_glp1_status"
    private var savedGlp1: String?
    private var savedAdjust: Int = 0

    override func setUp() {
        super.setUp()
        savedGlp1 = UserDefaults.standard.string(forKey: glp1Key)
        savedAdjust = UserDefaults.standard.integer(forKey: WeeklyReview.proteinAdjustKey)
        UserDefaults.standard.removeObject(forKey: WeeklyReview.proteinAdjustKey)
    }

    override func tearDown() {
        if let savedGlp1 {
            UserDefaults.standard.set(savedGlp1, forKey: glp1Key)
        } else {
            UserDefaults.standard.removeObject(forKey: glp1Key)
        }
        UserDefaults.standard.set(savedAdjust, forKey: WeeklyReview.proteinAdjustKey)
        super.tearDown()
    }

    func testProteinDefaultCohortUnchanged() {
        UserDefaults.standard.removeObject(forKey: glp1Key)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 70, adjustG: 0), 85)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 50, adjustG: 0), 70)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 120, adjustG: 0), 130)
    }

    func testProteinGLP1LargeBodyUnchanged() {
        UserDefaults.standard.set("current", forKey: glp1Key)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 70, adjustG: 0), 110)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 58, adjustG: 0), 95)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 100, adjustG: 0), 140)
    }

    func testProteinGLP1SmallBodyStaysInsideAdvisoryBand() {
        // The v8 honesty fix (04_DECISIONS): pre-v8 a 50kg GLP-1
        // user got the flat 90g floor = 1.8 g/kg, above the cited
        // 1.2-1.6 advisory band. The floor now caps at the band
        // value itself.
        UserDefaults.standard.set("current", forKey: glp1Key)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 50, adjustG: 0), 80)
        for kg in stride(from: 42.0, through: 130.0, by: 4.0) {
            let g = Double(TargetsService.proteinTargetG(weightKg: kg, adjustG: 0))
            XCTAssertLessThanOrEqual(
                g / kg, 1.6 + 0.05,
                "target at \(kg)kg leaves the advisory band"
            )
        }
    }

    func testProteinPolicyIsInjected() {
        UserDefaults.standard.removeObject(forKey: glp1Key)
        var p = variant
        p.protein.perKgDefault = 1.5
        p.protein.floorDefaultG = 80
        XCTAssertEqual(
            TargetsService.proteinTargetG(weightKg: 70, adjustG: 0, careProtocol: p), 105
        )
    }
}
