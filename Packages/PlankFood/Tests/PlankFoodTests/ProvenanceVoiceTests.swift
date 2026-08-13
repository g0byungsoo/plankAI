import XCTest
@testable import PlankFood

// MARK: - ProvenanceVoiceTests
//
// The defect these pin, in one sentence: E8.1 was named for killing the
// line "read from your photo" on a plate the user had TYPED. It fixed
// `PlateDetailSheet` — the SECOND surface a plate reaches — and left the
// identical lie standing on the first.
//
// `ResultDetailCopy.provenance`, read at the moment of the scan, ended:
//
//     return "estimated from the photo · ranges, not exact"
//
// with no branch on the door. A photographed Nutrition Facts panel, a
// scanned barcode, a typed sentence and a restaurant estimate all said
// it. The vocabulary that says it correctly existed, in this repo, in
// this domain, written one era earlier, as a private static on a
// different surface.
//
// It lives on `EntryMethod` now — the type that owns the doors — so a
// door cannot ship without a sentence.

final class ProvenanceVoiceTests: XCTestCase {

    private func plate(
        source: EntryMethod, kcal: Double = 400,
        confidence: Double = 0.9, low: Double? = nil, high: Double? = nil
    ) -> CapturedFood {
        let item = CapturedItem(
            id: "i", name: "granola", portionGrams: 55,
            portionGramsLow: 55, portionGramsHigh: 55,
            usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
            confidence: confidence, notes: nil,
            kcal: kcal, proteinG: 8, carbsG: 40, fatG: 12, fiberG: 4,
            nutritionSource: source == .label ? .labelDeclared : .llmDirect
        )
        return CapturedFood(
            items: [item], plateType: .single, source: source,
            confidence: confidence, needsSecondPhoto: false,
            secondPhotoHint: nil, kcalLow: low, kcalHigh: high
        )
    }

    private func copy(_ food: CapturedFood) -> ResultDetailCopy {
        ResultDetailCopy(
            food: food,
            ctx: ResultDetailContext(
                proteinTargetG: 90, todayLoggedProtein: 20,
                kcalTarget: 1600, isGlp1: true, hour: 13
            )
        )
    }

    // MARK: - Every door has a sentence, and it is its own

    func testEveryDoorSaysSomethingDifferentFromTheOthersItMustNotBeConfusedWith() {
        XCTAssertEqual(EntryMethod.photo.provenanceLine,
                       "read from your photo \u{00B7} ranges, not exact")
        XCTAssertEqual(EntryMethod.words.provenanceLine,
                       "logged from your words \u{00B7} ranges, not exact")
        XCTAssertEqual(EntryMethod.label.provenanceLine,
                       "copied from the label \u{00B7} these are the package's numbers")
        XCTAssertEqual(EntryMethod.barcode.provenanceLine,
                       EntryMethod.label.provenanceLine)
        XCTAssertEqual(EntryMethod.again.provenanceLine,
                       "logged again from your record")
        XCTAssertEqual(EntryMethod.restaurant.provenanceLine,
                       "a restaurant estimate \u{00B7} a range, not a reading")
        XCTAssertEqual(EntryMethod.pantry.provenanceLine, "from the pantry")
        XCTAssertEqual(EntryMethod.unknown.provenanceLine, "ranges, not exact")
    }

    func testNoDoorClaimsAPhotographItDoesNotHave() {
        for door in EntryMethod.allCases where door != .photo {
            XCTAssertFalse(
                door.provenanceLine.contains("photo"),
                "\(door.rawValue) claims a photograph: \(door.provenanceLine)"
            )
        }
    }

    func testPrintedTruthNeverApologisesForBeingAnEstimate() {
        for door in EntryMethod.allCases where door.isPrintedTruth {
            XCTAssertFalse(door.provenanceLine.contains("not exact"),
                           "\(door.rawValue) hedges printed truth")
            XCTAssertFalse(door.provenanceLine.contains("estimate"),
                           "\(door.rawValue) hedges printed truth")
        }
    }

    func testStoredFormResolvesLegacyAndAbsentValuesWithoutGuessingADoor() {
        // Pre-E8.1 rows say `photo` for photographs, labels and typed
        // sentences alike. Nothing can recover which, and the three legacy
        // CHECK values no build has written are not doors either.
        XCTAssertEqual(EntryMethod.provenanceLine(for: nil),
                       EntryMethod.unknown.provenanceLine)
        XCTAssertEqual(EntryMethod.provenanceLine(for: ""),
                       EntryMethod.unknown.provenanceLine)
        for legacy in EntryMethod.legacyTolerated {
            XCTAssertEqual(EntryMethod.provenanceLine(for: legacy),
                           EntryMethod.unknown.provenanceLine, legacy)
        }
        XCTAssertEqual(EntryMethod.provenanceLine(for: "label"),
                       EntryMethod.label.provenanceLine)
    }

    // MARK: - The first surface, which was the one that was wrong

    func testTypedPlateIsNotToldItWasPhotographed() {
        let line = copy(plate(source: .words)).provenance
        XCTAssertEqual(line, EntryMethod.words.provenanceLine)
        XCTAssertFalse(line?.contains("photo") ?? true)
    }

    func testPhotographedNutritionPanelIsNotCalledAnEstimate() {
        let line = copy(plate(source: .label)).provenance
        XCTAssertEqual(line, EntryMethod.label.provenanceLine)
    }

