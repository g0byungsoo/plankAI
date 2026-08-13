import Foundation

// MARK: - PlateShare
//
// THE PORTION IS PART OF THE NUMBER.
//
// The food-vision schema has computed two fields since 2026-06-23 that
// exist for exactly one purpose. From the Edge Function's own system
// prompt:
//
//   "- servings_in_dish = how many normal human servings the WHOLE
//      visible food is (whole large pizza ~8 …)
//    - DO NOT pre-divide and DO NOT estimate headcount. the app divides
//      by the user's own input."
//
// and its worked example C:
//
//   "C — a whole 12-inch pepperoni pizza on the table: kcal is for the
//    WHOLE pizza (~2200), NOT a slice. … the app lets the user say they
//    ate 2 slices."
//
// The app never did. `servingsInDish`, `isShareable`, `count` and `unit`
// were threaded through eight copy constructors and read by nothing, and
// the only "how much of it" control was a hard-coded 1 / ¾ / ½ / ¼
// ladder clamped to `min(f, 1.0)`. On a whole pizza the finest thing she
// could say was "a few bites" — 25%, or two slices — and the plate filed
// ~2,200 kcal by default.
//
// That is the seam in its purest form: a layer knows the dish is meant
// to be divided, and no layer says so.
//
// TWO RULES THIS ENGINE KEEPS
//
// 1. THE COMMON PLATE IS UNTOUCHED. The trigger is the model's own
//    `is_shareable` on the item that carries the plate's calories. The
//    prompt tells it to set `servings_in_dish=1, is_shareable=false` for
//    "a normal single plate (the common case)", so a bowl of oatmeal
//    keeps the ladder it has always had. Logging does not become a
//    questionnaire; the question appears only where the answer moves the
//    record by multiples.
//
// 2. THE NUMBER IS NEVER CHANGED SILENTLY. A shared dish still defaults
//    to "all of it". Defaulting to 1/N would be guessing in the other
//    direction, and this product does not invent a portion any more than
//    it invents a calorie. What changes is that the plate now SAYS what
//    its numbers describe, and offers rungs that can express the answer.

public enum PlateShare {

    /// One rung of the "how much of it did you eat" ladder. `label`
    /// renders in the body face and `punch` in the serif italic, the
    /// same two-run composition the chips have always used.
    public struct Rung: Equatable, Sendable, Identifiable {
        public let label: String
        public let punch: String
        public let value: Double
        public var id: Double { value }

        public init(label: String, punch: String, value: Double) {
            self.label = label
            self.punch = punch
            self.value = value
        }

        /// What VoiceOver says. The chips are the only control on the
        /// reading whose meaning is entirely in its text.
        public var voiceLabel: String { "ate \(label)\(punch)" }
    }

    /// The ladder for one plate in front of one person. Unchanged from
    /// the shipped chips — this is what almost every scan still gets.
    public static let soloLadder: [Rung] = [
        Rung(label: "all of ", punch: "it", value: 1.0),
        Rung(label: "about ", punch: "\u{00BE}", value: 0.75),
        Rung(label: "about ", punch: "half", value: 0.5),
        Rung(label: "a few ", punch: "bites", value: 0.25),
    ]

    // MARK: - Is this a dish meant to be divided?

    /// The item carrying the plate's calories. A shared table is usually
    /// a platter plus small sides; the platter's serving count is the one
    /// that means anything, and it is also the item the Edge Function
    /// reasons hardest about ("opaque-bowl depth on the dominant-kcal
    /// item").
    static func dominantItem(of food: CapturedFood) -> CapturedItem? {
        food.items.max { ($0.kcal ?? 0) < ($1.kcal ?? 0) }
    }

    /// How many human servings the whole visible dish is, but ONLY when
    /// the model also said it is a dish people share. Both halves are
    /// required: `servings_in_dish` alone says a big lasagne is four
    /// servings, which is true and irrelevant when one person is holding
    /// the plate.
    ///
    /// nil means "one person, one plate" — the answer for the vast
    /// majority of scans.
    public static func servings(in food: CapturedFood) -> Int? {
        guard let item = dominantItem(of: food),
              item.isShareable == true,
              let n = item.servingsInDish,
              n >= 2
        else { return nil }
        // A dish claiming more than 24 servings is a model artefact, not
        // a dinner. Clamp rather than render "1/40th of it".
        return min(n, 24)
    }

    // MARK: - The unit word

    /// The countable noun for one serving, when one visible unit IS one
    /// serving — a pizza cut into 8 slices where the model set count=8
    /// and servings_in_dish=8. A platter (count=1, unit="serving",
    /// servings=4) has no such noun and falls back to "serving".
    ///
    /// Guarded because `unit` is free-form model output that reaches a
    /// rendered string: letters only, short, and singular.
    static func unitWord(for item: CapturedItem?, servings: Int) -> String {
        guard let item,
              let raw = item.unit?.trimmingCharacters(in: .whitespacesAndNewlines)
                  .lowercased(),
              !raw.isEmpty,
              raw.count <= 12,
              raw.allSatisfy({ $0.isLetter }),
              raw != "serving",
              item.count == servings
        else { return "serving" }
        return raw
    }

    static func pluralize(_ word: String, _ n: Int) -> String {
        n == 1 ? word : word + "s"
    }

    // MARK: - The ladder

