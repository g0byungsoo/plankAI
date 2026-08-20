import XCTest
@testable import PlankFood

// MARK: - Pass55FieldCarryTests (pass 55 §2)
//
// The defaulted-init drop family, instances #7–#9: `setLoggedDay` and
// both sign-in merge branches re-init `Entry` by hand and were written
// before p53 added `edits` and `barcode` — so redating a plate, or
// signing in, silently erased her hand edits and the verify-once key
// from BOTH copies of the record (the whole-row upsert pushes the
// nulls). These tests pin the carry through every mutation path, plus
// the subtractive half of the qualifier law and the refine
// composition's memory carry.

@MainActor
final class Pass55FieldCarryTests: XCTestCase {

    private let scratch = FileManager.default.temporaryDirectory
        .appendingPathComponent("p55-field-carry-\(UUID().uuidString)")

    override func setUp() {
        super.setUp()
        FoodLogPersister.debugResetStore(to: scratch)
    }

    override func tearDown() {
        FoodLogPersister.debugResetStore(to: nil)
        try? FileManager.default.removeItem(at: scratch)
        super.tearDown()
    }

    private func seedFullFat(
        id: String, userId: String = "p55-user", loggedAt: Date = .now
    ) {
        FoodLogPersister.debugSeed(
            id: id, userId: userId, loggedAt: loggedAt, kcal: 240,
            protein: 20, carbs: 18, fat: 9, fiber: 3, sugar: 12,
            sodiumMg: 180, title: "fairlife shake", source: "barcode",
            itemsDetail: [.init(
                name: "fairlife shake", portionG: 340, kcal: 240,
                protein: 20, carbs: 18, fat: 9, sodiumMg: 180, satFatG: 2
            )],
            corrections: ["that was the chocolate one"],
            edits: ["your numbers: 240 kcal"],
            barcode: "0811620021972"
        )
    }

    private func entry(_ id: String, userId: String = "p55-user") -> FoodLogPersister.FoodLogEntry? {
        FoodLogPersister.allEntries(userId: userId).first {
            $0.id.lowercased() == id.lowercased()
        }
    }

    // MARK: - Redating carries everything (drop #7)

    func testRedatingAPlateKeepsHerEditsAndTheVerifyOnceKey() {
        seedFullFat(id: "p55-redate")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        XCTAssertTrue(FoodLogPersister.setLoggedDay(id: "p55-redate", to: yesterday))
        let moved = entry("p55-redate")
        XCTAssertEqual(moved?.edits, ["your numbers: 240 kcal"],
                       "redating a plate must not erase her hand edits")
        XCTAssertEqual(moved?.barcode, "0811620021972",
                       "redating a plate must not break verify-once")
        XCTAssertEqual(moved?.corrections, ["that was the chocolate one"])
        XCTAssertTrue(moved?.wasVerified ?? false,
                      "her YOUR NUMBERS tier must survive the move")
    }

    // MARK: - The sign-in merge carries everything (drops #8, #9)

    func testSignInMergePreservingIdsCarriesEditsAndBarcode() {
        seedFullFat(id: "p55-merge-keep", userId: "anon-uid")
        FoodLogPersister.reattributeEntries(
            from: "anon-uid", to: "signed-uid", preservingIds: true
        )
        let carried = entry("p55-merge-keep", userId: "signed-uid")
        XCTAssertEqual(carried?.edits, ["your numbers: 240 kcal"],
                       "the id-preserving merge dropped her edits")
        XCTAssertEqual(carried?.barcode, "0811620021972")
        XCTAssertTrue(carried?.wasVerified ?? false)
    }

    func testSignInMergeFreshIdsCarriesEditsAndBarcode() {
        seedFullFat(id: "p55-merge-fresh", userId: "anon-uid-2")
        FoodLogPersister.reattributeEntries(
            from: "anon-uid-2", to: "signed-uid-2", preservingIds: false
        )
        let carried = FoodLogPersister.allEntries(userId: "signed-uid-2").first
        XCTAssertNotNil(carried)
        XCTAssertEqual(carried?.edits, ["your numbers: 240 kcal"],
                       "the fresh-id merge dropped her edits — the FOURTH time at this one call site")
        XCTAssertEqual(carried?.barcode, "0811620021972")
    }

    // MARK: - The subtractive qualifier law

