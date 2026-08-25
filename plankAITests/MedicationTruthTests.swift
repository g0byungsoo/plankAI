import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - MedicationTruthTests (app v25 pass 58)
//
// THE RECORD OUTRANKS THE QUESTIONNAIRE. "On medication" was decided
// by the consult's answer key (`onboarding_glp1_status == "current"`)
// alone, while the regimen record — the thing she actually maintains,
// dose by dose — was never consulted. Walked on the sim: a persona
// with an active injectable regimen and no consult key saw
// "your shot is today" and "187 over" ON THE SAME SCREEN, against the
// p53/p57 law that the on-medication cohort never hears "over"; her
// protein floor ran the default branch; and PostHog's own
// CohortIdentity stamped her `medicated: true` while the product read
// her as unmedicated. Reachable in production: she answers
// "considering" in june and starts through the regimen editor in
// august (which never touched the consult key), or a clinic patient
// whose care-team plan arrived through a door that deliberately
// writes no consult keys.
//
// The fix is belt and braces:
//   BELT — `RegimenService.reconcileCohortStatus` maintains the key
//   at the same chokepoints that own regimen truth (applySelfRegimen,
//   endMedicationPlan, care reconciliation, the Home refresh), so
//   every existing key reader heals at once.
//   BRACES — the read seams that already hold a ModelContext
//   (TodayStateService's chapter, the reading's count-up provider,
//   TargetsService's protein branch) derive from the record directly,
//   so a care-team plan counts even before any chokepoint runs.
//
// RED: the belt and braces tests below ran against the shipped code
// (no stubs — applySelfRegimen, endMedicationPlan and
// TargetsService.current are the real paths) and failed; the controls
// passed. The pure-derivation table is new law, pinned at birth and
// stated as such.

@MainActor
final class MedicationTruthTests: XCTestCase {

    private let d = UserDefaults.standard
    private var savedStatus: String?
    private var savedAdjust: Int = 0
    private var savedMaintenance: Any?
    private var seededUserIds: [String] = []

    override func setUp() {
        super.setUp()
        savedStatus = d.string(forKey: "onboarding_glp1_status")
        savedAdjust = d.integer(forKey: WeeklyReview.proteinAdjustKey)
        savedMaintenance = d.object(forKey: "program_mode")
        d.removeObject(forKey: "onboarding_glp1_status")
        d.removeObject(forKey: WeeklyReview.proteinAdjustKey)
        seededUserIds = []
    }

