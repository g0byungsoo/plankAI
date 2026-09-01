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

public enum SnapResultMath {
    /// p53 — the physics line: does the plate's claimed energy
    /// disagree with its own macros by more than a quarter (Atwater
    /// 4/4/9)? Absence never testifies — an item missing any macro
    /// sits the comparison out, and a plate with no complete item
    /// cannot disagree with itself.
    public static func plateDisagrees(_ food: CapturedFood) -> Bool {
        var kcal = 0.0, atwater = 0.0, complete = 0
        for item in food.items {
            guard let k = item.kcal, let p = item.proteinG,
                  let c = item.carbsG, let f = item.fatG else { continue }
            kcal += k
            atwater += 4 * p + 4 * c + 9 * f
            complete += 1
        }
        guard complete > 0, max(kcal, atwater) >= 40 else { return false }
        return abs(kcal - atwater) > 0.25 * max(kcal, atwater)
    }
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

    /// p53 — ids the "+ add something" path introduced (they join
    /// the baseline, so the diff needs its own memory of them).
    private var addedIds: Set<String> = []

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
        addedIds.formUnion(clamped.map(\.id))
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

    /// p53 — the session's DELIBERATE edits, derived from the diff
    /// (state, never an event log — four stepper ticks on one item
    /// are one note, and reset-to-baseline is no note at all).
    public var derivedEditNotes: [String] {
        var notes: [String] = []
        // Removed: baseline rows absent from the working set (a
        // user-added item she removed again leaves no trace).
        for base in baseline where item(base.id) == nil {
            guard !addedIds.contains(base.id) else { continue }
            notes.append("removed \(base.name.lowercased())")
        }
        for current in items {
            if addedIds.contains(current.id) {
                notes.append("added \(current.name.lowercased())")
                continue
            }
            guard isEdited(current.id), let base = baselineItem(current.id)
            else { continue }
            let k = portionMultiplier(current.id)
            let portionOnly = current.nutritionEquals(
                base.scalingNutrition(by: k)
            )
            if portionOnly, abs(k - 1) > 0.001 {
                notes.append(
                    "\(current.name.lowercased()) — \(Self.portionWord(k)) the scan"
                )
            } else {
                notes.append("\(current.name.lowercased()) — your numbers")
            }
        }
        if abs(fraction - 1) > 0.001 {
            notes.append("had \(Self.fractionWord(fraction))")
        }
        return notes
    }

    static func portionWord(_ k: Double) -> String {
        switch k {
        case ..<0.999: return "\(Self.trim(k))× of"
        default: return "\(Self.trim(k))×"
        }
    }

    static func fractionWord(_ f: Double) -> String {
        switch f {
        case 0.24...0.26: return "a quarter of it"
        case 0.49...0.51: return "half of it"
        case 0.74...0.76: return "three quarters of it"
        case 1.99...2.01: return "two servings"
        case 2.99...3.01: return "three servings"
        default: return "\(Self.trim(f))× of it"
        }
    }

    private static func trim(_ v: Double) -> String {
        let s = String(format: "%.2f", v)
        return s.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    /// The CapturedFood the host persists / shares. Effective items +
    /// range bounds scaled with the kcal total so the honesty band
    /// never contradicts the hero number.
    public func rebuiltFood() -> CapturedFood {
        let list = effectiveItems
        let baselineKcal = baseline.compactMap(\.kcal).reduce(0, +)
        let currentKcal = list.compactMap(\.kcal).reduce(0, +)
        let ratio = baselineKcal > 0 ? currentKcal / baselineKcal : 1
        // A mutation of the source plate, not a re-init: the plate's
        // memory (corrections, prior provenance) and any field this
        // rebuild never heard of ride along by construction (pass 51 —
        // this site used to re-init and re-attach two fields by hand).
        var out = sourceFood
        out.items = list
        out.kcalLow = sourceFood.kcalLow.map { $0 * ratio }
        out.kcalHigh = sourceFood.kcalHigh.map { $0 * ratio }
        // p53 — every deliberate edit is a remembered fact: the
        // diff's notes join whatever the plate already carried (a
        // relogged base keeps its history).
        out.editNotes = sourceFood.editNotes + derivedEditNotes
        return out
    }

    // MARK: - Physics clamp

    /// Bound a model-reported item by what its mass can physically
    /// carry: kcal ≤ 9 kcal/g (pure fat), each macro ≤ the item's gram
    /// weight. A floor of 400 kcal on the cap keeps tiny-portion items
    /// (a 20g "candy" misread) from being over-tidied into nonsense.
    static func physicsClamped(_ item: CapturedItem) -> (item: CapturedItem, adjusted: Bool) {
        // p61 — no mass, no physics. This used to floor an unknown
        // portion to 1g, whose cap is the 400 floor — so a stated
        // 800-kcal plate with no recorded grams was "tidied" to 400.
        // A bound derived from a mass we do not know is not a bound.
        guard item.portionGrams > 0 else { return (item, false) }
        let grams = item.portionGrams
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
//
// v25 pass 51 — every helper here is a MUTATION of `self`, never a
// re-init through the memberwise initializer. A hand-written init with
// defaulted parameters hides an omission from the compiler, and that
// exact shape dropped a newly-added field five recorded times — the
// fifth being these three helpers erasing `micros` on every portion
// edit, fraction, clamp and re-key. A mutation names what it changes
// and carries every other field by construction.
// `FieldPreservationTests` pins the contract and catches the next
// forgotten field when the model grows.

extension CapturedItem {

    /// Copy with portion + all nutrition fields replaced; every field
    /// the edit did not name — identity, provenance, accuracy metadata,
    /// micronutrients — carried through by construction. All current
    /// callers keep the portion unchanged (the clamp, the editor's
    /// macro rewrite); the micros stay as grounded.
    func withNutrition(
        portionGrams newPortion: Double,
        kcal newKcal: Double?,
        proteinG newProtein: Double?,
        carbsG newCarbs: Double?,
        fatG newFat: Double?,
        fiberG newFiber: Double?,
        name newName: String? = nil
    ) -> CapturedItem {
        var copy = self
        copy.name = newName ?? name
        copy.portionGrams = newPortion
        copy.kcal = newKcal
        copy.proteinG = newProtein
        copy.carbsG = newCarbs
        copy.fatG = newFat
        copy.fiberG = newFiber
        return copy
    }

    /// Linear scale of portion + every nutrition field (the portion-
    /// change contract: mass and macros move together — and so do the
    /// micronutrients, which are the same portion's contents).
    func scalingNutrition(by f: Double) -> CapturedItem {
        var copy = self
        copy.portionGrams = portionGrams * f
        copy.portionGramsLow = portionGramsLow * f
        copy.portionGramsHigh = portionGramsHigh * f
        copy.kcal = kcal.map { $0 * f }
        copy.proteinG = proteinG.map { $0 * f }
        copy.carbsG = carbsG.map { $0 * f }
        copy.fatG = fatG.map { $0 * f }
        copy.fiberG = fiberG.map { $0 * f }
        copy.sugarG = sugarG.map { $0 * f }
        copy.sodiumMg = sodiumMg.map { $0 * f }
        copy.saturatedFatG = saturatedFatG.map { $0 * f }
        copy.micros = micros.map { $0.scaled(by: f) }
        return copy
    }

    /// Keep another item's id (used when a baseline-derived rebuild
    /// must continue to identify as the on-screen row). The id changes
    /// and NOTHING else.
    func withIdentity(of other: CapturedItem) -> CapturedItem {
        var copy = self
        copy.id = other.id
        return copy
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
