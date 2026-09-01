#if canImport(UIKit)
import SwiftUI

// MARK: - IngredientEditorSheet
//
// v1.2 snap-food rebuild (2026-07-01) — the deep-edit surface behind a
// ledger-row tap. Supersedes the private IngredientEditSheet that
// lived inside ResultDecisionCard.
//
// What's new vs the old sheet:
//   - COHERENT MATH. Editing protein / carbs / fat live-recomputes
//     calories (Atwater 4/4/9); editing calories directly rescales the
//     macros to keep their shape. The category leader ships macro
//     edits that leave calories frozen — this is the credibility gap
//     the rebuild closes. A quiet "numbers stay in sync ♡" caption
//     names the behavior so the auto-updating field reads as care,
//     not a glitch.
//   - Save is a COCOA capsule (the one-CTA system; the old rose fill
//     violated the locked cocoa-CTA rule).
//   - "reset to the scan" restores name + portion + every number.
//
// Presentation: cream sheet, her75 typography, hairline rules, single
// rose accent. Medium detent covers everything; large gives the
// keyboard room.

struct IngredientEditorSheet: View {

    let original: CapturedItem
    /// The scan's baseline for this item (reset target). nil for a
    /// user-added item — reset hides.
    let scanBaseline: CapturedItem?
    let onSave: (CapturedItem) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var portion: Double
    @State private var kcal: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double

    private enum Field: Hashable { case name, kcal, protein, carbs, fat }
    @FocusState private var focused: Field?

    init(
        original: CapturedItem,
        scanBaseline: CapturedItem?,
        onSave: @escaping (CapturedItem) -> Void,
        onRemove: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.original = original
        self.scanBaseline = scanBaseline
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
        _name = State(initialValue: original.name)
        _portion = State(initialValue: original.portionGrams)
        _kcal = State(initialValue: (original.kcal ?? 0).rounded())
        _protein = State(initialValue: (original.proteinG ?? 0).rounded())
        _carbs = State(initialValue: (original.carbsG ?? 0).rounded())
        _fat = State(initialValue: (original.fatG ?? 0).rounded())
    }

    private var anchor: CapturedItem { scanBaseline ?? original }

    private var portionMin: Double { max(10, anchor.portionGrams * 0.25) }
    private var portionMax: Double { max(anchor.portionGrams * 4, portionMin + 10) }

    /// p61 — an item with no recorded mass (a usual rebuilt from a
    /// plate-level record; a stated quick add) has no anchor to scale
    /// from. The slider used to render a 10–20g nonsense range whose
    /// delta multiplied every scaled field by `portion / 1`. No mass →
    /// no portion row; the direct fields still edit.
    private var portionIsKnown: Bool { anchor.portionGrams > 0 }

    private var isLowConfidence: Bool {
        (original.confidence ?? 1) < 0.65
    }

