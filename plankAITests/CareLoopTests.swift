import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// app v8 S4 — the patient side of the clinic loop
// (docs/app_v8/10_S4_CLINIC_LOOP.md). Reconciliation state machine,
// the care-team-first active-plan resolver, F1 masking through the
// packet, dose-join provenance, and the packet wire shape. All
// SwiftData tests share the ONE container (distinct userIds).

@MainActor
final class CareLoopTests: XCTestCase {

    private var ctx: ModelContext { TestModelContainer.shared.mainContext }

    private func uid() -> String { "s4-\(UUID().uuidString)" }

    private func selfPlan(_ userId: String, weekday: Int = 3) -> RegimenPlanRecord {
        let p = RegimenPlanRecord(
            userId: userId, kind: "medication", displayName: "my shot",
            scheduleRule: "weeklyAnchor", anchorWeekday: weekday
        )
        p.authority = "self"
        ctx.insert(p)
        try? ctx.save()
        return p
    }

    private func careTeamPlan(_ userId: String, weekday: Int = 5, name: String = "semaglutide") -> RegimenPlanRecord {
        let p = RegimenPlanRecord(
            userId: userId, kind: "medication", displayName: name,
            scheduleRule: "weeklyAnchor", anchorWeekday: weekday
        )
        p.authority = "care_team"
        p.orgId = "org-1"
        p.strengthValue = 0.5
        p.strengthUnit = "mg"
        ctx.insert(p)
        try? ctx.save()
        return p
    }

    // MARK: - active-plan resolver prefers care_team

    func testActivePlanPrefersCareTeamWhenBothActive() {
        let u = uid()
        _ = selfPlan(u, weekday: 3)
        let ct = careTeamPlan(u, weekday: 5)
        let active = RegimenService.activeMedicationPlan(userId: u, in: ctx)
        XCTAssertEqual(active?.id, ct.id, "care-team plan must lead when both are active")
        XCTAssertEqual(active?.anchorWeekday, 5)
    }

    func testSelfAndCareTeamAccessorsAreDistinct() {
        let u = uid()
        let s = selfPlan(u)
        let ct = careTeamPlan(u)
        XCTAssertEqual(RegimenService.activeSelfMedicationPlan(userId: u, in: ctx)?.id, s.id)
        XCTAssertEqual(RegimenService.activeCareTeamMedicationPlan(userId: u, in: ctx)?.id, ct.id)
    }

    // MARK: - reconciliation state machine

    func testReconciliationNoneWithoutCareTeamPlan() {
        let u = uid()
        _ = selfPlan(u)
        if case .none = CareReconciliation.state(userId: u, in: ctx) {} else {
            XCTFail("a self-only patient needs no reconciliation")
        }
    }

    func testReconciliationNeedsConfirmationThenReconciled() {
        let u = uid()
        _ = selfPlan(u)
        let ct = careTeamPlan(u)
        guard case let .needsConfirmation(plan) = CareReconciliation.state(userId: u, in: ctx) else {
            return XCTFail("an unacknowledged care-team plan needs confirmation")
        }
        XCTAssertEqual(plan.id, ct.id)

        // Confirm — writes the local ack and retires the self plan.
        CareReconciliation.confirm(plan: ct, userId: u, in: ctx)

        if case .reconciled = CareReconciliation.state(userId: u, in: ctx) {} else {
            XCTFail("after confirm the state is reconciled")
        }
        // Self plan retired (history intact — endedAt only), care-team stays.
        XCTAssertNil(RegimenService.activeSelfMedicationPlan(userId: u, in: ctx),
                     "the self plan is no longer active after confirmation")
        XCTAssertNotNil(RegimenService.activeCareTeamMedicationPlan(userId: u, in: ctx))
    }

