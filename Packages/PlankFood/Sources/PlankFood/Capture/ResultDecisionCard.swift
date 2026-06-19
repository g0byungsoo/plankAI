#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDecisionCard
//
// v1.0.23 (2026-06-18) — rebuilt against the cohort-prioritized
// research agent's spec. Founder feedback: the dense "everything"
// layout read like a nutrition-facts label, not a decision aid.
// The research agent's load-bearing call:
//
//   1. Protein as CO-HERO with calories (equal-sized numerals) —
//      single biggest signal-vs-noise upgrade for the cohort.
//      No major competitor (Cal AI / MacroFactor / SnapCalorie /
//      Yazio / MFP / Lifesum / Foodvisor / ZOE) ships this.
//      Validation: cleaneatzkitchen 2025 + ScienceDirect MPS data,
//      U Texas Austin GLP-1 trial, Midi / TaraMD RD recs.
//   2. Satiety as a qualitative one-line PREDICTION — owns the
//      post-Ozempic food-noise vocabulary nobody else has.
//   3. Ruthless silence on everything else — carbs / fat / sodium /
//      sugar / sat fat / NHANES comparative / week pace / ingredients
//      list ALL drop from slide 1. They live one tap away or on
//      slide 2. Validation: 2025 perfectionism + disordered-eating
//      RCT on dense nutrition-label screens driving anxious tracking
//      in women 22-35.
//
// Layout (top to bottom):
//
//   - Hairline-rule eyebrow (today's *meal* · time)
//   - Italic editorial dish title
//   - CO-HERO row: calories + protein numerals, equal height
//   - Protein threshold micro-line (conditional)
//   - Fiber line + italic satiety prediction (when fiber ≥ 3g)
//   - Divider hairline
//   - Day-context one-liner ("X kcal left today · Y g protein left")
//   - Smart pair suggestion (conditional only when gap exists)
//   - Tag chips (single row, max 2)
//
// v1.0.29 (2026-06-18) — full her75 typography swap: every italic
// punch + supporting roman serif on slide 1 now uses JeniHeroSerif
// (Playfair Display rename) per the locked her75 register. Fraunces
// is out across slide 1 — JeniHeroSerif's roman/italic pair carries
// the editorial voice. DMSans stays on body prose + chips. Hearts
// as terminal punctuation on insight lines per locked voice rules.

struct ResultDecisionCard: View {

    let result: CapturedFood
    let mealLabel: String
    let dishName: String
    var loggedAt: Date = Date()
    var onEditItem: ((Int) -> Void)? = nil
    /// v1.0.32 (2026-06-19) — fired when the inline `+ pair` action
    /// chip is tapped on the protein adequacy stamp. Receives the
    /// smart-pair punch word (e.g. "boiled egg") so the caller can
    /// pre-fill the food capture / quick-add with the suggestion.
    var onLogPair: ((String) -> Void)? = nil
    /// v1.0.34 (2026-06-19) — fired when the user saves or removes an
    /// ingredient in IngredientEditSheet. Receives a freshly-built
    /// CapturedFood (items with the edit applied + nutrient totals
    /// scaled). NutritionCarousel forwards this to its onCorrect so
    /// PhotoCaptureView's existing capturedResult re-render picks up
    /// the new data automatically.
    var onResultEdited: ((CapturedFood) -> Void)? = nil

    /// v1.0.34 — the index of the row currently being edited (nil
    /// when the sheet is dismissed). Wrapped via `EditingItemIndex`
    /// so `.sheet(item:)` keeps the data alive for the sheet body.
    @State private var editingItem: EditingItemIndex? = nil

    private struct EditingItemIndex: Identifiable {
        let index: Int
        var id: Int { index }
    }

    @State private var revealedSteps: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingCurrentWeightKg") private var onboardingCurrentWeightKg: Double = 0
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""

