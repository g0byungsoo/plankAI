import XCTest
@testable import PlankFood

// MARK: - AnsweringFoodTests (app v25 pass 53 — THE ANSWERING RECORD)
//
// The food record learns to answer back: a deliberate hand edit is a
// remembered fact (not an analytics ping), her repeated foods rank by
// how she actually eats (frequency, then recency), the same typed
// sentence lands on her own verified numbers instead of a fresh
// guess, and a barcode she has corrected once serves HER truth with
// the package's numbers one tap away. Laws carried whole from pass
// 27/51: a prior never overrules a stated portion (usuals REPLACE
// nothing — they match exact stated identity only, and the fresh
// estimate stays one tap away); spoken corrections remain the only
// PlatePriors source; nothing is ever silently overridden.
//
// RED before GREEN: run against the honest-BEFORE stubs (no edits
// channel, recency-only recents, no usual match anywhere).

@MainActor
final class AnsweringFoodTests: XCTestCase {

    private var scratch: URL!

    override func setUp() {
        super.setUp()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("answering-food-\(UUID().uuidString).jsonl")
        FoodLogPersister.debugResetStore(to: scratch)
    }

    override func tearDown() {
        FoodLogPersister.debugResetStore(to: nil)
        try? FileManager.default.removeItem(at: scratch)
        super.tearDown()
    }

    private func item(
        _ name: String, kcal: Double = 200, protein: Double = 20,
        carbs: Double = 10, fat: Double = 5,
        portion: Double = 300, id: String = UUID().uuidString
    ) -> CapturedItem {
        CapturedItem(
            id: id, name: name, portionGrams: portion,
            portionGramsLow: portion, portionGramsHigh: portion,
            usdaSearchTerms: [name], preparation: nil, cuisineHint: nil,
            confidence: 0.9, notes: nil,
            kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat,
            fiberG: nil, nutritionSource: .llmDirect
        )
    }

