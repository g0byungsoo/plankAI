import XCTest
@testable import PlankFood

// MARK: - ResultDetailVoiceTests (app v25 pass 54)
//
// `ResultDetailCopy` is the largest interpretive corpus in the food
// rail (~30 sentences a plate can say at the reading) and until this
// pass it had voice coverage on exactly one module (provenance). The
// census found what an unswept corpus grows:
//
//   · em-dashes inside shipped strings, in a product whose design law
//     bans them between words
//   · claims past their evidence ("extends fullness by hours",
//     "blunts later cravings"), and grading ("a practical win") in a
//     product whose law is report-never-grade
//   · water-drinking advice attached to a sodium read ("extra water
//     helps") — the E9 stance is that no fluid instruction ships
//     without the label's own authority behind it
//   · "plan a lighter evening meal" delivered to the on-medication
//     cohort — an instruction to eat less, aimed at the population
//     the count-up grammar exists to protect from exactly that
//
// RED before GREEN against the shipped copy.

final class ResultDetailVoiceTests: XCTestCase {

    private func plate(
        kcal: Double, protein: Double = 8, carbs: Double = 40,
        fat: Double = 12, fiber: Double = 4,
        sugar: Double = 0, sodium: Double = 0, satfat: Double = 0,
        items: Int = 1
    ) -> CapturedFood {
        let all = (0..<items).map { index in
            CapturedItem(
                id: "i\(index)", name: "granola \(index)", portionGrams: 55,
                portionGramsLow: 55, portionGramsHigh: 55,
                usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
                confidence: 0.9, notes: nil,
                kcal: kcal / Double(items),
                proteinG: protein / Double(items),
                carbsG: carbs / Double(items),
                fatG: fat / Double(items),
                fiberG: fiber / Double(items),
                nutritionSource: .llmDirect,
                sugarG: sugar > 0 ? sugar / Double(items) : nil,
                sodiumMg: sodium > 0 ? sodium / Double(items) : nil,
                saturatedFatG: satfat > 0 ? satfat / Double(items) : nil
            )
        }
        return CapturedFood(
            items: all, plateType: .single, source: .photo,
            confidence: 0.9, needsSecondPhoto: false,
            secondPhotoHint: nil, kcalLow: nil, kcalHigh: nil
        )
    }

    private func everySentence(
        _ food: CapturedFood, isGlp1: Bool, hour: Int = 13,
        kcalTarget: Int = 1600
    ) -> [String] {
        let copy = ResultDetailCopy(
            food: food,
            ctx: ResultDetailContext(
                proteinTargetG: 90, todayLoggedProtein: 20,
                kcalTarget: kcalTarget, isGlp1: isGlp1, hour: hour
            )
        )
        var out: [String] = []
        let fit = copy.dayFit
        out.append(fit.prefix + fit.punch + fit.suffix)
        if let consideration = copy.consideration {
            out.append(consideration.ackPrefix + consideration.ackPunch
                       + consideration.ackSuffix)
            out.append(consideration.action)
        }
        let note = copy.jeniNote
        out.append(note.prefix + note.punch + note.suffix)
        if let provenance = copy.provenance { out.append(provenance) }
        return out
    }

    /// A probe grid wide enough to reach every module branch: sodium,
    /// sugar, sat-fat, carb-shape, low-protein, fat-share, safety net,
    /// multi-item, high-protein, both cohorts, morning and evening.
    private var probes: [(CapturedFood, Bool, Int)] {
        [
            (plate(kcal: 900, sodium: 950), false, 13),
            (plate(kcal: 700, sugar: 24), false, 13),
            (plate(kcal: 700, satfat: 9), false, 13),
            (plate(kcal: 500, protein: 8, carbs: 70, fat: 8, fiber: 2), false, 13),
            (plate(kcal: 450, protein: 6), false, 13),
            (plate(kcal: 400, protein: 10, carbs: 5, fat: 30), false, 20),
            (plate(kcal: 120), false, 13),
            (plate(kcal: 620, protein: 34), false, 9),
            (plate(kcal: 620, protein: 34), true, 9),
            (plate(kcal: 500, items: 4), false, 13),
            (plate(kcal: 430, fat: 22, fiber: 1), false, 18),
            (plate(kcal: 900, sodium: 950), true, 13),
            (plate(kcal: 850), true, 12),
            (plate(kcal: 850), false, 12),
            (plate(kcal: 1100), true, 14),
            (plate(kcal: 1100), false, 19),
        ]
    }

    // MARK: - the register holds everywhere

    func testNoInterpretiveSentenceCarriesAnEmDash() {
        for (food, glp1, hour) in probes {
            for sentence in everySentence(food, isGlp1: glp1, hour: hour) {
                XCTAssertFalse(
                    sentence.contains("\u{2014}"),
                    "an em-dash between words, in shipped copy: \(sentence)"
                )
            }
        }
    }

    func testNoSentenceGradesOrOverclaims() {
        // Each token is a named finding: hours-of-fullness is a claim
        // past the satiety evidence; "blunts" and "a practical win"
        // are grading; "energy curve" is precision theater; "usually
        // brings better fiber" guesses at a value this plate MEASURES;
        // "extra water helps" is fluid advice without the label's
        // authority.
        let banned = [
            "by hours", "blunts", "practical win", "energy curve",
            "usually brings better", "extra water helps",
        ]
        for (food, glp1, hour) in probes {
            for sentence in everySentence(food, isGlp1: glp1, hour: hour) {
                for token in banned {
                    XCTAssertFalse(
                        sentence.contains(token),
                        "'\(token)' in: \(sentence)"
                    )
                }
            }
        }
    }

    // MARK: - the count-up law reaches the reading

    /// The medication cohort under-eats; "plan a lighter evening meal"
    /// is an instruction to eat less, handed to the population every
    /// other surface protects with the count-up grammar. The reading
    /// states the share and stops.
    func testAGlp1PlateIsNeverToldToPlanALighterMeal() {
        for hour in [10, 14, 19] {
            for kcal in [700.0, 900.0, 1_200.0] {
                let sentences = everySentence(
                    plate(kcal: kcal), isGlp1: true, hour: hour
                )
                for sentence in sentences {
                    XCTAssertFalse(
                        sentence.contains("lighter"),
                        "an eat-less instruction reached the on-medication cohort: \(sentence)"
                    )
                }
            }
        }
    }
}
