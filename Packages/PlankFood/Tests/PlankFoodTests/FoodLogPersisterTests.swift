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

    // MARK: - THE BACK-DATED PLATE (v25 §34)
    //
    // Every capture path stamps `Date()`, so a plate could only ever
    // land on the day it was LOGGED. A dinner logged at 12:10am went on
    // tomorrow and took 700 kcal off the day it actually fed; a meal
    // remembered the next morning could not be filed at all. Three
    // sessions named this as the largest remaining boring gap.

    private func cal() -> Calendar { Calendar(identifier: .gregorian) }

    func testAPlateMovesToTheDaySheAteIt() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        // 12:10am today — the after-midnight dinner.
        let loggedAt = c.date(bySettingHour: 0, minute: 10, second: 0,
                              of: c.startOfDay(for: .now))!
        seed(id: id, userId: userId, loggedAt: loggedAt, kcal: 700,
             title: "salmon and rice")
        let yesterday = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: .now))!

        XCTAssertTrue(
            FoodLogPersister.setLoggedDay(id: id, to: yesterday, calendar: c)
        )

        let entry = FoodLogPersister.allEntries(userId: userId).first
        XCTAssertNotNil(entry)
        XCTAssertTrue(c.isDate(entry!.loggedAt, inSameDayAs: yesterday),
                      "the plate must land on the day she ate it")
        // Today is short by exactly that plate, and it is not lost.
        XCTAssertEqual(FoodLogPersister.todayMacros(userId: userId).kcal, 0)
        XCTAssertEqual(FoodLogPersister.allEntries(userId: userId).count, 1)
    }

    /// The plate is the SAME plate. The id is what the photograph is
    /// keyed by (`FoodPhotoStore`) and what the cloud row upserts on, so
    /// a re-date that minted a new id would orphan the picture and write
    /// a duplicate row.
    func testMovingAPlateKeepsItsIdenityAndEveryNumber() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        let detail = [
            FoodLogPersister.ItemDetail(
                name: "salmon", portionG: 140, kcal: 280,
                protein: 34, carbs: 0, fat: 15, sodiumMg: 90, satFatG: 3
            )
        ]
        seed(id: id, userId: userId, kcal: 610, sugar: 4,
             title: "salmon and rice", itemsDetail: detail,
             corrections: ["it was a bigger piece"])
        let twoDaysAgo = c.date(byAdding: .day, value: -2, to: c.startOfDay(for: .now))!

        XCTAssertTrue(FoodLogPersister.setLoggedDay(id: id, to: twoDaysAgo, calendar: c))

        let moved = FoodLogPersister.allEntries(userId: userId)
        XCTAssertEqual(moved.count, 1)
        XCTAssertEqual(moved[0].id, id, "same plate, same id")
        XCTAssertEqual(moved[0].kcal, 610)
        XCTAssertEqual(moved[0].sugar, 4)
        XCTAssertEqual(moved[0].itemsDetail, detail)
        XCTAssertEqual(moved[0].corrections, ["it was a bigger piece"],
                       "her own words must ride the move")
        XCTAssertEqual(moved[0].title, "salmon and rice")
        XCTAssertEqual(moved[0].source, "photo", "the door it came through does not change")
    }

    /// She ate at 9:40pm whichever day we file it under. Inventing a
    /// time would be inventing a fact, and the plate page prints it.
    func testTheClockTimeSurvivesTheMove() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        let at = c.date(bySettingHour: 21, minute: 40, second: 0,
                        of: c.startOfDay(for: .now))!
        seed(id: id, userId: userId, loggedAt: at)
        let yesterday = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: .now))!

        XCTAssertTrue(FoodLogPersister.setLoggedDay(id: id, to: yesterday, calendar: c))

        let moved = FoodLogPersister.allEntries(userId: userId)[0]
        XCTAssertEqual(c.component(.hour, from: moved.loggedAt), 21)
        XCTAssertEqual(c.component(.minute, from: moved.loggedAt), 40)
    }

    /// A plate cannot have been eaten tomorrow. A forward-dated entry
    /// would silently subtract itself from today's total and reappear
    /// out of nowhere, which is the "nothing important disappears" law
    /// broken from the other direction.
    func testAPlateCannotBeMovedIntoTheFuture() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        seed(id: id, userId: userId, kcal: 500)
        let tomorrow = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: .now))!

        XCTAssertFalse(FoodLogPersister.setLoggedDay(id: id, to: tomorrow, calendar: c),
                       "a future day must be refused")
        XCTAssertEqual(FoodLogPersister.todayMacros(userId: userId).kcal, 500,
                       "the refusal must leave the plate exactly where it was")
    }

    /// Re-filing a plate on the day it already sits on is not a move.
    /// Returning true would let a caller claim a repair that did not
    /// happen — and it would rewrite the JSONL for nothing.
    func testMovingAPlateToItsOwnDayIsNotAMove() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        seed(id: id, userId: userId)
        XCTAssertFalse(
            FoodLogPersister.setLoggedDay(id: id, to: .now, calendar: c)
        )
    }

    func testMovingAPlateThatIsNotOnFileChangesNothing() {
        let userId = UUID().uuidString
        seed(id: UUID().uuidString, userId: userId, kcal: 420)
        let c = cal()
        let yesterday = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: .now))!
        XCTAssertFalse(
            FoodLogPersister.setLoggedDay(id: "not-a-real-id", to: yesterday, calendar: c)
        )
        XCTAssertEqual(FoodLogPersister.todayMacros(userId: userId).kcal, 420)
    }

    /// A moved plate must be pushed, or the correction lives on one
    /// device. `mergeRemote` is insert-only by id, so the server row is
    /// an UPDATE of `logged_at` and the old date can never come back.
    func testAMovedPlateIsQueuedForTheServerWithItsNewDay() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        seed(id: id, userId: userId)
        var pushed: [FoodLogPersister.SyncableEntry] = []
        FoodLogPersister.onEntryPersisted = { pushed.append($0) }
        defer { FoodLogPersister.onEntryPersisted = nil }

        let yesterday = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: .now))!
        XCTAssertTrue(FoodLogPersister.setLoggedDay(id: id, to: yesterday, calendar: c))

        XCTAssertEqual(pushed.count, 1)
        XCTAssertEqual(pushed[0].id, id)
        XCTAssertTrue(c.isDate(pushed[0].loggedAt, inSameDayAs: yesterday))
    }

    /// The whole point, stated as the day totals: yesterday gains what
    /// today loses, and the record's size never changes.
    func testTheDayTotalsFollowThePlate() {
        let userId = UUID().uuidString
        let id = UUID().uuidString
        let c = cal()
        seed(id: id, userId: userId, kcal: 700)
        seed(id: UUID().uuidString, userId: userId, kcal: 300)
        XCTAssertEqual(FoodLogPersister.todayMacros(userId: userId).kcal, 1000)

        let yesterday = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: .now))!
        XCTAssertTrue(FoodLogPersister.setLoggedDay(id: id, to: yesterday, calendar: c))

        XCTAssertEqual(FoodLogPersister.todayMacros(userId: userId).kcal, 300)
        let byDay = FoodLogPersister.last7DaysKcal(userId: userId)
        XCTAssertEqual(byDay.last?.kcal, 300, "today")
        XCTAssertEqual(byDay[byDay.count - 2].kcal, 700, "yesterday")
        XCTAssertEqual(FoodLogPersister.allEntries(userId: userId).count, 2)
    }
}
