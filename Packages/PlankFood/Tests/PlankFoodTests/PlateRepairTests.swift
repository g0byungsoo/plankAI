import XCTest
@testable import PlankFood

// MARK: - PlateRepairTests (p61)
//
// THE FILED PLATE IS CORRECTABLE. Until now "add it" was a one-way
// door: the persister's public mutation set was persist / relog /
// re-date / delete, so the only remedy for a wrong number was
// destroying the record. These pin the round trip: entry → editable
// plate → edit → the SAME entry, updated in place, by the SAME
// arithmetic `persist` uses.

@MainActor
final class PlateRepairTests: XCTestCase {

    private var scratch: URL!

    override func setUp() async throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlateRepairTests-\(UUID().uuidString)",
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

    /// Seeds through the REAL persist path, so the entry carries
    /// exactly what a scanned plate carries (detail incl. p61's
    /// per-item fiber/sugar).
    @discardableResult
    private func seedDetailed(id: String, userId: String) -> String {
        let items = [
            CapturedItem(
                id: "a", name: "jeyuk bokkeum",
                portionGrams: 400, portionGramsLow: 320, portionGramsHigh: 480,
                usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
                confidence: 0.9, notes: nil,
                kcal: 800, proteinG: 60, carbsG: 40, fatG: 35, fiberG: 6,
                nutritionSource: .llmDirect, sugarG: 8, sodiumMg: 900
            ),
            CapturedItem(
                id: "b", name: "steamed rice",
                portionGrams: 200, portionGramsLow: 160, portionGramsHigh: 240,
                usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
                confidence: 0.9, notes: nil,
                kcal: 260, proteinG: 5, carbsG: 56, fatG: 1, fiberG: 1,
                nutritionSource: .llmDirect, sugarG: 0, sodiumMg: 5
            ),
        ]
        var food = CapturedFood(
            items: items, plateType: .mixed, source: .photo,
            confidence: 0.9, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: 1000, kcalHigh: 1150
        )
        food.appliedCorrections = ["it was a large, not a medium"]
        _ = id
        return (try? FoodLogPersister.persist(food, userId: userId)) ?? ""
    }

    // MARK: - Reconstruction

    func testAFiledPlateRebuildsItemByItem() throws {
        let userId = UUID().uuidString
        seedDetailed(id: "r1", userId: userId)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)

