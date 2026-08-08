#if canImport(UIKit)
import SwiftUI

// MARK: - SnapResultView
//
// v23 THE STILL LIFE §5 — THE READING. One page in reading order on
// the two-detent panel; the carousel died (navigation was spending
// the screen's one idea). The photograph stays the hero above:
//
//   context line (time · meal) → the name → THE NUMERAL (counted
//   kcal + the ± band) → PROTEIN (the one collected floor) → THE
//   SPLIT (what the plate's energy was made of) → THE LEDGER
//   (carbs · fat · fiber · sugar · sodium as hairline rows — no
//   bars: no collected denominator) → THE ITEMS (editable, portion
//   steppers, the refine composers) → THE FRACTION → WHAT JENI
//   NOTICED (the note came home to the page) → the footer ("add it").
//
// The share composer is an overlay state over the same steady photo
// (`page == 2` — the host's chrome contract unchanged).
//
// All mutation routes through PlateEditSession (SnapResultMath.swift);
// this file is presentation + choreography only. One grammar for
// every source: photo, barcode, label, described (S3).

public struct SnapResultView: View {
    var userId: String = ""

    let initialFood: CapturedFood
    let mealLabel: String
    let dishName: String
    let onLog: (CapturedFood) -> Void
    let onRetake: () -> Void
    /// Fired on every committed edit with the rebuilt plate so the
    /// host's mirror (persist + share) stays in sync.
    let onEdited: (CapturedFood) -> Void
    /// The natural-language refine pipeline ("fix it with words" +
    /// "+ add something"). nil hides both affordances (previews).
    let refine: ((SnapRefineRequest) async throws -> SnapRefineOutcome)?
    /// Carousel slide (0 plate · 1 note · 2 share). Host-owned so the
    /// floating chrome (close vs back/share-CTA) can swap with it and
    /// debug args can jump slides.
    @Binding var page: Int

    @State private var session: PlateEditSession
    @State private var revealed: Int = 0
    @State private var expanded: Bool = false
    @State private var editingItemID: String? = nil
    /// Rise-in on arrival — the panel owns its entrance (spring from
    /// 44pt below + fade) so the host stage can stay a plain
    /// cross-dissolve. Content cascade runs on top of this.
    @State private var risen: Bool = false
    @GestureState private var dragTranslation: CGFloat = 0

    /// Inline composer for the two natural-language affordances. One
    /// at a time; the field expands in place of its trigger row.
    private enum Composer { case addItem, fixWords }
    @State private var composer: Composer? = nil
    @State private var composerText: String = ""
    @State private var refining: Bool = false
    @State private var refineErrorLine: String? = nil
    @FocusState private var composerFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingCurrentWeightKg") private var currentWeightKg: Double = 0
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0

    var loggedAt: Date = Date()

    /// v23 — the share composer needs a photograph to render; the
    /// described path passes false and the footer stays two verbs.
    var allowsShare: Bool = true

