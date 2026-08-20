import XCTest
import SwiftData
@testable import PlankSync

// MARK: - InventedProvenanceTests
//
// v25 pass 51 — UNKNOWN STAYS UNKNOWN, at every hydrate.
//
// The write side has one law (absent → "unknown"); the read side
// carried three surviving pre-law defaults, the same family as the
// fixed food `?? "photo"`: a NULL-source weight row hydrated as
// `"manual"` — the word that means SHE TYPED IT, and the word that
// decides which author wins the day under `BodyMassImportService`'s
// per-day rule; dose events hydrated NULL as `"sheet"` (a door she
// never used) and observations as `"manual"`. This file pins the
// weight seam (the one with a pure apply function); the dose and
// observation sites carry the identical one-token fix, named in the
// pass record — their hydrates are inline network functions and
// extracting seams to unit-test a string literal is exactly the
// casual sync restructuring this pass refuses.

@MainActor
final class InventedProvenanceTests: XCTestCase {

    private var context: ModelContext {
        HydrationNormalizationTests.container.mainContext
    }

    private let userId = "AAAA1111-BBBB-2222-CCCC-P51PROVENANC"

    override func setUpWithError() throws { wipe() }
    override func tearDownWithError() throws { wipe() }

    private func wipe() {
        let uid = userId
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    private func fetch(_ id: String) -> WeightLogRecord? {
        try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    func testANullSourceWeighInHydratesAsUnknownNeverAsHers() {
        SyncService.applyHydratedWeightLogs(
            [WeightLogHydrateRow(
                id: "P51-PROV-NULL", user_id: userId.lowercased(),
                weight_kg: 74.2, logged_at: "2026-07-01T08:00:00Z",
                source: nil
            )],
            userId: userId, context: context
        )
        XCTAssertEqual(fetch("P51-PROV-NULL")?.source, "unknown",
            "a NULL source is an absence; 'manual' means SHE TYPED IT and decides which author wins the day")
    }

    /// Control — a stated source survives verbatim.
    func testAStatedSourceSurvivesTheHydrate() {
        SyncService.applyHydratedWeightLogs(
            [WeightLogHydrateRow(
                id: "P51-PROV-HK", user_id: userId.lowercased(),
                weight_kg: 74.2, logged_at: "2026-07-01T08:00:00Z",
                source: "healthkit"
            )],
            userId: userId, context: context
        )
        XCTAssertEqual(fetch("P51-PROV-HK")?.source, "healthkit")
    }

    /// A server-written logged_at (microseconds) keeps its instant —
    /// the sibling `?? .now` must never re-date history to today.
    func testAMicrosecondLoggedAtKeepsItsDay() throws {
        SyncService.applyHydratedWeightLogs(
            [WeightLogHydrateRow(
                id: "P51-PROV-TS", user_id: userId.lowercased(),
                weight_kg: 74.2,
                logged_at: "2026-07-01T08:00:00.654321+00:00",
                source: "manual"
            )],
            userId: userId, context: context
        )
        let at = try XCTUnwrap(fetch("P51-PROV-TS")?.loggedAt)
        let expected = try XCTUnwrap(WireTimestamp.parse("2026-07-01T08:00:00.654321+00:00"))
        XCTAssertEqual(at.timeIntervalSince1970,
                       expected.timeIntervalSince1970, accuracy: 1.0)
    }
}
