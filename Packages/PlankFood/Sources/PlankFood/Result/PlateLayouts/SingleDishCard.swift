#if canImport(UIKit)
import SwiftUI

// MARK: - SingleDishCard
//
// Result card layout for `plate_type: single | bowl` — when the LLM
// identifies one dominant food (e.g. "creamy carbonara" or "açaí
// bowl"). Composes ItemRow + ConfidencePill + NutrientGrid + JeniLine
// per v5 §Calorie scan Screen 3.
//
// D54 (2026-06-05): pre-eat / just-ate mode collapsed. The card has
// one unified layout. Jeni's copy line carries permission framing
// regardless of whether the user took the photo pre-eat or mid-meal.
// Primary CTA "log it" + secondary "actually skip →" let the user
// decide intent AFTER seeing the result, not before the photo.

public struct SingleDishCard: View {

    public let food: CapturedFood
    /// v1.0.8 Phase E — receives the (potentially corrected) food on
    /// log tap. Quick-correction pills below the calorie pill adjust
    /// `correctionMultiplier` / `correctionAddKcal`; the corrected
    /// CapturedFood is what gets persisted.
    public let primaryAction: (CapturedFood) -> Void
    public let secondaryAction: () -> Void
    public let onItemTap: (CapturedItem) -> Void

    public init(
        food: CapturedFood,
        primaryAction: @escaping (CapturedFood) -> Void,
        secondaryAction: @escaping () -> Void,
        onItemTap: @escaping (CapturedItem) -> Void
    ) {
        self.food = food
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.onItemTap = onItemTap
    }

