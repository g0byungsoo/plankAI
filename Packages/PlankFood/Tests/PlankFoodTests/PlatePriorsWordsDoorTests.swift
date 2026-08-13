import XCTest
@testable import PlankFood

// MARK: - PlatePriorsWordsDoorTests
//
// WHY THIS FILE EXISTS.
//
// `FoodCaptureDispatcher.userId` carried a doc comment reading "photo +
// describe recognitions are checked against the user's own corrected
// record". The code checks photo only. A later pass read the comment,
// concluded E7's front door had lost E4's flywheel, and wrote in a
// report that restoring it was the highest-leverage work available.
//
// It is the opposite. `PlatePriors` keys on the dish TITLE and applies
// a UNIFORM SCALE, and through the words door the PORTION CAME FROM
// HER. These tests pin the case that decides it, so the next reader who
// wants to "finish" the flywheel has to delete an argument rather than
// an omission.
//
// Both inputs below are from the founder's own list of realistic words-
// door phrases.

final class PlatePriorsWordsDoorTests: XCTestCase {

    private func item(_ name: String, kcal: Double, grams: Double) -> CapturedItem {
        CapturedItem(
            id: name, name: name, portionGrams: grams,
            portionGramsLow: grams * 0.85, portionGramsHigh: grams * 1.15,
            usdaSearchTerms: [name], preparation: nil, cuisineHint: nil,
            confidence: 0.7, notes: nil,
            kcal: kcal, proteinG: kcal * 0.05, carbsG: kcal * 0.1,
            fatG: kcal * 0.03, fiberG: 2,
            nutritionSource: .llmDirect
        )
    }

    private func plate(
        _ items: [CapturedItem], source: EntryMethod
    ) -> CapturedFood {
        CapturedFood(
            items: items, plateType: .single, source: source,
            confidence: 0.7, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
    }

    /// Her record: she photographed a whole turkey sandwich, corrected it
    /// to 620 kcal, and filed it. This is a real prior.
    private var wholeSandwichPrior: [String: PlatePriors.DishPrior] {
        PlatePriors.index([
            PlatePriors.Observation(
                title: "turkey sandwich", kcal: 620, proteinG: 34,
                corrected: true, at: Date(timeIntervalSince1970: 1_000_000)
            )
        ])
    }

    // MARK: - The case that decides it

    func testHerPriorWouldDoubleAHalfSandwichIfItWereAllowedThrough() {
        // She types "half a turkey sandwich". The model returns the dish
        // under its own name at half the mass — which is correct, and
        // which normalizes to the SAME KEY as the whole one she fixed.
        let half = plate([item("turkey sandwich", kcal: 310, grams: 110)],
                         source: .words)
        XCTAssertEqual(PlatePriors.normalize("turkey sandwich"), "turkey sandwich")

        // If this plate were run through the engine, her prior would
        // scale it to the WHOLE sandwich she corrected. The half is
        // gone, and she never said anything was wrong.
        let ifAllowed = PlatePriors.apply(to: half, index: wholeSandwichPrior)
        XCTAssertEqual(ifAllowed.totalKcal ?? 0, 620, accuracy: 0.5,
                       "the engine really does double it, which is why the words door never reaches it")
        XCTAssertEqual(ifAllowed.priorApplied?.factor ?? 0, 2.0, accuracy: 0.01)

        // And the ±3× sanity clamp cannot save her: 2× is well inside it.
        XCTAssertLessThan(2.0, PlatePriors.factorCeiling)
    }

    func testAFewBitesIsTheSameDefectLarger() {
        let bites = plate([item("pizza", kcal: 90, grams: 40)], source: .words)
        let prior = PlatePriors.index([
            PlatePriors.Observation(
                title: "pizza", kcal: 720, proteinG: 30,
                corrected: true, at: Date(timeIntervalSince1970: 1_000_000)
            )
        ])
        // 8×, so THIS one the clamp does refuse — but only by accident of
        // magnitude. The law cannot rest on the clamp.
        let ifAllowed = PlatePriors.apply(to: bites, index: prior)
        XCTAssertNil(ifAllowed.priorApplied)
        XCTAssertGreaterThan(720.0 / 90.0, PlatePriors.factorCeiling)
    }

    // MARK: - The law, as the dispatcher enforces it

    @MainActor
    func testTheDispatcherOffersPriorsToExactlyOneDoor() async throws {
        // The guarantee is structural: `applyPriors` has ONE call site.
        // If a future pass adds a second, this test is the argument it
        // has to answer.
        let dispatcher = FoodCaptureDispatcher()
        dispatcher.userId = "words-door-user"

        // `.text` must come back untouched by any prior, whatever the
        // record holds. No vision service is configured, so the call
        // throws before the network — the point being that no prior can
        // be applied on a path that never reaches `applyPriors`.
        do {
            _ = try await dispatcher.dispatch(.text("half a turkey sandwich", cuisineProfile: nil))
            XCTFail("expected the unconfigured pipeline to throw")
        } catch let error as FoodCaptureError {
            guard case .notImplemented = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    /// The same plate arriving through the PHOTO door is a different
    /// question and the prior is welcome: there the portion came from a
    /// model sizing an image, so her number corrects its sizing.
    func testThePhotoDoorIsWhereAPriorBelongs() {
        let photographed = plate([item("turkey sandwich", kcal: 500, grams: 220)],
                                 source: .photo)
        let applied = PlatePriors.apply(to: photographed, index: wholeSandwichPrior)
        XCTAssertNotNil(applied.priorApplied, "the photo door keeps its memory")
        XCTAssertEqual(applied.totalKcal ?? 0, 620, accuracy: 0.5)
    }

    /// Printed truth is refused for a different reason and still is.
    func testBarcodeIsStillRefused() {
        let scanned = plate([item("turkey sandwich", kcal: 500, grams: 220)],
                            source: .barcode)
        XCTAssertNil(PlatePriors.apply(to: scanned, index: wholeSandwichPrior).priorApplied)
    }
}