    func testPrintedTruthSkipsTheRangeHedgeEvenWithAWideBand() {
        // Both remaining branches describe a MODEL judging a photograph:
        // a kcal range it invented, or a confidence it assigned itself.
        // Neither may speak for a transcription.
        let wide = plate(source: .barcode, low: 100, high: 900)
        XCTAssertEqual(copy(wide).provenance, EntryMethod.barcode.provenanceLine)
    }

    func testPrintedTruthSkipsTheLowConfidenceHedge() {
        let unsure = plate(source: .label, confidence: 0.2)
        XCTAssertEqual(copy(unsure).provenance, EntryMethod.label.provenanceLine)
    }

    func testAPhotographStillGetsItsHonestHedges() {
        // The hedges are good and specific where they belong. This is a
        // fix to WHO hears them, not a removal.
        let wide = plate(source: .photo, low: 100, high: 900)
        XCTAssertTrue(copy(wide).provenance?.contains("within a range") ?? false)
        let unsure = plate(source: .photo, confidence: 0.2)
        XCTAssertTrue(copy(unsure).provenance?.contains("lower confidence") ?? false)
    }

    // MARK: - The label door's numbers are declared, not estimated

    func testLabelReadIsStampedAsADeclarationNotAGuess() {
        // `FoodVisionService` serves photo, label and words from ONE
        // response shape and stamped every priced item `.llmDirect` — the
        // provenance of a guess about a bowl of stew. The dispatcher is
        // the only layer that still knows which door was used.
        let raw = plate(source: .label)
        let stamped = FoodCaptureDispatcher.stampingSource(.labelDeclared, on: raw)
        XCTAssertEqual(stamped.items.first?.nutritionSource, .labelDeclared)
        // And nothing else about the plate moved.
        XCTAssertEqual(stamped.items.count, raw.items.count)
        XCTAssertEqual(stamped.items.first?.kcal, raw.items.first?.kcal)
        XCTAssertEqual(stamped.source, raw.source)
    }

    func testAnUnpricedItemIsNotADeclaration() {
        // A blank the model could not price must stay open to the USDA
        // join. Stamping it would let an estimate inherit a source that
        // claims to be printed.
        let blank = CapturedItem(
            id: "b", name: "mystery", portionGrams: 100,
            portionGramsLow: 80, portionGramsHigh: 120,
            usdaSearchTerms: ["mystery"], preparation: nil, cuisineHint: nil,
            confidence: 0.3, notes: nil,
            kcal: nil, proteinG: nil, carbsG: nil, fatG: nil, fiberG: nil,
            nutritionSource: nil
        )
        let food = CapturedFood(
            items: [blank], plateType: .single, source: .label,
            confidence: 0.3, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        let stamped = FoodCaptureDispatcher.stampingSource(.labelDeclared, on: food)
        XCTAssertNil(stamped.items.first?.nutritionSource)
    }

    func testALabelDeclarationDoesNotYetClaimMicronutrients() {
        // A US panel PRINTS vitamin D, calcium, iron and potassium — but
        // the current FOOD_VISION_SCHEMA does not ask for them, so we have
        // not asked and do not know. "Asked, and there is none" is
        // knowledge; "never asked" is not. This flips in the same change
        // that lands the four fields in the schema.
        let item = CapturedItem(
            id: "i", name: "granola", portionGrams: 55,
            portionGramsLow: 55, portionGramsHigh: 55,
            usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
            confidence: 1, notes: nil,
            kcal: 210, proteinG: 8, carbsG: 40, fatG: 12, fiberG: 4,
            nutritionSource: .labelDeclared
        )
        XCTAssertFalse(item.publishesMicros)
    }

    // MARK: - The copy-constructor bug class

    func testACorrectedItemKeepsEverythingTheCorrectionDidNotName() {
        // `SnapRefineMerge.withId` was a 25-parameter re-init and dropped
        // `micros` — the fourth time in this package that a hand-written
        // init with defaulted parameters silently lost a field the
        // compiler could not see was missing. Identity is the only thing
        // that must cross over, so it is the only thing named.
        var model = CapturedItem(
            id: "from-model", name: "rice", portionGrams: 200,
            portionGramsLow: 180, portionGramsHigh: 220,
            usdaSearchTerms: ["rice"], preparation: "boiled", cuisineHint: "korean",
            confidence: 0.9, notes: "n",
            kcal: 260, proteinG: 5, carbsG: 57, fatG: 1, fiberG: 1,
            nutritionSource: .usdaCalibrated,
            sugarG: 0, sodiumMg: 2, saturatedFatG: 0,
            englishName: "steamed rice", count: 1, unit: "serving",
            servingsInDish: 1, isShareable: false
        )
        model.micros = CalorieMathService.Micronutrients(potassiumMg: 55)

        let merged = SnapRefineMerge.merge(
            current: [model.withIdentityForTest("original")],
            response: [model],
            note: "the rice was a bigger scoop"
        )
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].id, "original", "identity must survive")
        XCTAssertEqual(merged[0].micros?.potassiumMg, 55, "micros must survive")
        XCTAssertEqual(merged[0].servingsInDish, 1)
        XCTAssertEqual(merged[0].sodiumMg, 2)
    }
}

private extension CapturedItem {
    /// A same-shape twin under a different id, so the merge has an
    /// existing identity to preserve.
    func withIdentityForTest(_ newId: String) -> CapturedItem {
        var out = self
        out.id = newId
        return out
    }
}
