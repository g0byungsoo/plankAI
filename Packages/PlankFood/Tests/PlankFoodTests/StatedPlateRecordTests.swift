import XCTest
@testable import PlankFood

// MARK: - StatedPlateRecordTests (p70)
//
// p61 shipped the stated plate ("protein bar, 190 cal, 20g protein" —
// her numbers, verbatim, nothing invented) and p69's reading refuses to
// print an unstated macro as "0 g". But the RECORD flattened absence at
// persist: the per-item ledger wrote `carbsG ?? 0`, so the plate page
// rendered "carbs 0 g · fat 0 g" and a 100% protein split bar —
// statements she never made, filed under her name.
//
// The law: **what she did not state stays absent, all the way through
// the record** — persist, the ledger, the cloud payload, the repair
// path, and the usuals reconstruction. A true stated zero is a
// statement and survives as 0; an unstated macro survives as nil.

@MainActor
final class StatedPlateRecordTests: XCTestCase {

    private var scratch: URL!

    override func setUp() async throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatedPlateRecordTests-\(UUID().uuidString)",
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

    private func statedFood(_ sentence: String) -> CapturedFood {
        guard let statement = StatedPlate.parse(sentence) else {
            XCTFail("the sentence must parse as a statement: \(sentence)")
            return CapturedFood(items: [], plateType: .single, source: .words,
                                confidence: nil, needsSecondPhoto: false,
                                secondPhotoHint: nil, kcalLow: nil, kcalHigh: nil)
        }
        return StatedPlate.plate(from: statement)
    }

    // MARK: persist — absence reaches the ledger

    func testAStatedPlatePersistsAbsenceIntoTheLedger() throws {
        let userId = UUID().uuidString
        let food = statedFood("protein bar, 190 cal, 20g protein")
        _ = try FoodLogPersister.persist(food, userId: userId)

        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        let row = try XCTUnwrap(entry.itemsDetail?.first)
        XCTAssertEqual(row.kcal, 190)
        XCTAssertEqual(row.protein, 20)
        XCTAssertNil(row.carbs, "an unstated macro must persist as absence, not 0")
        XCTAssertNil(row.fat, "an unstated macro must persist as absence, not 0")
    }

