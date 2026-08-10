import XCTest
@testable import PlankFood

// MARK: - SnapRefineMergeTests (v25 E2 — B11)
//
// The correction-scope guard: one correction must never move the
// calories of a dish it didn't mention (SnappyMeal ablation — full-
// plate re-estimation degrades unmentioned items). Deterministic,
// client-side, cannot be prompt-disobeyed.

final class SnapRefineMergeTests: XCTestCase {

    private func item(
        _ id: String, _ name: String,
        grams: Double = 150, kcal: Double = 300,
        p: Double = 20, c: Double = 30, f: Double = 10,
        fiber: Double? = 4
    ) -> CapturedItem {
        CapturedItem(
            id: id, name: name,
            portionGrams: grams, portionGramsLow: grams * 0.8,
            portionGramsHigh: grams * 1.2,
            usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
            confidence: 0.8, notes: nil,
            kcal: kcal, proteinG: p, carbsG: c, fatG: f, fiberG: fiber,
            nutritionSource: .llmDirect
        )
    }

    func testUnmentionedDriftIsDiscarded() {
        // She fixed the rice. The model also moved the chicken —
        // exactly the ablation's failure. The chicken stands.
        let current = [
            item("a", "fried rice", grams: 200, kcal: 400),
            item("b", "grilled chicken", kcal: 280, fiber: 2),
        ]
        let response = [
            item("x", "fried rice", grams: 100, kcal: 200),
            item("y", "grilled chicken", kcal: 350, fiber: nil),
        ]
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "the rice was one cup, not two"
        )
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].kcal, 200)          // the correction landed
        XCTAssertEqual(merged[0].id, "a")            // on the existing identity
        XCTAssertEqual(merged[1].kcal, 280)          // the chicken never moved
        XCTAssertEqual(merged[1].fiberG, 2)          // fiber survives too
        XCTAssertEqual(merged[1].id, "b")
    }

    func testCleanEchoKeepsIdentityAndProvenance() {
        let current = [item("a", "salmon", kcal: 320)]
        let response = [item("z", "salmon", kcal: 320.4)]   // within ε
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "add a spoon of salmon roe"   // mentions salmon
        )
        XCTAssertEqual(merged[0].id, "a")
        XCTAssertEqual(merged[0].kcal, 320)
    }

    func testMentionedAdditionSurvivesHallucinatedOneDies() {
        let current = [item("a", "salad", kcal: 180)]
        let response = [
            item("x", "salad", kcal: 180),
            item("y", "ranch dressing", kcal: 120),
            item("z", "garlic bread", kcal: 210),   // never mentioned
        ]
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "there was ranch on it"
        )
        XCTAssertEqual(merged.map(\.name), ["salad", "ranch dressing"])
    }

    func testRenameReplacesInPlace() {
        let current = [
            item("a", "carbonara", kcal: 550),
            item("b", "side salad", kcal: 120),
        ]
        let response = [
            item("x", "cacio e pepe", kcal: 480),
            item("y", "side salad", kcal: 120),
        ]
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "that's not carbonara, it's cacio e pepe"
        )
        XCTAssertEqual(merged.map(\.name), ["cacio e pepe", "side salad"])
        XCTAssertEqual(merged[0].kcal, 480)
        XCTAssertEqual(merged[1].id, "b")
    }

    func testNothingIsSilentlyDeleted() {
        // The model omitted the fries without any replacement being
        // named — the fries stay.
        let current = [
            item("a", "burger", kcal: 500),
            item("b", "fries", kcal: 350),
        ]
        let response = [item("x", "burger", grams: 180, kcal: 420)]
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "the burger was smaller"
        )
        XCTAssertEqual(merged.map(\.name), ["burger", "fries"])
        XCTAssertEqual(merged[0].kcal, 420)
        XCTAssertEqual(merged[1].kcal, 350)
    }

    func testGlobalNoteAppliesWholesale() {
        // A note that names nothing is a plate-global correction —
        // the model's whole answer applies.
        let current = [
            item("a", "pasta", kcal: 600),
            item("b", "bread", kcal: 200),
        ]
        let response = [
            item("x", "pasta", grams: 75, kcal: 300),
            item("y", "bread", grams: 30, kcal: 100),
        ]
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "way less than that, maybe half"
        )
        XCTAssertEqual(merged.map(\.kcal), [300, 100])
    }

    func testPluralAndSnakeCaseNamesStillMatch() {
        let current = [item("a", "scrambled_eggs", kcal: 220)]
        let response = [item("x", "scrambled eggs", kcal: 160)]
        let merged = SnapRefineMerge.merge(
            current: current, response: response,
            note: "only two eggs, not three"   // "eggs" ↔ "egg(s)"
        )
        XCTAssertEqual(merged[0].kcal, 160)
        XCTAssertEqual(merged[0].id, "a")
    }
}