    private var isDirty: Bool {
        name != anchor.name
            || abs(portion - anchor.portionGrams) >= 1
            || abs(kcal - (anchor.kcal ?? 0)) >= 1
            || abs(protein - (anchor.proteinG ?? 0)) >= 1
            || abs(carbs - (anchor.carbsG ?? 0)) >= 1
            || abs(fat - (anchor.fatG ?? 0)) >= 1
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    header
                    nameField
                    hairline
                    if portionIsKnown { portionBlock }
                    hairline
                    numbersBlock
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            actionRow
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 20)
        }
        .background(FoodTheme.bgPrimary.ignoresSafeArea())
        // Portion slider drag → everything rescales linearly from the
        // scan anchor (the "less of that" gesture).
        .onChange(of: portion) { _, newPortion in
            guard portionIsKnown else { return }
            let s = newPortion / max(anchor.portionGrams, 1)
            kcal = ((anchor.kcal ?? 0) * s).rounded()
            protein = ((anchor.proteinG ?? 0) * s).rounded()
            carbs = ((anchor.carbsG ?? 0) * s).rounded()
            fat = ((anchor.fatG ?? 0) * s).rounded()
        }
        // COHERENT MATH — a macro edit recomputes kcal; a kcal edit
        // rescales the macros. Guarded on which field the user is
        // actually typing in so the two rules can't feed back.
        .onChange(of: protein) { _, _ in macroDidChange() }
        .onChange(of: carbs) { _, _ in macroDidChange() }
        .onChange(of: fat) { _, _ in macroDidChange() }
        .onChange(of: kcal) { _, newKcal in
            guard focused == .kcal else { return }
            let scaled = PlateMath.macrosScaled(
                toKcal: newKcal, protein: protein, carbs: carbs, fat: fat
            )
            protein = scaled.protein.rounded()
            carbs = scaled.carbs.rounded()
            fat = scaled.fat.rounded()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done") { focused = nil }
                    .font(.custom("DMSans-SemiBold", size: 15))
                    .foregroundStyle(FoodTheme.accent)
            }
        }
    }

    private func macroDidChange() {
        guard focused == .protein || focused == .carbs || focused == .fat else { return }
        kcal = PlateMath.kcalFromMacros(protein: protein, carbs: carbs, fat: fat)
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            (Text("edit ")
                .font(.custom("DMSans-Regular", size: 13))
            + Text("this one")
                .font(.custom("JeniHeroSerif-Italic", size: 15)))
                .foregroundStyle(FoodTheme.textSecondary)
                .kerning(0.4)
            Spacer()
            if isDirty, scanBaseline != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.2)) { resetToScan() }
                } label: {
                    (Text("reset to the ")
                        .font(.custom("DMSans-Regular", size: 12))
                    + Text("snap")
                        .font(.custom("JeniHeroSerif-Italic", size: 13)))
                        .foregroundStyle(FoodTheme.accent)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    private func resetToScan() {
        guard let base = scanBaseline else { return }
        focused = nil
        name = base.name
        kcal = (base.kcal ?? 0).rounded()
        protein = (base.proteinG ?? 0).rounded()
        carbs = (base.carbsG ?? 0).rounded()
        fat = (base.fatG ?? 0).rounded()
        // Portion last: its onChange rescales from the anchor, which
        // re-derives the exact numbers above for the anchor portion.
        portion = base.portionGrams
    }

    // MARK: - Name

    @ViewBuilder private var nameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            TextField("what is it?", text: $name)
                .font(.custom("JeniHeroSerif-Regular", size: 27))
                .foregroundStyle(FoodTheme.textPrimary)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($focused, equals: .name)
            if isLowConfidence {
                (Text("we weren't sure about this one. feel ")
                    .font(.custom("DMSans-Regular", size: 12))
                + Text("free")
                    .font(.custom("JeniHeroSerif-Italic", size: 13))
                + Text(" to correct.")
                    .font(.custom("DMSans-Regular", size: 12)))
                    .foregroundStyle(FoodTheme.accent)
            }
        }
    }

    // MARK: - Portion

    @ViewBuilder private var portionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("portion")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .kerning(0.4)
                Spacer()
                (Text("\(Int(portion.rounded()))")
                    .font(.custom("JeniHeroSerif-Regular", size: 27))
                    .foregroundColor(FoodTheme.textPrimary)
                + Text("g")
                    .font(.custom("JeniHeroSerif-Italic", size: 17))
                    .foregroundColor(FoodTheme.accent))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.16), value: Int(portion.rounded()))
            }
            sliderWithScanTick
        }
    }

    /// Slider with a thin cocoa tick at the scan's estimate so the
    /// user always has the model's anchor in view while correcting.
    @ViewBuilder private var sliderWithScanTick: some View {
        let span = portionMax - portionMin
        let fraction = span > 0
            ? min(1, max(0, (anchor.portionGrams - portionMin) / span))
            : 0.5
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Slider(value: $portion, in: portionMin...portionMax, step: 5)
                    .tint(FoodTheme.accent)
                let trackInset: CGFloat = 12
                let trackWidth = max(0, geo.size.width - trackInset * 2)
                let x = trackInset + CGFloat(fraction) * trackWidth
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(FoodTheme.textPrimary.opacity(0.30))
                        .frame(width: 1, height: 14)
                    Text("snap")
                        .font(.custom("JeniHeroSerif-Italic", size: 9))
                        .foregroundStyle(FoodTheme.textPrimary.opacity(0.45))
                        .kerning(0.3)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .position(x: x, y: geo.size.height / 2)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 38)
    }

    // MARK: - The numbers

    @ViewBuilder private var numbersBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                (Text("the ")
                    .font(.custom("DMSans-Regular", size: 13))
                + Text("numbers")
                    .font(.custom("JeniHeroSerif-Italic", size: 15)))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .kerning(0.4)
                Spacer()
                (Text("they stay in ")
                    .font(.custom("DMSans-Regular", size: 11))
                + Text("sync")
                    .font(.custom("JeniHeroSerif-Italic", size: 12))
                + Text("")
                    .font(.custom("DMSans-Regular", size: 11)))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.75))
            }

            HStack(spacing: 10) {
                numberField("calories", value: $kcal, unit: nil, field: .kcal)
                numberField("protein", value: $protein, unit: "g", field: .protein)
            }
            HStack(spacing: 10) {
                numberField("carbs", value: $carbs, unit: "g", field: .carbs)
                numberField("fat", value: $fat, unit: "g", field: .fat)
            }
        }
    }

    @ViewBuilder
    private func numberField(
        _ label: String,
        value: Binding<Double>,
        unit: String?,
        field: Field
    ) -> some View {
        let isActive = focused == field
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundStyle(FoodTheme.textSecondary)
                .kerning(0.3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                    .font(.custom("JeniHeroSerif-Regular", size: 22))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .focused($focused, equals: field)
                    .fixedSize()
                if let unit {
                    Text(unit)
                        .font(.custom("JeniHeroSerif-Italic", size: 14))
                        .foregroundStyle(FoodTheme.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.9 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isActive
                            ? FoodTheme.accent.opacity(0.55)
                            : FoodTheme.textPrimary.opacity(0.10),
                        lineWidth: isActive ? 1 : 0.75
                    )
            )
            .animation(.easeOut(duration: 0.18), value: isActive)
        }
    }

    @ViewBuilder private var hairline: some View {
        Rectangle()
            .fill(FoodTheme.textPrimary.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Actions

    @ViewBuilder private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onRemove()
            } label: {
                Text("remove")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .overlay(
                        Capsule().stroke(
                            FoodTheme.textSecondary.opacity(0.30), lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } label: {
                Text("cancel")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSave(makeUpdatedItem())
            } label: {
                (Text("save ")
                    .font(.custom("DMSans-SemiBold", size: 15))
                + Text("it")
                    .font(.custom("JeniHeroSerif-Italic", size: 16)))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Output

    /// The edited item. Typed numbers are the source of truth; fiber /
    /// sugar / sodium / sat-fat / micronutrients (not directly
    /// editable) scale with the portion delta from the anchor.
    /// Identity + provenance — and every field this editor never heard
    /// of — preserved by construction: this is a mutation of
    /// `original`, not a re-init (pass 51; the re-init here was the
    /// fourth live instance of the defaulted-init field drop — it
    /// erased a grounded item's micros on every hand edit).
    private func makeUpdatedItem() -> CapturedItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = portionIsKnown ? portion / max(anchor.portionGrams, 1) : 1
        var out = original
        out.name = trimmed.isEmpty ? original.name : trimmed
        out.portionGrams = portionIsKnown ? portion : original.portionGrams
        out.portionGramsLow = anchor.portionGramsLow * s
        out.portionGramsHigh = anchor.portionGramsHigh * s
        out.kcal = kcal
        out.proteinG = protein
        out.carbsG = carbs
        out.fatG = fat
        out.fiberG = anchor.fiberG.map { $0 * s }
        out.sugarG = anchor.sugarG.map { $0 * s }
        out.sodiumMg = anchor.sodiumMg.map { $0 * s }
        out.saturatedFatG = anchor.saturatedFatG.map { $0 * s }
        out.micros = anchor.micros.map { $0.scaled(by: s) }
        return out
    }
}
#endif
