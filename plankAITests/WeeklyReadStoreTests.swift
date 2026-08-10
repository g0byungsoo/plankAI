import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// E1 THE SPINE — the read's record store (docs/app_v25/05_E1_SPINE
// §2). Decisions only; deterministic per-window ids; the cooldown
// reads live here.

@MainActor
final class WeeklyReadStoreTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private func freshUser(_ tag: String) -> String { "e1-read-\(tag)-\(UUID().uuidString)" }
    private let t0 = Date(timeIntervalSince1970: 1_754_000_000)
    private func daysAgo(_ d: Double) -> Date { t0.addingTimeInterval(-d * 86_400) }

    func testRecordDecisionWritesDeterministicRow() throws {
        let user = freshUser("row")
        let rec = WeeklyReadStore.recordDecision(
            windowStartDay: "2026-08-03", anchor: .doseDay,
            shown: "steps:5|protein:3", offer: .stepGoalRecalc(newGoal: 5_150, reason: "r"),
            decision: "accepted", factId: "f1",
            userId: user, now: t0, in: context
        )
        XCTAssertEqual(rec?.id, WeeklyReadRecord.deterministicId(
            userId: user, windowStartDay: "2026-08-03"
        ))
        XCTAssertEqual(rec?.offerKey, "step_goal_recalc")
        XCTAssertTrue(
            WeeklyReadStore.signedWindows(userId: user, in: context)
                .contains("2026-08-03")
        )
    }

    func testDoubleDecisionConvergesOnOneRow() throws {
        let user = freshUser("converge")
        WeeklyReadStore.recordDecision(
            windowStartDay: "2026-08-03", anchor: .enrollment, shown: nil,
            offer: .v4(.holdSteady(reason: "r")), decision: "declined",
            factId: nil, userId: user, now: t0, in: context
        )
        WeeklyReadStore.recordDecision(
            windowStartDay: "2026-08-03", anchor: .enrollment, shown: nil,
            offer: .v4(.holdSteady(reason: "r")), decision: "accepted",
            factId: nil, userId: user, now: t0.addingTimeInterval(60), in: context
        )
        let rows = try context.fetch(FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == user }
        ))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.decision, "accepted")
    }

    func testDeclinedKindsWithinCooldown() throws {
        let user = freshUser("cooldown")
        WeeklyReadStore.recordDecision(
            windowStartDay: "2026-07-27", anchor: .doseDay, shown: nil,
            offer: .stepGoalRecalc(newGoal: 5_000, reason: "r"),
            decision: "declined", factId: nil,
            userId: user, now: daysAgo(6), in: context
        )
        XCTAssertEqual(
            WeeklyReadStore.recentlyDeclinedKinds(userId: user, now: t0, in: context),
            ["step_goal_recalc"]
        )
    }

    func testDeclinedKindsExpireAfterCooldown() throws {
        let user = freshUser("expired")
        WeeklyReadStore.recordDecision(
            windowStartDay: "2026-07-01", anchor: .doseDay, shown: nil,
            offer: .stepGoalRecalc(newGoal: 5_000, reason: "r"),
            decision: "declined", factId: nil,
            userId: user, now: daysAgo(20), in: context
        )
        XCTAssertTrue(
            WeeklyReadStore.recentlyDeclinedKinds(userId: user, now: t0, in: context).isEmpty
        )
    }

    func testAcceptedNeverCoolsDown() throws {
        let user = freshUser("accepted")
        WeeklyReadStore.recordDecision(
            windowStartDay: "2026-08-03", anchor: .doseDay, shown: nil,
            offer: .stepGoalRecalc(newGoal: 5_000, reason: "r"),
            decision: "accepted", factId: "f",
            userId: user, now: daysAgo(3), in: context
        )
        XCTAssertTrue(
            WeeklyReadStore.recentlyDeclinedKinds(userId: user, now: t0, in: context).isEmpty
        )
    }

    func testUserScoping() throws {
        let a = freshUser("a")
        let b = freshUser("b")
        WeeklyReadStore.recordDecision(
            windowStartDay: "2026-08-03", anchor: .doseDay, shown: nil,
            offer: .v4(.holdSteady(reason: "r")), decision: "declined",
            factId: nil, userId: a, now: t0, in: context
        )
        XCTAssertTrue(WeeklyReadStore.signedWindows(userId: b, in: context).isEmpty)
    }
}