    func testReconciliationConfirmPreservesSelfHistory() {
        let u = uid()
        let s = selfPlan(u)
        let sid = s.id
        let ct = careTeamPlan(u)
        CareReconciliation.confirm(plan: ct, userId: u, in: ctx)
        // The self record still EXISTS (ended, not deleted).
        let d = FetchDescriptor<RegimenPlanRecord>(predicate: #Predicate { $0.id == sid })
        let found = try? ctx.fetch(d).first
        XCTAssertNotNil(found, "confirming never deletes the self record")
        XCTAssertNotNil(found?.endedAt, "the self record is ended, its history preserved")
    }

    func testReconciliationFlaggedStopsReoffering() {
        let u = uid()
        let ct = careTeamPlan(u)
        CareReconciliation.markFlagged(plan: ct, userId: u, in: ctx)
        // Flagged is acknowledged → no longer needsConfirmation, but
        // the plan still composes (active resolver still returns it).
        if case .needsConfirmation = CareReconciliation.state(userId: u, in: ctx) {
            XCTFail("a flagged plan must not keep re-offering")
        }
        XCTAssertNotNil(RegimenService.activeMedicationPlan(userId: u, in: ctx),
                        "a disputed plan still composes — flagged, never deleted")
    }

    // MARK: - the patient CANNOT locally mutate a care-team plan

    func testSetShotDayRefusesCareTeamPlan() {
        let u = uid()
        let ct = careTeamPlan(u, weekday: 5)
        _ = RegimenService.setShotDay(2, userId: u, in: ctx)
        // The care-team plan's schedule is unchanged (guard holds).
        XCTAssertEqual(
            RegimenService.activeCareTeamMedicationPlan(userId: u, in: ctx)?.anchorWeekday, 5
        )
        _ = ct
    }

    func testEndMedicationRefusesCareTeamPlan() {
        let u = uid()
        _ = careTeamPlan(u)
        RegimenService.endMedicationPlan(userId: u, in: ctx)
        XCTAssertNotNil(
            RegimenService.activeCareTeamMedicationPlan(userId: u, in: ctx),
            "the patient cannot end a clinician plan locally"
        )
    }

    // MARK: - F1: self med name never leaks through the packet

    func testPacketSelfRegimenNeverLeaksName() {
        let u = uid()
        let s = selfPlan(u, weekday: 3)
        s.displayName = "ZepSecretBrand"
        s.startedAt = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        try? ctx.save()
        let packet = VisitPacketBuilder.build(userId: u, in: ctx)
        XCTAssertEqual(packet.regimen?.displayLine, "your weekly medication")
        XCTAssertEqual(packet.regimen?.authorityLabel, "self-reported")
        // Serialize and assert the brand appears nowhere.
        let data = VisitPacketPublisher.payloadData(packet, displayUnit: "lb")!
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("ZepSecretBrand"), "self medication name must never serialize")
    }

    func testPacketCareTeamRegimenRendersAssignedFacts() {
        let u = uid()
        let ct = careTeamPlan(u, weekday: 5, name: "semaglutide")
        ct.startedAt = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        try? ctx.save()
        let packet = VisitPacketBuilder.build(userId: u, in: ctx)
        XCTAssertEqual(packet.regimen?.authorityLabel, "assigned by your care team")
        XCTAssertTrue(packet.regimen?.displayLine.contains("semaglutide") ?? false)
    }

    // MARK: - dose marks stamp the ACTIVE (care-team) regimen id

    func testDoseObservationJoinsCareTeamPlan() {
        let u = uid()
        _ = selfPlan(u)
        let ct = careTeamPlan(u)
        // The id the UI stamps a dose with is the active plan's id.
        let joinId = RegimenService.activeMedicationPlanId(userId: u, in: ctx)
        XCTAssertEqual(joinId, ct.id, "future dose marks join the care-team plan")
    }

    // MARK: - the packet wire shape matches the dashboard contract

    func testPacketWireShapeEncodesUnrecordedAndUnit() throws {
        let u = uid()
        let ct = careTeamPlan(u, weekday: 5)
        ct.startedAt = Calendar.current.date(byAdding: .day, value: -21, to: .now)!
        try? ctx.save()
        let packet = VisitPacketBuilder.build(userId: u, in: ctx)
        let data = VisitPacketPublisher.payloadData(packet, displayUnit: "kg")!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["displayUnit"] as? String, "kg")
        if let regimen = obj["regimen"] as? [String: Any] {
            XCTAssertNotNil(regimen["unrecordedCount"], "unrecordedCount is explicit in the wire shape")
            XCTAssertNotNil(regimen["scheduledCount"])
        }
        XCTAssertNotNil(obj["questions"])
        XCTAssertNotNil(obj["gaps"])
    }

    // MARK: - CareModels decode (RPC response shapes)

    func testInvitationPreviewDecodesSnakeCase() throws {
        let json = """
        {"ok":true,"org_id":"o1","org_name":"Cedar","patient_label":"J","expires_at":"2026-08-01T00:00:00Z"}
        """.data(using: .utf8)!
        let p = try JSONDecoder().decode(CareInvitationPreview.self, from: json)
        XCTAssertTrue(p.ok)
        XCTAssertEqual(p.orgName, "Cedar")
        XCTAssertEqual(p.patientLabel, "J")
    }

    func testAcceptResultDecodesSoftFailure() throws {
        let json = #"{"ok":false,"reason":"invalid"}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(CareAcceptResult.self, from: json)
        XCTAssertFalse(r.ok)
        XCTAssertEqual(r.reason, "invalid")
    }

    func testCareScopeTitlesExistForAll() {
        for scope in CareScope.allCases {
            XCTAssertFalse(scope.title.isEmpty)
            XCTAssertFalse(scope.detail.isEmpty)
        }
    }
}
