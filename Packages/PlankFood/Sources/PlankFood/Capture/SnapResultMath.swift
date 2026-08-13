import Foundation

// MARK: - PlateEditSession
//
// v1.2 snap-food rebuild (2026-07-01) — the pure edit engine behind the
// new single-surface result card. Every edit affordance (portion
// steppers, "ate about half" fraction chips, direct macro typing,
// remove / add ingredient, fix-with-words rebase) routes through this
// value type so the math stays coherent in ONE place and unit-testable
// without a view in sight.
//
// Coherence contract (the industry-wide gap this closes — Cal AI
// ships macro edits that leave calories frozen and totals that don't
// add up, its most-documented credibility bug):
//
//   1. Editing any macro recomputes the item's kcal via Atwater
//      (4p + 4c + 9f).
//   2. Editing kcal directly preserves the macro SHAPE — protein /
//      carbs / fat scale by the same ratio.
//   3. Portion changes scale portion + kcal + every macro linearly.
//   4. Plate totals are always the sum of effective items; the
//      honest-range bounds (kcalLow/High) scale with the total so
//      "± 50" never contradicts the hero number.
//
// Physics clamp (the "27-million-calorie candy bar" guard): at ingest,
// an item's kcal is bounded by what its mass could physically carry
// (9 kcal/g — pure fat), and each macro by the item's gram weight.
// Model output beyond those bounds is a hallucination, not a
// measurement; we tidy it silently and flag the session so telemetry
// can count how often the guard fires.

public struct PlateTotals: Equatable, Sendable {
    public let kcal: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double
    public let grams: Double
}

public struct PlateEditSession {

    /// The scan's items as ingested (post physics-clamp). Reset target.
    public private(set) var baseline: [CapturedItem]
    /// Current working items — per-item edits applied, PRE-fraction.
    public private(set) var items: [CapturedItem]
    /// Plate-level "how much of it did you eat" multiplier (1, ¾, ½, ¼).
    public private(set) var fraction: Double = 1.0
    /// Plate-level metadata carried through from the scan.
    public private(set) var sourceFood: CapturedFood
    /// True when the physics clamp had to tidy at least one ingested
    /// value. Surfaced to analytics, never to the user as an alarm.
    public private(set) var ingestAdjusted: Bool = false

    public init(food: CapturedFood) {
        let clamped = food.items.map(Self.physicsClamped)
        self.baseline = clamped.map(\.item)
        self.items = clamped.map(\.item)
        self.sourceFood = food
        self.ingestAdjusted = clamped.contains(where: \.adjusted)
    }

    // MARK: - Reads

    /// Items with the plate fraction applied — what the card renders
    /// and what gets persisted on "log it".
    public var effectiveItems: [CapturedItem] {
        guard fraction != 1.0 else { return items }
        return items.map { $0.scalingNutrition(by: fraction) }
    }

    public var totals: PlateTotals {
        let list = effectiveItems
        return PlateTotals(
            kcal: list.compactMap(\.kcal).reduce(0, +),
            protein: list.compactMap(\.proteinG).reduce(0, +),
            carbs: list.compactMap(\.carbsG).reduce(0, +),
            fat: list.compactMap(\.fatG).reduce(0, +),
            fiber: list.compactMap(\.fiberG).reduce(0, +),
            grams: list.reduce(0) { $0 + $1.portionGrams }
        )
    }

    public func item(_ id: String) -> CapturedItem? {
        items.first { $0.id == id }
    }

    public func baselineItem(_ id: String) -> CapturedItem? {
        baseline.first { $0.id == id }
    }

    /// True when this item differs from its scan baseline (or was
    /// added by the user — no baseline row).
    public func isEdited(_ id: String) -> Bool {
        guard let current = item(id) else { return false }
        guard let base = baselineItem(id) else { return true }
        return !current.nutritionEquals(base)
    }

