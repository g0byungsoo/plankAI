import XCTest
@testable import PlankFood

// MARK: - FoodLogPersisterTests
//
// 2026-07-25 uuid-case + reattribution fixes. Postgres normalizes uuid
// columns to lowercase while locally-minted ids are uppercase
// (UUID().uuidString), so every compare in the persister has to be
// case-insensitive. Before the fix, mergeRemote re-inserted a
// photo-less lowercase twin of every local entry on each re-login, and
// reattributeEntries silently dropped sugar + itemsDetail on the
// sign-in merge.
//
// Every test points the JSONL store at a scratch temp file via
// debugResetStore so nothing touches the real journal.

@MainActor
final class FoodLogPersisterTests: XCTestCase {

    private var scratch: URL!

    override func setUp() async throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("FoodLogPersisterTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: scratch, withIntermediateDirectories: true
        )
        FoodLogPersister.debugResetStore(
            to: scratch.appendingPathComponent("entries.jsonl")
        )
    }

    override func tearDown() async throws {
        FoodLogPersister.debugResetStore(to: nil)
        try? FileManager.default.removeItem(at: scratch)
    }

    private func seed(
        id: String, userId: String, loggedAt: Date = .now, kcal: Double = 430,
        sugar: Double = 0, title: String = "scrambled eggs",
        itemsDetail: [FoodLogPersister.ItemDetail]? = nil,
        corrections: [String]? = nil
    ) {
        FoodLogPersister.debugSeed(
            id: id, userId: userId, loggedAt: loggedAt, kcal: kcal,
            protein: 25, carbs: 30, fat: 12, fiber: 4, sugar: sugar,
            title: title, source: "photo", itemsDetail: itemsDetail,
            corrections: corrections
        )
    }

    // MARK: - HER OWN SENTENCES COME BACK OUT OF THE RECORD
    //
    // E4 shipped corrections that PERSIST; only the WRITE half shipped.
    // The public DTO every food surface reads through had no field for
    // them, so a correction could never be shown again — the most
    // valuable bytes in a food record were the one thing the record
    // could not read.

    func testACorrectionSurvivesIntoThePublicRecord() {
        let userId = UUID().uuidString
        seed(id: UUID().uuidString, userId: userId,
             corrections: ["it was a large, not a medium"])

        let entry = FoodLogPersister.allEntries(userId: userId).first
        XCTAssertEqual(entry?.corrections, ["it was a large, not a medium"])
        XCTAssertEqual(entry?.wasCorrected, true)
    }

    func testAnUntouchedPlateCarriesNoCorrectionAndClaimsNone() {
        let userId = UUID().uuidString
        seed(id: UUID().uuidString, userId: userId)
        let entry = FoodLogPersister.allEntries(userId: userId).first
        XCTAssertNil(entry?.corrections)
        XCTAssertEqual(entry?.wasCorrected, false)
    }

    /// An empty array is not a correction. A plate that went through the
    /// fix flow and had every sentence reverted must not claim she fixed
    /// it.
    func testAnEmptyCorrectionListIsNotACorrection() {
        let userId = UUID().uuidString
        seed(id: UUID().uuidString, userId: userId, corrections: [])
        XCTAssertEqual(
            FoodLogPersister.allEntries(userId: userId).first?.wasCorrected, false
        )
    }

    /// THE RECORD MUST COMPOUND, NOT DECAY. A relog copies the corrected
    /// NUMBERS, so it has to copy the fact that they were corrected —
    /// otherwise `priorObservations` reads the new row as uncorrected and
    /// relogging a dish she taught jeni about dilutes her own knowledge
    /// through the cheapest door in the product.
    func testARelogCarriesTheCorrectionSoThePriorSurvives() {
        let userId = UUID().uuidString
        seed(id: UUID().uuidString, userId: userId, title: "chicken poke bowl",
             corrections: ["it was a large, not a medium"])
        guard let original = FoodLogPersister.allEntries(userId: userId).first
        else { return XCTFail("seed did not land") }

        FoodLogPersister.relog(original, userId: userId)

        let all = FoodLogPersister.allEntries(userId: userId)
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.allSatisfy { $0.wasCorrected },
                      "the relog dropped her correction")
        // The flywheel's own view of the record: BOTH rows are corrected
        // observations of the same dish, so the prior still speaks.
        let priors = PlatePriors.index(
            FoodLogPersister.priorObservations(userId: userId)
        )
        XCTAssertNotNil(priors["chicken poke bowl"])
        XCTAssertEqual(priors["chicken poke bowl"]?.timesCorrected, 2)
    }

    /// The sign-in merge has now dropped a newly-added field THREE times
    /// (sugar + itemsDetail in 2026-07-25, sodium + satFat in 2026-08-08,
    /// corrections in 2026-08-12). Pin the whole shape.
    func testTheSignInMergeKeepsHerCorrections() {
        let oldId = UUID().uuidString
        let newId = UUID().uuidString
        seed(id: UUID().uuidString, userId: oldId, sugar: 9,
             corrections: ["no avocado on this one"])

        FoodLogPersister.reattributeEntries(from: oldId, to: newId)

        let carried = FoodLogPersister.allEntries(userId: newId)
        XCTAssertEqual(carried.count, 1)
        XCTAssertEqual(carried[0].corrections, ["no avocado on this one"])
        XCTAssertEqual(carried[0].sugar, 9)
    }

    // MARK: mergeRemote uuid-case dedupe

    /// The re-login hydration bug: the server echoes a local entry back
    /// with its id lowercased. That is the SAME entry — it must be
    /// skipped, not re-inserted as a photo-less duplicate.
    func testMergeRemoteSkipsLowercaseTwinOfLocalEntry() {
        let localId = UUID().uuidString   // uppercase, like a real mint
        let userId = UUID().uuidString
        seed(id: localId, userId: userId, sugar: 9)

        FoodLogPersister.mergeRemote([
            FoodLogPersister.SyncableEntry(
                id: localId.lowercased(), userId: userId.lowercased(),
                loggedAt: .now, kcal: 430, protein: 25, carbs: 30,
                fat: 12, fiber: 4, title: "scrambled eggs", source: "photo"
            )
        ])

        let entries = FoodLogPersister.allEntries(userId: userId)
        XCTAssertEqual(entries.count, 1, "lowercase twin must NOT re-insert")
        XCTAssertEqual(entries[0].id, localId, "the original local entry survives")
        XCTAssertEqual(entries[0].sugar, 9, "local fidelity (sugar) is kept, not the stripped remote row")
    }

    /// Guard the other side: a genuinely new remote row still lands.
    func testMergeRemoteInsertsGenuinelyNewRow() {
        let userId = UUID().uuidString
        seed(id: UUID().uuidString, userId: userId)

        FoodLogPersister.mergeRemote([
            FoodLogPersister.SyncableEntry(
                id: UUID().uuidString.lowercased(), userId: userId.lowercased(),
                loggedAt: .now, kcal: 620, protein: 40, carbs: 55,
                fat: 20, fiber: 6, title: "chipotle chicken bowl", source: "photo"
            )
        ])

        XCTAssertEqual(FoodLogPersister.allEntries(userId: userId).count, 2)
    }

    /// The read paths that were still case-sensitive (todayAndWeekly,
    /// last7DaysKcal, allSyncableEntries) must see entries whose stored
    /// userId casing differs from the query's.
    func testUserScopedReadsAreCaseInsensitive() {
        let userId = UUID().uuidString   // stored uppercase
        seed(id: UUID().uuidString, userId: userId, kcal: 500)

        let lower = userId.lowercased()
        XCTAssertEqual(FoodLogPersister.todayAndWeekly(userId: lower).today, 500)
        XCTAssertEqual(FoodLogPersister.last7DaysKcal(userId: lower).last?.kcal, 500)
        XCTAssertEqual(FoodLogPersister.allSyncableEntries(userId: lower).count, 1)
    }

    // MARK: reattribution keeps full fidelity

    /// The sign-in merge re-keys entries to the new account. Sugar and
    /// itemsDetail were dropped in the rebuild before 2026-07-25 — they
    /// must survive, alongside the fresh-id invariant.
    func testReattributionCarriesSugarAndItemsDetail() {
        let oldUser = UUID().uuidString
        let newUser = UUID().uuidString
        let originalId = UUID().uuidString
        let detail = [
            FoodLogPersister.ItemDetail(
                name: "scrambled eggs", portionG: 120, kcal: 180,
                protein: 13, carbs: 2, fat: 12
            ),
            FoodLogPersister.ItemDetail(
                name: "sourdough toast", portionG: 60, kcal: 160,
                protein: 6, carbs: 30, fat: 1
            ),
        ]
        seed(id: originalId, userId: oldUser, sugar: 11, itemsDetail: detail)

        // Lowercased oldId exercises the case-insensitive userId match
        // (Postgres-cased uid vs locally-cased entries).
        FoodLogPersister.reattributeEntries(
            from: oldUser.lowercased(), to: newUser
        )

        XCTAssertTrue(FoodLogPersister.allEntries(userId: oldUser).isEmpty)
        let moved = FoodLogPersister.allEntries(userId: newUser)
        XCTAssertEqual(moved.count, 1)
        XCTAssertEqual(moved[0].sugar, 11, "sugar must survive the re-key")
        XCTAssertEqual(moved[0].itemsDetail, detail, "itemsDetail must survive the re-key")
        XCTAssertNotEqual(moved[0].id, originalId, "fresh-id invariant (clean INSERT under the new account)")
    }
}
