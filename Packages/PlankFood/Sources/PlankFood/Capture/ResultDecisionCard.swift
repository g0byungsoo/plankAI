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
    /// Slide 1 stays a compact glance so the card floats over the food
    /// photo (not filling it). The full editable ledger expands on tap.
    @State private var ledgerExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingCurrentWeightKg") private var onboardingCurrentWeightKg: Double = 0
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""

    var body: some View {
        GeometryReader { geo in
        // Center within the VISIBLE screen width. The paging carousel can
        // propose a slot wider than the screen, and centering in that slot
        // drifts the card right; instead we pin a screen-width region to
        // the slot's leading edge and center the card inside it.
        let w = min(geo.size.width, UIScreen.main.bounds.width)
        ZStack(alignment: .top) {
            // Transparent backdrop — the frozen camera photo behind the
            // carousel slot shows around the floating card.
            Color.clear

            card
                .cardLand()
                .padding(.horizontal, 18)
                .padding(.top, 48)
                .padding(.bottom, 40)
        }
        .frame(width: w)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(textPrimary.opacity(0.07), lineWidth: 0.75)
            )
            .shadow(
                color: Color(red: 0.36, green: 0.20, blue: 0.18).opacity(0.07),
                radius: 14,
                x: 0,
                y: 5
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
        // v1.1 (2026-06-24) — zone spacing tightened 11 → 8 so the dense
        // card (2-line dish + macro bar + satiety + tag chip) fits the
        // floating slot on smaller devices without clipping the bottom
        // chip. Founder bug: "high fiber" pill cut off on the result card.
        // The 0.5pt hairline rules carry the zone separation, so tighter
        // spacing still reads editorial, not cramped.
        VStack(alignment: .leading, spacing: 8) {
            metaRow.zoneEntrance(0, revealed: revealedSteps)
            dishTitle.zoneEntrance(0, revealed: revealedSteps)
            zoneRule
            kcalHero.zoneEntrance(1, revealed: revealedSteps)
            proteinCoHero.zoneEntrance(2, revealed: revealedSteps)
            zoneRule
            ingredientLedger.zoneEntrance(3, revealed: revealedSteps)
            zoneRule
            macroMicroBar.zoneEntrance(4, revealed: revealedSteps)
            satietyAndDensity.zoneEntrance(5, revealed: revealedSteps)
            // v1.1.2 — day-protein bar, protein density + the threshold
            // consideration moved to slide 2 ("a note from jeni") so each
            // fact lives in one place and slide 1 stays a clean glance.
            // 2026-06-23 — the full smart-pair SENTENCE ("a handful of
            // berries later locks in fiber") was dropped from slide 1 per
            // founder: it pushed the card past the slot height and cut off
            // the tag chips. The compact "+ berries" pairing chip (driven
            // by the same smartPair data via pairActionPunch) stays.
            tagChips.zoneEntrance(6, revealed: revealedSteps)
        }
    }

    /// Half-pt hairline rule between zones — the single convention
    /// that lets density read as magazine, not spreadsheet.
    @ViewBuilder private var zoneRule: some View {
        Rectangle()
            .fill(textPrimary.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Zone A: meta row (time · meal · confidence pill)

    @ViewBuilder private var metaRow: some View {
        HStack(alignment: .center) {
            (Text(timeLabel)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(textSecondary)
            + Text("  ·  ")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(textPrimary.opacity(0.25))
            + Text(mealLabelDisplay)
                .font(.custom("JeniHeroSerif-Italic", size: 14))
                .foregroundColor(textSecondary)
            + (cuisineLabel.map {
                Text("  ·  ")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(textPrimary.opacity(0.25))
                + Text($0)
                    .font(.custom("JeniHeroSerif-Italic", size: 13))
                    .foregroundColor(textSecondary)
            } ?? Text("")))
            .kerning(0.2)
            Spacer(minLength: 0)
            confidencePill
        }
    }

    /// First non-empty cuisineHint across items, lowercased. Reads as
    /// a quiet anchor for what kind of food this is ("italian",
    /// "japanese", "diner"). Nil when no item carries the field.
    private var cuisineLabel: String? {
        let raw = result.items
            .compactMap { $0.cuisineHint?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return raw?.lowercased()
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
            .font(.custom("DMSans-Regular", size: 12))
        + Text(word.1)
            .font(.custom("JeniHeroSerif-Italic", size: 14))
        + Text(" \u{2661}")
            .font(.custom("DMSans-Medium", size: 11)))
            .foregroundStyle(accent.opacity(0.80))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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

    // MARK: - Dish title (the food's name)

    @ViewBuilder private var dishTitle: some View {
        let text = dishTitleText
        if !text.isEmpty {
            // 2026-06-24 — the dish title is now a discoverable EDIT entry
            // (founder: users couldn't find a way to fix a wrong result).
            // Tapping it opens the editor for the primary item where the
            // name, calories, protein + macros are all directly editable.
            // The pencil signals it's tappable.
            let canEdit = (onResultEdited != nil || onEditItem != nil) && !result.items.isEmpty
            Button {
                guard canEdit else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onEditItem?(0)
                editingItem = EditingItemIndex(index: 0)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(text)
                        .font(.custom("JeniHeroSerif-Italic", size: 21))
                        .foregroundStyle(textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if canEdit {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(accent.opacity(0.65))
                            .baselineOffset(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)
            .accessibilityLabel("\(text), tap to edit")
        }
    }

    /// The food's name for the title line. Prefers the passed dish name;
    /// falls back to the first couple of detected items so the user always
    /// sees what the plate is.
    private var dishTitleText: String {
        let name = dishName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name.lowercased() }
        let items = result.items.prefix(2).map { $0.name.lowercased() }
        return items.joined(separator: ", ")
    }

    // MARK: - Zone B: kcal hero (number + ±range + italic meal name)

    @ViewBuilder private var kcalHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CountUpNumber(
                target: totalKcal,
                fontName: "JeniHeroSerif-Regular",
                italicFontName: "JeniHeroSerif-Italic",
                // v1.1 (2026-06-24) — 64 → 58, a touch smaller per founder.
                // Pairs with the zone-spacing tighten to fit the dense card.
                size: 58,
                color: textPrimary
            )
            VStack(alignment: .leading, spacing: 1) {
                Text("calories")
                    .font(.custom("JeniHeroSerif-Italic", size: 19))
                    .foregroundStyle(textSecondary)
                if let range = kcalRangeLabel {
                    Text(range)
                        .font(.custom("DMSans-Regular", size: 12))
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // v1.1 (2026-06-24) — protein co-hero 40 → 37 to stay
            // proportional with the slightly smaller calorie hero.
            (Text("\(totalProtein)")
                .font(.custom("JeniHeroSerif-Regular", size: 37))
                .foregroundColor(textPrimary)
            + Text("g")
                .font(.custom("JeniHeroSerif-Italic", size: 16))
                .foregroundColor(accent))
                .monospacedDigit()
            Text("protein")
                .font(.custom("JeniHeroSerif-Italic", size: 18))
                .foregroundStyle(textSecondary)
                .baselineOffset(5)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
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
                    .font(.custom("DMSans-Medium", size: 12))
                + Text(punch)
                    .font(.custom("JeniHeroSerif-Italic", size: 13))
            )
            .foregroundStyle(accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.85)))
            .overlay(Capsule().stroke(accent.opacity(0.55), lineWidth: 0.75))
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
        HStack(spacing: 5) {
            if totalProtein >= 30 {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(stateGood)
            }
            (Text(word.prefix)
                .font(.custom("DMSans-Regular", size: 12))
            + Text(word.italic)
                .font(.custom("JeniHeroSerif-Italic", size: 14)))
                .foregroundStyle(totalProtein >= 30 ? stateGood : textSecondary)
                // 2026-06-24 — keep the stamp on ONE line. When the protein
                // number is wide (e.g. "100g") the trailing column got
                // squeezed and "hits enough" wrapped into a cramped circle
                // (founder bug). lineLimit + fixedSize make the capsule hug
                // the text on a single line.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
                // Collapsed summary (default) keeps the card compact so the
                // food photo shows around it. Tap to reveal the editable list.
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.28)) { ledgerExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(ledgerSummaryLine)
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundStyle(textPrimary.opacity(0.6))
                        Image(systemName: ledgerExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(textPrimary.opacity(0.38))
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ledgerExpanded ? "hide ingredients" : "show \(items.count) ingredients")

                if ledgerExpanded {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline) {
                        Circle()
                            .fill(accent.opacity(0.7))
                            .frame(width: 5, height: 5)
                            .padding(.trailing, 3)
                        Text(item.name.lowercased())
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(textPrimary)
                        Spacer(minLength: 0)
                        Text(item.portion)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(textPrimary.opacity(0.45))
                            .monospacedDigit()
                        // Pencil shows whenever the sheet is available
                        // (i.e. the parent is going to receive the
                        // edit either via onEditItem or via
                        // onResultEdited's auto-reconstruct path).
                        if onEditItem != nil || onResultEdited != nil {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(textPrimary.opacity(0.35))
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 7)
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
    }

    /// Compact one-line ledger summary shown when collapsed:
    /// "4 ingredients  ·  560g".
    private var ledgerSummaryLine: String {
        let n = displayIngredients.count
        let total = Int(result.items.prefix(5).reduce(0.0) { $0 + $1.portionGrams }.rounded())
        let noun = n == 1 ? "ingredient" : "ingredients"
        return total > 0 ? "\(n) \(noun)  \u{00B7}  \(total)g" : "\(n) \(noun)"
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
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(height: 6)
            HStack(spacing: 14) {
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
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            (Text("\(grams)g ")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(textPrimary)
            + Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundColor(textSecondary))
        }
    }

    // MARK: - Zone F: satiety + protein density

    @ViewBuilder private var satietyAndDensity: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("holds you ")
                .font(.custom("JeniHeroSerif-Regular", size: 17))
            + Text(satietyHoursLabel)
                .font(.custom("JeniHeroSerif-Italic", size: 17))
            + Text("  ·  ")
                .font(.custom("JeniHeroSerif-Regular", size: 17))
                .foregroundColor(textPrimary.opacity(0.25))
            + Text("\(totalFiber)g")
                .font(.custom("JeniHeroSerif-Regular", size: 17))
            + Text(" fiber  \u{2661}")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundColor(accent.opacity(0.7)))
                .foregroundStyle(textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
            return ("a ", "\(totalProtein)g", " start. pair it later")
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
                .font(.custom("DMSans-Medium", size: 12))
            + Text(punch)
                .font(.custom("JeniHeroSerif-Italic", size: 14))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
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
    // 2026-06-24 — directly-editable nutrition. Founder: users had no way
    // to fix a wrong calorie / protein number (only portion-scaling). Now
    // each macro is a typed field: drag the portion slider to scale them
    // proportionally, OR type the right number directly.
    @State private var editedKcal: Double
    @State private var editedProtein: Double
    @State private var editedCarbs: Double
    @State private var editedFat: Double
    @FocusState private var fieldFocused: Bool
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
        self._editedKcal = State(initialValue: original.kcal ?? 0)
        self._editedProtein = State(initialValue: original.proteinG ?? 0)
        self._editedCarbs = State(initialValue: original.carbsG ?? 0)
        self._editedFat = State(initialValue: original.fatG ?? 0)
    }

    private var portionMin: Double {
        max(10, original.portionGrams * 0.25)
    }

    private var portionMax: Double {
        original.portionGrams * 4
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    eyebrow
                    nameField
                    hairline
                    portionBlock
                    hairline
                    nutrientEditor
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            }
            actionRow
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 22)
        }
        .background(
            Color(red: 0.992, green: 0.965, blue: 0.957)
                .ignoresSafeArea()
        )
        // Drag the portion slider → rescale the macros proportionally from
        // the original (the "less of that" path). Typing directly in a
        // macro field overrides until the next portion drag.
        .onChange(of: portion) { _, newPortion in
            let s = newPortion / max(original.portionGrams, 1)
            editedKcal = (original.kcal ?? 0) * s
            editedProtein = (original.proteinG ?? 0) * s
            editedCarbs = (original.carbsG ?? 0) * s
            editedFat = (original.fatG ?? 0) * s
        }
        // numberPad has no return key, and the keyboard would cover the
        // pinned Save button — give it a "done" to dismiss + commit.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done") { fieldFocused = false }
                    .font(.custom("DMSans-SemiBold", size: 15))
                    .foregroundStyle(Color(red: 0.769, green: 0.404, blue: 0.478))
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            TextField("ingredient name", text: $name)
                .font(.custom("JeniHeroSerif-Regular", size: 28))
                .foregroundStyle(Color(red: 0.239, green: 0.165, blue: 0.165))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(false)
                .submitLabel(.done)
            if isLowConfidence {
                (Text("we weren't sure about this one. feel ")
                    .font(.custom("DMSans-Regular", size: 12))
                + Text("free")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                + Text(" to correct \u{2661}")
                    .font(.custom("DMSans-Regular", size: 12)))
                    .foregroundStyle(Color(red: 0.769, green: 0.404, blue: 0.478))
            }
        }
    }

    private var isLowConfidence: Bool {
        guard let c = original.confidence else { return false }
        return c < 0.65
    }

    @ViewBuilder private var portionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("portion")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                    .kerning(0.4)
                if isPortionEdited {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) {
                            portion = original.portionGrams
                        }
                    } label: {
                        (Text("reset to ")
                            .font(.custom("DMSans-Regular", size: 12))
                        + Text("original")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13)))
                            .foregroundStyle(Color(red: 0.769, green: 0.404, blue: 0.478))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                Spacer()
                (Text("\(Int(portion.rounded()))")
                    .font(.custom("JeniHeroSerif-Regular", size: 28))
                    .foregroundColor(Color(red: 0.239, green: 0.165, blue: 0.165))
                + Text("g")
                    .font(.custom("JeniHeroSerif-Italic", size: 18))
                    .foregroundColor(Color(red: 0.769, green: 0.404, blue: 0.478)))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            sliderWithOriginalTick
        }
    }

    /// Slider with a thin vertical tick at the original-portion
    /// position. The tick sits behind the rose track but in front of
    /// the slider's background, giving the user a clear anchor for
    /// the AI's inferred portion.
    @ViewBuilder private var sliderWithOriginalTick: some View {
        let span = portionMax - portionMin
        let fraction = span > 0
            ? (original.portionGrams - portionMin) / span
            : 0.5
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Slider(
                    value: $portion,
                    in: portionMin...portionMax,
                    step: 5
                )
                .tint(Color(red: 0.769, green: 0.404, blue: 0.478))
                // Tick — vertical 12pt cocoa rule + tiny "scan" eyebrow
                // below (was "ai" — no "AI" word in user copy). Marks the
                // scan's original portion estimate. The slider track pads
                // ~10pt each side natively so we inset the tick to match.
                let trackInset: CGFloat = 12
                let trackWidth = max(0, geo.size.width - trackInset * 2)
                let x = trackInset + CGFloat(fraction) * trackWidth
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.239, green: 0.165, blue: 0.165).opacity(0.30))
                        .frame(width: 1, height: 14)
                    Text("scan")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 9))
                        .foregroundStyle(Color(red: 0.239, green: 0.165, blue: 0.165).opacity(0.45))
                        .kerning(0.3)
                        .padding(.top, 2)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .position(x: x, y: geo.size.height / 2)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 38)
    }

    private var isPortionEdited: Bool {
        abs(portion - original.portionGrams) >= 1
    }

    /// 2026-06-24 — directly EDITABLE nutrition (founder: "users dont
    /// have any options to correct them even when the result is wrong").
    /// Type the right calories / protein / carbs / fat; or drag the
    /// portion slider above to scale them all proportionally.
    @ViewBuilder private var nutrientEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("the ")
                .font(.custom("DMSans-Regular", size: 13))
            + Text("numbers")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14)))
                .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                .kerning(0.4)

            // calories + protein on the first row so both (the two the
            // founder named) are visible on the medium detent; carbs + fat
            // on the second row.
            HStack(spacing: 10) {
                editableField(label: "calories", value: $editedKcal, unit: nil)
                editableField(label: "protein", value: $editedProtein, unit: "g")
            }
            HStack(spacing: 10) {
                editableField(label: "carbs", value: $editedCarbs, unit: "g")
                editableField(label: "fat", value: $editedFat, unit: "g")
            }
        }
    }

    @ViewBuilder
    private func editableField(label: String, value: Binding<Double>, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundStyle(Color(red: 0.482, green: 0.349, blue: 0.349))
                .kerning(0.3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                    .font(.custom("JeniHeroSerif-Regular", size: 22))
                    .foregroundStyle(Color(red: 0.239, green: 0.165, blue: 0.165))
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .focused($fieldFocused)
                    .fixedSize()
                if let unit {
                    Text(unit)
                        .font(.custom("JeniHeroSerif-Italic", size: 14))
                        .foregroundStyle(Color(red: 0.769, green: 0.404, blue: 0.478))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.769, green: 0.404, blue: 0.478).opacity(0.28), lineWidth: 1)
            )
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

    /// Constructs the edited CapturedItem with name (trimmed; fallback
    /// to original) + scaled portion + scaled nutrient values. The
    /// ID + provenance metadata (preparation, cuisineHint, etc.) are
    /// preserved so downstream consumers don't lose context.
    private func makeUpdatedItem() -> CapturedItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? original.name : trimmedName
        // The macro fields are the source of truth (typed directly, or
        // scaled from the portion slider via onChange). fiber / sugar /
        // sodium / sat-fat aren't directly editable, so they scale with
        // the portion delta. Accuracy fields (native gloss, count, share)
        // are preserved.
        let s = portion / max(original.portionGrams, 1)
        return CapturedItem(
            id: original.id,
            name: finalName,
            portionGrams: portion,
            portionGramsLow: original.portionGramsLow * s,
            portionGramsHigh: original.portionGramsHigh * s,
            usdaSearchTerms: original.usdaSearchTerms,
            preparation: original.preparation,
            cuisineHint: original.cuisineHint,
            confidence: original.confidence,
            notes: original.notes,
            kcal: editedKcal,
            proteinG: editedProtein,
            carbsG: editedCarbs,
            fatG: editedFat,
            fiberG: original.fiberG.map { $0 * s },
            nutritionSource: original.nutritionSource,
            sugarG: original.sugarG.map { $0 * s },
            sodiumMg: original.sodiumMg.map { $0 * s },
            saturatedFatG: original.saturatedFatG.map { $0 * s },
            englishName: original.englishName,
            count: original.count,
            unit: original.unit,
            servingsInDish: original.servingsInDish,
            isShareable: original.isShareable
        )
    }
}

#endif  // canImport(UIKit)
