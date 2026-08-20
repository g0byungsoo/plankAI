import XCTest
@testable import PlankFood

// MARK: - FieldPreservationTests
//
// v25 pass 51 — EDITING CANNOT DESTROY UNRELATED TRUTH.
//
// THE DEFECT FAMILY this file exists to end: a "copy this item but
// change one thing" site re-inits `CapturedItem` through a hand-written
// call with defaulted parameters, and the compiler cannot see an
// omission in one of those. It has now happened FIVE recorded times
// (sugar + itemsDetail, sodium + satFat, corrections, `SnapRefineMerge
// .withId` dropping micros, and — this pass's finding — all three
// `PlateEditSession` copy helpers dropping `micros`). The cost of the
// fifth instance: stepping the portion of a USDA-grounded item, or
// saying "I ate half", silently erased the plate's micronutrients, so
// `namedMicros` summed a PARTIAL plate — the exact estimate-wearing-a-
// measurement's-clothes defect the `publishesMicros` gate was built to
// prevent. A record made poorer because she touched it.
//
// Two layers of defense, and they are different jobs:
//
//   1. The copy helpers are rewritten as MUTATIONS of `self` — a copy
//      of the whole value that then names only what it changes — so a
//      field they did not name is carried BY CONSTRUCTION and this
//      family is closed for those sites forever.
//   2. This file's Mirror-based harness catches the NEXT site: it
//      pins the model's field count and asserts, for every copy path,
//      that no populated field comes back empty. A new stored field
//      fails `testTheFixturePopulatesEveryField` first, which forces
//      the fixture to grow, which extends the sweep to the new field.

final class FieldPreservationTests: XCTestCase {

    // MARK: - The fully-populated fixture

    /// Every optional non-nil, every value distinct enough to notice
    /// if it moves. When `CapturedItem` grows a field, populate it
    /// here — `testTheFixturePopulatesEveryField` fails until you do,
    /// and every preservation sweep below covers it from then on.
    private func fullyPopulated(id: String = "FIX-1") -> CapturedItem {
        CapturedItem(
            id: id,
            name: "salmon bowl",
            portionGrams: 250,
            portionGramsLow: 200,
            portionGramsHigh: 300,
            usdaSearchTerms: ["salmon bowl", "salmon"],
            preparation: "grilled",
            cuisineHint: "japanese",
            confidence: 0.9,
            notes: "with rice",
            kcal: 560,
            proteinG: 38,
            carbsG: 52,
            fatG: 21,
            fiberG: 5,
            nutritionSource: .usdaFDC,
            sugarG: 6,
            sodiumMg: 720,
            saturatedFatG: 4,
            englishName: "salmon rice bowl",
            count: 1,
            unit: "bowl",
            servingsInDish: 2,
            isShareable: true,
            micros: CalorieMathService.Micronutrients(
                vitaminAUg: 150, vitaminCMg: 12, vitaminDUg: 11,
                vitaminEMg: 2, vitaminB12Ug: 4.5, calciumMg: 60,
                ironMg: 1.4, magnesiumMg: 55, potassiumMg: 800, zincMg: 1.1
            )
        )
    }

    // MARK: - Mirror plumbing

    private func isNilOptional(_ value: Any) -> Bool {
        let m = Mirror(reflecting: value)
        return m.displayStyle == .optional && m.children.isEmpty
    }

    private func nilFieldLabels(of item: CapturedItem) -> Set<String> {
        Set(Mirror(reflecting: item).children.compactMap { child -> String? in
            guard let label = child.label else { return nil }
            return isNilOptional(child.value) ? label : nil
        })
    }

    // MARK: - The tripwire

    /// `CapturedItem` stores exactly this many fields today. If this
    /// fails you ADDED (or removed) a stored field: update the count,
    /// populate the new field in `fullyPopulated`, and check every
    /// copy path carries it. That is the entire point of the pin.
    func testTheModelFieldCountIsPinned() {
        XCTAssertEqual(
            Mirror(reflecting: fullyPopulated()).children.count, 25,
            "CapturedItem grew or shrank — update fullyPopulated() and re-audit every copy helper before touching this number"
        )
    }

    func testTheFixturePopulatesEveryField() {
        XCTAssertTrue(
            nilFieldLabels(of: fullyPopulated()).isEmpty,
            "the fixture must populate every optional or the preservation sweep is blind to it"
        )
    }

    // MARK: - The sweep: no copy path empties a populated field