    @State private var showMacros: Bool = false
    /// v1.0.8 Phase E (2026-06-07) — quick-correction state.
    /// `correctionMultiplier` scales the kcal (e.g. 1.25 = +25% for
    /// "bigger portion"). `correctionAddKcal` adds an absolute
    /// amount (e.g. +120 kcal for "more sauce"). Resets each scan.
    @State private var correctionMultiplier: Double = 1.0
    @State private var correctionAddKcal: Double = 0
    /// Drives the soft calorie-pill jiggle on each correction tap.
    @State private var jigglePhase: Int = 0
    /// "got it ♥" sticker pop after a successful correction.
    @State private var lastCorrectionLabel: String? = nil
    /// Sprint A (2026-06-15) — satiety check-in state. Optional;
    /// transient (per-card, not persisted). The vocabulary-loop
    /// foundation per the PMF expert brief.
    @State private var satietyChoice: SatietyChoice? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.lg) {
            // Defensive empty-state: if items is empty, the camera-layer
            // guard should have caught this — but if it slips through,
            // render a clean "couldn't identify" panel instead of a card
            // with only CTAs (founder bug 2026-06-05).
            if food.items.isEmpty {
                emptyStatePanel
            }

            // 2026-06-06 — feeling-word hero reverted per founder
            // direction: "bright doesn't tell me anything. i want to
            // see 17 cal bigger." Calorie number back as the visible
            // hero. The behavioral risk (calorie-as-hero for an anti-
            // shame Gen-Z cohort) is real and documented in
            // docs/home_becoming_research_behavioral_2026_06_06.md but
            // the founder is overriding for the post-scan moment
            // specifically — at the point of "what did I just eat?",
            // the number IS the answer she wants. Trend-as-hero stays
            // the Home decision (different surface, different need).
            // Macros-behind-disclosure + tell-me-more ♥ kept from A.4.
            if let item = food.items.first, let kcal = item.kcal {
                // v1.0.8 Phase E — calorie-pill jiggle on correction.
                // The displayedKcal computed property applies the
                // current correction multiplier + add. Wrapped in a
                // ZStack so the "got it ♥" sticker can pop over the
                // pill on each correction without disturbing layout.
                ZStack(alignment: .topTrailing) {
                    ConfidencePill(
                        kcal: displayedKcal(original: kcal),
                        kcalLow: nil,
                        kcalHigh: nil
                    )
                    .scaleEffect(jigglePhase > 0 ? 1.05 : 1.0)
                    .animation(.spring(response: 0.32, dampingFraction: 0.5), value: jigglePhase)

                    if let label = lastCorrectionLabel {
                        gotItSticker(label: label)
                            .offset(x: 16, y: -10)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            } else if food.totalKcal == nil {
                // USDA join pending — show name only, kcal lands when it does.
                if let item = food.items.first {
                    Text(ItalicAccentText.parseAsterisks(item.name).base)
                        .font(.custom("Fraunces72pt-SemiBold", size: 24))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Text("reading the plate…")
                        .font(.system(size: 13))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
            }

            // The item itself — tap to edit portion / name.
            if let item = food.items.first {
                ItemRow(
                    name: item.name,
                    portionGrams: item.portionGrams,
                    confidence: item.confidence,
                    onTap: { onItemTap(item) }
                )

                if item.kcal != nil {
                    macrosDisclosure(item: item)
                }
            }

            // Jeni interpretation line. D54: single unified copy that
            // lands as permission OR verdict depending on the context
            // the user brings (pre-eat or mid-meal — only the user
            // knows which).
            if let jeniCopy = Self.synthesizeJeniLine(for: food) {
                JeniLine(jeniCopy)
            }

            // v1.0.8 Phase E — "correct me ♥" quick-correction row.
            // Three soft pills that recalibrate the calorie pill in
            // place. Attacks Cal AI's #1 complaint head-on: "guessed
            // wrong, can't fix without rage." Each tap fires a small
            // jiggle on the calorie pill + a "got it ♥" sticker pop
            // for tactile feedback. The corrections-as-moat lever —
            // every tap is private telemetry for v1.0.9 per-user
            // model tuning.
            if food.items.first?.kcal != nil {
                correctionRow
            }

            // "tell me more ♥" inline — deeper correction surface
            // (full item-name + portion edit via FoodCorrectionSheet).
            // Kept alongside the quick pills for users who need to
            // change the item itself, not just the calorie scale.
            if let item = food.items.first {
                tellMeMoreLink(item: item)
            }

            // Sprint A (2026-06-15) — satiety check-in. Above the
            // divider so it reads as the last gloss before "log it,"
            // not as another action button. Only shown when there's
            // actually a plate to react to (kcal computed).
            if food.items.first?.kcal != nil {
                SatietyPill(choice: $satietyChoice) { value in
                    FoodAnalytics.track(.satietyMarked, properties: [
                        "state": value.rawValue
                    ])
                }
            }

            Divider()
                .overlay(FoodTheme.accentSubtle)

            // CTAs. When items is empty, only the secondary (back to
            // camera) makes sense — primary "log it" would log a 0-cal
            // phantom entry.
            if food.items.isEmpty {
                emptyStateActions
            } else {
                actionButtons
            }
        }
        .padding(FoodTheme.Space.lg)
        .background(FoodTheme.bgElevated)
        // Scrapbook chrome per v5 D37 + feedback_visual_richness_over_restraint:
        // 1.5pt accent border + hard offset shadow (radius:0, x/y:3)
        // gives the y2k-coquette weight WITHOUT relying on bitmap
        // stickers. Subtle by itself; loud when combined with the
        // sticker overlay below.
        .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.5), lineWidth: FoodTheme.Stroke.scrapbook)
        )
        .shadow(color: FoodTheme.textPrimary.opacity(0.2), radius: 0, x: 3, y: 3)
        // v1.0.7 Phase E sticker discipline — cherries = food family
        // per the luxury brief mapping. v1.1 design pass: emoji
        // stand-in swapped for the brand cherries asset (this was the
        // polish ticket the old comment carried).
        .overlay(alignment: .topTrailing) {
            Image("sticker_cherries", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(10))
                .offset(x: 8, y: -12)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Feeling-word hero (v1.0.7 Phase A.4)

    /// Calorie-bucket → italic-Fraunces feeling word. Five buckets that
    /// span the realistic single-dish range. All five are neutral-
    /// positive descriptors — never moral framing ("indulgent",
    /// "guilty"), never deficit framing ("burned", "deserved"). The
    /// post-Ozempic vocab lock + the behavioral expert's "calorie-as-
    /// hero is disordered-eating-accelerator" finding both point here:
    /// describe the FEELING of the food, not its judgment.
    /// Internal (was private) so MixedPlateCard shares the same scheme.
    static func feelingWord(forKcal kcal: Double) -> String {
        switch kcal {
        case ..<80:    return "bright"        // espresso, lemon, mint, broth
        case 80..<200: return "easy"          // toast, fruit, latte
        case 200..<400: return "satisfying"   // sandwich, bowl, pasta single
        case 400..<600: return "hearty"       // pasta plate, burger, big bowl
        default:       return "nourishing"    // steak dinner, brunch plate
        }
    }

    /// v1.0.7 founder feedback round 7 (2026-06-06):
    /// > "after taking a photo to calculate calories, it's very
    /// >  confusing because it doesn't say calories. Let's be very
    /// >  simple and minimalistic about the information we're
    /// >  giving within jenifit theme. ... right now, app needs to
    /// >  serve women who want to lose weight as a tool."
    ///
    /// Tool-first reset: calorie number is now the HERO (Fraunces
    /// Light 48pt). Feeling word + permission frame demoted to a
    /// quiet supporting line. The cohort scanning food wants the
    /// calorie answer in 2 seconds without writing anything (per
    /// the behavioral research definition of "useful tool"). The
    /// JeniFit theme survives in the meal name italic-Fraunces and
    /// the soft cocoa register — but the answer to her actual
    /// question (kcal) leads.
    @ViewBuilder
    private func feelingHero(item: CapturedItem, kcal: Double) -> some View {
        let feeling = Self.feelingWord(forKcal: kcal)
        let mealName = ItalicAccentText.parseAsterisks(item.name).base

        VStack(alignment: .leading, spacing: 6) {
            // Calorie HERO — Fraunces Light 48pt, tabular, the
            // single biggest type on the surface. "cal" unit
            // baseline-aligned in 16pt cocoa-secondary, like the
            // weight digit on Becoming.
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(Int(kcal.rounded()))")
                    .font(.custom("Fraunces72pt-Light", size: 48))
                    .monospacedDigit()
                    .foregroundStyle(FoodTheme.textPrimary)
                Text("cal")
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundStyle(FoodTheme.textSecondary)
            }

            // Meal name — plain Fraunces 17pt cocoa-secondary.
            Text(mealName)
                .font(.custom("Fraunces72pt-Regular", size: 17))
                .foregroundStyle(FoodTheme.textSecondary)

            // Quiet supporting line — feeling word + permission
            // frame, italic-Fraunces on the feeling punch word so
            // the JeniFit voice survives without competing with the
            // hero numeral.
            HStack(spacing: 4) {
                Text(feeling)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(FoodTheme.textSecondary)
                Text("·")
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.6))
                Text("fits")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(FoodTheme.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(kcal.rounded())) calories. \(mealName). \(feeling), fits.")
    }

    // MARK: - Macros disclosure (v1.0.7 Phase A.4)
    //
    // The full NutrientGrid is now hidden behind a tap. Defaults to
    // collapsed because the macro grid is a power-user lens — most
    // logging events don't need it, and showing it upfront re-anchors
    // the result card on numbers (which is exactly the calorie-hero
    // anti-pattern the behavioral expert flagged). User who wants
    // macros taps "show macros" and the grid expands in place.

    @ViewBuilder
    private func macrosDisclosure(item: CapturedItem) -> some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showMacros.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showMacros ? "hide macros" : "show macros")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
                        .rotationEffect(.degrees(showMacros ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showMacros {
                NutrientGrid(
                    kcal: item.kcal,
                    proteinG: item.proteinG,
                    carbsG: item.carbsG,
                    fatG: item.fatG,
                    fiberG: item.fiberG,
                    sugarG: item.sugarG,
                    sodiumMg: item.sodiumMg,
                    saturatedFatG: item.saturatedFatG
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Tell me more (v1.0.7 Phase A.4)
    //
    // Corrections-as-moat surface per the Cal AI teardown brief.
    // v1.0.7 routes to the existing FoodCorrectionSheet (portion +
    // name edit) — same UI users already see when tapping the item
    // row. v1.0.8 will swap this for the inline conversation flow
    // ("tell me more" → jeni line + clarifying questions + memory).

    @ViewBuilder
    private func tellMeMoreLink(item: CapturedItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onItemTap(item)
        } label: {
            HStack(spacing: 6) {
                Text("tell me")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                (Text("more")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    .foregroundStyle(FoodTheme.accent)
                 + Text(" ♥")
                    .font(.system(size: 15))
                    .foregroundStyle(FoodTheme.accent))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FoodTheme.accent.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(FoodTheme.accentSubtle.opacity(0.45))
            .overlay(
                Capsule().stroke(FoodTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phase E corrections

    /// "more sauce" / "bigger portion" / "nope, not this" row. Each
    /// pill applies its correction in-place and fires telemetry; the
    /// "got it ♥" sticker pops over the calorie pill for ~1s after
    /// each tap so the user gets clear "i heard you" feedback.
    @ViewBuilder private var correctionRow: some View {
        HStack(spacing: 8) {
            correctionPill(
                label: "more sauce",
                icon: "drop.fill"
            ) {
                applyCorrection(label: "sauce", addKcal: 120)
            }
            correctionPill(
                label: "bigger",
                icon: "arrow.up.right"
            ) {
                applyCorrection(label: "bigger", multiplier: 1.25)
            }
            correctionPill(
                label: "not this",
                icon: "questionmark.circle"
            ) {
                // Routes to the existing FoodCorrectionSheet via the
                // tellMeMoreLink mechanism — same surface, faster
                // entry point. Founder bug to revisit in Phase F:
                // surface this as inline text input per UX-2 spec.
                if let item = food.items.first {
                    onItemTap(item)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func correctionPill(
        label: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.custom("DMSans-Medium", size: 12))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(FoodTheme.accent)
            .background(
                Capsule().fill(FoodTheme.accentSubtle.opacity(0.45))
            )
            .overlay(
                Capsule().stroke(FoodTheme.accent.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("correct: \(label)")
    }

    /// "got it ♥" sticker pop — fires after each correction so the
    /// user gets tactile + visual feedback that the correction
    /// landed. Auto-clears via the same animation block.
    @ViewBuilder
    private func gotItSticker(label: String) -> some View {
        HStack(spacing: 3) {
            Text("got it")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11))
            Text("♥")
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(.white)
        .background(Capsule().fill(FoodTheme.accent))
        .shadow(color: FoodTheme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    /// Apply a correction: bump the multiplier/add, fire jiggle on
    /// the calorie pill, pop the "got it ♥" sticker for ~1s, log
    /// telemetry. The displayed kcal updates immediately via the
    /// `displayedKcal(original:)` computed value.
    private func applyCorrection(
        label: String,
        multiplier: Double? = nil,
        addKcal: Double? = nil
    ) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let m = multiplier { correctionMultiplier *= m }
        if let a = addKcal { correctionAddKcal += a }
        jigglePhase &+= 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
            lastCorrectionLabel = label
        }
        // Clear the sticker pop after ~1s. Subsequent corrections
        // re-fire withAnimation so the sticker stays visible if the
        // user is rapid-tapping.
        let stamp = label  // capture for the async closure's equality check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if lastCorrectionLabel == stamp {
                withAnimation(.easeOut(duration: 0.35)) {
                    lastCorrectionLabel = nil
                }
            }
        }
        FoodAnalytics.track(.scanCorrectionApplied, properties: [
            "correction": label,
            "multiplier": correctionMultiplier,
            "add_kcal": Int(correctionAddKcal.rounded()),
        ])
    }

    /// Current displayed kcal after corrections.
    private func displayedKcal(original: Double) -> Double {
        max(0, original * correctionMultiplier + correctionAddKcal)
    }

    /// Build the CapturedFood that should actually get persisted —
    /// the original food's first item with kcal + macros scaled by
    /// the corrections. Macros scale by the multiplier only (the
    /// addKcal is sauce/fat-heavy on average, but we don't have a
    /// per-macro split for it; v1.0.9 telemetry will tell us if this
    /// is meaningful enough to model precisely).
    private func correctedFood() -> CapturedFood {
        guard correctionMultiplier != 1.0 || correctionAddKcal != 0,
              let item = food.items.first,
              let originalKcal = item.kcal else {
            return food
        }
        let newKcal = displayedKcal(original: originalKcal)
        let scale = correctionMultiplier
        let correctedItem = CapturedItem(
            id: item.id,
            name: item.name,
            portionGrams: item.portionGrams * scale,
            portionGramsLow: item.portionGramsLow * scale,
            portionGramsHigh: item.portionGramsHigh * scale,
            usdaSearchTerms: item.usdaSearchTerms,
            preparation: item.preparation,
            cuisineHint: item.cuisineHint,
            confidence: item.confidence,
            notes: item.notes,
            kcal: newKcal,
            proteinG: item.proteinG.map { $0 * scale },
            carbsG: item.carbsG.map { $0 * scale },
            fatG: item.fatG.map { $0 * scale },
            fiberG: item.fiberG.map { $0 * scale },
            nutritionSource: item.nutritionSource,
            sugarG: item.sugarG.map { $0 * scale },
            sodiumMg: item.sodiumMg.map { $0 * scale },
            saturatedFatG: item.saturatedFatG.map { $0 * scale }
        )
        return CapturedFood(
            items: [correctedItem],
            plateType: food.plateType,
            source: food.source,
            confidence: food.confidence,
            needsSecondPhoto: food.needsSecondPhoto,
            secondPhotoHint: food.secondPhotoHint,
            kcalLow: food.kcalLow.map { displayedKcal(original: $0) },
            kcalHigh: food.kcalHigh.map { displayedKcal(original: $0) }
        )
    }

    // MARK: - Action buttons

    // MARK: - Empty state

    @ViewBuilder private var emptyStatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("couldn't read this one")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("no food made it through. too dark, too blurry, or maybe nothing on the plate yet. let's try again.")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, FoodTheme.Space.sm)
    }

    @ViewBuilder private var emptyStateActions: some View {
        Button(action: secondaryAction) {
            Text("retake →")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FoodTheme.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(FoodTheme.textPrimary))
        }
    }

    @ViewBuilder private var actionButtons: some View {
        VStack(spacing: FoodTheme.Space.sm) {
            Button {
                // v1.0.8 Phase E — pass the corrected food so the
                // log persists what the user actually saw, not the
                // raw LLM output.
                primaryAction(correctedFood())
            } label: {
                Text("log it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }

            Button(action: secondaryAction) {
                Text("actually skip →")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
    }

    // MARK: - Copy

    /// Unified Jeni copy — lands as permission OR verdict depending
    /// on the user's context (only they know if they ate it or are
    /// deciding). Real per-item interpretation will come from the
    /// GPT-5 system prompt later; this is the voice-locked fallback
    /// when the upstream pipeline doesn't inject anything custom.
    ///
    /// Voice locked: no banned vocabulary, italic on punch word,
    /// heart as terminal punctuation. Kcal-adaptive so Jeni's
    /// register matches the size of the food (a lemon doesn't get
    /// the same "totally fits" line as a Chipotle bowl). Founder
    /// rewrite 2026-06-07 — dropped the kcal number from the line
    /// (it's already in the title above) and ditched "easy yes if
    /// you want it" (read as marketing-y, not friend-y).
    static func synthesizeJeniLine(for food: CapturedFood) -> String? {
        guard food.items.first != nil else { return nil }
        guard let kcal = food.items.first?.kcal else {
            return "this *works* ♥"
        }
        switch kcal {
        case ..<100:        return "barely *counts* ♥"
        case 100..<500:     return "totally *fits* ♥"
        default:            return "this *works* ♥"
        }
    }
}

// MARK: - Preview

#Preview("SingleDishCard — logged data") {
    SingleDishCard(
        food: .preview(),
        primaryAction: { _ in print("log it") },
        secondaryAction: { print("actually skip") },
        onItemTap: { _ in print("tap item") }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("SingleDishCard — USDA pending") {
    SingleDishCard(
        food: .previewPending(),
        primaryAction: { _ in },
        secondaryAction: { },
        onItemTap: { _ in }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

// MARK: - Preview helpers

extension CapturedFood {
    static func preview() -> CapturedFood {
        CapturedFood(
            items: [
                CapturedItem(
                    id: "1",
                    name: "creamy *carbonara*",
                    portionGrams: 320,
                    portionGramsLow: 280,
                    portionGramsHigh: 360,
                    usdaSearchTerms: ["carbonara", "pasta with cream sauce"],
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
            ],
            plateType: .single,
            source: .photo,
            confidence: 0.87,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }

    static func previewPending() -> CapturedFood {
        CapturedFood(
            items: [
                CapturedItem(
                    id: "1",
                    name: "*matcha* latte with oat",
                    portionGrams: 350,
                    portionGramsLow: 300,
                    portionGramsHigh: 400,
                    usdaSearchTerms: ["matcha latte"],
                    preparation: nil,
                    cuisineHint: "japanese",
                    confidence: 0.92,
                    notes: nil,
                    kcal: nil, proteinG: nil, carbsG: nil, fatG: nil, fiberG: nil,
                    nutritionSource: nil
                )
            ],
            plateType: .single,
            source: .photo,
            confidence: 0.92,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }
}

#endif  // canImport(UIKit)