    public init(
        userId: String = "",
        food: CapturedFood,
        mealLabel: String,
        dishName: String,
        page: Binding<Int>,
        allowsShare: Bool = true,
        onLog: @escaping (CapturedFood) -> Void,
        onRetake: @escaping () -> Void,
        onEdited: @escaping (CapturedFood) -> Void,
        refine: ((SnapRefineRequest) async throws -> SnapRefineOutcome)? = nil
    ) {
        self.userId = userId
        self.initialFood = food
        self.mealLabel = mealLabel
        self.dishName = dishName
        _page = page
        self.allowsShare = allowsShare
        self.onLog = onLog
        self.onRetake = onRetake
        self.onEdited = onEdited
        self.refine = refine
        _session = State(initialValue: PlateEditSession(food: food))
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            let peekHeight = min(geo.size.height * 0.62, 560)
            // Full detent leaves ~120pt of photo so the floating X stays
            // on the photo, never stranded over the cream card.
            let fullHeight = min(geo.size.height * 0.92, geo.size.height - 120)
            let baseHeight = expanded ? fullHeight : peekHeight
            let liveHeight = rubberBanded(
                baseHeight - dragTranslation,
                lo: peekHeight, hi: fullHeight
            )

            // v23 — one page. The share composer overlays the same
            // steady photo when asked (page == 2); the dots died with
            // the carousel.
            ZStack(alignment: .top) {
                if page == 2 {
                    shareSlide
                        .transition(.opacity)
                } else {
                    panelSlide(liveHeight: liveHeight, peek: peekHeight, full: fullHeight) {
                        platePage
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: page == 2)
        }
        .onChange(of: page) { _, _ in
            // A slide swap shouldn't strand the composer keyboard over
            // the note or share slide.
            composerFocused = false
        }
        .onAppear {
            if reduceMotion {
                risen = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    risen = true
                }
            }
            runCascade()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--debug-result-expanded") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        expanded = true
                    }
                }
            }
            // Sim QA: auto-open a composer for screenshot capture.
            if ProcessInfo.processInfo.arguments.contains("--debug-composer-fix") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    openComposer(.fixWords)
                }
            } else if ProcessInfo.processInfo.arguments.contains("--debug-composer-add") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    openComposer(.addItem)
                }
            }
            #endif
            #if DEBUG
            // Sim QA: `--debug-edit-sheet` auto-opens the editor on the
            // first item so the harness can screenshot it without taps.
            if ProcessInfo.processInfo.arguments.contains("--debug-edit-sheet"),
               let first = session.effectiveItems.first,
               editingItemID == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    editingItemID = first.id
                }
            }
            #endif
        }
        .sheet(item: editingBinding) { box in
            IngredientEditorSheet(
                original: box.item,
                scanBaseline: session.baselineItem(box.item.id),
                onSave: { updated in
                    commit { $0.replace(updated) }
                    editingItemID = nil
                },
                onRemove: {
                    commit { $0.remove(box.item.id) }
                    editingItemID = nil
                },
                onCancel: { editingItemID = nil }
            )
            // .medium folds the carbs/fat row under the pinned action
            // bar; 0.72 shows the full number grid with the keyboard
            // still able to push to .large.
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Carousel slides

    /// The shared two-detent panel chrome. Slides 1-2 each wrap their
    /// content in this so the whole panel carousels TikTok-style (card
    /// slides as one object); the detent state is shared, so a swap
    /// mid-expanded keeps the height.
    @ViewBuilder
    private func panelSlide<Content: View>(
        liveHeight: CGFloat, peek: CGFloat, full: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            header
                .contentShape(Rectangle())
                .gesture(detentDrag(peek: peek, full: full))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .padding(.horizontal, 22)
                .padding(.top, 2)
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .frame(height: liveHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(cardChrome)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .offset(y: risen ? 0 : 44)
        .opacity(risen ? 1 : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.86),
            value: expanded
        )
    }

    /// THE READING (§5) — one page in reading order: the numbers,
    /// the plate's items, the honest portion, the correction levers,
    /// then what jeni noticed. Nothing to swipe for.
    @ViewBuilder private var platePage: some View {
        heroBlock.cascade(1, revealed)
        hairline.cascade(2, revealed)
        ledger.cascade(2, revealed)
        fractionChips.cascade(3, revealed)
        if refine != nil {
            composerBlock.cascade(4, revealed)
        }
        hairline.cascade(5, revealed)
        noteBlock.cascade(5, revealed)
    }

    /// Slide 3 — the on-photo share composer. SnapShareSlide draws
    /// overlay-only (embedsPhoto: false down the stack), so the host's
    /// steady photo backdrop shows through and the swipe reads as the
    /// composer chrome sliding in over the plate.
    private var shareSlide: some View {
        SnapShareSlide(
            photo: nil,
            mealLabel: mealLabel,
            dishName: dishTitleText,
            itemNames: session.effectiveItems.map { $0.name },
            totals: shareTotals()
        )
    }

    private func shareTotals() -> (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int) {
        let food = session.rebuiltFood()
        return (
            carbs: Int(food.items.compactMap { $0.carbsG }.reduce(0, +).rounded()),
            protein: Int(food.items.compactMap { $0.proteinG }.reduce(0, +).rounded()),
            fat: Int(food.items.compactMap { $0.fatG }.reduce(0, +).rounded()),
            fiber: Int(food.items.compactMap { $0.fiberG }.reduce(0, +).rounded()),
            kcal: displayKcal(session.totals)
        )
    }

    // MARK: - Edit plumbing

    private struct EditingBox: Identifiable {
        let item: CapturedItem
        var id: String { item.id }
    }

    private var editingBinding: Binding<EditingBox?> {
        Binding(
            get: {
                guard let id = editingItemID,
                      let item = session.item(id) else { return nil }
                return EditingBox(item: item)
            },
            set: { editingItemID = $0?.item.id }
        )
    }

    /// Single funnel for every mutation: apply, then hand the rebuilt
    /// plate up so the host mirror stays true.
    private func commit(_ mutate: (inout PlateEditSession) -> Void) {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.28)) {
            mutate(&session)
        }
        onEdited(session.rebuiltFood())
    }

    // MARK: - Detent drag

    private func detentDrag(peek: CGFloat, full: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                if projected < -40 {
                    setExpanded(true)
                } else if projected > 40 {
                    setExpanded(false)
                }
            }
    }

    private func setExpanded(_ value: Bool) {
        guard expanded != value else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        expanded = value
    }

    /// Soft clamp with 0.22 resistance past the detent bounds so the
    /// card breathes at the edges instead of hitting a wall.
    private func rubberBanded(_ x: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        if x < lo { return lo - (lo - x) * 0.22 }
        if x > hi { return hi + (x - hi) * 0.22 }
        return x
    }

    // MARK: - Chrome

    private var cardChrome: some View {
        // v23 — the page is PAPER (the token, not a bespoke cream),
        // separated from the photograph by fill + one soft shadow.
        // The stroke overlay died with the border law (§6.1).
        UnevenRoundedRectangle(
            topLeadingRadius: 28, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 28,
            style: .continuous
        )
        .fill(FoodTheme.bgPrimary)
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -8)
        .ignoresSafeArea(edges: .bottom)
    }

    private var hairline: some View {
        Rectangle()
            .fill(FoodTheme.textPrimary.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Header (grabber + meta + dish title)

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule()
                .fill(FoodTheme.textPrimary.opacity(0.18))
                .frame(width: 36, height: 4.5)
                .frame(maxWidth: .infinity)
                .padding(.top, 9)
                .padding(.bottom, 3)

            HStack(alignment: .firstTextBaseline) {
                metaLine
                Spacer(minLength: 8)
                confidenceWordView
            }
            dishTitle
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 9)
        .cascade(0, revealed)
        .accessibilityAddTraits(.isHeader)
    }

    private var metaLine: some View {
        (Text(timeLabel)
            .font(.custom("DMSans-Medium", size: 12))
            .foregroundColor(FoodTheme.textSecondary)
        + Text("  \u{00B7}  ")
            .font(.custom("DMSans-Medium", size: 12))
            .foregroundColor(FoodTheme.textPrimary.opacity(0.25))
        + Text(mealLabel.isEmpty ? "today" : mealLabel.lowercased())
            .font(.custom("JeniHeroSerif-Italic", size: 13))
            .foregroundColor(FoodTheme.textSecondary)
        + (cuisineLabel.map {
            Text("  \u{00B7}  ")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundColor(FoodTheme.textPrimary.opacity(0.25))
            + Text($0)
                .font(.custom("JeniHeroSerif-Italic", size: 13))
                .foregroundColor(FoodTheme.textSecondary)
        } ?? Text("")))
            .kerning(0.2)
            .lineLimit(1)
    }

    private var cuisineLabel: String? {
        session.effectiveItems
            .compactMap { $0.cuisineHint?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }?
            .lowercased()
    }

    private var timeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    /// Confidence voiced as a word, never a percent.
    private var confidenceWordView: some View {
        let c = initialFood.confidence ?? 0.85
        let word: (String, String) = {
            switch c {
            case ..<0.65: return ("let's ", "check")
            case ..<0.85: return ("close ", "enough")
            default:      return ("", "clear")
            }
        }()
        return (Text(word.0)
            .font(.custom("DMSans-Regular", size: 12))
        + Text(word.1)
            .font(.custom("JeniHeroSerif-Italic", size: 14))
        + Text("")
            .font(.custom("DMSans-Medium", size: 11)))
            .foregroundStyle(FoodTheme.accent.opacity(0.85))
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder private var dishTitle: some View {
        let text = dishTitleText
        if !text.isEmpty {
            Button {
                guard let first = session.effectiveItems.first else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingItemID = first.id
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(text)
                        .font(.custom("JeniHeroSerif-Italic", size: 23))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FoodTheme.accent.opacity(0.6))
                        .baselineOffset(2)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .disabled(session.effectiveItems.isEmpty)
            .accessibilityLabel("\(text), tap to edit")
        }
    }

    private var dishTitleText: String {
        let name = dishName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name.lowercased() }
        return session.effectiveItems.prefix(2)
            .map { $0.name.lowercased() }
            .joined(separator: ", ")
    }

    // MARK: - Hero (kcal + protein co-hero)

    @ViewBuilder private var heroBlock: some View {
        let totals = session.totals
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                CountUpNumber(
                    target: displayKcal(totals),
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 54,
                    color: FoodTheme.textPrimary
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text("calories")
                        .font(.custom("JeniHeroSerif-Italic", size: 19))
                        .foregroundStyle(FoodTheme.textSecondary)
                    if let range = kcalRangeLabel {
                        Text(range)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundStyle(FoodTheme.textPrimary.opacity(0.45))
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)

            // v23 §5 — the reading order: PROTEIN leads (the one
            // nutrient with a collected floor), THE SPLIT states what
            // the plate's energy was made of, THE LEDGER carries the
            // rest as hairline rows. Uncollected fields stay silent
            // (§1.6); no bars without a denominator (D2).
            proteinCard(totals)
                .padding(.top, 8)

            plateSplitBar(totals)
                .padding(.top, 9)

            chemistryLedger
                .padding(.top, 5)

            // THE DAY LINE — what this plate does to today. Same
            // provenance as Home's kcal bar (app-injected target +
            // eaten-so-far); suppressed cohorts and target-less users
            // never see it. Over is words, never red.
            if let day = dayLine(totals) {
                (Text(day.prefix)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(FoodTheme.textSecondary)
                + Text(day.punch)
                    .font(.custom("JeniHeroSerif-Italic", size: 15))
                    .foregroundColor(FoodTheme.textPrimary)
                + Text(day.suffix)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(FoodTheme.textSecondary))
                    .padding(.top, 3)
                    .accessibilityLabel("\(day.prefix)\(day.punch)\(day.suffix)")
            }
        }
    }

    /// "carbs 45 · fat 17 · fiber 7" — grams, nonzero components only.
    private func chemistryLine(_ totals: PlateTotals) -> String? {
        var parts: [String] = []
        if totals.carbs >= 1 { parts.append("carbs \(Int(totals.carbs.rounded()))g") }
        if totals.fat >= 1 { parts.append("fat \(Int(totals.fat.rounded()))g") }
        if totals.fiber >= 1 { parts.append("fiber \(Int(totals.fiber.rounded()))g") }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  \u{00B7}  ")
    }

    /// One sentence answering "and my day?" — room left after this
    /// plate, in Home's own voice. nil when there is no honest number
    /// to speak (no target, suppressed cohort, no provider).
    private func dayLine(_ totals: PlateTotals) -> (prefix: String, punch: String, suffix: String)? {
        guard
            let ctx = FoodModule.dayContextProvider?(),
            let target = ctx.kcalTarget, target > 0
        else { return nil }
        let after = ctx.kcalEatenToday + displayKcal(totals)
        let room = target - after
        if room >= 150 {
            // Nearest 50 — "about 600", never "612".
            let rounded = (room / 50) * 50
            return ("room for ", "about \(rounded)", " in your day after this")
        }
        if room >= -60 {
            // Under ~150 the honest read isn't a number, it's "you've
            // arrived" — a 50-kcal remainder is not an invitation.
            return ("this lands today ", "right around", " your target")
        }
        return ("a little ", "over", " today \u{00B7} tomorrow resets")
    }

    private func displayKcal(_ totals: PlateTotals) -> Int {
        let raw: Double = totals.kcal > 0
            ? totals.kcal
            : ((initialFood.kcalLow ?? 0) + (initialFood.kcalHigh ?? 0)) / 2
        // Round to the nearest 5 — precision theater is dishonest at
        // ±15-20% model accuracy; the range label carries the truth.
        return Int((raw / 5).rounded()) * 5
    }

    private var kcalRangeLabel: String? {
        let food = session.rebuiltFood()
        guard let lo = food.kcalLow, let hi = food.kcalHigh, hi > lo else { return nil }
        let band = Int(((hi - lo) / 2).rounded())
        guard band >= 20 else { return nil }
        return "\u{00B1} \(band)"
    }

    @ViewBuilder private func adequacyStamp(protein: Int) -> some View {
        let word: (prefix: String, italic: String) = {
            switch protein {
            case 30...: return isGlp1Cohort ? ("muscle ", "stays") : ("hits ", "enough")
            case 20..<30: return isGlp1Cohort ? ("", "steady") : ("", "solid")
            case 10..<20: return ("a ", "start")
            default: return ("", "light")
            }
        }()
        let strong = protein >= 30
        HStack(spacing: 5) {
            if strong {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(stateGood)
            }
            (Text(word.prefix)
                .font(.custom("DMSans-Regular", size: 12))
            + Text(word.italic)
                .font(.custom("JeniHeroSerif-Italic", size: 14)))
                .foregroundStyle(strong ? stateGood : FoodTheme.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(
                (strong ? stateGood : FoodTheme.textSecondary)
                    .opacity(strong ? 0.13 : 0.09)
            )
        )
    }

    // v23 — the emphasis is the ramp's berry (the deprecated
    // stateGood alias retired from this surface).
    private var stateGood: Color { FoodTheme.roseBerry }

    /// v23 §5.6 — THE LEDGER: the five target-less nutrients as
    /// hairline rows (ledgers may rule lines; a stat-card grid was
    /// Cal AI's voice, E4). Numbers count to new values on edit.
    @ViewBuilder private var chemistryLedger: some View {
        let items = session.rebuiltFood().items
        let totals = session.totals
        let sugar = items.compactMap { $0.sugarG }.reduce(0, +)
        let sodium = items.compactMap { $0.sodiumMg }.reduce(0, +)
        let rows: [(String, String)] = [
            ("carbs", totals.carbs >= 1 ? "\(Int(totals.carbs.rounded()))g" : ""),
            ("fat", totals.fat >= 1 ? "\(Int(totals.fat.rounded()))g" : ""),
            ("fiber", totals.fiber >= 1 ? "\(Int(totals.fiber.rounded()))g" : ""),
            ("sugar intake", sugar >= 1 ? "\(Int(sugar.rounded()))g" : ""),
            ("sodium", sodium >= 1 ? "\(Int(sodium.rounded()).formatted())mg" : ""),
        ].filter { !$0.1.isEmpty }

        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.0) { idx, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(FoodTheme.textSecondary)
                        Spacer(minLength: 8)
                        Text(row.1)
                            .font(.custom("DMSans-SemiBold", size: 15))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(FoodTheme.textPrimary)
                    }
                    .padding(.vertical, 8)
                    if idx < rows.count - 1 {
                        Rectangle()
                            .fill(FoodTheme.textPrimary.opacity(0.07))
                            .frame(height: 0.5)
                    }
                }
            }
            .animation(.easeOut(duration: 0.4), value: rows.map(\.1))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func proteinCard(_ totals: PlateTotals) -> some View {
        let grams = Int(totals.protein.rounded())
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROTEIN")
                    .font(.custom("DMSans-Regular", size: 9.5))
                    .kerning(0.9)
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(grams)")
                        .font(.custom("DMSans-SemiBold", size: 20))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.45), value: grams)
                        .foregroundStyle(FoodTheme.textPrimary)
                    Text("g")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
            }
            if let target = FoodModule.proteinTargetProvider?(), target > 0 {
                proteinFloorBar(plateG: totals.protein, targetG: Double(target))
            }
            adequacyStamp(protein: grams)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }

    /// v22 — how far this plate carries the day's protein floor:
    /// blush track, rose fill, berry once the plate alone lands 100%.
    @ViewBuilder
    private func proteinFloorBar(plateG: Double, targetG: Double) -> some View {
        let fraction = min(1, max(0, plateG / targetG))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FoodTheme.accent.opacity(0.16)).frame(height: 5)
                Capsule()
                    .fill(fraction >= 1 ? FoodTheme.roseBerry : FoodTheme.accent)
                    .frame(width: max(5, geo.size.width * fraction), height: 5)
                    .animation(.easeOut(duration: 0.45), value: fraction)
            }
        }
        .frame(height: 5)
        .accessibilityLabel(
            "this plate covers \(Int((fraction * 100).rounded())) percent of your protein floor"
        )
    }

    /// v22 — the split: protein berry, carbs rose, fat blush (D11's
    /// depths: emphasis follows the floor, never judgment).
    @ViewBuilder
    private func plateSplitBar(_ totals: PlateTotals) -> some View {
        let p = totals.protein * 4, c = totals.carbs * 4, f = totals.fat * 9
        let total = p + c + f
        if total > 0 {
            GeometryReader { geo in
                let gap: CGFloat = 2
                let usable = max(0, geo.size.width - gap * 2)
                HStack(spacing: gap) {
                    Capsule().fill(FoodTheme.roseBerry)
                        .frame(width: max(0, usable * p / total))
                    Capsule().fill(FoodTheme.accent)
                        .frame(width: max(0, usable * c / total))
                    Capsule().fill(FoodTheme.roseBlush)
                        .frame(width: max(0, usable * f / total))
                }
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(height: 6)
            .accessibilityHidden(true)   // the chemistry line speaks
        }
    }

    private var isGlp1Cohort: Bool {
        let n = glp1Status.lowercased()
        return n.contains("current") || n.contains("on_glp1") || n == "on"
            || n == "post" || n.contains("triedoff") || n.contains("tried_off")
    }

    // MARK: - Fraction chips ("how much of it")

    private static let fractions: [(label: String, punch: String, value: Double)] = [
        ("all of ", "it", 1.0),
        ("about ", "\u{00BE}", 0.75),
        ("about ", "half", 0.5),
        ("a few ", "bites", 0.25),
    ]

    @ViewBuilder private var fractionChips: some View {
        HStack(spacing: 7) {
            ForEach(Self.fractions, id: \.value) { f in
                fractionChip(f)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func fractionChip(_ f: (label: String, punch: String, value: Double)) -> some View {
        let isOn = abs(session.fraction - f.value) < 0.01
        Button {
            guard !isOn else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            commit { $0.setFraction(f.value) }
        } label: {
            (Text(f.label)
                .font(.custom("DMSans-Medium", size: 12))
            + Text(f.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 13)))
                .foregroundStyle(isOn ? FoodTheme.bgPrimary : FoodTheme.textPrimary.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .frame(height: 33)
                .background(
                    Capsule().fill(isOn ? FoodTheme.textPrimary : Color.white.opacity(0.55))
                )
                .overlay(
                    Capsule().stroke(
                        FoodTheme.textPrimary.opacity(isOn ? 0 : 0.12),
                        lineWidth: 0.75
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.22), value: isOn)
        .accessibilityLabel("ate \(f.label)\(f.punch)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Ledger

    @ViewBuilder private var ledger: some View {
        let items = session.effectiveItems
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("on your plate")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .kerning(0.3)
                Spacer()
                if session.totals.grams > 0 {
                    Text("\(Int(session.totals.grams.rounded()))g")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(FoodTheme.textPrimary.opacity(0.40))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: Int(session.totals.grams.rounded()))
                }
            }
            .padding(.bottom, 4)

            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                ledgerRow(item)
                if idx < items.count - 1 {
                    Rectangle()
                        .fill(FoodTheme.textPrimary.opacity(0.07))
                        .frame(height: 0.5)
                }
            }
        }
    }

    @ViewBuilder private func ledgerRow(_ item: CapturedItem) -> some View {
        let edited = session.isEdited(item.id)
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    editingItemID = item.id
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.name.lowercased())
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(FoodTheme.textPrimary)
                            .lineLimit(1)
                        if let gloss = item.englishName?.lowercased() {
                            Text(gloss)
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundStyle(FoodTheme.textSecondary.opacity(0.8))
                                .lineLimit(1)
                        }
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FoodTheme.textPrimary.opacity(0.28))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name), tap to edit")

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    if edited {
                        Circle()
                            .fill(FoodTheme.accent.opacity(0.8))
                            .frame(width: 4.5, height: 4.5)
                            .accessibilityLabel("edited by you")
                    }
                    Text("\(Int((item.kcal ?? 0).rounded())) cal")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(FoodTheme.textPrimary.opacity(0.75))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: Int((item.kcal ?? 0).rounded()))
                }
            }

            portionStepper(item)
        }
        .padding(.vertical, 9)
    }

    /// Inline − grams + stepper: the zero-navigation portion fix. Ticks
    /// move over the quarter-of-the-scan grid in PlateEditSession.
    @ViewBuilder private func portionStepper(_ item: CapturedItem) -> some View {
        HStack(spacing: 0) {
            stepperButton("minus", enabled: session.canStepPortion(item.id, up: false)) {
                commit { $0.stepPortion(item.id, up: false) }
            }
            Text("\(Int(item.portionGrams.rounded()))g")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundStyle(FoodTheme.textPrimary.opacity(0.80))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.32), value: Int(item.portionGrams.rounded()))
                .frame(minWidth: 56)
            stepperButton("plus", enabled: session.canStepPortion(item.id, up: true)) {
                commit { $0.stepPortion(item.id, up: true) }
            }
        }
        .background(Capsule().fill(Color.white.opacity(0.55)))
        .overlay(Capsule().stroke(FoodTheme.textPrimary.opacity(0.10), lineWidth: 0.75))
    }

    @ViewBuilder
    private func stepperButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary.opacity(enabled ? 0.70 : 0.22))
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "more" : "less")
    }

    // MARK: - Composer (fix it with words · + add something)

    @ViewBuilder private var composerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if refining {
                refiningLine
            } else if let composer {
                composerField(composer)
            } else {
                composerTriggers
            }
            if let line = refineErrorLine, !refining {
                (Text(line)
                    .font(.custom("DMSans-Regular", size: 12))
                + Text("")
                    .font(.custom("DMSans-Regular", size: 11)))
                    .foregroundStyle(FoodTheme.accent.opacity(0.85))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.24), value: refining)
        .animation(.easeOut(duration: 0.24), value: composer != nil)
    }

    /// The two quiet trigger rows, side by side: additions on the
    /// left (a ledger continuation), corrections on the right.
    @ViewBuilder private var composerTriggers: some View {
        HStack(alignment: .firstTextBaseline) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openComposer(.addItem)
            } label: {
                (Text("+ add ")
                    .font(.custom("DMSans-Medium", size: 13))
                + Text("something")
                    .font(.custom("JeniHeroSerif-Italic", size: 14)))
                    .foregroundStyle(FoodTheme.textPrimary.opacity(0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("add something to this plate")

            Spacer(minLength: 12)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openComposer(.fixWords)
            } label: {
                (Text("off? ")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(FoodTheme.textSecondary)
                + Text("fix it with ")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(FoodTheme.accent)
                + Text("words")
                    .font(.custom("JeniHeroSerif-Italic", size: 14))
                    .foregroundColor(FoodTheme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("fix the estimate with words")
        }
        .padding(.vertical, 2)
    }

    private func openComposer(_ mode: Composer) {
        refineErrorLine = nil
        composerText = ""
        withAnimation(.easeOut(duration: 0.24)) { composer = mode }
        // Focus after the field mounts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            composerFocused = true
        }
    }

    @ViewBuilder private func composerField(_ mode: Composer) -> some View {
        let placeholder = mode == .addItem
            ? "a splash of olive oil, a side of kimchi…"
            : "tell jeni what's off…"
        HStack(spacing: 8) {
            TextField(placeholder, text: $composerText, axis: .vertical)
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundStyle(FoodTheme.textPrimary)
                .lineLimit(1...3)
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit { submitComposer(mode) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FoodTheme.accent.opacity(0.35), lineWidth: 0.75)
                )

            Button {
                submitComposer(mode)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            composerText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? FoodTheme.textPrimary.opacity(0.25)
                                : FoodTheme.textPrimary
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(composerText.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("send")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                composerFocused = false
                withAnimation(.easeOut(duration: 0.2)) {
                    composer = nil
                    refineErrorLine = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.8))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("cancel")
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// The in-flight line — italic serif with a slow breathe, no
    /// spinner (progress theater reads clinical against this card).
    @ViewBuilder private var refiningLine: some View {
        let phrase = composer == .addItem
            ? (lead: "adding it ", punch: "in", tail: "…")
            : (lead: "rereading your ", punch: "plate", tail: "…")
        RefiningBreatheText(lead: phrase.lead, punch: phrase.punch, tail: phrase.tail)
            .padding(.vertical, 4)
    }

    private func submitComposer(_ mode: Composer) {
        let note = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, let refine, !refining else { return }
        composerFocused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.24)) {
            refining = true
            refineErrorLine = nil
        }
        let request: SnapRefineRequest = mode == .addItem
            ? .addItem(note: note)
            : .fixWords(current: session.rebuiltFood(), note: note)
        Task { @MainActor in
            do {
                let outcome = try await refine(request)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeOut(duration: 0.4)) {
                    switch outcome {
                    case .rebased(let food):
                        session.rebase(on: food)
                    case .added(let items):
                        session.append(items)
                    }
                    refining = false
                    composer = nil
                    composerText = ""
                }
                onEdited(session.rebuiltFood())
            } catch {
                withAnimation(.easeOut(duration: 0.24)) {
                    refining = false
                    refineErrorLine = "didn't catch that. one more try?"
                }
            }
        }
    }

    // MARK: - Jeni section

    private var detailCopy: ResultDetailCopy {
        ResultDetailCopy(
            food: session.rebuiltFood(),
            ctx: ResultDetailContext(
                proteinTargetG: proteinTargetG,
                todayLoggedProtein: Int(
                    (userId.isEmpty
                        ? FoodLogPersister.todayMacros()
                        : FoodLogPersister.todayMacros(userId: userId)
                    ).protein.rounded()
                ),
                // v5.1 — the canonical target (TargetsService via the
                // day-context provider) so the note's day-fit speaks
                // the same number as Home's kcal bar; the legacy
                // AppStorage value only backstops provider-less runs
                // (previews, package tests).
                kcalTarget: FoodModule.dayContextProvider?()?.kcalTarget
                    ?? Int(foodDailyTarget),
                isGlp1: isGlp1Cohort,
                hour: Calendar.current.component(.hour, from: loggedAt)
            )
        )
    }

    private var proteinTargetG: Int {
        // App v2: the app injects the canonical target (TargetsService,
        // 1.2/1.6 g/kg by cohort) so this number matches Today +
        // Becoming exactly. Package-local fallback only when the
        // provider is absent (previews, package tests).
        if let provided = FoodModule.proteinTargetProvider?() {
            return provided
        }
        let kg = currentWeightKg
        let raw = kg > 30 ? 1.2 * kg : 0
        return max(70, min(130, Int(raw.rounded())))
    }

    /// v23 §5.9 — the note came home to the page: the reading closes
    /// in jeni's voice, quiet, at the end of the scroll. The sparkle
    /// theater retired with the carousel — restraint is the note.
    @ViewBuilder private var noteBlock: some View {
        let copy = detailCopy
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT JENI NOTICED")
                .font(.custom("DMSans-Medium", size: 10.5))
                .kerning(1.2)
                .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
                .padding(.top, 2)

            jeniNoteText(copy.jeniNote)

            dayFitText(copy.dayFit)

            if let proteinRow = copy.details.first(where: { $0.progress != nil }) {
                proteinTodayRow(proteinRow)
                    .padding(.top, 2)
            }

            if let p = copy.provenance {
                Text(p)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
            }
        }
        .padding(.bottom, 6)
    }

    private func jeniNoteText(_ n: PunchLine) -> some View {
        (Text(n.prefix)
            .font(.custom("JeniHeroSerif-Regular", size: 19))
        + Text(n.punch)
            .font(.custom("JeniHeroSerif-Italic", size: 19))
        + Text(n.suffix)
            .font(.custom("JeniHeroSerif-Regular", size: 19)))
            .foregroundStyle(FoodTheme.textPrimary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dayFitText(_ l: PunchLine) -> some View {
        (Text(l.prefix)
            .font(.custom("DMSans-Regular", size: 13))
        + Text(l.punch)
            .font(.custom("JeniHeroSerif-Italic", size: 14))
        + Text(l.suffix)
            .font(.custom("DMSans-Regular", size: 13)))
            .foregroundStyle(FoodTheme.textSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func proteinTodayRow(_ row: DetailRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.label)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer(minLength: 8)
                Text(row.value)
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
            }
            if let p = row.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FoodTheme.accentSubtle)
                        Capsule()
                            .fill(p >= 1 ? FoodTheme.roseBerry : FoodTheme.accent)
                            .frame(width: max(4, geo.size.width * min(1, p)))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    // MARK: - Footer (retake · log it · share)

    @ViewBuilder private var footer: some View {
        HStack(spacing: 12) {
            footerCircle("arrow.uturn.backward", label: "retake") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onRetake()
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLog(session.rebuiltFood())
            } label: {
                // v23 — the verb of the era: the idle caption taught
                // "add it before you eat"; the pill keeps the word.
                Text("add it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("add it")

            if allowsShare {
                footerCircle("square.and.arrow.up", label: "share") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    // The composer overlays the same steady photo.
                    withAnimation(.easeOut(duration: 0.3)) { page = 2 }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            // A soft paper fade so scrolled content dissolves under
            // the footer instead of shearing against it (token paper,
            // not a bespoke cream).
            LinearGradient(
                colors: [FoodTheme.bgPrimary.opacity(0), FoodTheme.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.top, -30)
            .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func footerCircle(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary.opacity(0.8))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.65)))
                .overlay(Circle().stroke(FoodTheme.textPrimary.opacity(0.12), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Cascade

    private func runCascade() {
        if reduceMotion { revealed = 6; return }
        revealed = 0
        for i in 0...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07 * Double(i)) {
                withAnimation(.easeOut(duration: 0.42)) { revealed = max(revealed, i) }
            }
        }
    }
}

// MARK: - Cascade modifier

private extension View {
    func cascade(_ step: Int, _ revealed: Int) -> some View {
        modifier(SnapCascadeStep(step: step, revealed: revealed))
    }
}

private struct SnapCascadeStep: ViewModifier {
    let step: Int
    let revealed: Int
    func body(content: Content) -> some View {
        content
            .opacity(revealed >= step ? 1 : 0)
            .offset(y: revealed >= step ? 0 : 10)
    }
}

// MARK: - RefiningBreatheText
//
// The composer's in-flight state: an italic-punch serif line that
// breathes (opacity 0.55 ↔ 1.0) while the correction round-trips.
// Reduce-motion holds it steady.

private struct RefiningBreatheText: View {
    let lead: String
    let punch: String
    let tail: String

    @State private var bright = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        (Text(lead)
            .font(.custom("JeniHeroSerif-Regular", size: 16))
        + Text(punch)
            .font(.custom("JeniHeroSerif-Italic", size: 16))
        + Text(tail)
            .font(.custom("JeniHeroSerif-Regular", size: 16)))
            .foregroundStyle(FoodTheme.textPrimary.opacity(bright ? 1.0 : 0.55))
            .onAppear {
                guard !reduceMotion else { bright = true; return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
            .accessibilityLabel("working on it")
    }
}

#endif