    public var isPlateEdited: Bool {
        fraction != 1.0
            || items.count != baseline.count
            || items.contains { isEdited($0.id) }
    }

    /// Current portion as a multiple of the scan's estimate. 1.0 for
    /// user-added items (they are their own baseline).
    public func portionMultiplier(_ id: String) -> Double {
        guard let current = item(id) else { return 1 }
        guard let base = baselineItem(id), base.portionGrams > 0 else { return 1 }
        return current.portionGrams / base.portionGrams
    }

    public func canStepPortion(_ id: String, up: Bool) -> Bool {
        let k = portionMultiplier(id)
        return up ? k < Self.portionGrid.last! - 0.001
                  : k > Self.portionGrid.first! + 0.001
    }

    // MARK: - Mutations

    /// Quarter-of-the-scan portion grid: fine steps around the
    /// estimate, coarser past 2× (matching how people actually
    /// misjudge — "a bit more rice" vs "it was double").
    public static let portionGrid: [Double] =
        [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0]

    /// One stepper tick — snap the current multiplier to the grid and
    /// move one notch. All nutrition scales linearly with the portion.
    public mutating func stepPortion(_ id: String, up: Bool) {
        guard let base = baselineItem(id), base.portionGrams > 0,
              let current = item(id) else { return }
        let k = current.portionGrams / base.portionGrams
        guard let target = Self.neighbor(of: k, up: up) else { return }
        let scaled = base.scalingNutrition(by: target)
        replaceInPlace(scaled.withIdentity(of: current))
    }

    static func neighbor(of k: Double, up: Bool) -> Double? {
        // Nearest grid slot, then move one notch in the tick direction.
        // A value sitting between slots snaps in the direction of travel
        // first (so a 1.1× item steps down to 1.0, up to 1.25).
        guard let nearestIdx = portionGrid.indices.min(by: {
            abs(portionGrid[$0] - k) < abs(portionGrid[$1] - k)
        }) else { return nil }
        let nearest = portionGrid[nearestIdx]
        var idx = nearestIdx
        if up {
            if k >= nearest - 0.001 { idx += 1 }
        } else {
            if k <= nearest + 0.001 { idx -= 1 }
        }
        guard portionGrid.indices.contains(idx) else { return nil }
        return portionGrid[idx]
    }

    /// Plate-level "how much of it did you eat" multiplier.
    /// Non-destructive: stored as a layer over the per-item edits, so
    /// tapping back restores exactly.
    ///
    /// The ceiling used to be a hardcoded 1.0, which is right for a
    /// photographed plate — there is no more food than what was in the
    /// frame — and wrong for a package, where the numbers describe ONE
    /// serving and she may have had two. `PlateShare.maxFraction` reads
    /// the ceiling off the door.
    public mutating func setFraction(_ f: Double) {
        fraction = max(0.05, min(f, PlateShare.maxFraction(for: sourceFood)))
    }

    /// Replace an item wholesale (the editor sheet's save path). The
    /// edited values are re-clamped against physics so a typo (an
    /// extra zero) tidies itself instead of poisoning the plate.
    public mutating func replace(_ item: CapturedItem) {
        replaceInPlace(Self.physicsClamped(item).item)
    }

    public mutating func remove(_ id: String) {
        items.removeAll { $0.id == id }
    }

    /// Append newly-described items (the "+ add something" path). They
    /// join the baseline too — their own values ARE their scan truth.
    public mutating func append(_ newItems: [CapturedItem]) {
        let clamped = newItems.map { Self.physicsClamped($0).item }
        items.append(contentsOf: clamped)
        baseline.append(contentsOf: clamped)
    }

    public mutating func resetItem(_ id: String) {
        guard let base = baselineItem(id) else { return }
        replaceInPlace(base)
    }

    /// Adopt a fresh scan result as the new truth (fix-with-words
    /// response). Per-item edits and the fraction reset — the user
    /// just told us what the plate really is; stale local edits on
    /// top of it would compound confusion.
    public mutating func rebase(on food: CapturedFood) {
        self = PlateEditSession(food: food)
    }

