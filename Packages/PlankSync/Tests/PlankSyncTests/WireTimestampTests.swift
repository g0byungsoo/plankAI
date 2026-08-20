import XCTest
import SwiftData
@testable import PlankSync

// MARK: - WireTimestampTests
//
// v25 pass 51 — A SERVER-WRITTEN TIMESTAMP MUST PARSE.
//
// Client-written `timestamptz` values are whole-second; SERVER-written
// ones (`now()` defaults, support SQL, RPCs) carry microseconds, which
// a plain ISO8601DateFormatter refuses. The proven harm: the pass-43
// production repair set `archived_at = now()` on a duplicate plan, the
// merge parsed the microsecond string to nil, `adopt(nil, \.archivedAt)`
// fired — and the plan support archived silently UN-archived on every
// hydrate. Same class: `started_at` from a column DEFAULT parsed nil,
// so `createdAt` stayed the hydration instant and the active-plan pick
// fell back to loop order — the exact defect the started_at read-back
// was shipped to fix.

@MainActor
final class WireTimestampTests: XCTestCase {

    private var context: ModelContext {
        HydrationNormalizationTests.container.mainContext
    }

    private let userId = "AAAA1111-BBBB-2222-CCCC-P51TIMESTAMP"

    override func setUpWithError() throws { wipe() }
    override func tearDownWithError() throws { wipe() }

    private func wipe() {
        let uid = userId
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    // MARK: - The parser itself

    func testBothWireShapesParseAndGarbageDoesNot() {
        XCTAssertNotNil(WireTimestamp.parse("2026-08-15T09:00:00Z"))
        XCTAssertNotNil(WireTimestamp.parse("2026-08-15T09:00:00+00:00"))
        XCTAssertNotNil(WireTimestamp.parse("2026-08-15T09:00:00.123456+00:00"),
                        "the server's own now() shape must parse")
        XCTAssertNil(WireTimestamp.parse(nil))
        XCTAssertNil(WireTimestamp.parse("not-a-timestamp"))
        let whole = WireTimestamp.parse("2026-08-15T09:00:00+00:00")
        let micro = WireTimestamp.parse("2026-08-15T09:00:00.123456+00:00")
        if let whole, let micro {
            XCTAssertEqual(micro.timeIntervalSince(whole), 0.123456, accuracy: 0.001)
        }
    }

    // MARK: - The support archive must land (the pass-43 repair)

    func testAServerSideArchiveWithMicrosecondsLandsInsteadOfUnarchiving() {
        let plan = ProgramPlanRecord(
            id: "P51-TS-ARCHIVE", userId: userId,
            startDate: .now.addingTimeInterval(-40 * 86_400),
            goalDate: .now.addingTimeInterval(80 * 86_400),
            totalDays: 119, currentWeightKg: 75, goalWeightKg: 65,
            intensityTier: "medium", phase: "active"
        )
        context.insert(plan)
        plan.pendingUpsert = false
        try? context.save()

        let row = ProgramPlanHydrateRow(
            id: "p51-ts-archive", user_id: userId.lowercased(),
            start_date: "2026-07-09", goal_date: "2026-11-05",
            total_days: 119, current_weight_kg: 75, goal_weight_kg: 65,
            intensity_tier: "medium", phase: "abandoned",
            parent_plan_id: nil,
            archived_at: "2026-08-15T09:00:00.123456+00:00",   // now() — microseconds
            completed_at: nil
        )
        ProgramPlanMerge.apply(row, to: plan)

        XCTAssertEqual(plan.phase, "abandoned")
        XCTAssertNotNil(plan.archivedAt,
            "the support-side archive parsed to nil and UN-archived the plan — the pass-43 production repair could never land")
    }

    /// And the mirror: a plan the device archived must not be
    /// UN-archived just because the echo of its own archive carries
    /// server microseconds after a round trip.
    func testALocallyArchivedPlanStaysArchivedThroughTheEcho() {
        let archivedAt = Date(timeIntervalSince1970: 1_787_000_000)
        let plan = ProgramPlanRecord(
            id: "P51-TS-ECHO", userId: userId,
            startDate: .now.addingTimeInterval(-40 * 86_400),
            goalDate: .now.addingTimeInterval(80 * 86_400),
            totalDays: 119, currentWeightKg: 75, goalWeightKg: 65,
            intensityTier: "medium", phase: "abandoned"
        )
        plan.archivedAt = archivedAt
        plan.pendingUpsert = false
        context.insert(plan)
        try? context.save()

        let row = ProgramPlanHydrateRow(
            id: "p51-ts-echo", user_id: userId.lowercased(),
            start_date: "2026-07-09", goal_date: "2026-11-05",
            total_days: 119, current_weight_kg: 75, goal_weight_kg: 65,
            intensity_tier: "medium", phase: "abandoned",
            parent_plan_id: nil,
            archived_at: "2026-08-15T09:00:00.500000+00:00",
            completed_at: nil
        )
        ProgramPlanMerge.apply(row, to: plan)
        XCTAssertNotNil(plan.archivedAt)
    }

    // MARK: - started_at with a server DEFAULT still orders plans

    func testAServerDefaultStartedAtStillBecomesTheEnrollmentMoment() throws {
        let row = ProgramPlanHydrateRow(
            id: "p51-ts-started", user_id: userId.lowercased(),
            start_date: "2026-06-01", goal_date: "2026-09-28",
            total_days: 119, current_weight_kg: 75, goal_weight_kg: 65,
            intensity_tier: "medium", phase: "active",
            parent_plan_id: nil, archived_at: nil, completed_at: nil,
            started_at: "2026-06-01T10:15:30.987654+00:00"   // column DEFAULT now()
        )
        SyncService.applyHydratedProgramPlans([row], userId: userId, context: context)

        let uid = userId
        let plan = try XCTUnwrap(
            (try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
                predicate: #Predicate { $0.userId == uid })))?.first
        )
        let expected = try XCTUnwrap(
            WireTimestamp.parse("2026-06-01T10:15:30.987654+00:00"))
        XCTAssertEqual(plan.createdAt.timeIntervalSince1970,
                       expected.timeIntervalSince1970, accuracy: 1.0,
            "a microsecond started_at parsed to nil, so createdAt stayed the hydration instant and the active-plan pick fell back to loop order")
    }
}
