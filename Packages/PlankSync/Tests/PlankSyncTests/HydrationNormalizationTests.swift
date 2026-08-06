import XCTest
import SwiftData
@testable import PlankSync

// MARK: - HydrationNormalizationTests
//
// Postgres uuid columns come back lowercase from PostgREST while
// locally-created rows carry uppercase UUID().uuidString values, and
// Swift String == is case-sensitive. THE BUG this pins: hydrates that
// stored row.user_id verbatim produced rows invisible to every reader
// (they all filter on the uppercase auth uid), and the plan dedupe that
// compared ids case-sensitively re-inserted the same cloud plan as a
// duplicate local row. These tests hold the three rules that fix it:
//   1. inserts store the uppercase userId param, never row.user_id;
//   2. uuid-typed ids/pointers normalize to uppercase on insert;
//   3. dedupe is case-insensitive, so the same cloud row never lands
//      twice (insert-only semantics intact).
//
// ONE ModelContainer for the whole class + the full PlankSync model
// list. A second in-memory container in the same process hangs, and a
// subset schema crashes (see plankAITests/ReattributionTests for the
// original discovery). Tests share the store, so every test uses its
// own ids.

@MainActor
final class HydrationNormalizationTests: XCTestCase {

    static let container: ModelContainer = {
        try! ModelContainer(
            for: UserRecord.self, SessionLogRecord.self, DayProgressRecord.self,
                SessionRatingRecord.self, WeightLogRecord.self,
                ExerciseRecord.self, ExerciseCalibrationRecord.self,
                ProgramPlanRecord.self, ProgramDayCheckRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()

    private var context: ModelContext { Self.container.mainContext }

    /// The auth uid as Swift renders it (UUID().uuidString is uppercase).
    private let userUpper = "AAAA1111-BBBB-2222-CCCC-333344445555"
    /// The same uid as PostgREST returns it from a uuid column.
    private var userLower: String { userUpper.lowercased() }

    // MARK: - Defect 1: hydrated rows must store the uppercase userId

    func testHydratedWeightLogStoresUppercaseUserId() throws {
        let rows = [WeightLogHydrateRow(
            id: "WL-CASE-1", user_id: userLower, weight_kg: 74.2,
            logged_at: "2026-07-01T08:00:00Z", source: "manual"
        )]
        SyncService.applyHydratedWeightLogs(rows, userId: userUpper, context: context)

        let log = try fetchWeightLog(id: "WL-CASE-1")
        XCTAssertEqual(log?.userId, userUpper,
            "a hydrated weigh-in must carry the uppercase uid or the trend chart's user filter never sees it")
        XCTAssertEqual(log?.pendingUpsert, false, "server rows never push back")

        // Insert-only: a second pass must not duplicate.
        SyncService.applyHydratedWeightLogs(rows, userId: userUpper, context: context)
        XCTAssertEqual(try countWeightLogs(id: "WL-CASE-1"), 1)
    }

    func testHydratedPlanNormalizesUserIdAndUuidPointers() throws {
        let planId = "5D7C0000-1111-2222-3333-00000000AAAA"
        let parentId = "5D7C0000-1111-2222-3333-00000000BBBB"
        let rows = [ProgramPlanHydrateRow(
            id: planId.lowercased(), user_id: userLower,
            start_date: "2026-06-01", goal_date: "2026-10-19",
            total_days: 140, current_weight_kg: 74, goal_weight_kg: 65,
            intensity_tier: "medium", phase: "active",
            parent_plan_id: parentId.lowercased(),
            archived_at: nil, completed_at: nil
        )]
        SyncService.applyHydratedProgramPlans(rows, userId: userUpper, context: context)

        let plan = try fetchPlan(id: planId)
        XCTAssertNotNil(plan, "the plan must land under the UPPERCASE id readers join on")
        XCTAssertEqual(plan?.userId, userUpper,
            "a hydrated plan must carry the uppercase uid or ProgramService.activePlan never finds it (day-1 reset)")
        XCTAssertEqual(plan?.parentPlanId, parentId,
            "the plan-chain pointer is a uuid column too; it must normalize with the ids")
        XCTAssertEqual(plan?.totalDays, 140)
    }

    func testHydratedDayCheckNormalizesUserIdAndPlanPointer() throws {
        let planId = "5D7C0000-1111-2222-3333-00000000CCCC"
        let rows = [ProgramDayCheckHydrateRow(
            id: "CHECK-CASE-1", user_id: userLower,
            program_plan_id: planId.lowercased(), program_day: 5,
            item_key: "weigh_in", state: "complete", completed_at: nil
        )]
        SyncService.applyHydratedProgramDayChecks(rows, userId: userUpper, context: context)

        let check = try fetchCheck(id: "CHECK-CASE-1")
        XCTAssertEqual(check?.userId, userUpper)
        XCTAssertEqual(check?.programPlanId, planId,
            "the check must point at the plan's normalized uppercase id or the day's kept state goes dark")

        // Insert-only: re-running must not duplicate (text id, exact match).
        SyncService.applyHydratedProgramDayChecks(rows, userId: userUpper, context: context)
        XCTAssertEqual(try countChecks(id: "CHECK-CASE-1"), 1)
    }

    func testHydratedSessionRatingStoresUppercaseUserId() throws {
        let rows = [SessionRatingHydrateRow(
            id: "RATING-CASE-1", user_id: userLower,
            session_log_id: "SESSION-X", rating: 4, tags: ["loved_it"],
            created_at: Date(timeIntervalSince1970: 1_780_000_000)
        )]
        SyncService.applyHydratedSessionRatings(rows, userId: userUpper, context: context)

        let rating = try fetchRating(id: "RATING-CASE-1")
        XCTAssertEqual(rating?.userId, userUpper)
        XCTAssertEqual(rating?.rating, 4)
        XCTAssertEqual(rating?.pendingUpsert, false)

        SyncService.applyHydratedSessionRatings(rows, userId: userUpper, context: context)
        XCTAssertEqual(try countRatings(id: "RATING-CASE-1"), 1)
    }

    // MARK: - Defect 2: case-insensitive plan dedupe

    func testPlanDedupeIsCaseInsensitiveAgainstLocalUppercaseRow() throws {
        // The exact production shape: enrollment created the plan locally
        // with an uppercase id, pushed it, and the hydrate returns the
        // SAME plan with a lowercase id from the uuid column.
        let planId = "5D7C0000-1111-2222-3333-00000000DDDD"
        let local = ProgramPlanRecord(
            id: planId, userId: userUpper,
            startDate: .now, goalDate: .now, totalDays: 90, intensityTier: "soft"
        )
        local.pendingUpsert = false
        context.insert(local)
        try context.save()

        let rows = [ProgramPlanHydrateRow(
            id: planId.lowercased(), user_id: userLower,
            start_date: "2026-07-20", goal_date: "2026-10-18",
            total_days: 90, current_weight_kg: nil, goal_weight_kg: nil,
            intensity_tier: "soft", phase: "active",
            parent_plan_id: nil, archived_at: nil, completed_at: nil
        )]
        SyncService.applyHydratedProgramPlans(rows, userId: userUpper, context: context)

        XCTAssertEqual(try countPlans(idCaseInsensitive: planId), 1,
            "the lowercase cloud echo of a local plan must dedupe, not insert a duplicate row")
        XCTAssertEqual(try fetchPlan(id: planId)?.userId, userUpper)
    }

    // MARK: - Casing heal for rows a pre-fix hydrate stored lowercase

    func testPreFixLowercasePlanRowIsRecasedInPlace() throws {
        // A store hydrated before the fix: the plan sits under a
        // lowercase id + lowercase userId, invisible to every reader.
        let planId = "5D7C0000-1111-2222-3333-00000000EEEE"
        let stranded = ProgramPlanRecord(
            id: planId.lowercased(), userId: userLower,
            startDate: .now, goalDate: .now, totalDays: 75, intensityTier: "medium"
        )
        stranded.pendingUpsert = false
        context.insert(stranded)
        try context.save()

        let rows = [ProgramPlanHydrateRow(
            id: planId.lowercased(), user_id: userLower,
            start_date: "2026-05-01", goal_date: "2026-07-15",
            total_days: 75, current_weight_kg: nil, goal_weight_kg: nil,
            intensity_tier: "medium", phase: "active",
            parent_plan_id: nil, archived_at: nil, completed_at: nil
        )]
        SyncService.applyHydratedProgramPlans(rows, userId: userUpper, context: context)

        XCTAssertEqual(try countPlans(idCaseInsensitive: planId), 1, "heal in place, never duplicate")
        let healed = try fetchPlan(id: planId)
        XCTAssertEqual(healed?.userId, userUpper, "the stranded row must surface for readers")
        XCTAssertEqual(healed?.totalDays, 75, "data fields stay untouched (insert-only semantics)")
    }

    // MARK: - Fetch helpers

    private func fetchWeightLog(id: String) throws -> WeightLogRecord? {
        try context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.id == id })).first
    }

    private func countWeightLogs(id: String) throws -> Int {
        try context.fetchCount(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.id == id }))
    }

    private func fetchPlan(id: String) throws -> ProgramPlanRecord? {
        try context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.id == id })).first
    }

    private func countPlans(idCaseInsensitive id: String) throws -> Int {
        try context.fetch(FetchDescriptor<ProgramPlanRecord>())
            .filter { $0.id.caseInsensitiveCompare(id) == .orderedSame }
            .count
    }

    private func fetchCheck(id: String) throws -> ProgramDayCheckRecord? {
        try context.fetch(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.id == id })).first
    }

    private func countChecks(id: String) throws -> Int {
        try context.fetchCount(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.id == id }))
    }

    private func fetchRating(id: String) throws -> SessionRatingRecord? {
        try context.fetch(FetchDescriptor<SessionRatingRecord>(
            predicate: #Predicate { $0.id == id })).first
    }

    private func countRatings(id: String) throws -> Int {
        try context.fetchCount(FetchDescriptor<SessionRatingRecord>(
            predicate: #Predicate { $0.id == id }))
    }
}