    private mutating func replaceInPlace(_ item: CapturedItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
    }

    // MARK: - Output

    /// The CapturedFood the host persists / shares. Effective items +
    /// range bounds scaled with the kcal total so the honesty band
    /// never contradicts the hero number.
    public func rebuiltFood() -> CapturedFood {
        let list = effectiveItems
        let baselineKcal = baseline.compactMap(\.kcal).reduce(0, +)
        let currentKcal = list.compactMap(\.kcal).reduce(0, +)
        let ratio = baselineKcal > 0 ? currentKcal / baselineKcal : 1
        var out = CapturedFood(
            items: list,
            plateType: sourceFood.plateType,
            source: sourceFood.source,
            confidence: sourceFood.confidence,
            needsSecondPhoto: sourceFood.needsSecondPhoto,
            secondPhotoHint: sourceFood.secondPhotoHint,
            kcalLow: sourceFood.kcalLow.map { $0 * ratio },
            kcalHigh: sourceFood.kcalHigh.map { $0 * ratio }
        )
        // v25 E4 — the plate's memory rides every rebuild: the
        // corrections list (persisted with the entry) and the prior
        // provenance (the reading's "your numbers" row + revert).
        out.appliedCorrections = sourceFood.appliedCorrections
        out.priorApplied = sourceFood.priorApplied
        return out
    }

    // MARK: - Physics clamp

    /// Bound a model-reported item by what its mass can physically
    /// carry: kcal ≤ 9 kcal/g (pure fat), each macro ≤ the item's gram
    /// weight. A floor of 400 kcal on the cap keeps tiny-portion items
    /// (a 20g "candy" misread) from being over-tidied into nonsense.
    static func physicsClamped(_ item: CapturedItem) -> (item: CapturedItem, adjusted: Bool) {
        let grams = max(item.portionGrams, 1)
        let kcalCap = max(400, grams * 9)
        let macroCap = grams

        let kcal = item.kcal.map { min(max($0, 0), kcalCap) }
        let protein = item.proteinG.map { min(max($0, 0), macroCap) }
        let carbs = item.carbsG.map { min(max($0, 0), macroCap) }
        let fat = item.fatG.map { min(max($0, 0), macroCap) }
        let fiber = item.fiberG.map { min(max($0, 0), macroCap) }

        let adjusted = kcal != item.kcal || protein != item.proteinG
            || carbs != item.carbsG || fat != item.fatG || fiber != item.fiberG

        guard adjusted else { return (item, false) }
        return (item.withNutrition(
            portionGrams: item.portionGrams,
            kcal: kcal, proteinG: protein, carbsG: carbs,
            fatG: fat, fiberG: fiber
        ), true)
    }
}

// MARK: - PlateMath (field-level coherence for the editor sheet)

public enum PlateMath {

    /// Atwater factors — the standard 4 / 4 / 9 kcal per gram.
    public static func kcalFromMacros(protein: Double, carbs: Double, fat: Double) -> Double {
        (4 * max(protein, 0) + 4 * max(carbs, 0) + 9 * max(fat, 0)).rounded()
    }

    /// Direct kcal edit — preserve the macro shape, scale all three by
    /// the same ratio. A zero-macro item (or zero prior kcal) can't
    /// scale; macros stay put and only kcal moves.
    public static func macrosScaled(
        toKcal newKcal: Double,
        protein: Double, carbs: Double, fat: Double
    ) -> (protein: Double, carbs: Double, fat: Double) {
        let currentKcal = 4 * protein + 4 * carbs + 9 * fat
        guard currentKcal > 0, newKcal >= 0 else { return (protein, carbs, fat) }
        let r = newKcal / currentKcal
        return (protein * r, carbs * r, fat * r)
    }
}

// MARK: - CapturedItem copy helpers