    func testEveryCopyHelperPreservesEveryPopulatedField() {
        let item = fullyPopulated()

        // Identity-argument copies: same values in, so EVERY field must
        // come back populated.
        let rewritten = item.withNutrition(
            portionGrams: item.portionGrams, kcal: item.kcal,
            proteinG: item.proteinG, carbsG: item.carbsG,
            fatG: item.fatG, fiberG: item.fiberG
        )
        XCTAssertTrue(nilFieldLabels(of: rewritten).isEmpty,
                      "withNutrition emptied: \(nilFieldLabels(of: rewritten))")

        let scaled = item.scalingNutrition(by: 1.0)
        XCTAssertTrue(nilFieldLabels(of: scaled).isEmpty,
                      "scalingNutrition emptied: \(nilFieldLabels(of: scaled))")

        let rekeyed = item.withIdentity(of: fullyPopulated(id: "FIX-2"))
        XCTAssertTrue(nilFieldLabels(of: rekeyed).isEmpty,
                      "withIdentity emptied: \(nilFieldLabels(of: rekeyed))")
        XCTAssertEqual(rekeyed.id, "FIX-2")
        XCTAssertEqual(rekeyed.micros, item.micros,
                       "a re-key changes the id and NOTHING else")
    }

    // MARK: - Micros ride every edit (the pass-50 F2 reproduction)

    /// Stepping a portion is a linear scale of the SAME food — the
    /// micronutrients are that portion's contents and must scale with
    /// it, exactly as `PlatePriors.scale` already does.
    func testSteppingAPortionScalesTheMicronutrientsWithIt() {
        var session = PlateEditSession(food: plate(with: fullyPopulated()))
        session.stepPortion("FIX-1", up: true)   // 1.0 → 1.25 on the grid

        let stepped = session.item("FIX-1")
        let micros = stepped?.micros
        XCTAssertNotNil(micros, "one stepper tick erased the grounded micronutrients")
        XCTAssertEqual(micros?.vitaminCMg ?? 0, 12 * 1.25, accuracy: 0.001)
        XCTAssertEqual(micros?.potassiumMg ?? 0, 800 * 1.25, accuracy: 0.001)
        XCTAssertEqual(stepped?.nutritionSource, .usdaFDC,
                       "the grounding attribution rides the same edit")
    }

    /// "I ate half" halves the plate — including what the plate carried.
    func testThePlateFractionScalesTheMicronutrientsWithIt() {
        var session = PlateEditSession(food: plate(with: fullyPopulated()))
        session.setFraction(0.5)

        let effective = session.effectiveItems.first
        XCTAssertNotNil(effective?.micros,
                        "the half-plate fraction erased the grounded micronutrients")
        XCTAssertEqual(effective?.micros?.calciumMg ?? 0, 30, accuracy: 0.001)

        let persisted = session.rebuiltFood().items.first
        XCTAssertNotNil(persisted?.micros,
                        "the persisted rebuild must carry what the reading showed")
    }

    /// The ingest clamp tidies hallucinated kcal. It must not tidy away
    /// the item's grounded micronutrients while doing it — the clamp
    /// fires at session INIT, before she has touched anything.
    func testThePhysicsClampNeverErasesMicronutrients() {
        var wild = fullyPopulated()
        wild = wild.withNutrition(
            portionGrams: wild.portionGrams, kcal: 9_999,   // > 9 kcal/g cap
            proteinG: wild.proteinG, carbsG: wild.carbsG,
            fatG: wild.fatG, fiberG: wild.fiberG
        )
        // Re-seed micros in case the copy above dropped them (it must
        // not, but this test is about the clamp, not the copy).
        wild.micros = fullyPopulated().micros

        let (clamped, adjusted) = PlateEditSession.physicsClamped(wild)
        XCTAssertTrue(adjusted, "fixture must actually trip the clamp")
        XCTAssertEqual(clamped.micros, fullyPopulated().micros,
                       "the clamp bounds kcal and macros; the micronutrients were never its business")
    }

    // MARK: - Controls

    /// UNKNOWN STAYS UNKNOWN — an ungrounded item carries no micros and
    /// no edit may invent them.
    func testAnUngroundedItemStaysHonestlyMicroFree() {
        var bare = fullyPopulated()
        bare.micros = nil
        bare.nutritionSource = .llmDirect

        var session = PlateEditSession(food: plate(with: bare))
        session.stepPortion("FIX-1", up: true)
        session.setFraction(0.75)

        XCTAssertNil(session.item("FIX-1")?.micros,
                     "no edit may manufacture micronutrients for an ungrounded item")
        XCTAssertNil(session.effectiveItems.first?.micros)
    }

    // MARK: - Plumbing

    private func plate(with item: CapturedItem) -> CapturedFood {
        CapturedFood(
            items: [item], plateType: .single, source: .photo,
            confidence: 0.9, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
    }
}