    func testTheDTODerivesAbsenceFromTheLedger() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(entry.measuredProtein, 20)
        XCTAssertNil(entry.measuredCarbs, "nobody measured carbs — the DTO must say so")
        XCTAssertNil(entry.measuredFat)
        XCTAssertFalse(entry.splitIsKnown,
                       "one stated macro is not a composition — the split bar lies")
    }

    func testAMeasuredPlateKeepsItsMacrosMeasured() throws {
        let userId = UUID().uuidString
        let item = CapturedItem(
            id: UUID().uuidString, name: "chicken bowl",
            portionGrams: 320, portionGramsLow: 280, portionGramsHigh: 360,
            usdaSearchTerms: ["chicken bowl"], preparation: nil,
            cuisineHint: nil, confidence: 0.8, notes: nil,
            kcal: 520, proteinG: 38, carbsG: 55, fatG: 14, fiberG: 6,
            nutritionSource: .llmDirect
        )
        let food = CapturedFood(
            items: [item], plateType: .single, source: .photo,
            confidence: 0.8, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: 470, kcalHigh: 570
        )
        _ = try FoodLogPersister.persist(food, userId: userId)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(entry.measuredProtein, 38)
        XCTAssertEqual(entry.measuredCarbs, 55)
        XCTAssertEqual(entry.measuredFat, 14)
        XCTAssertTrue(entry.splitIsKnown)
    }

    /// She can state a zero — "rice cake, 35 cal, 0g fat" — and a
    /// statement of zero is a statement, not an absence.
    func testAStatedZeroSurvivesAsAZero() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("rice cake, 35 cal, 0g fat"), userId: userId
        )
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(entry.measuredFat, 0, "a stated 0 is her statement — keep it")
        XCTAssertNil(entry.measuredCarbs)
    }

    // MARK: ledger-less rows — the standing 0-means-not-collected rule

    func testALedgerlessZeroReadsAsAbsence() {
        let userId = UUID().uuidString
        // "dining out" shape: energy known, macros never measured.
        FoodLogPersister.debugSeed(
            id: UUID().uuidString, userId: userId, loggedAt: .now,
            kcal: 650, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0,
            title: "dining out", source: "restaurant", itemsDetail: nil
        )
        let entry = FoodLogPersister.allEntries(userId: userId).first
        XCTAssertNil(entry?.measuredProtein)
        XCTAssertNil(entry?.measuredCarbs)
        XCTAssertNil(entry?.measuredFat)
        XCTAssertEqual(entry?.splitIsKnown, false)
    }

    func testALedgerlessMeasuredValueStaysMeasured() {
        let userId = UUID().uuidString
        FoodLogPersister.debugSeed(
            id: UUID().uuidString, userId: userId, loggedAt: .now,
            kcal: 430, protein: 25, carbs: 30, fat: 12, fiber: 4, sugar: 0,
            title: "scrambled eggs", source: "photo", itemsDetail: nil
        )
        let entry = FoodLogPersister.allEntries(userId: userId).first
        XCTAssertEqual(entry?.measuredProtein, 25)
        XCTAssertEqual(entry?.measuredCarbs, 30)
        XCTAssertEqual(entry?.splitIsKnown, true)
    }

    // MARK: the JSONL round trip — absence survives disk

    func testAbsenceSurvivesTheStoreRoundTrip() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        // Force a cold re-read of the JSONL from disk.
        let url = scratch.appendingPathComponent("entries.jsonl")
        FoodLogPersister.debugResetStore(to: url)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertNil(entry.measuredCarbs,
                     "absence must survive its own journal — a decode default of 0 re-invents the statement")
        XCTAssertEqual(entry.measuredProtein, 20)
    }

    /// Rows written before this pass carry literal numbers for every
    /// ledger field. They must decode exactly as they were written.
    func testALegacyLedgerRowDecodesItsNumbers() throws {
        let legacy = #"{"name":"toast","portionG":60,"kcal":180,"protein":5,"carbs":30,"fat":4}"#
        let row = try JSONDecoder().decode(
            FoodLogPersister.ItemDetail.self, from: Data(legacy.utf8)
        )
        XCTAssertEqual(row.carbs, 30)
        XCTAssertEqual(row.protein, 5)
    }

    func testAnAbsentMacroEncodesAsAnAbsentKey() throws {
        let row = FoodLogPersister.ItemDetail(
            name: "protein bar", portionG: 0,
            kcal: 190, protein: 20, carbs: nil, fat: nil
        )
        let data = try JSONEncoder().encode(row)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("\"carbs\""),
                       "nil must encode as an absent key, not 0 — the wire is the record")
        XCTAssertTrue(json.contains("\"protein\""))
    }

    // MARK: repair — fixing a stated plate must not invent macros

    func testRepairKeepsAbsence() throws {
        let userId = UUID().uuidString
        let id = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        // She corrects the energy by hand; carbs/fat stay unstated.
        var food = statedFood("protein bar, 210 cal, 20g protein")
        food.editNotes = ["protein bar — your numbers"]
        XCTAssertTrue(FoodLogPersister.updateEntry(id: id, with: food))

        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(entry.kcal, 210)
        XCTAssertNil(entry.measuredCarbs,
                     "a repair she made about energy must not mint a carbs statement")
    }

    // MARK: authorship — "ranges, not exact" may never hedge her numbers
    //
    // The reading knows a stated plate is HER declaration
    // (`ResultDetailCopy`: "your numbers, as you gave them") because it
    // holds `CapturedItem.nutritionSource`. The record dropped that at
    // persist, so the plate page printed the words door's generic
    // "logged from your words · ranges, not exact" over numbers she
    // stated verbatim — the reading and the plate page contradicting
    // each other about the same plate, one screen apart.

    func testAStatedPlateKeepsHerAuthorshipInTheRecord() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertEqual(entry.itemsDetail?.first?.source, "user_stated")
        XCTAssertTrue(entry.isUserStated)
    }

    func testAMeasuredPlateClaimsNoAuthorship() throws {
        let userId = UUID().uuidString
        FoodLogPersister.debugSeed(
            id: UUID().uuidString, userId: userId, loggedAt: .now,
            kcal: 430, protein: 25, carbs: 30, fat: 12, fiber: 4, sugar: 0,
            title: "scrambled eggs", source: "photo", itemsDetail: nil
        )
        let entry = FoodLogPersister.allEntries(userId: userId).first
        XCTAssertEqual(entry?.isUserStated, false,
                       "a ledger-less row must never claim she authored it")
    }

    func testAuthorshipSurvivesTheStoreRoundTrip() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        let url = scratch.appendingPathComponent("entries.jsonl")
        FoodLogPersister.debugResetStore(to: url)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertTrue(entry.isUserStated)
    }

    /// Relogging her usual must keep her authorship: the reconstruction
    /// used to set `nutritionSource: nil`, so a re-served stated plate
    /// degraded into an anonymous estimate on its second filing.
    func testAStatedUsualRelogsAsStated() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        let first = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        let usual = FoodUsuals.Usual(
            title: first.title, useCount: 3, lastAt: first.loggedAt,
            entry: first, isVerified: false
        )
        let plate = FoodUsuals.plate(from: usual, via: .words)
        XCTAssertEqual(plate.items.first?.nutritionSource, .userStated)

        _ = try FoodLogPersister.persist(plate, userId: userId)
        let relogged = try XCTUnwrap(
            FoodLogPersister.allEntries(userId: userId).first
        )
        XCTAssertTrue(relogged.isUserStated,
                      "the second filing is still her numbers")
    }

    // MARK: the editor — coherence math may not run over absence
    //
    // A stated "250 cal, 28g protein" opens the item editor with
    // absent carbs/fat shown as editable 0s. Before p70, nudging her
    // protein re-derived kcal by Atwater over those absences
    // (28→30 g rewrote her stated 250 kcal to 120), and ANY save
    // minted "carbs 0 g · fat 0 g" statements. The `plateDisagrees`
    // law names the principle: absence never testifies.

    func testTheEditorKnowsWhichFieldsAreStatements() {
        let statedItem = statedFood("cottage cheese bowl, 250 cal, 28g protein")
            .items[0]
        XCTAssertEqual(
            IngredientEditorSheet.statedAtOpen(statedItem), [.kcal, .protein]
        )
        let full = statedFood("chicken, 400 cal, 30g protein, 20g carbs, 10g fat")
            .items[0]
        XCTAssertEqual(
            IngredientEditorSheet.statedAtOpen(full),
            [.kcal, .protein, .carbs, .fat]
        )
    }

    func testCoherenceMathRequiresTheWholeComposition() {
        XCTAssertFalse(
            IngredientEditorSheet.coherenceMayRun(stated: [.kcal, .protein]),
            "Atwater over an absent macro treats the absence as a measured 0"
        )
        XCTAssertTrue(
            IngredientEditorSheet.coherenceMayRun(
                stated: [.kcal, .protein, .carbs, .fat]
            )
        )
        XCTAssertTrue(
            IngredientEditorSheet.coherenceMayRun(
                stated: [.protein, .carbs, .fat]
            ),
            "a complete macro set derives kcal even when kcal itself was absent"
        )
    }

    // MARK: the usual — reconstruction must not invent zeros

    func testAStatedUsualReconstructsWithoutInventedZeros() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            statedFood("protein bar, 190 cal, 20g protein"), userId: userId
        )
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        let usual = FoodUsuals.Usual(
            title: entry.title, useCount: 3, lastAt: entry.loggedAt,
            entry: entry, isVerified: false
        )
        let plate = FoodUsuals.plate(from: usual, via: .words)
        let item = try XCTUnwrap(plate.items.first)
        XCTAssertEqual(item.proteinG, 20)
        XCTAssertNil(item.carbsG,
                     "re-serving her usual must not re-invent a 0 g carbs statement")
        XCTAssertNil(item.fatG)
    }
}