    /// "greek yogurt" must never re-serve "greek yogurt + 2 more" —
    /// she stated one food; the record holds three. The additive half
    /// ("half a…", "…with berries") has been law since p53; this is
    /// the direction it never considered.
    func testATypedSingleFoodNeverMatchesABiggerPlate() {
        FoodLogPersister.debugSeed(
            id: "p55-multi", userId: "p55-user", loggedAt: .now, kcal: 420,
            protein: 24, carbs: 44, fat: 14, fiber: 5, sugar: 22,
            title: "greek yogurt + 2 more", source: "photo",
            itemsDetail: [
                .init(name: "greek yogurt", portionG: 170, kcal: 140,
                      protein: 20, carbs: 8, fat: 4, sodiumMg: 60, satFatG: 2),
                .init(name: "granola", portionG: 40, kcal: 180,
                      protein: 4, carbs: 28, fat: 6, sodiumMg: 20, satFatG: 1),
                .init(name: "honey", portionG: 21, kcal: 100,
                      protein: 0, carbs: 8, fat: 0, sodiumMg: 0, satFatG: 0),
            ],
            edits: ["your numbers"]
        )
        let entries = FoodLogPersister.allEntries(userId: "p55-user")
        XCTAssertNil(
            FoodUsuals.match(sentence: "greek yogurt", in: entries),
            "one stated food must not rebuild granola and honey"
        )
        XCTAssertNotNil(
            FoodUsuals.match(sentence: "greek yogurt + 2 more", in: entries),
            "control: naming the whole plate still re-serves it"
        )
    }

    /// A single-food usual still matches — the daily-latte loop the
    /// whole feature exists for.
    func testASingleFoodUsualStillMatches() {
        seedFullFat(id: "p55-single")
        let entries = FoodLogPersister.allEntries(userId: "p55-user")
        XCTAssertNotNil(FoodUsuals.match(sentence: "fairlife shake", in: entries))
    }

    // MARK: - The refine composition carries the plate's memory

    func testFixWithWordsKeepsHandEditsAndTheUsualBanner() {
        var current = CapturedFood(
            items: [CapturedItem(
                id: "i1", name: "turkey sandwich",
                portionGrams: 220, portionGramsLow: 200, portionGramsHigh: 240,
                usdaSearchTerms: ["turkey sandwich"],
                preparation: nil, cuisineHint: nil,
                confidence: 0.8, notes: nil,
                kcal: 380, proteinG: 26, carbsG: 40, fatG: 12,
                fiberG: 3, nutritionSource: nil
            )],
            plateType: .single, source: .photo,
            confidence: 0.8, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: 340, kcalHigh: 420
        )
        current.editNotes = ["×2 the scan"]
        current.usualApplied = .init(
            title: "turkey sandwich", lastAt: .now, timesLogged: 4,
            verified: true, via: .words
        )
        let response = CapturedFood(
            items: current.items, plateType: .single, source: .photo,
            confidence: 0.9, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: 360, kcalHigh: 400
        )
        let merged = SnapRefine.composeFixedPlate(
            current: current, mergedItems: current.items,
            response: response, note: "it was grilled not fried"
        )
        XCTAssertEqual(
            merged.editNotes, ["×2 the scan"],
            "a spoken fix after a hand edit must not erase the hand edit"
        )
        XCTAssertEqual(merged.appliedCorrections, ["it was grilled not fried"])
        XCTAssertNotNil(
            merged.usualApplied,
            "the plate is still her usual, now with a fix — the banner's provenance survives"
        )
        XCTAssertNil(merged.priorApplied, "a correction still dissolves any prior")
    }

    /// A spoken fix on a barcode plate re-prices it through the model;
    /// the printed-truth stamp must not survive onto numbers the
    /// package never printed.
    func testFixWithWordsOnABarcodePlateDropsThePrintedTruthStamp() {
        let current = CapturedFood(
            items: [CapturedItem(
                id: "barcode-0811620021972", name: "fairlife shake",
                portionGrams: 340, portionGramsLow: 340, portionGramsHigh: 340,
                usdaSearchTerms: ["fairlife shake"],
                preparation: nil, cuisineHint: nil,
                confidence: 1.0, notes: nil,
                kcal: 240, proteinG: 20, carbsG: 18, fatG: 9,
                fiberG: 3, nutritionSource: nil
            )],
            plateType: .single, source: .barcode,
            confidence: 1.0, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        let merged = SnapRefine.composeFixedPlate(
            current: current, mergedItems: current.items,
            response: current, note: "I only drank half"
        )
        XCTAssertEqual(
            merged.source, .words,
            "the model priced this now; 'copied from the label' would be a lie"
        )
        // Control: a photo plate's stamp is untouched.
        var photo = current
        photo.source = .photo
        XCTAssertEqual(
            SnapRefine.composeFixedPlate(
                current: photo, mergedItems: photo.items,
                response: photo, note: "half"
            ).source, .photo
        )
    }
}
