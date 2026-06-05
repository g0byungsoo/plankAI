#if canImport(UIKit)
import SwiftUI

// MARK: - FoodCorrectionSheet
//
// Per v5 §Calorie scan Screen 7: edit sheet shown when the user
// taps an item in the result card. Three correction affordances
// (top to bottom by frequency of use):
//
//   1. PortionStepper — adjust grams via 3-stop haptic slider
//      (covers ~70% of corrections per audience research; people
//      mostly want "less of that")
//   2. Search for the right thing — open canonical_pantry + USDA
//      + recent foods picker (covers ~25%; "this isn't carbonara,
//      it's arrabbiata")
//   3. Describe in words → re-runs LLM with text context (covers
//      ~5%; complex cases where the visual + initial guess both
//      missed)
//
// The food_corrections row insert (v3 corrections-as-moat) fires
// on Save regardless of which affordance the user used — captures
// the diff between original LLM output and final logged data.
// That data flywheel is what makes JeniFit's accuracy compound
// post-launch (the v1.0.8 fine-tune kicks off when ~50k corrections
// have accumulated per v5 D27).
//
// For W3-T5 we ship affordance #1 (PortionStepper) fully wired,
// #2 and #3 as stubbed buttons that surface "coming soon" — the
// search picker and re-run-with-text are W3.5/W4 tickets that
// touch more infrastructure (recent-foods cache, LLM text-context
// re-run path).

public struct FoodCorrectionSheet: View {

    public let original: CapturedItem
    public let onSave: (CapturedItem) -> Void
    public let onCancel: () -> Void

    @State private var editedGrams: Double

    public init(
        original: CapturedItem,
        onSave: @escaping (CapturedItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.original = original
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedGrams = State(initialValue: original.portionGrams)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.lg) {

            topBar

            // Item header — show what's being edited.
            VStack(alignment: .leading, spacing: 4) {
                Text("editing")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .tracking(1.5)
                let parsed = ItalicAccentText.parseAsterisks(original.name)
                ItalicAccentText(
                    parsed.base,
                    italic: parsed.italic,
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 22),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22)
                )
            }

            Divider().overlay(FoodTheme.accentSubtle)

            // Affordance #1 — portion slider. Lands in v1.0.7.
            PortionStepper(
                initialGrams: original.portionGrams,
                lowGrams: max(original.portionGramsLow, 10),
                highGrams: max(original.portionGramsHigh, original.portionGrams * 1.5),
                onChange: { newGrams in
                    editedGrams = newGrams
                }
            )

            Divider().overlay(FoodTheme.accentSubtle)

            // Affordance #2 — food picker. Stubbed in v1.0.7;
            // search sheet is a W3.5 ticket.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
                Text("not \(displayNameForSearch)?")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
                Text("search →")
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
            .padding(.vertical, 12)
            .accessibilityHint("opens food picker")

            // Affordance #3 — describe in words. Stubbed in v1.0.7;
            // text-context LLM re-run is a W3.5 / W4 ticket.
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
                Text("describe it instead →")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 12)
            .accessibilityHint("re-runs identification with your description")

            Spacer(minLength: 0)

            saveButton
        }
        .padding(FoodTheme.Space.lg)
        .background(FoodTheme.bgPrimary)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Subviews

    @ViewBuilder private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("cancel")
        }
    }

    @ViewBuilder private var saveButton: some View {
        Button {
            saveTapped()
        } label: {
            Text("save")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FoodTheme.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(FoodTheme.textPrimary))
        }
    }

    // MARK: - Helpers

    /// Strip the italic asterisks from the item name for the
    /// "not <name>?" search prompt. (The italic markers are display-
    /// only; the search query is the plain name.)
    private var displayNameForSearch: String {
        ItalicAccentText.parseAsterisks(original.name).base
    }

    private func saveTapped() {
        // Recompute the item with the edited portion. Macros scale
        // linearly with portion via CalorieMathService when we have
        // a NutritionDensity; here we approximate by scaling each
        // macro field by the ratio (editedGrams / originalGrams).
        let ratio = original.portionGrams > 0
            ? editedGrams / original.portionGrams
            : 1.0
        let scaled = scale(original, by: ratio, newGrams: editedGrams)

        // TODO: W3-T5 follow-up — fire food_corrections insert with
        // diff between `original` and `scaled`. Requires SyncService
        // upsertFoodCorrection method (W3-T6 SwiftData model + sync
        // landing in the same sprint).
        onSave(scaled)
    }

    /// Pure scaling helper — multiplies portion + each macro by the
    /// new/old grams ratio. Keeps confidence + source_id intact
    /// because the corrections-as-moat row still references the
    /// LLM's original output.
    private func scale(_ item: CapturedItem, by ratio: Double, newGrams: Double) -> CapturedItem {
        CapturedItem(
            id: item.id,
            name: item.name,
            portionGrams: newGrams,
            portionGramsLow: item.portionGramsLow * ratio,
            portionGramsHigh: item.portionGramsHigh * ratio,
            usdaSearchTerms: item.usdaSearchTerms,
            preparation: item.preparation,
            cuisineHint: item.cuisineHint,
            confidence: item.confidence,
            notes: item.notes,
            kcal: item.kcal.map { $0 * ratio },
            proteinG: item.proteinG.map { $0 * ratio },
            carbsG: item.carbsG.map { $0 * ratio },
            fatG: item.fatG.map { $0 * ratio },
            fiberG: item.fiberG.map { $0 * ratio },
            nutritionSource: item.nutritionSource
        )
    }
}

// MARK: - Preview

#Preview("FoodCorrectionSheet") {
    let original = CapturedItem(
        id: "1",
        name: "creamy *carbonara*",
        portionGrams: 320,
        portionGramsLow: 250,
        portionGramsHigh: 400,
        usdaSearchTerms: ["carbonara"],
        preparation: "boiled",
        cuisineHint: "italian",
        confidence: 0.87,
        notes: nil,
        kcal: 480,
        proteinG: 22,
        carbsG: 50,
        fatG: 18,
        fiberG: 2,
        nutritionSource: .canonicalPantry
    )

    return Color.clear
        .sheet(isPresented: .constant(true)) {
            FoodCorrectionSheet(
                original: original,
                onSave: { _ in print("save") },
                onCancel: { print("cancel") }
            )
        }
}

#endif  // canImport(UIKit)