    override func tearDown() {
        if let savedStatus { d.set(savedStatus, forKey: "onboarding_glp1_status") }
        else { d.removeObject(forKey: "onboarding_glp1_status") }
        d.set(savedAdjust, forKey: WeeklyReview.proteinAdjustKey)
        if let savedMaintenance { d.set(savedMaintenance, forKey: "program_mode") }
        // The container is process-shared (TestModelContainer law):
        // rows this suite seeded must leave with it, or an unrelated
        // suite's unpredicated count inherits them — the p36 lesson,
        // re-learned here when ReattributionTests read 5 weigh-ins
        // where it seeded 2. Fixed in THIS file; the other test was
        // not weakened.
        let context = TestModelContainer.shared.mainContext
        for uid in seededUserIds {
            for w in (try? context.fetch(FetchDescriptor<WeightLogRecord>(
                predicate: #Predicate { $0.userId == uid }
            ))) ?? [] { context.delete(w) }
            for r in (try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
                predicate: #Predicate { $0.userId == uid }
            ))) ?? [] { context.delete(r) }
        }
        try? context.save()
        super.tearDown()
    }

    private func user(_ tag: String) -> String {
        let u = "p58-\(tag)-\(UUID().uuidString)"
        seededUserIds.append(u)
        return u
    }

    private func spec(dose: Double = 0.5) -> RegimenService.SelfRegimenSpec {
        var s = RegimenService.SelfRegimenSpec()
        s.productId = "ozempic"
        s.displayName = "ozempic"
        s.route = "injection"
        s.scheduleRule = "weeklyAnchor"
        s.anchorWeekday = 3
        s.doseValue = dose
        return s
    }

    /// A regimen row seeded DIRECTLY — no chokepoint runs, which is
    /// exactly the care-team arrival shape (the clinic door writes no
    /// consult keys, deliberately) and the reinstall-hydrate shape.
    private func seedRegimenRow(
        userId: String, authority: String, in context: ModelContext
    ) {
        let plan = RegimenPlanRecord(
            userId: userId,
            kind: "medication",
            displayName: "wegovy",
            scheduleRule: "weeklyAnchor",
            anchorWeekday: 3,
            timeOfDayMinutes: nil,
            startedAt: .now,
            reminderEnabled: false,
            productId: "wegovy",
            route: "injection"
        )
        plan.strengthValue = 1.0
        plan.strengthUnit = "mg"
        plan.authority = authority
        context.insert(plan)
        try? context.save()
    }

    private func seedWeight(_ kg: Double, userId: String, in context: ModelContext) {
        let log = WeightLogRecord(
            userId: userId, weightKg: kg, loggedAt: .now, source: "manual"
        )
        context.insert(log)
        try? context.save()
    }

    // MARK: - BELT: the chokepoints keep the key honest

    func testAnActiveRegimenAloneMakesTheMedicationChapter() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("belt")
        d.removeObject(forKey: "onboarding_glp1_status")

        _ = RegimenService.applySelfRegimen(spec(), userId: userId, in: context)

        XCTAssertEqual(
            CohortStore.chapter, .onMedication,
            "she maintains an active injectable regimen; the chapter must follow her record, not the unanswered consult"
        )
    }

    func testStartingMedicationUpdatesTheStatusKeyAtTheChokepoint() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("start")
        d.set("considering", forKey: "onboarding_glp1_status")

        _ = RegimenService.applySelfRegimen(spec(), userId: userId, in: context)

        XCTAssertEqual(
            d.string(forKey: "onboarding_glp1_status"), "current",
            "recording a regimen IS stating current medication use — the june answer aged the moment she recorded the august fact"
        )
    }

    func testEndingTheLastRegimenAgesCurrentToPast() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("end")
        d.set("current", forKey: "onboarding_glp1_status")

        _ = RegimenService.applySelfRegimen(spec(), userId: userId, in: context)
        RegimenService.endMedicationPlan(userId: userId, in: context)

        XCTAssertEqual(
            d.string(forKey: "onboarding_glp1_status"), "past",
            "the record ended the medication; a stated `current` ages to `past` by her own record"
        )
    }

    // Control (passes before AND after): an answer the record neither
    // confirms nor denies is HER word and is never rewritten.
    func testAConsultAnswerWithNoRegimenHistoryIsNeverRewritten() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("hold")
        d.set("current", forKey: "onboarding_glp1_status")

        // No regimen was ever built (the consult's all-skips path).
        // Ending nothing must not age her stated answer.
        RegimenService.endMedicationPlan(userId: userId, in: context)

        XCTAssertEqual(d.string(forKey: "onboarding_glp1_status"), "current")
    }

    // MARK: - BRACES: record-aware reads, no chokepoint ran

    func testProteinFloorFollowsTheRecordWithoutTheConsultKey() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("floor")
        d.removeObject(forKey: "onboarding_glp1_status")
        seedRegimenRow(userId: userId, authority: "self", in: context)
        seedWeight(70, userId: userId, in: context)

        let targets = TargetsService.current(userId: userId, in: context)

        // 70 kg on the GLP-1 branch: min(140, max(min(90, 112), 112))
        // = 112 → 110 after the 5 g grain. The default branch would
        // say 85 — the wrong floor for a body on appetite suppression.
        XCTAssertEqual(
            targets.proteinG, 110,
            "an active medication regimen on the record must select the lean-mass-first floor even when no consult key exists"
        )
    }

    func testACareTeamRegimenAloneCarriesTheGLP1Floor() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("care")
        d.removeObject(forKey: "onboarding_glp1_status")
        seedRegimenRow(userId: userId, authority: "care_team", in: context)
        seedWeight(70, userId: userId, in: context)

        let targets = TargetsService.current(userId: userId, in: context)

        XCTAssertEqual(
            targets.proteinG, 110,
            "a clinician-assigned regimen is still medication support; the clinic door writes no consult keys and must not need to"
        )
    }

    // Control (passes before AND after): no record, no key → default.
    func testNoRegimenAndNoKeyStaysTheDefaultFloor() {
        let context = TestModelContainer.shared.mainContext
        let userId = user("none")
        d.removeObject(forKey: "onboarding_glp1_status")
        seedWeight(70, userId: userId, in: context)

        let targets = TargetsService.current(userId: userId, in: context)

        XCTAssertEqual(targets.proteinG, 85)
    }

    // MARK: - The pure derivation (new law, pinned at birth)

    func testChapterDerivationTruthTable() {
        // The record wins whatever the key says; the key still counts
        // alone; maintenance yields only when neither speaks.
        XCTAssertEqual(
            Chapter.derive(glp1StatusKey: "", isMaintenanceMode: false,
                           hasActiveMedicationRegimen: true),
            .onMedication
        )
        XCTAssertEqual(
            Chapter.derive(glp1StatusKey: "past", isMaintenanceMode: true,
                           hasActiveMedicationRegimen: true),
            .onMedication
        )
        XCTAssertEqual(
            Chapter.derive(glp1StatusKey: "current", isMaintenanceMode: false,
                           hasActiveMedicationRegimen: false),
            .onMedication
        )
        XCTAssertEqual(
            Chapter.derive(glp1StatusKey: "none", isMaintenanceMode: true,
                           hasActiveMedicationRegimen: false),
            .keeping
        )
        XCTAssertEqual(
            Chapter.derive(glp1StatusKey: "considering", isMaintenanceMode: false,
                           hasActiveMedicationRegimen: false),
            .losing
        )
    }
}