        let food = FoodLogPersister.repairFood(from: entry)
        XCTAssertEqual(food.items.count, 2)
        XCTAssertEqual(food.items[0].name, "jeyuk bokkeum")
        XCTAssertEqual(food.items[0].kcal, 800)
        XCTAssertEqual(food.items[0].portionGrams, 400)
        XCTAssertEqual(food.items[0].fiberG, 6, "p61 detail carries fiber now")
        XCTAssertEqual(food.appliedCorrections, ["it was a large, not a medium"],
                       "her sentences ride the reconstruction")
    }

    /// A pre-detail entry (older row, cloud-restored row) rebuilds as
    /// ONE item carrying the plate's numbers, with no invented mass.
    func testANoDetailEntryRebuildsAsOneDirectItem() {
        let userId = UUID().uuidString
        FoodLogPersister.debugSeed(
            id: "r2", userId: userId, loggedAt: .now, kcal: 640,
            protein: 30, carbs: 50, fat: 22, fiber: 4, sugar: 12,
            title: "burrito bowl", source: "photo", itemsDetail: nil,
            corrections: nil
        )
        let entry = FoodLogPersister.allEntries(userId: userId).first!
        let food = FoodLogPersister.repairFood(from: entry)
        XCTAssertEqual(food.items.count, 1)
        XCTAssertEqual(food.items[0].name, "burrito bowl")
        XCTAssertEqual(food.items[0].kcal, 640)
        XCTAssertEqual(food.items[0].portionGrams, 0, "no mass is invented")
    }

    // MARK: - The round trip

    func testHalvingThePlateHalvesTheRecordInPlace() throws {
        let userId = UUID().uuidString
        seedDetailed(id: "r3", userId: userId)
        let before = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)

        var session = PlateEditSession(food: FoodLogPersister.repairFood(from: before))
        session.setFraction(0.5)
        XCTAssertTrue(FoodLogPersister.updateEntry(
            id: before.id, with: session.rebuiltFood()
        ))

        let after = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(after.id, before.id, "same plate, same identity")
        XCTAssertEqual(after.edits?.count, 1,
                       "one fix, one note — never printed twice (film-caught)")
        XCTAssertEqual(after.loggedAt, before.loggedAt, "the day never moves on a repair")
        XCTAssertEqual(after.kcal, 530, accuracy: 0.001,
                       "1060 halved, by the one energy rule")
        XCTAssertEqual(after.protein, 32.5, accuracy: 0.001)
        XCTAssertEqual(after.fiber, 3.5, accuracy: 0.001,
                       "per-item fiber re-derives from the parts")
        XCTAssertEqual(after.corrections, before.corrections,
                       "her sentences survive the repair")
        XCTAssertEqual(after.source, before.source, "the door never changes")
    }

    func testRemovingAnItemRewritesTitleAndNumbers() throws {
        let userId = UUID().uuidString
        seedDetailed(id: "r4", userId: userId)
        let before = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(before.title, "jeyuk bokkeum + 1 more")

        var session = PlateEditSession(food: FoodLogPersister.repairFood(from: before))
        let riceId = session.items.first { $0.name == "steamed rice" }!.id
        session.remove(riceId)
        XCTAssertTrue(FoodLogPersister.updateEntry(
            id: before.id, with: session.rebuiltFood()
        ))

        let after = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(after.title, "jeyuk bokkeum",
                       "the row renames when its parts change")
        XCTAssertEqual(after.kcal, 800, accuracy: 0.001)
        XCTAssertEqual(after.itemsDetail?.count, 1)
    }

    /// Pre-p61 rows carry fiber/sugar only as plate aggregates. A
    /// repair must not zero them (the "record made poorer because she
    /// touched it" family) — they scale with the energy edit instead.
    func testPlateAggregatesScaleWhenThePartsNeverCarriedThem() throws {
        let userId = UUID().uuidString
        FoodLogPersister.debugSeed(
            id: "r5", userId: userId, loggedAt: .now, kcal: 600,
            protein: 30, carbs: 60, fat: 20, fiber: 8, sugar: 14,
            title: "pasta night", source: "photo",
            itemsDetail: [.init(name: "pasta night", portionG: 0, kcal: 600,
                                protein: 30, carbs: 60, fat: 20)],
            corrections: nil
        )
        let before = FoodLogPersister.allEntries(userId: userId).first!
        var session = PlateEditSession(food: FoodLogPersister.repairFood(from: before))
        session.setFraction(0.5)
        XCTAssertTrue(FoodLogPersister.updateEntry(
            id: before.id, with: session.rebuiltFood()
        ))
        let after = FoodLogPersister.allEntries(userId: userId).first!
        XCTAssertEqual(after.kcal, 300, accuracy: 0.001)
        XCTAssertEqual(after.fiber, 4, accuracy: 0.001,
                       "an unmeasured aggregate follows the energy edit")
        XCTAssertEqual(after.sugar, 7, accuracy: 0.001)
    }

    func testUpdatingAPlateNotOnFileChangesNothing() {
        let userId = UUID().uuidString
        FoodLogPersister.debugSeed(
            id: "r6", userId: userId, loggedAt: .now, kcal: 420,
            protein: 20, carbs: 30, fat: 10, fiber: 3, sugar: 5,
            title: "eggs", source: "photo", itemsDetail: nil, corrections: nil
        )
        let food = StatedPlate.plate(from: .init(
            name: "x", kcal: 100, proteinG: nil, carbsG: nil, fatG: nil
        ))
        XCTAssertFalse(FoodLogPersister.updateEntry(id: "ghost", with: food))
        XCTAssertEqual(FoodLogPersister.allEntries(userId: userId).first?.kcal, 420)
    }

    /// The repair reaches the cloud row: the upsert hook fires with the
    /// repaired numbers, keyed by the SAME id.
    func testTheRepairPushesTheCloudRow() throws {
        let userId = UUID().uuidString
        seedDetailed(id: "r7", userId: userId)
        let before = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)

        var pushed: FoodLogPersister.SyncableEntry?
        let old = FoodLogPersister.onEntryPersisted
        defer { FoodLogPersister.onEntryPersisted = old }
        FoodLogPersister.onEntryPersisted = { pushed = $0 }

        var session = PlateEditSession(food: FoodLogPersister.repairFood(from: before))
        session.setFraction(0.5)
        XCTAssertTrue(FoodLogPersister.updateEntry(
            id: before.id, with: session.rebuiltFood()
        ))
        XCTAssertEqual(pushed?.id, before.id)
        XCTAssertEqual(pushed?.kcal ?? 0, 530, accuracy: 0.001)
    }
}

// MARK: - p62: a repeated identical statement prints once

extension PlateRepairTests {

    /// Film-caught (p62): the standing QA plate carried "had half of
    /// it" TWICE — one repair per walk session, each appending the
    /// identical sentence. YOUR NUMBERS is what she told jeni, not an
    /// arithmetic ledger; the same sentence twice reads as a stutter.
    /// Genuinely different statements still all survive, in order.
    func testARepeatedIdenticalEditNotePrintsOnce() throws {
        let userId = UUID().uuidString
        seedDetailed(id: "r7", userId: userId)
        let before = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)

        var first = PlateEditSession(food: FoodLogPersister.repairFood(from: before))
        first.setFraction(0.5)
        XCTAssertTrue(FoodLogPersister.updateEntry(id: before.id, with: first.rebuiltFood()))

        let mid = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        var second = PlateEditSession(food: FoodLogPersister.repairFood(from: mid))
        second.setFraction(0.5)
        XCTAssertTrue(FoodLogPersister.updateEntry(id: before.id, with: second.rebuiltFood()))

        let after = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(after.edits, ["had half of it"],
                       "the identical sentence collapses to one line")
        XCTAssertEqual(after.kcal, 265, accuracy: 0.001,
                       "the numbers still tell the arithmetic truth: half of half")
    }
}