    /// The rungs offered for this plate.
    ///
    /// For a solo plate: the shipped ladder, untouched.
    ///
    /// For a dish of N servings, in descending order:
    ///   - all of it
    ///   - half, when N is 4 or more (a natural human split that is not
    ///     also a whole number of servings)
    ///   - two servings, when N is 3 or more
    ///   - one serving
    ///
    /// Deduped within 2% — on a 4-serving dish "two servings" IS half, and
    /// the serving label wins because it is the more precise instrument.
    /// Capped at four rungs, which is the width the row has always been.
    public static func ladder(for food: CapturedFood) -> [Rung] {
        if isPackagedServing(food) { return packagedLadder(for: food) }
        guard let n = servings(in: food) else { return soloLadder }
        let unit = unitWord(for: dominantItem(of: food), servings: n)
        let denominator = Double(n)

        var out: [Rung] = [Rung(label: "all of ", punch: "it", value: 1.0)]
        if n >= 4 {
            out.append(Rung(label: "about ", punch: "half", value: 0.5))
        }
        if n >= 3 {
            out.append(
                Rung(label: "2 ", punch: pluralize(unit, 2), value: 2 / denominator)
            )
        }
        out.append(Rung(label: "1 ", punch: pluralize(unit, 1), value: 1 / denominator))

        // Dedupe by value, keeping the LAST of any collision: the serving
        // rungs are appended after "half", so a 4-serving dish keeps
        // "2 servings" over "half".
        var kept: [Rung] = []
        for rung in out {
            if let i = kept.firstIndex(where: { abs($0.value - rung.value) < 0.02 }) {
                kept[i] = rung
            } else {
                kept.append(rung)
            }
        }
        return Array(kept.sorted { $0.value > $1.value }.prefix(4))
    }

    // MARK: - What the numbers describe

    /// The sentence that makes the ladder legible, and the whole point of
    /// this engine: a plate whose numbers describe more food than one
    /// person eats must say so before she files it.
    ///
    /// nil for a solo plate — there is nothing to explain, and a caption
    /// under every scan would be noise.
    public static func wholeDishNote(for food: CapturedFood) -> String? {
        if isPackagedServing(food) {
            // Says the unit the numbers are IN. The label's serving is
            // the manufacturer's choice, not hers, and it is the one
            // thing about a barcode read she cannot see.
            guard let n = packageServings(food) else {
                return "these are one serving's numbers, from the label"
            }
            return "one serving \u{00B7} this package holds about \(n)"
        }
        guard let n = servings(in: food) else { return nil }
        let unit = unitWord(for: dominantItem(of: food), servings: n)
        // Short on purpose. It sits under the dish name and above every
        // number it qualifies, so at AX5 a longer sentence pushed the
        // protein figure out of the opening detent — filmed. It cannot
        // be shortened past the two facts it carries: these numbers
        // cover the WHOLE thing, and the whole thing is about N.
        return "the whole dish \u{00B7} about \(n) \(pluralize(unit, n))"
    }

    // MARK: - Packaged food counts UP

    /// A barcode or a nutrition panel describes ONE SERVING as the
    /// manufacturer defined it — `BarcodeRead` maps `portion_grams` to
    /// the label's serving mass and notes "one serving, from the label".
    ///
    /// So the whole ladder pointed the wrong way. Every rung on a printed
    /// plate was a fraction of one serving; a person who ate two servings
    /// of a four-serving bag had no rung at all and had to open the
    /// ingredient editor and drag a gram slider to say so. The most
    /// accurate reading in the app was the least expressible, and it
    /// carried `confidence: 1.0` while its portion was pure assumption.
    ///
    /// Printed plates count up.
    public static func isPackagedServing(_ food: CapturedFood) -> Bool {
        food.source.isPrintedTruth && food.items.count == 1
    }

    /// The most servings of one packaged item a rung will offer when the
    /// package size is unknown. Past three the ingredient editor's gram
    /// stepper is the better instrument, and a row of eight chips is not
    /// a control.
    static let maxPackagedServings = 3

    /// How many servings the package holds, when the source knows.
    ///
    /// `BarcodeRead` derives it from Open Food Facts' own
    /// `product_quantity ÷ serving_quantity`; a label read will carry the
    /// panel's printed "servings per container" once the Edge Function
    /// asks for it. nil means the package size was never established, and
    /// the ladder falls back to a generic three.
    static func packageServings(_ food: CapturedFood) -> Int? {
        guard isPackagedServing(food), let n = food.items.first?.servingsInDish,
              n >= 2 else { return nil }
        return min(n, 24)
    }

    /// A packaged plate counts UP, and stops where the package does. A
    /// four-serving bag offers no rung past four: an instrument that can
    /// express "five servings of a four-serving bag" is not honest about
    /// the package it just read.
    static func packagedLadder(for food: CapturedFood) -> [Rung] {
        let ceiling = min(packageServings(food) ?? maxPackagedServings, 3)
        var out: [Rung] = []
        for n in stride(from: ceiling, through: 2, by: -1) {
            out.append(Rung(label: "\(n) ", punch: "servings", value: Double(n)))
        }
        out.append(Rung(label: "1 ", punch: "serving", value: 1.0))
        out.append(Rung(label: "about ", punch: "half", value: 0.5))
        return out
    }

    /// The ceiling `PlateEditSession.setFraction` clamps to. One for a
    /// plate of visible food — there is no more of it than what was
    /// photographed — and, for a package, the whole package when its size
    /// is known and a generic three when it is not.
    public static func maxFraction(for food: CapturedFood) -> Double {
        guard isPackagedServing(food) else { return 1.0 }
        return Double(packageServings(food) ?? maxPackagedServings)
    }
}
