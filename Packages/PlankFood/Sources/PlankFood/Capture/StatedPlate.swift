import Foundation

// MARK: - StatedPlate (p61)
//
// **When she states the number, the number is hers.**
//
// The words door sent EVERY sentence to the vision model — including
// "protein bar, 190 cal, 20g protein", a sentence that contains no
// question. The model's job is to estimate what she did not state;
// asked to estimate what she DID state, it can only echo her or
// contradict her, five seconds and one network round trip later.
// Category research says the same thing from the other side: quick-add
// of a known calorie count is one of the small features paying users
// call indispensable, and its absence is a named churn reason.
//
// This is deliberately a STATEMENT parser, not a food parser:
//   - it fires only when the sentence declares energy in calories —
//     "2 eggs and toast" has numbers but states no energy, and goes to
//     the model exactly as before;
//   - what she stated is kept verbatim; what she did not state stays
//     absent (no invented carbs, no invented grams);
//   - the plate wears `NutritionSource.userStated`, so no surface may
//     print an estimate's hedge over her own declaration.
//
// The reading still shows and she still confirms — the parser changes
// WHO authored the numbers, never whether she sees them.

public enum StatedPlate {

    public struct Statement: Equatable, Sendable {
        public var name: String
        public var kcal: Double
        public var proteinG: Double?
        public var carbsG: Double?
        public var fatG: Double?
    }

    /// Bounds of plausibility for a typo, not a physics model: one
    /// plate over 5,000 kcal or a macro over 400 g is more likely a
    /// slipped digit than a meal, and the model door is the safer
    /// reading for it.
    private static let maxKcal: Double = 5_000
    private static let maxMacroG: Double = 400

    // One vocabulary for "calories": kcal / kcals / cal / cals /
    // calorie / calories. The unit is REQUIRED — that is the whole
    // trigger.
    private static let energyPattern =
        #"(?:about |around |roughly |~\s?)?(\d{1,4})\s*(?:k?cals?|calories?)\b"#

    private static func macroPattern(_ words: String) -> [String] {
        [
            // "20g protein" · "20 g of protein" · "20 grams protein"
            #"(\d{1,3}(?:\.\d)?)\s*(?:g|grams?)\s*(?:of\s+)?(?:\#(words))\b"#,
            // "protein 20g" · "protein: 20"
            #"(?:\#(words))[:\s]+(\d{1,3}(?:\.\d)?)\s*(?:g|grams?)?\b"#,
        ]
    }

    /// Parse a sentence into a statement, or nil when the sentence
    /// does not state its own energy (→ the model door, unchanged).
    public static func parse(_ text: String) -> Statement? {
        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else { return nil }

        var consumed: [Range<String.Index>] = []

        guard let energy = firstNumber(in: sentence, pattern: energyPattern,
                                       consumed: &consumed),
              energy > 0, energy <= maxKcal
        else { return nil }

        func macro(_ words: String) -> Double? {
            for pattern in macroPattern(words) {
                if let v = firstNumber(in: sentence, pattern: pattern,
                                       consumed: &consumed) {
                    guard v <= maxMacroG else { return nil }
                    return v
                }
            }
            return nil
        }

        let protein = macro("protein")
        let carbs = macro("carbs?|carbohydrates?")
        let fat = macro("fat")

        // The name is the sentence minus its number phrases.
        var name = sentence
        for range in consumed.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            name.removeSubrange(range)
        }
        name = name
            .replacingOccurrences(of: #"\s*(?:,|·|;|\band\b|\bwith\b|-)\s*$"#,
                                  with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*(?:,|·|;|\band\b|\bwith\b|-)\s*"#,
                                  with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"\s+,"#, with: ",",
                                  options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,·;-"))

        return Statement(
            name: name.isEmpty ? "quick add" : name,
            kcal: energy,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat
        )
    }

    /// The plate a statement becomes. One item, her numbers verbatim,
    /// nothing invented: no portion mass, no range band, no confidence
    /// (confidence describes a model's judgement; there was none).
    public static func plate(from statement: Statement) -> CapturedFood {
        let item = CapturedItem(
            id: UUID().uuidString,
            name: statement.name,
            portionGrams: 0, portionGramsLow: 0, portionGramsHigh: 0,
            usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
            confidence: nil, notes: nil,
            kcal: statement.kcal,
            proteinG: statement.proteinG,
            carbsG: statement.carbsG,
            fatG: statement.fatG,
            fiberG: nil,
            nutritionSource: .userStated
        )
        return CapturedFood(
            items: [item], plateType: .single,
            source: .words,
            confidence: nil, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
    }

    // MARK: - Matching

    /// First match of `pattern` whose capture-1 parses as a number and
    /// whose range does not overlap an already-consumed phrase. The
    /// matched range is consumed so "chicken 300 cal 20g protein"
    /// cannot read 300 twice.
    private static func firstNumber(
        in sentence: String, pattern: String,
        consumed: inout [Range<String.Index>]
    ) -> Double? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive]
        ) else { return nil }
        let ns = sentence as NSString
        let matches = regex.matches(
            in: sentence, range: NSRange(location: 0, length: ns.length)
        )
        for match in matches {
            guard let whole = Range(match.range, in: sentence),
                  match.numberOfRanges > 1,
                  let capture = Range(match.range(at: 1), in: sentence),
                  let value = Double(sentence[capture])
            else { continue }
            guard !consumed.contains(where: { $0.overlaps(whole) }) else { continue }
            consumed.append(whole)
            return value
        }
        return nil
    }
}