extension CapturedItem {

    /// Copy with portion + all nutrition fields replaced; identity and
    /// provenance metadata carried through.
    func withNutrition(
        portionGrams newPortion: Double,
        kcal newKcal: Double?,
        proteinG newProtein: Double?,
        carbsG newCarbs: Double?,
        fatG newFat: Double?,
        fiberG newFiber: Double?,
        name newName: String? = nil
    ) -> CapturedItem {
        CapturedItem(
            id: id,
            name: newName ?? name,
            portionGrams: newPortion,
            portionGramsLow: portionGramsLow,
            portionGramsHigh: portionGramsHigh,
            usdaSearchTerms: usdaSearchTerms,
            preparation: preparation,
            cuisineHint: cuisineHint,
            confidence: confidence,
            notes: notes,
            kcal: newKcal,
            proteinG: newProtein,
            carbsG: newCarbs,
            fatG: newFat,
            fiberG: newFiber,
            nutritionSource: nutritionSource,
            sugarG: sugarG,
            sodiumMg: sodiumMg,
            saturatedFatG: saturatedFatG,
            englishName: englishName,
            count: count,
            unit: unit,
            servingsInDish: servingsInDish,
            isShareable: isShareable
        )
    }

    /// Linear scale of portion + every nutrition field (the portion-
    /// change contract: mass and macros move together).
    func scalingNutrition(by f: Double) -> CapturedItem {
        CapturedItem(
            id: id,
            name: name,
            portionGrams: portionGrams * f,
            portionGramsLow: portionGramsLow * f,
            portionGramsHigh: portionGramsHigh * f,
            usdaSearchTerms: usdaSearchTerms,
            preparation: preparation,
            cuisineHint: cuisineHint,
            confidence: confidence,
            notes: notes,
            kcal: kcal.map { $0 * f },
            proteinG: proteinG.map { $0 * f },
            carbsG: carbsG.map { $0 * f },
            fatG: fatG.map { $0 * f },
            fiberG: fiberG.map { $0 * f },
            nutritionSource: nutritionSource,
            sugarG: sugarG.map { $0 * f },
            sodiumMg: sodiumMg.map { $0 * f },
            saturatedFatG: saturatedFatG.map { $0 * f },
            englishName: englishName,
            count: count,
            unit: unit,
            servingsInDish: servingsInDish,
            isShareable: isShareable
        )
    }

    /// Keep another item's id (used when a baseline-derived rebuild
    /// must continue to identify as the on-screen row).
    func withIdentity(of other: CapturedItem) -> CapturedItem {
        guard other.id != id else { return self }
        return CapturedItem(
            id: other.id,
            name: name,
            portionGrams: portionGrams,
            portionGramsLow: portionGramsLow,
            portionGramsHigh: portionGramsHigh,
            usdaSearchTerms: usdaSearchTerms,
            preparation: preparation,
            cuisineHint: cuisineHint,
            confidence: confidence,
            notes: notes,
            kcal: kcal,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            nutritionSource: nutritionSource,
            sugarG: sugarG,
            sodiumMg: sodiumMg,
            saturatedFatG: saturatedFatG,
            englishName: englishName,
            count: count,
            unit: unit,
            servingsInDish: servingsInDish,
            isShareable: isShareable
        )
    }

    /// Nutrition-relevant equality (name + portion + macro fields) —
    /// drives the "edited by you" provenance dot.
    func nutritionEquals(_ other: CapturedItem) -> Bool {
        name == other.name
            && abs(portionGrams - other.portionGrams) < 0.5
            && optEq(kcal, other.kcal)
            && optEq(proteinG, other.proteinG)
            && optEq(carbsG, other.carbsG)
            && optEq(fatG, other.fatG)
    }

    private func optEq(_ a: Double?, _ b: Double?, tolerance: Double = 0.5) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return abs(x - y) < tolerance
        default: return false
        }
    }
}