    var body: some View {
        ZStack {
            // v1.0.25 (2026-06-18) — transparent backdrop. The frozen
            // camera photo behind the carousel slot shows around the
            // floating card per founder direction: "slide1 and slide2
            // still need to be card design on captured photo."
            Color.clear

            card
                .padding(.horizontal, 56)
                .padding(.top, 96)
                .padding(.bottom, 160)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
        .onAppear {
            startCascade()
            // Debug-only: `--debug-edit-sheet` auto-opens the
            // IngredientEditSheet on item 0 so the harness can
            // capture its appearance without fighting TabView swipe
            // gestures.
            if ProcessInfo.processInfo.arguments.contains("--debug-edit-sheet"),
               !result.items.isEmpty,
               editingItem == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    editingItem = EditingItemIndex(index: 0)
                }
            }
        }
        .sheet(item: $editingItem) { editing in
            let item = result.items[editing.index]
            IngredientEditSheet(
                original: item,
                onSave: { updatedItem in
                    let newItems = replaceItem(at: editing.index, with: updatedItem)
                    onResultEdited?(rebuildFood(with: newItems))
                    editingItem = nil
                },
                onRemove: {
                    var newItems = result.items
                    newItems.remove(at: editing.index)
                    onResultEdited?(rebuildFood(with: newItems))
                    editingItem = nil
                },
                onCancel: { editingItem = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Returns a copy of `result.items` with the item at `idx`
    /// replaced by `updated`. Used by the edit sheet's save handler.
    private func replaceItem(at idx: Int, with updated: CapturedItem) -> [CapturedItem] {
        var items = result.items
        guard idx < items.count else { return items }
        items[idx] = updated
        return items
    }

    /// Rebuilds the CapturedFood with a new items array. Recomputes
    /// kcalLow / kcalHigh proportionally to the kcal-total change so
    /// downstream consumers (carousel slide 2, share renderer) see
    /// consistent totals.
    private func rebuildFood(with newItems: [CapturedItem]) -> CapturedFood {
        let oldKcalTotal = result.items.compactMap { $0.kcal }.reduce(0, +)
        let newKcalTotal = newItems.compactMap { $0.kcal }.reduce(0, +)
        let scale = oldKcalTotal > 0 ? newKcalTotal / oldKcalTotal : 1
        return CapturedFood(
            items: newItems,
            plateType: result.plateType,
            source: result.source,
            confidence: result.confidence,
            needsSecondPhoto: result.needsSecondPhoto,
            secondPhotoHint: result.secondPhotoHint,
            kcalLow: (result.kcalLow ?? 0) * scale,
            kcalHigh: (result.kcalHigh ?? 0) * scale
        )
    }

    /// The floating cream card. v1.0.30 (2026-06-19) — chrome
    /// upgraded to match the Becoming dashboard's luxuryCard
    /// register. Warm cream-to-warmer-cream linear gradient inside,
    /// hairline cocoa border softened to 7%, soft warm drop shadow
    /// (radius 18, cocoa @ 6%). Drops the heavy her75 hard-offset
    /// cocoa shadow that read as a "text shadow" against the cream
    /// background — founder feedback: "wired with old screens (text
    /// shades)."
    @ViewBuilder private var card: some View {
        contentColumn
            .padding(.horizontal, 56)
            .padding(.vertical, 56)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.980, blue: 0.973),
                                Color(red: 0.984, green: 0.949, blue: 0.933),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(textPrimary.opacity(0.07), lineWidth: 0.75)
            )
            .shadow(
                color: Color(red: 0.36, green: 0.20, blue: 0.18).opacity(0.06),
                radius: 18,
                x: 0,
                y: 6
            )
    }

    /// v1.0.32 (2026-06-19) — Whoop's 80ms perceptual lag between
    /// zones. The first zone (meta row) lands free; every following
    /// zone arrives 80ms after the previous lands. Cause precedes
    /// effect: meta reveals, then kcal hero, then protein, then
    /// ingredients, etc. The CountUpNumber's own onAppear roll
    /// (0.9s + curtsy) layers on top, naturally lagging the visual
    /// primary by ~80ms because the card cascade already moved.
    private func startCascade() {
        if reduceMotion { revealedSteps = 10; return }
        revealedSteps = 0
        for i in 0...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(i)) {
                withAnimation(.easeOut(duration: 0.42)) {
                    revealedSteps = max(revealedSteps, i)
                }
            }
        }
    }

    private func opacityFor(_ step: Int) -> Double {
        revealedSteps >= step ? 1.0 : 0.0
    }

    // MARK: - Content column
    //
    // v1.0.31 (2026-06-19) — densified per the panel synthesis:
    // founder asked for more info aesthetically. Layout uses hairline
    // rules between zones (magazine convention) so density reads as
    // editorial rather than nutrition-label.
    //
    //   Zone A: meta row — time · meal · confidence pill
    //   Zone B: kcal hero + ±range + italic meal name
    //   Zone C: protein co-hero + adequacy stamp
    //   Zone D: ingredient ledger (3-5 hairline rows w/ portion grams)
    //   Zone E: macro micro-bar (compressed, no legend)
    //   Zone F: satiety line + protein density inline
    //   Zone G: today's protein progress (adequacy, NOT calorie)
    //   Zone H: smart pair suggestion (conditional)
    //   Zone I: tag chips (cap 2)

    @ViewBuilder private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            metaRow.zoneEntrance(0, revealed: revealedSteps)
            zoneRule
            kcalHero.zoneEntrance(1, revealed: revealedSteps)
            proteinCoHero.zoneEntrance(2, revealed: revealedSteps)
            zoneRule
            ingredientLedger.zoneEntrance(3, revealed: revealedSteps)
            zoneRule
            macroMicroBar.zoneEntrance(4, revealed: revealedSteps)
            satietyAndDensity.zoneEntrance(5, revealed: revealedSteps)
            if let flag = thresholdFlag {
                thresholdFlagLine(flag)
                    .zoneEntrance(5, revealed: revealedSteps)
            }
            todayProteinBar.zoneEntrance(5, revealed: revealedSteps)
            if let pair = smartPair {
                zoneRule
                smartPairLine(pair).zoneEntrance(6, revealed: revealedSteps)
            }
            tagChips.zoneEntrance(6, revealed: revealedSteps)
        }
    }

    /// Half-pt hairline rule between zones — the single convention
    /// that lets density read as magazine, not spreadsheet.
    @ViewBuilder private var zoneRule: some View {
        Rectangle()
            .fill(textPrimary.opacity(0.12))
            .frame(height: 0.75)
            .padding(.vertical, 2)
    }

    // MARK: - Zone A: meta row (time · meal · confidence pill)

    @ViewBuilder private var metaRow: some View {
        HStack(alignment: .center) {
            (Text(timeLabel)
                .font(.custom("DMSans-Medium", size: 32))
                .foregroundColor(textSecondary)
            + Text("  ·  ")
                .font(.custom("DMSans-Medium", size: 32))
                .foregroundColor(textPrimary.opacity(0.25))
            + Text(mealLabelDisplay)
                .font(.custom("JeniHeroSerif-Italic", size: 34))
                .foregroundColor(textSecondary))
            Spacer(minLength: 0)
            confidencePill
        }
    }

    private var timeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    private var mealLabelDisplay: String {
        mealLabel.isEmpty ? "today" : mealLabel.lowercased()
    }

    @ViewBuilder private var confidencePill: some View {
        let word = confidenceWord
        (Text(word.0)
            .font(.custom("DMSans-Regular", size: 28))
        + Text(word.1)
            .font(.custom("JeniHeroSerif-Italic", size: 32))
        + Text(" \u{2661}")
            .font(.custom("DMSans-Medium", size: 26)))
            .foregroundStyle(accent.opacity(0.80))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Capsule().fill(accentSubtle.opacity(0.45)))
    }

    /// Italic state word reading the AI's confidence — never %.
    /// Same data, voiced.
    private var confidenceWord: (String, String) {
        let c = result.confidence ?? 0.85
        switch c {
        case ..<0.65: return ("let's ", "check")
        case ..<0.85: return ("close ", "enough")
        default:      return ("", "clear")
        }
    }

    // MARK: - Zone B: kcal hero (number + ±range + italic meal name)

    @ViewBuilder private var kcalHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            CountUpNumber(
                target: totalKcal,
                fontName: "JeniHeroSerif-Regular",
                italicFontName: "JeniHeroSerif-Italic",
                size: 200,
                color: textPrimary
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("calories")
                    .font(.custom("JeniHeroSerif-Italic", size: 48))
                    .foregroundStyle(textSecondary)
                if let range = kcalRangeLabel {
                    Text(range)
                        .font(.custom("DMSans-Regular", size: 30))
                        .foregroundStyle(textPrimary.opacity(0.50))
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Honest uncertainty band, e.g. "± 50" — only when low + high
    /// differ enough to matter. Reads as transparency, not anxiety.
    private var kcalRangeLabel: String? {
        guard let lo = result.kcalLow, let hi = result.kcalHigh, hi > lo else { return nil }
        let band = Int(((hi - lo) / 2).rounded())
        guard band >= 20 else { return nil }
        return "± \(band)"
    }

    // MARK: - Zone C: protein co-hero + adequacy stamp

    @ViewBuilder private var proteinCoHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            (Text("\(totalProtein)")
                .font(.custom("JeniHeroSerif-Regular", size: 104))
                .foregroundColor(textPrimary)
            + Text("g")
                .font(.custom("JeniHeroSerif-Italic", size: 56))
                .foregroundColor(accent))
                .monospacedDigit()
            Text("protein")
                .font(.custom("JeniHeroSerif-Italic", size: 44))
                .foregroundStyle(textSecondary)
                .baselineOffset(14)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 10) {
                adequacyStamp
                if let punch = pairActionPunch {
                    pairActionChip(punch)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Returns the punch word from smartPair when it exists AND the
    /// action would actually move the user toward a meaningful goal
    /// (only show the chip on protein-gap and fiber-gap pairs; the
    /// fat-balance variant isn't a logging action).
    private var pairActionPunch: String? {
        guard let pair = smartPair else { return nil }
        let punch = pair.punch.lowercased()
        if punch.contains("egg") || punch.contains("berries") { return pair.punch }
        return nil
    }

    @ViewBuilder
    private func pairActionChip(_ punch: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onLogPair?(punch)
        } label: {
            (
                Text("+ ")
                    .font(.custom("DMSans-Medium", size: 28))
                + Text(punch)
                    .font(.custom("JeniHeroSerif-Italic", size: 30))
            )
            .foregroundStyle(accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.85)))
            .overlay(Capsule().stroke(accent.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("add a \(punch) later")
    }

    /// Single-word stamp reading the protein adequacy. Cohort-routed:
    /// GLP-1 users (current/post) get "stays steady" instead of "solid"
    /// since lean-mass-protection is the framing that resonates for
    /// appetite-suppressed users (Wilding 2022 + Conte 2024).
    @ViewBuilder private var adequacyStamp: some View {
        let word: (prefix: String, italic: String) = {
            switch totalProtein {
            case 30...:
                return isGlp1Cohort ? ("muscle ", "stays") : ("hits ", "enough")
            case 20..<30:
                return isGlp1Cohort ? ("", "steady") : ("", "solid")
            case 10..<20:
                return ("a ", "start")
            default:
                return ("", "light")
            }
        }()
        HStack(spacing: 6) {
            if totalProtein >= 30 {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(stateGood)
            }
            (Text(word.prefix)
                .font(.custom("DMSans-Regular", size: 28))
            + Text(word.italic)
                .font(.custom("JeniHeroSerif-Italic", size: 34)))
                .foregroundStyle(totalProtein >= 30 ? stateGood : textSecondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(
                (totalProtein >= 30 ? stateGood : textSecondary)
                    .opacity(totalProtein >= 30 ? 0.14 : 0.10)
            )
        )
        .overlay(
            Capsule().stroke(
                stateGood.opacity(totalProtein >= 30 ? 0.35 : 0),
                lineWidth: 0.75
            )
        )
        .shadow(
            color: stateGood.opacity(totalProtein >= 30 ? 0.30 : 0),
            radius: 10,
            x: 0,
            y: 0
        )
    }

    private var isGlp1Cohort: Bool {
        let normalized = glp1Status.lowercased()
        return normalized.contains("current")
            || normalized.contains("on_glp1")
            || normalized == "on"
            || normalized == "post"
            || normalized.contains("triedoff")
            || normalized.contains("tried_off")
    }

    // MARK: - Zone D: ingredient ledger (3-5 rows)

    @ViewBuilder private var ingredientLedger: some View {
        let items = displayIngredients
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline) {
                        Circle()
                            .fill(accent.opacity(0.7))
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 4)
                        Text(item.name.lowercased())
                            .font(.custom("DMSans-Medium", size: 36))
                            .foregroundStyle(textPrimary)
                        Spacer(minLength: 0)
                        Text(item.portion)
                            .font(.custom("DMSans-Regular", size: 30))
                            .foregroundStyle(textPrimary.opacity(0.45))
                            .monospacedDigit()
                        // Pencil shows whenever the sheet is available
                        // (i.e. the parent is going to receive the
                        // edit either via onEditItem or via
                        // onResultEdited's auto-reconstruct path).
                        if onEditItem != nil || onResultEdited != nil {
                            Image(systemName: "pencil")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(textPrimary.opacity(0.35))
                                .padding(.leading, 10)
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onEditItem?(idx)
                        editingItem = EditingItemIndex(index: idx)
                    }
                    if idx < items.count - 1 {
                        Rectangle()
                            .fill(textPrimary.opacity(0.08))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var displayIngredients: [(name: String, portion: String)] {
        result.items.prefix(5).map { item in
            let portion = item.portionGrams > 0
                ? "\(Int(item.portionGrams.rounded()))g"
                : ""
            return (name: item.name, portion: portion)
        }
    }

    // MARK: - Zone E: macro micro-bar (compressed, no legend)

    @ViewBuilder private var macroMicroBar: some View {
        let total = max(1, totalProtein + totalCarbs + totalFat + totalFiber)
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(accent.opacity(0.92))
                        .frame(width: width * CGFloat(totalProtein) / CGFloat(total))
                    Rectangle()
                        .fill(textPrimary.opacity(0.58))
                        .frame(width: width * CGFloat(totalCarbs) / CGFloat(total))
                    Rectangle()
                        .fill(textPrimary.opacity(0.32))
                        .frame(width: width * CGFloat(totalFat) / CGFloat(total))
                    Rectangle()
                        .fill(stateGood.opacity(0.85))
                        .frame(width: width * CGFloat(totalFiber) / CGFloat(total))
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            HStack(spacing: 28) {
                macroLegendInline(color: accent.opacity(0.92), label: "protein", grams: totalProtein)
                macroLegendInline(color: textPrimary.opacity(0.58), label: "carbs", grams: totalCarbs)
                macroLegendInline(color: textPrimary.opacity(0.32), label: "fat", grams: totalFat)
                macroLegendInline(color: stateGood.opacity(0.85), label: "fiber", grams: totalFiber)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func macroLegendInline(color: Color, label: String, grams: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            (Text("\(grams)g ")
                .font(.custom("DMSans-Medium", size: 24))
                .foregroundColor(textPrimary)
            + Text(label)
                .font(.custom("DMSans-Regular", size: 24))
                .foregroundColor(textSecondary))
        }
    }

    // MARK: - Zone F: satiety + protein density

    @ViewBuilder private var satietyAndDensity: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("holds you ")
                .font(.custom("JeniHeroSerif-Regular", size: 44))
            + Text(satietyHoursLabel)
                .font(.custom("JeniHeroSerif-Italic", size: 44))
            + Text("  ·  ")
                .font(.custom("JeniHeroSerif-Regular", size: 44))
                .foregroundColor(textPrimary.opacity(0.25))
            + Text("\(totalFiber)g")
                .font(.custom("JeniHeroSerif-Regular", size: 44))
            + Text(" fiber  \u{2661}")
                .font(.custom("DMSans-Medium", size: 32))
                .foregroundColor(accent.opacity(0.7)))
                .foregroundStyle(textPrimary)
                .kerning(-0.2)
                .fixedSize(horizontal: false, vertical: true)
            if let density = proteinDensityLabel {
                Text(density)
                    .font(.custom("DMSans-Regular", size: 28))
                    .foregroundStyle(textSecondary)
            }
        }
    }

    private var proteinDensityLabel: String? {
        guard totalKcal > 0 else { return nil }
        let perHundred = Double(totalProtein) / Double(totalKcal) * 100
        let rounded = (perHundred * 10).rounded() / 10
        guard rounded >= 4 else { return nil }
        let dense = rounded >= 7 ? " · dense plate" : ""
        return "\(String(format: "%.1f", rounded))g protein per 100 cal\(dense)"
    }

    // MARK: - Conditional threshold flag (sodium / sugar / satfat)
    //
    // Per the panel: surface ONLY when meaningfully high — never a
    // numeric, never red, never "you're over." Italic state-pill in
    // peach-tinted capsule: "*sodium-heavy* — water with it ♥". Picks
    // the most-relevant flag (sodium > sugar > satfat priority) and
    // shows ONE; never stacks. Reads as honest acknowledgment, not
    // judgment.
    //
    // Thresholds (per-meal, conservative):
    //   • sodium ≥ 800mg  → 35% DV at 2300mg/day; restaurant + UPF tell
    //   • added sugars ≥ 20g  → 80% WHO daily; soda/sweets tell
    //   • saturated fat ≥ 7g  → 35% DV; butter + processed-meat tell

    private struct ThresholdFlag {
        let glyph: String
        let prefix: String
        let italic: String
        let suffix: String
    }

    private var thresholdFlag: ThresholdFlag? {
        let sodium = result.items.compactMap { $0.sodiumMg }.reduce(0, +)
        let sugar = result.items.compactMap { $0.sugarG }.reduce(0, +)
        let satfat = result.items.compactMap { $0.saturatedFatG }.reduce(0, +)
        if sodium >= 800 {
            return ThresholdFlag(
                glyph: "drop.fill",
                prefix: "",
                italic: "sodium-heavy",
                suffix: " — water with it \u{2661}"
            )
        }
        if sugar >= 20 {
            return ThresholdFlag(
                glyph: "circle.hexagonpath.fill",
                prefix: "",
                italic: "sugar-forward",
                suffix: " — be soft on it \u{2661}"
            )
        }
        if satfat >= 7 {
            return ThresholdFlag(
                glyph: "leaf.fill",
                prefix: "",
                italic: "rich on butter",
                suffix: " — that's okay \u{2661}"
            )
        }
        return nil
    }

    @ViewBuilder
    private func thresholdFlagLine(_ flag: ThresholdFlag) -> some View {
        HStack(spacing: 10) {
            Image(systemName: flag.glyph)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(accent.opacity(0.75))
            (Text(flag.prefix)
                .font(.custom("DMSans-Regular", size: 28))
            + Text(flag.italic)
                .font(.custom("JeniHeroSerif-Italic", size: 32))
            + Text(flag.suffix)
                .font(.custom("DMSans-Regular", size: 28)))
                .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Capsule().fill(accentSubtle.opacity(0.35)))
    }

    // MARK: - Zone G: today's protein adequacy bar
    //
    // NOT a calorie remaining bar (that's the diet-culture register
    // the brand is built to refuse). Protein-only progress reads as
    // *adequacy* not *budget*. Target derives from onboarding weight
    // (1.0g/kg, floor 70g) when available.

    @ViewBuilder private var todayProteinBar: some View {
        let target = proteinTargetG
        let logged = todayLoggedProtein + totalProtein
        let progress = min(1.0, Double(logged) / Double(max(target, 1)))
        VStack(alignment: .leading, spacing: 8) {
            (Text("today: ")
                .font(.custom("DMSans-Regular", size: 28))
            + Text("\(logged)g")
                .font(.custom("JeniHeroSerif-Italic", size: 32))
                .foregroundColor(textPrimary)
            + Text(" / ~\(target)g protein")
                .font(.custom("DMSans-Regular", size: 28)))
                .foregroundStyle(textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(textPrimary.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.95),
                                    accent.opacity(0.62),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 10)
        }
    }

    private var proteinTargetG: Int {
        let kg = onboardingCurrentWeightKg
        let raw = kg > 30 ? 1.0 * kg : 0
        return max(70, min(150, Int(raw.rounded())))
    }

    private var todayLoggedProtein: Int {
        Int(FoodLogPersister.todayMacros().protein.rounded())
    }

    // MARK: - Macro distribution bar (visual at-a-glance)
    //
    // Horizontal stack bar showing the relative balance of protein /
    // carbs / fat / fiber. Reads how the meal is composed without
    // requiring number-parsing. Colors lean on the locked palette:
    //   - protein: accent rose (cohort priority signal)
    //   - carbs:   cocoa @ 0.55
    //   - fat:     cocoa @ 0.30
    //   - fiber:   stateGood sage (the cohort's "you're doing it"
    //              positive signal)
    //
    // Below the bar: tiny color-dot legend with grams per macro.

    @ViewBuilder private var macroDistributionBar: some View {
        let total = max(1, totalProtein + totalCarbs + totalFat + totalFiber)
        VStack(alignment: .leading, spacing: 18) {
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(accent.opacity(0.88))
                        .frame(width: width * CGFloat(totalProtein) / CGFloat(total))
                    Rectangle()
                        .fill(textPrimary.opacity(0.55))
                        .frame(width: width * CGFloat(totalCarbs) / CGFloat(total))
                    Rectangle()
                        .fill(textPrimary.opacity(0.30))
                        .frame(width: width * CGFloat(totalFat) / CGFloat(total))
                    Rectangle()
                        .fill(stateGood.opacity(0.85))
                        .frame(width: width * CGFloat(totalFiber) / CGFloat(total))
                }
                .clipShape(Capsule())
            }
            .frame(height: 18)

            HStack(spacing: 22) {
                macroLegendItem(color: accent.opacity(0.88), label: "protein", grams: totalProtein)
                macroLegendItem(color: textPrimary.opacity(0.55), label: "carbs", grams: totalCarbs)
                macroLegendItem(color: textPrimary.opacity(0.30), label: "fat", grams: totalFat)
                macroLegendItem(color: stateGood.opacity(0.85), label: "fiber", grams: totalFiber)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func macroLegendItem(color: Color, label: String, grams: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            (
                Text("\(grams)g ")
                    .font(.custom("DMSans-Medium", size: 22))
                    .foregroundColor(textPrimary)
                + Text(label)
                    .font(.custom("DMSans-Light", size: 22))
                    .foregroundColor(textSecondary)
            )
        }
    }

    private var stateGood: Color { Color(red: 0.373, green: 0.451, blue: 0.271) }


    // MARK: - Co-hero row (kcal + protein at equal height)

    @ViewBuilder private var coHeroRow: some View {
        HStack(alignment: .top, spacing: 56) {
            VStack(alignment: .leading, spacing: 6) {
                CountUpNumber(
                    target: totalKcal,
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 180,
                    color: textPrimary
                )
                Text("calories")
                    .font(.custom("JeniHeroSerif-Italic", size: 42))
                    .foregroundStyle(textSecondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    CountUpNumber(
                        target: totalProtein,
                        fontName: "JeniHeroSerif-Regular",
                        italicFontName: "JeniHeroSerif-Italic",
                        size: 180,
                        color: textPrimary
                    )
                    Text("g")
                        .font(.custom("JeniHeroSerif-Italic", size: 60))
                        .foregroundStyle(textSecondary)
                        .baselineOffset(36)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("protein")
                        .font(.custom("JeniHeroSerif-Italic", size: 42))
                        .foregroundStyle(textSecondary)
                    if let line = proteinThresholdLine {
                        (
                            Text(line.prefix)
                                .font(.custom("DMSans-Light", size: 28))
                            + Text(line.punch)
                                .font(.custom("JeniHeroSerif-Italic", size: 30))
                            + Text(line.suffix)
                                .font(.custom("DMSans-Light", size: 28))
                        )
                        .foregroundStyle(accent.opacity(0.85))
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Per-meal protein threshold call-out per the research agent's
    /// load-bearing #3 recommendation. 30g = the MPS / GLP-1
    /// distribution target. Below 15g: hide (don't shame).
    private var proteinThresholdLine: (prefix: String, punch: String, suffix: String)? {
        if totalProtein >= 30 {
            return ("hits the ", "30g", " mark ♡")
        }
        if totalProtein >= 15 {
            return ("a ", "\(totalProtein)g", " start — pair it later")
        }
        return nil
    }

    // MARK: - Satiety + fiber block

    /// Combined: fiber line + italic satiety prediction stacked.
    /// Fiber rendered only when ≥3g (below that the "0g fiber" stat
    /// creates shame without action per research agent). Satiety
    /// always renders.
    @ViewBuilder private var satietyAndFiberBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            if totalFiber >= 3 {
                (
                    Text("\(totalFiber)g")
                        .font(.custom("JeniHeroSerif-Regular", size: 64))
                    + Text(" fiber  ·  ")
                        .font(.custom("JeniHeroSerif-Regular", size: 40))
                        .foregroundColor(textSecondary)
                    + Text(fiberQualitative)
                        .font(.custom("JeniHeroSerif-Italic", size: 40))
                        .foregroundColor(textSecondary)
                )
                .foregroundStyle(textPrimary)
                .kerning(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            }
            (
                Text("this should hold you ")
                    .font(.custom("JeniHeroSerif-Regular", size: 42))
                + Text(satietyHoursLabel)
                    .font(.custom("JeniHeroSerif-Italic", size: 42))
                + Text(".  ")
                    .font(.custom("JeniHeroSerif-Regular", size: 42))
                + Text("♡")
                    .font(.custom("DMSans-Medium", size: 32))
                    .foregroundColor(accent.opacity(0.7))
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fiberQualitative: String {
        if totalFiber >= 8 { return "keeps you full longer" }
        if totalFiber >= 5 { return "easy on your gut" }
        return "a soft start"
    }

    private var satietyHoursLabel: String {
        SatietyEstimate.hoursLabel(
            kcal: totalKcal,
            proteinG: totalProtein,
            fiberG: totalFiber
        )
    }

    // MARK: - Smart pair suggestion

    /// Research agent's load-bearing add: ONE specific suggestion
    /// that closes the largest gap, only when a gap exists. Hide on
    /// balanced plates — silence is the reward.
    private var smartPair: (prefix: String, punch: String, suffix: String)? {
        if totalProtein < 25 {
            return ("a ", "boiled egg", " later pushes you past 30g.")
        }
        if totalFiber < 5 {
            return ("a handful of ", "berries", " later locks in fiber.")
        }
        let fatKcal = totalFat * 9
        if totalKcal > 0, Double(fatKcal) / Double(totalKcal) > 0.55 {
            return ("pair with a ", "lean protein", " to balance.")
        }
        return nil
    }

    @ViewBuilder
    private func smartPairLine(
        _ pair: (prefix: String, punch: String, suffix: String)
    ) -> some View {
        (
            Text(pair.prefix)
                .font(.custom("JeniHeroSerif-Regular", size: 42))
            + Text(pair.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 44))
            + Text(pair.suffix)
                .font(.custom("JeniHeroSerif-Regular", size: 42))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 34))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textSecondary)
        .kerning(-0.2)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tag chips

    @ViewBuilder private var tagChips: some View {
        let tags = activeTags
        if !tags.isEmpty {
            HStack(spacing: 12) {
                ForEach(tags, id: \.self) { tag in
                    chip(tag)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func chip(_ tag: String) -> some View {
        let parts = tag.split(separator: " ", maxSplits: 1).map(String.init)
        let prefix = parts.count == 2 ? parts[0] + " " : ""
        let punch = parts.last ?? tag
        (
            Text(prefix)
                .font(.custom("DMSans-Medium", size: 32))
            + Text(punch)
                .font(.custom("JeniHeroSerif-Italic", size: 34))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 28))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Capsule().fill(accentSubtle.opacity(0.6)))
        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 0.75))
    }

    private var activeTags: [String] {
        var tags: [String] = []
        if totalProtein >= 25 { tags.append("high protein") }
        if totalFiber >= 8 { tags.append("high fiber") }
        return Array(tags.prefix(2))
    }

    // MARK: - Totals

    private var totalKcal: Int {
        let raw: Double = result.totalKcal
            ?? Double((result.kcalLow ?? 0) + (result.kcalHigh ?? 0)) / 2
        return Int((raw / 5).rounded()) * 5
    }
    private var totalProtein: Int {
        Int(result.items.compactMap { $0.proteinG }.reduce(0, +).rounded())
    }
    private var totalCarbs: Int {
        Int(result.items.compactMap { $0.carbsG }.reduce(0, +).rounded())
    }
    private var totalFat: Int {
        Int(result.items.compactMap { $0.fatG }.reduce(0, +).rounded())
    }
    private var totalFiber: Int {
        Int(result.items.compactMap { $0.fiberG }.reduce(0, +).rounded())
    }

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
    private var accentSubtle: Color { Color(red: 0.961, green: 0.835, blue: 0.847) }
}

// MARK: - Zone entrance modifier
//
// v1.0.33 (2026-06-19) — per-zone arrival polish. Each zone fades in
// AND slides up 14pt as the cascade reaches its step. Combined with
// the 80ms perceptual-lag stagger, the page reads as content arriving
// from below, not as a list animating. Reduce-motion: snaps to final.

private struct ZoneEntrance: ViewModifier {
    let step: Int
    let revealed: Int

    func body(content: Content) -> some View {
        let visible = revealed >= step
        return content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
    }
}

extension View {
    /// Apply at each cascade step. Pair with the parent's
    /// `revealedSteps` @State; the modifier crossfades + slides
    /// based on whether the step has been reached.
    fileprivate func zoneEntrance(_ step: Int, revealed: Int) -> some View {
        modifier(ZoneEntrance(step: step, revealed: revealed))
    }
}

// MARK: - IngredientEditSheet
//
// v1.0.34 (2026-06-19) — the real edit surface behind the pencil-tap
// gesture on slide 1's ingredient ledger. Lets her correct what the
// AI inferred: rename the item ("scrambled eggs" → "soft scrambled
// w/ feta") and re-portion it. Nutrients scale linearly with the
// portion change so the per-meal kcal/protein/etc. stay honest.
//
// Design: medium-detent cream sheet, her75-leaning typography,
// hairline rules, single accent rose punch. Live nutrient preview
// updates as the slider drags so she sees the impact in real time.

private struct IngredientEditSheet: View {

    let original: CapturedItem
    let onSave: (CapturedItem) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var portion: Double
    @Environment(\.dismiss) private var dismiss

    init(
        original: CapturedItem,
        onSave: @escaping (CapturedItem) -> Void,
        onRemove: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.original = original
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
        self._name = State(initialValue: original.name)
        self._portion = State(initialValue: original.portionGrams)
    }

    private var scale: Double {
        portion / max(original.portionGrams, 1)
    }

    private var portionMin: Double {
        max(10, original.portionGrams * 0.25)
    }

    private var portionMax: Double {
        original.portionGrams * 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            eyebrow
            nameField
            hairline
            portionBlock
            hairline
            nutrientPreview
            Spacer(minLength: 0)
            actionRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .background(
            Color(red: 0.992, green: 0.965, blue: 0.957)
                .ignoresSafeArea()
        )
    }

    // MARK: - Subviews

    @ViewBuilder private var eyebrow: some View {
        (Text("edit ")
            .font(.custom("DMSans-Regular", size: 13))
        + Text("plate item")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14)))
            .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
            .kerning(0.4)
    }

    @ViewBuilder private var nameField: some View {
        TextField("ingredient name", text: $name)
            .font(.custom("JeniHeroSerif-Regular", size: 28))
            .foregroundStyle(Color(red: 0.239, green: 0.165, blue: 0.165))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(false)
            .submitLabel(.done)
    }

    @ViewBuilder private var portionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("portion")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                    .kerning(0.4)
                Spacer()
                (Text("\(Int(portion.rounded()))")
                    .font(.custom("JeniHeroSerif-Regular", size: 28))
                    .foregroundColor(Color(red: 0.239, green: 0.165, blue: 0.165))
                + Text("g")
                    .font(.custom("JeniHeroSerif-Italic", size: 18))
                    .foregroundColor(Color(red: 0.769, green: 0.404, blue: 0.478)))
                    .monospacedDigit()
            }
            Slider(
                value: $portion,
                in: portionMin...portionMax,
                step: 5
            )
            .tint(Color(red: 0.769, green: 0.404, blue: 0.478))
        }
    }

    @ViewBuilder private var nutrientPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text("in this ")
                .font(.custom("DMSans-Regular", size: 13))
            + Text("portion")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14)))
                .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                .kerning(0.4)

            HStack(spacing: 16) {
                preview(value: scaled(original.kcal), unit: "cal")
                if scaled(original.proteinG) > 0 {
                    preview(value: scaled(original.proteinG), unit: "g protein")
                }
                if scaled(original.carbsG) > 0 {
                    preview(value: scaled(original.carbsG), unit: "g carbs")
                }
                if scaled(original.fatG) > 0 {
                    preview(value: scaled(original.fatG), unit: "g fat")
                }
                if scaled(original.fiberG) > 0 {
                    preview(value: scaled(original.fiberG), unit: "g fiber")
                }
                Spacer(minLength: 0)
            }
            .animation(.easeOut(duration: 0.15), value: portion)
        }
    }

    @ViewBuilder
    private func preview(value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(Int(value.rounded()))")
                .font(.custom("JeniHeroSerif-Regular", size: 22))
                .foregroundStyle(Color(red: 0.239, green: 0.165, blue: 0.165))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                .kerning(0.3)
        }
    }

    @ViewBuilder private var hairline: some View {
        Rectangle()
            .fill(Color(red: 0.239, green: 0.165, blue: 0.165).opacity(0.10))
            .frame(height: 0.75)
    }

    @ViewBuilder private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onRemove()
            } label: {
                (Text("remove")
                    .font(.custom("DMSans-Medium", size: 14)))
                    .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .overlay(
                        Capsule().stroke(
                            Color(red: 0.482, green: 0.349, blue: 0.349).opacity(0.30),
                            lineWidth: 1
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
                    .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Button {
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                let updated = makeUpdatedItem()
                onSave(updated)
            } label: {
                (Text("save ")
                    .font(.custom("DMSans-SemiBold", size: 14))
                + Text("plate")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15)))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color(red: 0.769, green: 0.404, blue: 0.478))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    /// Linear nutrient scale by portion delta. Returns 0 when the
    /// underlying value is nil so the preview row hides cleanly.
    private func scaled(_ value: Double?) -> Double {
        guard let v = value else { return 0 }
        return v * scale
    }

    /// Constructs the edited CapturedItem with name (trimmed; fallback
    /// to original) + scaled portion + scaled nutrient values. The
    /// ID + provenance metadata (preparation, cuisineHint, etc.) are
    /// preserved so downstream consumers don't lose context.
    private func makeUpdatedItem() -> CapturedItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? original.name : trimmedName
        return CapturedItem(
            id: original.id,
            name: finalName,
            portionGrams: portion,
            portionGramsLow: original.portionGramsLow * scale,
            portionGramsHigh: original.portionGramsHigh * scale,
            usdaSearchTerms: original.usdaSearchTerms,
            preparation: original.preparation,
            cuisineHint: original.cuisineHint,
            confidence: original.confidence,
            notes: original.notes,
            kcal: original.kcal.map { $0 * scale },
            proteinG: original.proteinG.map { $0 * scale },
            carbsG: original.carbsG.map { $0 * scale },
            fatG: original.fatG.map { $0 * scale },
            fiberG: original.fiberG.map { $0 * scale },
            nutritionSource: original.nutritionSource,
            sugarG: original.sugarG.map { $0 * scale },
            sodiumMg: original.sodiumMg.map { $0 * scale },
            saturatedFatG: original.saturatedFatG.map { $0 * scale }
        )
    }
}

#endif  // canImport(UIKit)