    private func food(items: [CapturedItem], source: EntryMethod) -> CapturedFood {
        var food = CapturedFood(
            items: items, plateType: .single, source: source,
            confidence: 0.9, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        food.source = source
        return food
    }

    private func plate(
        _ names: [String], source: EntryMethod = .words,
        kcal: Double = 200, protein: Double = 20
    ) -> CapturedFood {
        food(items: names.map {
            item($0, kcal: kcal / Double(names.count), protein: protein / Double(names.count))
        }, source: source)
    }

    // MARK: every deliberate edit is a remembered fact

    func testAStepperEditWritesAStructuredEditNote() {
        let base = plate(["fairlife shake"])
        var session = PlateEditSession(food: base)
        session.stepPortion(base.items[0].id, up: true)
        let rebuilt = session.rebuiltFood()
        XCTAssertFalse(rebuilt.editNotes.isEmpty,
            "a portion she stepped on purpose is remembered on purpose")
        XCTAssertTrue(rebuilt.editNotes.first?.contains("fairlife shake") ?? false)
    }

    func testAnEditorReplaceAndARemoveWriteNotes() {
        let keep = item("greek yogurt")
        let cut = item("granola")
        let food = food(items: [keep, cut], source: .photo)
        var session = PlateEditSession(food: food)
        var edited = keep
        edited.kcal = 140
        session.replace(edited)
        session.remove(cut.id)
        let rebuilt = session.rebuiltFood()
        XCTAssertEqual(rebuilt.editNotes.count, 2)
        XCTAssertTrue(rebuilt.editNotes.contains { $0.contains("greek yogurt") })
        XCTAssertTrue(rebuilt.editNotes.contains { $0.contains("granola") })
    }

    func testEditsPersistAndRideTheRelog() throws {
        var food = plate(["fairlife shake"])
        food.editNotes = ["fairlife shake — your numbers"]
        _ = try FoodLogPersister.persist(food, userId: "u-edit")
        let entry = FoodLogPersister.allEntries(userId: "u-edit")[0]
        XCTAssertEqual(entry.edits, ["fairlife shake — your numbers"])
        XCTAssertTrue(entry.wasVerified)
        XCTAssertFalse(entry.wasCorrected,
            "hand edits are their own channel — they never masquerade as spoken corrections, so PlatePriors' source stays exactly what pass 27 pinned")

        FoodLogPersister.relog(entry, userId: "u-edit")
        let relogged = FoodLogPersister.allEntries(userId: "u-edit")[0]
        XCTAssertEqual(relogged.edits, ["fairlife shake — your numbers"])
    }

    func testAnEmptyEditListIsNotAnEdit() throws {
        let food = plate(["banana"])
        _ = try FoodLogPersister.persist(food, userId: "u-noedit")
        let entry = FoodLogPersister.allEntries(userId: "u-noedit")[0]
        XCTAssertNil(entry.edits)
        XCTAssertFalse(entry.wasVerified)
    }

    // MARK: her usuals — frequency then recency, verified carried

    func testUsualsRankByFrequencyThenRecency() throws {
        // oatmeal ×3 (older), sushi ×1 (newest) → oatmeal leads.
        for _ in 0..<3 {
            _ = try FoodLogPersister.persist(plate(["oatmeal"]), userId: "u-rank")
        }
        _ = try FoodLogPersister.persist(plate(["sushi"]), userId: "u-rank")
        let usuals = FoodUsuals.rank(
            FoodLogPersister.allEntries(userId: "u-rank"), limit: 6
        )
        XCTAssertEqual(usuals.first?.title, "oatmeal")
        XCTAssertEqual(usuals.first?.useCount, 3)
        XCTAssertEqual(usuals.dropFirst().first?.title, "sushi")
    }

    func testAUsualCarriesTheLatestVerifiedNumbers() throws {
        // Estimate 230 kcal, then a verified fix to 180, then a
        // plain relog — the usual answers 180 (her verified truth),
        // not the stale first guess.
        _ = try FoodLogPersister.persist(
            plate(["fairlife shake"], kcal: 230), userId: "u-verified"
        )
        var fixed = plate(["fairlife shake"], kcal: 180)
        fixed.editNotes = ["fairlife shake → 180 kcal"]
        _ = try FoodLogPersister.persist(fixed, userId: "u-verified")
        _ = try FoodLogPersister.persist(
            plate(["fairlife shake"], kcal: 230), userId: "u-verified"
        )
        let usual = FoodUsuals.rank(
            FoodLogPersister.allEntries(userId: "u-verified"), limit: 6
        ).first
        XCTAssertEqual(usual?.useCount, 3)
        XCTAssertTrue(usual?.isVerified ?? false)
        XCTAssertEqual(usual?.entry.kcal ?? 0, 180, accuracy: 0.5)
    }

    // MARK: the same sentence lands on her own record

    func testTheSameTypedSentenceMatchesHerUsual() throws {
        var fixed = plate(["fairlife shake"], kcal: 180, protein: 30)
        fixed.appliedCorrections = ["that's the 30g one"]
        _ = try FoodLogPersister.persist(fixed, userId: "u-match")
        let usual = FoodUsuals.match(
            sentence: "Fairlife Shake",
            in: FoodLogPersister.allEntries(userId: "u-match")
        )
        XCTAssertNotNil(usual, "her exact stated food answers from her record")
        XCTAssertEqual(usual?.entry.kcal ?? 0, 180, accuracy: 0.5)
    }

    func testADifferentSentenceNeverMatches() throws {
        _ = try FoodLogPersister.persist(plate(["fairlife shake"]), userId: "u-nomatch")
        let entries = FoodLogPersister.allEntries(userId: "u-nomatch")
        // A qualifier is contradictory evidence — the estimate runs
        // fresh. A learned fact never silently overrides it.
        XCTAssertNil(FoodUsuals.match(sentence: "half a fairlife shake", in: entries))
        XCTAssertNil(FoodUsuals.match(sentence: "fairlife shake with berries", in: entries))
        XCTAssertNil(FoodUsuals.match(sentence: "", in: entries))
    }

    func testTheUsualPlateWearsHonestProvenance() throws {
        var fixed = plate(["fairlife shake", "banana"], kcal: 280, protein: 32)
        fixed.editNotes = ["banana → 90 kcal"]
        _ = try FoodLogPersister.persist(fixed, userId: "u-plate")
        guard let usual = FoodUsuals.match(
            sentence: "fairlife shake + 1 more",
            in: FoodLogPersister.allEntries(userId: "u-plate")
        ) else { return XCTFail("expected a usual") }
        let served = FoodUsuals.plate(from: usual, via: .words)
        XCTAssertEqual(served.source, .again,
            "logged again from your record — the door that tells the truth")
        XCTAssertEqual(served.items.count, 2)
        XCTAssertEqual(served.usualApplied?.timesLogged, 1)
        XCTAssertEqual(
            served.items.compactMap(\.kcal).reduce(0, +), 280, accuracy: 1.0
        )
        XCTAssertNil(served.priorApplied,
            "a usual is not a prior — the two memories never stack")
    }

    // MARK: barcode — verify once, hers thereafter

    func testABarcodePlateRemembersItsCode() throws {
        let food = food(items: [
            item("chobani zero sugar", id: "barcode-0894700010137")
        ], source: .barcode)
        _ = try FoodLogPersister.persist(food, userId: "u-code")
        let entry = FoodLogPersister.allEntries(userId: "u-code")[0]
        XCTAssertEqual(entry.barcode, "0894700010137")
    }

    func testAVerifiedBarcodeEntryAnswersTheNextScan() throws {
        var food = food(items: [
            item("chobani zero sugar", kcal: 60, protein: 11,
                 id: "barcode-0894700010137")
        ], source: .barcode)
        food.editNotes = ["chobani zero sugar → 60 kcal"]
        _ = try FoodLogPersister.persist(food, userId: "u-scan")
        let usual = FoodUsuals.match(
            barcode: "0894700010137",
            in: FoodLogPersister.allEntries(userId: "u-scan")
        )
        XCTAssertNotNil(usual)
        XCTAssertEqual(usual?.entry.kcal ?? 0, 60, accuracy: 0.5)
    }

    func testAnUnverifiedBarcodeEntryStaysQuiet() throws {
        // She never touched the numbers — the package's own numbers
        // are the freshest truth; her record adds nothing over them.
        let food = food(items: [
            item("chobani zero sugar", id: "barcode-0894700010137")
        ], source: .barcode)
        _ = try FoodLogPersister.persist(food, userId: "u-quiet")
        XCTAssertNil(FoodUsuals.match(
            barcode: "0894700010137",
            in: FoodLogPersister.allEntries(userId: "u-quiet")
        ))
    }

    // MARK: the numbers must agree with each other

    func testPlateDisagreementFlagsImpossibleNumbers() {
        // 100 kcal claimed against 30g protein + 20g carbs + 10g fat
        // (≈ 290 kcal by Atwater) — the physics says look again.
        let wrong = food(items: [
            item("shake", kcal: 100, protein: 30, carbs: 20, fat: 10)
        ], source: .words)
        XCTAssertTrue(SnapResultMath.plateDisagrees(wrong))

        let right = food(items: [
            item("shake", kcal: 290, protein: 30, carbs: 20, fat: 10)
        ], source: .words)
        XCTAssertFalse(SnapResultMath.plateDisagrees(right))
    }

    func testSparseMacrosNeverFlagDisagreement() {
        // A plate with no macros recorded cannot disagree with
        // itself — absence is absence, never evidence.
        var noMacros = item("broth", kcal: 40, portion: 250)
        noMacros.proteinG = nil
        noMacros.carbsG = nil
        noMacros.fatG = nil
        let sparse = food(items: [noMacros], source: .words)
        XCTAssertFalse(SnapResultMath.plateDisagrees(sparse))
    }
}
