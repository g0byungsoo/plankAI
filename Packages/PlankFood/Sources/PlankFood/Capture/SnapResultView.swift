#if canImport(UIKit)
import SwiftUI

// MARK: - SnapResultView
//
// v1.2 snap-food rebuild (2026-07-01) — the editorial result panel that
// rises over the full-bleed captured photo, restructured (2026-07-02,
// founder call) as a 3-slide carousel: the swipe vocabulary of the
// v1.1.2 NutritionCarousel kept, the panel design language new.
//
//   slide 1 — the plate: kcal hero (count-up roll) + protein co-hero +
//             honest ± range, fraction chips (all · ¾ · half · bites),
//             ingredient ledger with portion steppers, tap-through
//             deep editor, "fix it with words" / "+ add something"
//   slide 2 — a note from jeni: the anti-shame copy engine gets its
//             own breathing room + a sparkle accent
//   slide 3 — share: the on-photo composer (SnapShareSlide) slides in
//             over the SAME steady photo; what she sees is the PNG
//
// Slides 1-2 share the two-detent panel chrome (peek shows the
// verdict, a pull expands the working room); slide 3 goes full-bleed.
// The photo never moves — surfaces carousel over it. White dots ride
// the top, host chrome (close vs back/share) swaps on the binding.
//
// All mutation routes through PlateEditSession (SnapResultMath.swift);
// this file is presentation + choreography only.

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

    public init(
        userId: String = "",
        food: CapturedFood,
        mealLabel: String,
        dishName: String,
        page: Binding<Int>,
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

            ZStack(alignment: .top) {
                TabView(selection: $page) {
                    panelSlide(liveHeight: liveHeight, peek: peekHeight, full: fullHeight) {
                        platePage
                    }
                    .tag(0)

                    panelSlide(liveHeight: liveHeight, peek: peekHeight, full: fullHeight) {
                        notePage
                    }
                    .tag(1)

                    shareSlide
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                slideDots
            }
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

    /// Slide 1 — the working page: verdict + every correction lever.
    @ViewBuilder private var platePage: some View {
        heroBlock.cascade(1, revealed)
        fractionChips.cascade(2, revealed)
        hairline.cascade(3, revealed)
        ledger.cascade(3, revealed)
        if refine != nil {
            composerBlock.cascade(4, revealed)
        }
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

    /// TikTok-register dots, floating on the photo above the panel.
    /// Tappable — a dot tap pages the carousel like a swipe would.
    private var slideDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    guard page != i else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeOut(duration: 0.3)) { page = i }
                } label: {
                    Circle()
                        .fill(.white.opacity(page == i ? 0.95 : 0.38))
                        .frame(width: 6.5, height: 6.5)
                        .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(["your plate", "a note from jeni", "share it"][i])
                .accessibilityAddTraits(page == i ? .isSelected : [])
            }
        }
        .shadow(color: .black.opacity(0.30), radius: 5, y: 1)
        .padding(.top, 20)
        .animation(.easeOut(duration: 0.25), value: page)
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
        UnevenRoundedRectangle(
            topLeadingRadius: 28, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 28,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.985, blue: 0.976),
                    Color(red: 0.992, green: 0.965, blue: 0.955),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.65), lineWidth: 0.75)
            .blendMode(.plusLighter)
        }
        .shadow(
            color: Color(red: 0.20, green: 0.10, blue: 0.09).opacity(0.22),
            radius: 26, x: 0, y: -10
        )
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
        + Text(" \u{2661}")
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

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                (Text("\(Int(totals.protein.rounded()))")
                    .font(.custom("JeniHeroSerif-Regular", size: 30))
                    .foregroundColor(FoodTheme.textPrimary)
                + Text("g")
                    .font(.custom("JeniHeroSerif-Italic", size: 15))
                    .foregroundColor(FoodTheme.accent))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.45), value: Int(totals.protein.rounded()))
                Text("protein")
                    .font(.custom("JeniHeroSerif-Italic", size: 17))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer(minLength: 8)
                adequacyStamp(protein: Int(totals.protein.rounded()))
            }

            // The rest of the chemistry, one quiet line (carbs/fat/
            // fiber ride the pipeline since Phase T; only protein had
            // a face). Zeros stay silent; an all-zero plate says
            // nothing.
            if let chemistry = chemistryLine(totals) {
                Text(chemistry)
                    .font(.custom("DMSans-Regular", size: 12.5))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.9))
                    .monospacedDigit()
                    .padding(.top, 1)
            }

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

    private var stateGood: Color { FoodTheme.stateGood }

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
                + Text(" \u{2661}")
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

    /// Slide 2 — the note gets its own breathing room (founder call:
    /// the anti-shame beat deserves a slide, not a footnote under the
    /// ledger). Bigger serif, a sparkle accent in the Sparkling-lottie
    /// motion language, nothing to edit.
    @ViewBuilder private var notePage: some View {
        let copy = detailCopy
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("a note from jeni")
                .font(.custom("JeniHeroSerif-Italic", size: 22))
                .foregroundStyle(FoodTheme.accent)
            NoteSparkles()
                .offset(y: -4)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)

        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(FoodTheme.accent.opacity(0.8))
                .frame(width: 2)
            jeniNoteText(copy.jeniNote)
        }

        dayFitText(copy.dayFit)

        if let proteinRow = copy.details.first(where: { $0.progress != nil }) {
            proteinTodayRow(proteinRow)
                .padding(.top, 4)
        }

        if let p = copy.provenance {
            Text(p)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
        }
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
                        Capsule().fill(FoodTheme.textPrimary.opacity(0.08))
                        Capsule()
                            .fill(FoodTheme.stateGood.opacity(0.8))
                            .frame(width: max(4, geo.size.width * p))
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
                Text("log it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("log it")

            footerCircle("square.and.arrow.up", label: "share") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // The share composer is the carousel's third slide —
                // the button rides you there, spatially.
                withAnimation(.easeOut(duration: 0.3)) { page = 2 }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            // A soft cream fade so scrolled content dissolves under the
            // footer instead of shearing against it. Tall enough (30pt
            // above the footer) that a row cut mid-glyph at the peek
            // fold melts away rather than slicing.
            LinearGradient(
                colors: [
                    Color(red: 0.992, green: 0.965, blue: 0.955).opacity(0),
                    Color(red: 0.992, green: 0.965, blue: 0.955),
                ],
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

// MARK: - NoteSparkles
//
// The note slide's accent, in the motion language of the founder's
// Sparkling.json lottie (which plays app-side on result land): concave
// four-point stars that pop 0 → 100 → 0 with an ease-in-out, staggered.
// Re-drawn natively here so the SPM package stays dependency-free and
// the fill honors the locked rose token at any size. Reduce-motion
// holds a static, faded cluster.

private struct NoteSparkles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            star(size: 17, delay: 0.0, tilt: -14, dx: 1, dy: 2, opacity: 0.95)
            star(size: 9, delay: 0.85, tilt: 12, dx: -14, dy: -7, opacity: 0.65)
            star(size: 11, delay: 1.7, tilt: 24, dx: 14, dy: -5, opacity: 0.78)
        }
        .frame(width: 44, height: 28)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func star(
        size: CGFloat, delay: Double, tilt: Double,
        dx: CGFloat, dy: CGFloat, opacity: Double
    ) -> some View {
        let glyph = SparkleGlyph()
            .fill(FoodTheme.accent.opacity(opacity))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(tilt))
            .offset(x: dx, y: dy)
        if reduceMotion {
            glyph.scaleEffect(0.85).opacity(0.8)
        } else {
            // The lottie's per-star pop (0→100→0, easy-ease) softened
            // for an ambient surface: stars breathe 30 ↔ 100 on a
            // staggered 2.6s round, so the cluster is always present
            // and always alive — twinkle, not strobe.
            KeyframeAnimator(initialValue: 0.3, repeating: true) { value in
                glyph.scaleEffect(value)
            } keyframes: { _ in
                CubicKeyframe(0.3, duration: max(0.01, delay))
                CubicKeyframe(1.0, duration: 0.45)
                CubicKeyframe(0.3, duration: 0.55)
                CubicKeyframe(0.3, duration: max(0.01, 2.6 - delay - 1.0))
            }
        }
    }
}

/// Concave-edged four-point star — the Sparkling.json polystar
/// silhouette (inner/outer radius ratio ~0.22 with heavy inner
/// smoothing reads as quad curves pulled to the diagonals).
private struct SparkleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let inner = r * 0.22
        let tips = (0..<4).map { i -> CGPoint in
            let a = CGFloat(i) * .pi / 2 - .pi / 2
            return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        }
        let controls = (0..<4).map { i -> CGPoint in
            let a = CGFloat(i) * .pi / 2 - .pi / 4
            return CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner)
        }
        var p = Path()
        p.move(to: tips[0])
        for i in 0..<4 {
            p.addQuadCurve(to: tips[(i + 1) % 4], control: controls[i])
        }
        p.closeSubpath()
        return p
    }
}
#endif
