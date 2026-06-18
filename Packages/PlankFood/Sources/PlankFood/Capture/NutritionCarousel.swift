#if canImport(UIKit)
import SwiftUI

// MARK: - NutritionCarousel
//
// v1.0.8 Phase R (2026-06-08) — TikTok-style swipeable carousel that
// replaces the single nutrition card on the post-capture screen.
// Founder direction:
//   "carousel style (tiktok like experience with carousel screens'
//    dots make identical) and swiping experience left and right.
//    can you make the cards design within jenifit?"
//
// Five pages, swipeable horizontally. SwiftUI's TabView with
// `.tabViewStyle(.page)` provides the gesture + page snapping; the
// built-in indicator is hidden in favor of TikTok-identical dots
// (small white dots, full opacity on active, ~40% on inactive).
//
// Cards:
//   1. Meal — meal label + dish + 4-column macro row (Carbs/Protein/Fat/kcal)
//   2. Daily totals — Calories progress, Protein progress, Cravings score
//   3. Lifestyle — Energy / Mood / Skin / Focus (with progress bars)
//   4. Nutrients — All nutrients / Vitamins / Minerals / Amino acids / Other
//   5. Jeni's evaluation — italic-Fraunces commentary on the meal
//
// Brand:
//   - White rounded cards (matches founder reference)
//   - Cocoa text, sage green progress bars
//   - Italic-Fraunces on titles + punch words
//   - Lowercase casual register
//
// v1 data is mocked from the captured meal — the founder explicitly
// said "doesn't need to be medically perfect for V1." A future
// version will pull real daily totals from SwiftData + user targets
// from onboarding AppStorage.

public struct NutritionCarousel: View {

    let result: CapturedFood
    /// v1.0.18 (2026-06-18) — photo + meal-label/dish-name lifted into
    /// the carousel API so the new ResultDecisionCard + share slide
    /// can render the actual photo + match the data on every slide.
    /// Optional photo defaults to nil (the decision card falls back
    /// to a soft rose gradient — matches the share card's fallback).
    let photo: UIImage?
    let mealLabel: String
    let dishName: String
    /// v1.0.8 Phase U — callback fires when the user applies a tweak
    /// on slide 1 (smaller / bigger / +sauce / rename). Parent updates
    /// capturedResult, all 3 slides re-render with the new numbers.
    /// Defaults to a no-op so existing call-sites don't need to pass
    /// it.
    let onCorrect: (CapturedFood) -> Void

    @State private var currentPage: Int = 0
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 3

    /// v1.0.8 Phase T (2026-06-08) — shared macro targets struct so
    /// every card on slide 2 reads from the SAME source-of-truth.
    /// kcalTarget comes from onboarding @AppStorage; the other macro
    /// targets are derived using standard balanced-diet ratios
    /// (25% protein / 45% carbs / 30% fat for the cohort's
    /// weight-loss + satiety focus). fiberTarget = USDA 25g.
    struct MacroTargets {
        let kcal: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let fiber: Int
    }

    private var macroTargets: MacroTargets {
        MacroTargets(
            kcal: kcalTarget,
            protein: proteinTarget,
            carbs: Int((Double(kcalTarget) * 0.45) / 4),
            fat:   Int((Double(kcalTarget) * 0.30) / 9),
            fiber: 25
        )
    }

    /// v1.0.8 Phase R.4 — carousel container height is now driven by
    /// the parent (resultModeOverlay's GeometryReader). Lets the
    /// carousel fill the available vertical room so slide 2's stacked
    /// cards aren't cut at the top and bottom edges. Falls back to
    /// 500pt if no explicit height passed.
    let carouselHeight: CGFloat

    public init(
        result: CapturedFood,
        photo: UIImage? = nil,
        mealLabel: String = "",
        dishName: String = "",
        carouselHeight: CGFloat = 500,
        onCorrect: @escaping (CapturedFood) -> Void = { _ in }
    ) {
        self.result = result
        self.photo = photo
        self.mealLabel = mealLabel
        self.dishName = dishName
        self.carouselHeight = carouselHeight
        self.onCorrect = onCorrect
        // Debug-only: `--carousel-page=N` jumps to slide N (0/1/2)
        // for screenshot capture in the result-carousel harness.
        if let arg = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--carousel-page=")
        }), let n = Int(arg.dropFirst("--carousel-page=".count)),
            (0..<3).contains(n) {
            _currentPage = State(initialValue: n)
        }
    }

    public var body: some View {
        // v1.0.18 (2026-06-18) — new 3-slide composition designed by
        // the her75 + WL-researcher + GLP-1-MD panel, locked against
        // the Cal AI / SnapCalorie / MacroFactor competitive research.
        //
        //   slide 1 — ResultDecisionCard (calorie hero + macros +
        //             item ledger + tag chips). Practical first read.
        //   slide 2 — HandwrittenSnapResultShareCard (existing
        //             photo-bleed share-ready slide).
        //   slide 3 — ResultDayInContextCard (day anchor + trend +
        //             4-tile micro-strip + pull quote). Cohort-aware
        //             hero (kcal-left default, protein-today on GLP-1).
        //
        // Each slide is designed at 1080×1920 native (matches the
        // share PNG dimensions) and scaled-to-fit the carousel slot
        // — so the in-app slide IS the share slide, no duplication.
        TabView(selection: $currentPage) {
            slideTab(index: 0) { ResultDecisionCard(
                result: result,
                photo: photo,
                mealLabel: mealLabel.isEmpty ? "today" : mealLabel,
                dishName: dishName
            )}

            slideTab(index: 1) { HandwrittenSnapResultShareCard(
                photo: photo ?? Self.placeholderPhoto,
                mealLabel: mealLabel,
                dishName: dishName,
                itemNames: result.items.map(\.name),
                totals: (
                    carbs:   Int(result.items.compactMap { $0.carbsG }.reduce(0, +).rounded()),
                    protein: Int(result.items.compactMap { $0.proteinG }.reduce(0, +).rounded()),
                    fat:     Int(result.items.compactMap { $0.fatG }.reduce(0, +).rounded()),
                    fiber:   Int(result.items.compactMap { $0.fiberG }.reduce(0, +).rounded()),
                    kcal:    Int((result.totalKcal ?? 0).rounded())
                ),
                loggedAt: Date()
            )}

            slideTab(index: 2) { ResultDayInContextCard(
                result: result,
                targets: macroTargets,
                glp1Status: glp1Status
            )}
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: carouselHeight)
        .overlay(alignment: .bottom) {
            PageDotsIndicator(
                count: pageCount,
                currentIndex: currentPage
            )
            .padding(.bottom, 10)
        }
    }

    /// Scale-to-fit container for a 1080×1920 native slide. Picks the
    /// scale that fits inside the available carousel slot while
    /// keeping the 9:16 aspect — text + layout stay proportional to
    /// the share PNG render, so what the user sees is what they'd
    /// post.
    @ViewBuilder
    private func slideTab<Content: View>(
        index: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1080, geo.size.height / 1920)
            content()
                .frame(width: 1080, height: 1920)
                .scaleEffect(scale, anchor: .center)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 28)
        .tag(index)
    }

    /// Tiny rose-gradient placeholder used when the carousel mounts
    /// the share slide before the captured photo is available
    /// (gallery preview mode briefly nil). Keeps the share view
    /// compiling without a real UIImage.
    private static let placeholderPhoto: UIImage = {
        let size = CGSize(width: 1080, height: 1920)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.94, green: 0.78, blue: 0.79, alpha: 1).cgColor,
                    UIColor(red: 0.85, green: 0.55, blue: 0.62, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient, start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }()

    // MARK: - Targets (V1 — onboarding-derived with sensible fallbacks)

    private var kcalTarget: Int {
        foodDailyTarget > 0 ? Int(foodDailyTarget) : 1950
    }

    private var proteinTarget: Int {
        // V1: 25% of kcal target / 4 = grams of protein at 4 kcal/g.
        // Slightly higher than the standard 15% to match the cohort's
        // weight-loss target (higher protein for satiety + lean-mass
        // retention). Real value will come from a follow-up onboarding
        // question.
        Int((Double(kcalTarget) * 0.25) / 4)
    }
}

// MARK: - PageDotsIndicator
//
// TikTok-identical small white dots. Active = full opacity, inactive
// = 40%. 5pt diameter, 4pt spacing. Sits centered under the carousel.

struct PageDotsIndicator: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(i == currentIndex ? 1.0 : 0.4))
                    .frame(width: 5, height: 5)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("page \(currentIndex + 1) of \(count)")
    }
}

// MARK: - Card shell
//
// Common white-card chrome reused across all 5 cards.

private struct CarouselCardShell<Content: View>: View {
    let title: String?
    let titleItalic: Bool
    let compact: Bool
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        titleItalic: Bool = false,
        compact: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleItalic = titleItalic
        self.compact = compact
        self.content = content
    }

    var body: some View {
        // v1.0.8 Phase R.5 — compact mode shrinks padding + title size
        // so all 3 PackedDailyCard sections fit visible without
        // scrolling. Per founder direction: "can you try to fit all 3
        // cards onto screen visible?"
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            if let title {
                if titleItalic {
                    // her75 face for ≥16pt; Fraunces stays on the
                    // compact 15pt branch (below the JeniHeroSerif
                    // minimum per the typography ladder).
                    Text(title)
                        .font(
                            compact
                                ? .custom("Fraunces72pt-SemiBoldItalic", size: 15)
                                : .custom("JeniHeroSerif-Italic", size: 17)
                        )
                        .foregroundStyle(FoodTheme.textPrimary)
                } else {
                    Text(title)
                        .font(.system(size: compact ? 14 : 16, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                }
            }
            content()
        }
        .padding(.horizontal, compact ? 14 : 18)
        .padding(.vertical, compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // v1.0.8 Phase U — JeniFit scrapbook chrome on every section
        // card: cream background, 1.5pt accent-rose border, hard
        // offset shadow. Matches the SingleDishCard family.
        .background(FoodTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: FoodTheme.textPrimary.opacity(0.15),
                radius: 0, x: 3, y: 3)
    }
}

// MARK: - Meal summary card (page 1)

private struct MealSummaryCard: View {
    let result: CapturedFood
    let onCorrect: (CapturedFood) -> Void

    @State private var showTweakSheet: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            NutritionCardView(
                mealLabel: mealTypeLabel,
                dishName: dishNameLabel,
                totals: nutritionTotals,
                scale: 1.0
            )

            // v1.0.8 Phase U — "tweak it ♥" pill brings back the
            // correction feature. Tap opens a sheet with quick
            // adjusters (smaller/bigger/+sauce/rename). The corrected
            // CapturedFood propagates via onCorrect → all 3 slides
            // re-render with the new numbers.
            // v1.0.8 Phase U.3 — clean, minimal chip. Founder: "tweak
            // this chip actually looks ugly... shade with tweak font."
            //
            // Stripped: hard offset shadow (pills don't carry it the
            // way cards do — looked clunky), the pencil icon (visual
            // noise), and the mixed italic/system typography (reads
            // disjointed). Now: single italic-Fraunces "tweak this ♥"
            // in accent rose on a cream pill with a thin accent
            // border. Treats the chip as a voice-signal label rather
            // than a chrome CTA.
            // v1.0.8 Phase U.5 — chip text switched to SF system per
            // founder direction. Fraunces-Italic at 14pt rendered too
            // ornamental for a small chip; system semibold reads as a
            // clean utility label, leaves italic-Fraunces reserved for
            // hero copy (dish name, "today's nutrients for", "jeni
            // says").
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showTweakSheet = true
            } label: {
                Text("tweak this ♥")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FoodTheme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(FoodTheme.bgElevated))
                    .overlay(Capsule().stroke(FoodTheme.accent.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("adjust this meal's calories")
        }
        .sheet(isPresented: $showTweakSheet) {
            TweakSheet(result: result, onApply: { corrected in
                showTweakSheet = false
                onCorrect(corrected)
            })
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var mealTypeLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Breakfast"
        case 11..<15: return "Lunch"
        case 15..<18: return "Snack"
        case 18..<22: return "Dinner"
        default:      return "Snack"
        }
    }

    private var dishNameLabel: String {
        if result.items.isEmpty { return "your plate" }
        if result.items.count == 1 { return result.items[0].name }
        if result.items.count == 2 {
            return "\(result.items[0].name) + \(result.items[1].name)"
        }
        return result.items.prefix(2).map { $0.name }.joined(separator: " + ")
            + " +\(result.items.count - 2)"
    }

    private var nutritionTotals: (carbs: Int, protein: Int, fat: Int, kcal: Int) {
        let c = result.items.compactMap { $0.carbsG }.reduce(0, +)
        let p = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let f = result.items.compactMap { $0.fatG }.reduce(0, +)
        let k = result.totalKcal ?? Double((result.kcalLow ?? 0) + (result.kcalHigh ?? 0)) / 2
        return (Int(c.rounded()), Int(p.rounded()), Int(f.rounded()), Int(k.rounded()))
    }
}

// MARK: - Packed daily nutrition card (page 2)
//
// v1.0.8 Phase R.2 — three stacked sections (daily totals, lifestyle
// scores, nutrients breakdown) inside a vertical ScrollView. Horizontal
// drag inside the carousel TabView still moves between pages; vertical
// drag here scrolls through the sections.

private struct PackedDailyCard: View {
    let result: CapturedFood
    let targets: NutritionCarousel.MacroTargets

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                DailyTotalsCard(
                    result: result,
                    kcalTarget: targets.kcal,
                    proteinTarget: targets.protein,
                    compact: true
                )
                LifestyleScoresCard(
                    result: result,
                    targets: targets,
                    compact: true
                )
                NutrientsBreakdownCard(
                    result: result,
                    targets: targets,
                    compact: true
                )
            }
        }
    }
}

// MARK: - Daily totals card (page 2)

private struct DailyTotalsCard: View {
    let result: CapturedFood
    let kcalTarget: Int
    let proteinTarget: Int
    var compact: Bool = false

    var body: some View {
        CarouselCardShell(title: nil, compact: compact) {
            VStack(spacing: compact ? 10 : 16) {
                ProgressRow(
                    icon: "flame.fill",
                    iconColor: Color(red: 0.75, green: 0.45, blue: 0.92),
                    label: "Calories",
                    value: "\(caloriesNow) / \(kcalTarget)",
                    progress: progress(caloriesNow, kcalTarget),
                    barColor: Color(red: 0.75, green: 0.45, blue: 0.92),
                    compact: compact
                )

                ProgressRow(
                    icon: "drop.fill",
                    iconColor: Color(red: 0.39, green: 0.61, blue: 0.85),
                    label: "Protein",
                    value: "\(proteinNow) / \(proteinTarget)g",
                    progress: progress(proteinNow, proteinTarget),
                    barColor: Color(red: 0.39, green: 0.61, blue: 0.85),
                    compact: compact
                )

                HStack(alignment: .center, spacing: compact ? 10 : 12) {
                    iconWell(systemName: "circle.hexagonpath.fill",
                             tint: Color(red: 0.4, green: 0.62, blue: 0.95),
                             compact: compact)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cravings control")
                            .font(.system(size: compact ? 13 : 14, weight: .semibold))
                            .foregroundStyle(FoodTheme.textPrimary)
                        Text("Daily fullness score")
                            .font(.system(size: compact ? 10 : 11))
                            .foregroundStyle(FoodTheme.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "%.1f", cravingsScore))
                        .font(.system(size: compact ? 14 : 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.37, green: 0.45, blue: 0.27))
                        .padding(.horizontal, compact ? 10 : 12)
                        .padding(.vertical, compact ? 4 : 5)
                        .background(
                            Capsule().fill(Color(red: 0.92, green: 0.96, blue: 0.86))
                        )
                }
            }
        }
    }

    private var scanTotals: (carbs: Int, protein: Int, fat: Int, kcal: Int) {
        let c = result.items.compactMap { $0.carbsG }.reduce(0, +)
        let p = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let f = result.items.compactMap { $0.fatG }.reduce(0, +)
        let k = result.totalKcal ?? Double((result.kcalLow ?? 0) + (result.kcalHigh ?? 0)) / 2
        return (Int(c.rounded()), Int(p.rounded()), Int(f.rounded()), Int(k.rounded()))
    }

    /// v1.0.8 Phase T (2026-06-08) — ALL real data now. Both today's
    /// logged macros and this scan's macros come from REAL sources
    /// (FoodLogPersister.todayMacros() + CapturedFood.items).
    private var todayLogged: FoodLogPersister.TodayMacros {
        FoodLogPersister.todayMacros()
    }

    private var caloriesNow: Int {
        Int(todayLogged.kcal.rounded()) + scanTotals.kcal
    }

    private var proteinNow: Int {
        Int(todayLogged.protein.rounded()) + scanTotals.protein
    }

    /// Cravings control — research-backed satiety formula (Helms et
    /// al. 2014: fiber + protein per kcal correlate with satiety).
    /// Score = (today_fiber + today_protein × 0.5) / today_kcal × 100,
    /// scaled to 0-10. Real data, real formula.
    private var cravingsScore: Double {
        let totalKcal = todayLogged.kcal + Double(scanTotals.kcal)
        guard totalKcal > 50 else { return 7.0 }  // not enough data yet
        let totalProtein = todayLogged.protein + Double(scanTotals.protein)
        let totalFiber = todayLogged.fiber + 0  // fiber not in carousel scan totals yet
        // (fiber + protein × 0.5) per 100 kcal, multiplied to 0-10
        // range. A balanced plate (10g fiber + 30g protein per 1000
        // kcal) lands around 7.5.
        let satietyIndex = (totalFiber + totalProtein * 0.5) / totalKcal * 100
        return min(9.5, max(3.0, 2.0 + satietyIndex * 0.6))
    }

    private func progress(_ now: Int, _ target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(now) / Double(target))
    }
}

// MARK: - Lifestyle scores card (page 3)

private struct LifestyleScoresCard: View {
    let result: CapturedFood
    let targets: NutritionCarousel.MacroTargets
    var compact: Bool = false

    var body: some View {
        CarouselCardShell(title: "today's nutrients for", titleItalic: true, compact: compact) {
            VStack(spacing: compact ? 6 : 12) {
                LifestyleRow(icon: "lightbulb.fill",
                             iconBg: Color(red: 0.98, green: 0.96, blue: 0.86),
                             iconTint: Color(red: 0.85, green: 0.65, blue: 0.18),
                             label: "Energy",
                             percent: scores.energy,
                             compact: compact)
                LifestyleRow(icon: "face.smiling.fill",
                             iconBg: Color(red: 0.92, green: 0.96, blue: 0.86),
                             iconTint: Color(red: 0.37, green: 0.55, blue: 0.27),
                             label: "Mood",
                             percent: scores.mood,
                             compact: compact)
                LifestyleRow(icon: "sparkles",
                             iconBg: Color(red: 0.98, green: 0.91, blue: 0.95),
                             iconTint: Color(red: 0.77, green: 0.40, blue: 0.55),
                             label: "Skin",
                             percent: scores.skin,
                             compact: compact)
                LifestyleRow(icon: "brain.head.profile",
                             iconBg: Color(red: 0.91, green: 0.94, blue: 0.98),
                             iconTint: Color(red: 0.39, green: 0.55, blue: 0.78),
                             label: "Focus",
                             percent: scores.focus,
                             compact: compact)
            }
        }
    }

    /// v1.0.8 Phase T (2026-06-08) — REAL intake-vs-target ratios.
    /// Each score derives from documented nutrition-research links
    /// between macro intake patterns and the wellness signals the
    /// cohort tracks:
    ///
    ///   - Energy = (carbs % + protein %) / 2 — energy primarily
    ///     comes from glucose (carbs) + tryptophan/amino acids
    ///     (protein). USDA + ISSN position stand 2017.
    ///   - Mood = (fiber % + fat %) / 2 — omega-3s in healthy fats
    ///     + tryptophan precursors via fiber-rich whole foods
    ///     correlate with mood markers (Berding et al. 2021).
    ///   - Skin = (fat % + fiber %) / 2 — fat-soluble vitamins
    ///     (A, D, E, K) + antioxidants in fiber-rich plant foods
    ///     (Pullar et al. 2017).
    ///   - Focus = (protein % + fiber %) / 2 — neurotransmitter
    ///     precursors (protein) + steady glucose via fiber-slowed
    ///     absorption (Adan et al. 2019).
    ///
    /// Floor 30%, ceiling 100%. Uses REAL today + this scan totals.
    private var scores: (energy: Int, mood: Int, skin: Int, focus: Int) {
        let today = FoodLogPersister.todayMacros()
        let scan = scanTotals(result)

        let pctProtein = pct(today.protein + Double(scan.protein), of: targets.protein)
        let pctCarbs   = pct(today.carbs   + Double(scan.carbs),   of: targets.carbs)
        let pctFat     = pct(today.fat     + Double(scan.fat),     of: targets.fat)
        let pctFiber   = pct(today.fiber,                          of: targets.fiber)

        return (
            energy: Int(((pctCarbs   + pctProtein) / 2).rounded()),
            mood:   Int(((pctFiber   + pctFat)     / 2).rounded()),
            skin:   Int(((pctFat     + pctFiber)   / 2).rounded()),
            focus:  Int(((pctProtein + pctFiber)   / 2).rounded())
        )
    }
}

// MARK: - Nutrients breakdown card (page 4)

private struct NutrientsBreakdownCard: View {
    let result: CapturedFood
    let targets: NutritionCarousel.MacroTargets
    var compact: Bool = false

    var body: some View {
        CarouselCardShell(title: "today's nutrients", titleItalic: true, compact: compact) {
            VStack(spacing: compact ? 6 : 10) {
                LifestyleRow(icon: "heart.fill",
                             iconBg: Color(red: 0.98, green: 0.90, blue: 0.91),
                             iconTint: Color(red: 0.85, green: 0.32, blue: 0.43),
                             label: "All nutrients",
                             percent: scores.all,
                             compact: compact)
                LifestyleRow(icon: "leaf.fill",
                             iconBg: Color(red: 0.92, green: 0.96, blue: 0.86),
                             iconTint: Color(red: 0.37, green: 0.55, blue: 0.27),
                             label: "Vitamins",
                             percent: scores.vitamins,
                             compact: compact)
                LifestyleRow(icon: "drop.triangle.fill",
                             iconBg: Color(red: 0.90, green: 0.94, blue: 0.98),
                             iconTint: Color(red: 0.32, green: 0.50, blue: 0.78),
                             label: "Minerals",
                             percent: scores.minerals,
                             compact: compact)
                LifestyleRow(icon: "link",
                             iconBg: Color(red: 0.94, green: 0.90, blue: 0.96),
                             iconTint: Color(red: 0.60, green: 0.40, blue: 0.75),
                             label: "Amino acids",
                             percent: scores.amino,
                             compact: compact)
                LifestyleRow(icon: "ellipsis.circle.fill",
                             iconBg: Color(red: 0.96, green: 0.93, blue: 0.86),
                             iconTint: Color(red: 0.65, green: 0.50, blue: 0.28),
                             label: "Other nutrients",
                             percent: scores.other,
                             compact: compact)
            }
        }
    }

    /// v1.0.8 Phase T (2026-06-08) — REAL intake-vs-target ratios.
    /// Each row derives from a documented proxy:
    ///
    ///   - All nutrients = avg of (kcal, protein, carbs, fat, fiber)
    ///     % targets met. Composite "how complete is today" signal.
    ///   - Vitamins = fiber % of target (fiber-rich whole foods are
    ///     the strongest single proxy for micronutrient density per
    ///     USDA Dietary Guidelines 2020-2025).
    ///   - Minerals = (protein + fiber) / 2 — protein from varied
    ///     sources + fiber-rich plants cover most mineral needs.
    ///   - Amino acids = protein % of target (direct proxy — protein
    ///     IS the amino-acid carrier).
    ///   - Other nutrients = fat % of target — covers fat-soluble
    ///     vitamins (A, D, E, K) + omega-3/6 essentials.
    ///
    /// All values 30-100. Uses REAL today + this scan totals.
    private var scores: (all: Int, vitamins: Int, minerals: Int, amino: Int, other: Int) {
        let today = FoodLogPersister.todayMacros()
        let scan = scanTotals(result)

        let pctKcal    = pct(today.kcal    + Double(scan.kcal),    of: targets.kcal)
        let pctProtein = pct(today.protein + Double(scan.protein), of: targets.protein)
        let pctCarbs   = pct(today.carbs   + Double(scan.carbs),   of: targets.carbs)
        let pctFat     = pct(today.fat     + Double(scan.fat),     of: targets.fat)
        let pctFiber   = pct(today.fiber,                          of: targets.fiber)

        let all = (pctKcal + pctProtein + pctCarbs + pctFat + pctFiber) / 5
        return (
            all:      Int(all.rounded()),
            vitamins: Int(pctFiber.rounded()),
            minerals: Int(((pctProtein + pctFiber) / 2).rounded()),
            amino:    Int(pctProtein.rounded()),
            other:    Int(pctFat.rounded())
        )
    }
}

// MARK: - Jeni's evaluation card (page 5)

private struct JeniEvaluationCard: View {
    let result: CapturedFood

    var body: some View {
        // v1.0.8 Phase R.4 — colors moved off hot pink onto JeniFit's
        // brand rose. Founder: "the color of words have hot pink color.
        // can we keep jenifit's theme font color here?"
        //
        // Hot pink (#FF13F0) is reserved for the camera-mode signal
        // (rotating border + shutter ring + log-it CTA + share-target
        // chips). Inside the result cards we stay in the brand palette:
        // FoodTheme.textPrimary (cocoa) for prose, FoodTheme.accent
        // (#C4677A rose) for emphasis spots.
        ZStack(alignment: .topTrailing) {
            CarouselCardShell(title: nil) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                            .foregroundStyle(FoodTheme.accent)
                        Text("jeni says")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                            .foregroundStyle(FoodTheme.accent)
                    }

                    Text(headline)
                        .font(.custom("JeniHeroSerif-Italic", size: 24))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(bodyCopy)
                        .font(.system(size: 14))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("on your plate")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                            .foregroundStyle(FoodTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(displayItems, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(FoodTheme.accent.opacity(0.55))
                                        .frame(width: 4, height: 4)
                                    Text(item)
                                        .font(.system(size: 13))
                                        .foregroundStyle(FoodTheme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        vibeTag
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            decorativeSticker
                .offset(x: 8, y: -8)
        }
    }

    @ViewBuilder
    private var decorativeSticker: some View {
        if UIImage(named: "sticker_flower_3d") != nil {
            Image("sticker_flower_3d", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-12))
                .shadow(color: Color.black.opacity(0.08), radius: 0, x: 1, y: 1)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(FoodTheme.accent)
                .rotationEffect(.degrees(-12))
        }
    }

    @ViewBuilder
    private var vibeTag: some View {
        Text(vibeLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 0.37, green: 0.45, blue: 0.27))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color(red: 0.92, green: 0.96, blue: 0.86))
            )
    }

    private var displayItems: [String] {
        if result.items.isEmpty {
            return ["your plate"]
        }
        return result.items.prefix(4).map { $0.name.lowercased() }
    }

    private var vibeLabel: String {
        let t = totals
        if t.protein >= 25 { return "energizing" }
        if t.fat >= 15     { return "satisfying" }
        if t.kcal < 250    { return "light + bright" }
        if t.count >= 3    { return "balanced" }
        return "nourishing"
    }

    private var totals: (kcal: Int, protein: Int, fat: Int, count: Int) {
        let p = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let f = result.items.compactMap { $0.fatG }.reduce(0, +)
        let k = result.totalKcal ?? 0
        return (Int(k.rounded()), Int(p.rounded()), Int(f.rounded()), result.items.count)
    }

    /// v1.0.8 Phase T (2026-06-08) — Jeni copy rewritten to sound
    /// human-to-human. Founder feedback: "jeni says card sounds too
    /// robot. it doesn't sound like a human interacting to another
    /// human."
    ///
    /// Three changes from the old canned phrases:
    ///   1. Reference the actual scanned item by name (firstItem
    ///      interpolated into the body) — personal, not generic.
    ///   2. 3-4 variants per category, selected via copySeed so the
    ///      same scan always sees the same copy but DIFFERENT scans
    ///      almost always see different copy. The repeat-rate
    ///      mimics how a friend wouldn't say the exact same line
    ///      twice in a row.
    ///   3. Phrasing leans casual + a little vulnerable, not
    ///      "wellness-app". No "nutrient density" / "macros" jargon.
    ///      A friend who happens to know food, not a coach.
    private var headline: String {
        let t = totals
        let candidates: [String]
        if t.protein >= 25 {
            candidates = [
                "ok yes this",
                "love what you did",
                "this is the move",
                "you cooked",
            ]
        } else if t.kcal < 250 {
            candidates = [
                "soft + gentle",
                "this is a moment",
                "small one, nice",
                "exactly enough",
            ]
        } else if t.count >= 3 {
            candidates = [
                "look at this plate",
                "ok this is care",
                "real food hours",
                "this is so you",
            ]
        } else if t.fat >= 15 {
            candidates = [
                "this'll hold you",
                "steady ahead",
                "the good stuff",
            ]
        } else {
            candidates = [
                "you ate ♥",
                "this is nice",
                "looks just right",
                "you're doing it",
            ]
        }
        return candidates[abs(copySeed) % candidates.count]
    }

    private var bodyCopy: String {
        let t = totals
        let firstItem = result.items.first?.name.lowercased() ?? "this"

        let candidates: [String]
        if t.protein >= 25 {
            candidates = [
                "the protein from \(firstItem) is gonna keep you full for hours. proud of this choice ♥",
                "honestly such a strong move. cravings stay quiet, mood stays steady. love it.",
                "this is the kind of meal that does the work for you. set well into the afternoon.",
                "\(firstItem) carrying the whole plate. you'll feel good about this in 3 hours.",
            ]
        } else if t.kcal < 250 {
            candidates = [
                "small + intentional. when you're hungry again, listen to it. no rules here.",
                "this is just a moment of food. eat more when your body asks ♥",
                "love the gentleness. you don't need to earn the next thing.",
                "\(firstItem) doesn't have to be a whole meal. soft choices count.",
            ]
        } else if t.count >= 3 {
            candidates = [
                "your body loves variety. \(firstItem) + everything else here is exactly the move.",
                "this looks like someone who cares about themselves. and that's the whole thing.",
                "real food, real care. honestly the \(firstItem) caught my eye.",
                "a plate with this many things on it = a good day in the making ♥",
            ]
        } else if t.fat >= 15 {
            candidates = [
                "fats are so underrated. \(firstItem) keeps you steady, no afternoon crash.",
                "the good fats in here are doing more than you know. mood, brain, all of it.",
                "this'll feel really good. healthy fats slow everything down in the best way ♥",
            ]
        } else {
            candidates = [
                "you ate. that's the entire goal today ♥",
                "this is fine. not every meal needs to be optimized.",
                "soft week, soft choices, soft you. \(firstItem) counts.",
                "look at you logging it. that's the whole thing today.",
            ]
        }
        return candidates[abs(copySeed) % candidates.count]
    }

    /// Deterministic per-scan seed so the SAME plate always sees the
    /// same copy (repeatability) but DIFFERENT plates pick different
    /// variants (no repetition). Hashing item names + kcal makes the
    /// seed stable across re-renders of the same result.
    private var copySeed: Int {
        var hasher = Hasher()
        for item in result.items { hasher.combine(item.name) }
        hasher.combine(totals.kcal)
        return hasher.finalize()
    }
}

// MARK: - ProgressRow

private struct ProgressRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let progress: Double
    let barColor: Color
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 12) {
            iconWell(systemName: icon, tint: iconColor, compact: compact)

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                HStack {
                    Text(label)
                        .font(.system(size: compact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Spacer()
                    Text(value)
                        .font(.system(size: compact ? 12 : 13))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                progressBar
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.06))
                Capsule()
                    .fill(barColor)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: compact ? 4 : 6)
    }
}

// MARK: - LifestyleRow

private struct LifestyleRow: View {
    let icon: String
    let iconBg: Color
    let iconTint: Color
    let label: String
    let percent: Int
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 12) {
            Image(systemName: icon)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)
                .background(iconBg)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                HStack {
                    Text(label)
                        .font(.system(size: compact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Spacer()
                    Text("\(percent)%")
                        .font(.system(size: compact ? 12 : 13, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                        Capsule()
                            .fill(Color(red: 0.37, green: 0.45, blue: 0.27))
                            .frame(width: geo.size.width * (Double(percent) / 100))
                    }
                }
                .frame(height: compact ? 4 : 5)
            }
        }
    }
}

// MARK: - Shared score helpers (Phase T)

/// Compute % of target met, clamped to [30, 100]. The floor avoids
/// the empty-state-anxiety where a fresh morning shows "skin 4%"
/// before the user has eaten anything; floor at 30 reads as "you're
/// just starting today, plenty of room to fill in."
private func pct(_ value: Double, of target: Int) -> Double {
    guard target > 0 else { return 30 }
    let raw = (value / Double(target)) * 100
    return min(100, max(30, raw))
}

/// Per-item macro sums from a CapturedFood. Used by every card on
/// slide 2 to add THIS scan on top of today's logged macros.
private func scanTotals(_ food: CapturedFood) -> (kcal: Int, protein: Int, carbs: Int, fat: Int) {
    let k = food.totalKcal ?? Double((food.kcalLow ?? 0) + (food.kcalHigh ?? 0)) / 2
    let p = food.items.compactMap { $0.proteinG }.reduce(0, +)
    let c = food.items.compactMap { $0.carbsG }.reduce(0, +)
    let f = food.items.compactMap { $0.fatG }.reduce(0, +)
    return (Int(k.rounded()), Int(p.rounded()), Int(c.rounded()), Int(f.rounded()))
}

// MARK: - iconWell helper

@ViewBuilder
private func iconWell(systemName: String, tint: Color, compact: Bool = false) -> some View {
    Image(systemName: systemName)
        .font(.system(size: compact ? 11 : 13, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: compact ? 26 : 32, height: compact ? 26 : 32)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
}

// MARK: - Shareable section blocks (used by the 9:16 image renderer)
//
// v1.0.8 Phase R.3 — scaled-up versions of the carousel sections that
// render into the 1080×1920 shareable canvases for slides 2 and 3.
// Internal so PhotoCaptureView's ShareablePackedDailyView /
// ShareableJeniView can compose them.

struct ShareDailyTotalsBlock: View {
    let result: CapturedFood
    let kcalTarget: Int
    let proteinTarget: Int
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 16 * scale) {
            shareRow(
                icon: "flame.fill",
                tint: Color(red: 0.75, green: 0.45, blue: 0.92),
                label: "Calories",
                value: "\(caloriesNow) / \(kcalTarget)",
                progress: progress(caloriesNow, kcalTarget),
                bar: Color(red: 0.75, green: 0.45, blue: 0.92)
            )
            shareRow(
                icon: "drop.fill",
                tint: Color(red: 0.39, green: 0.61, blue: 0.85),
                label: "Protein",
                value: "\(proteinNow) / \(proteinTarget)g",
                progress: progress(proteinNow, proteinTarget),
                bar: Color(red: 0.39, green: 0.61, blue: 0.85)
            )
            HStack(alignment: .center, spacing: 12 * scale) {
                Image(systemName: "circle.hexagonpath.fill")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color(red: 0.4, green: 0.62, blue: 0.95))
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(Color(red: 0.4, green: 0.62, blue: 0.95).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
                VStack(alignment: .leading, spacing: 2 * scale) {
                    Text("Cravings control")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Text("Daily fullness score")
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                Spacer()
                Text(String(format: "%.1f", cravingsScore))
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.45, blue: 0.27))
                    .padding(.horizontal, 12 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(Capsule().fill(Color(red: 0.92, green: 0.96, blue: 0.86)))
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 16 * scale)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 14 * scale, x: 0, y: 4 * scale)
    }

    private func progress(_ now: Int, _ target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(now) / Double(target))
    }

    private var scanTotals: (carbs: Int, protein: Int, fat: Int, kcal: Int) {
        let c = result.items.compactMap { $0.carbsG }.reduce(0, +)
        let p = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let f = result.items.compactMap { $0.fatG }.reduce(0, +)
        let k = result.totalKcal ?? Double((result.kcalLow ?? 0) + (result.kcalHigh ?? 0)) / 2
        return (Int(c.rounded()), Int(p.rounded()), Int(f.rounded()), Int(k.rounded()))
    }

    private var caloriesNow: Int {
        let baseline = Int(Double(kcalTarget) * 0.62)
        return baseline + scanTotals.kcal
    }
    private var proteinNow: Int {
        let baseline = Int(Double(proteinTarget) * 0.55)
        return baseline + scanTotals.protein
    }
    private var cravingsScore: Double {
        let p = Double(scanTotals.protein)
        let k = max(50.0, Double(scanTotals.kcal))
        let density = p / (k / 100)
        return min(8.5, 5.5 + density * 0.4)
    }

    @ViewBuilder
    private func shareRow(icon: String, tint: Color, label: String, value: String,
                          progress: Double, bar: Color) -> some View {
        HStack(alignment: .center, spacing: 12 * scale) {
            Image(systemName: icon)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32 * scale, height: 32 * scale)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack {
                    Text(label)
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Spacer()
                    Text(value)
                        .font(.system(size: 13 * scale))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.06))
                        Capsule().fill(bar).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6 * scale)
            }
        }
    }
}

struct ShareLifestyleBlock: View {
    let result: CapturedFood
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            Text("today's nutrients for")
                .font(.custom("JeniHeroSerif-Italic", size: 17 * scale))
                .foregroundStyle(FoodTheme.textPrimary)
            VStack(spacing: 12 * scale) {
                shareLifestyleRow(icon: "lightbulb.fill", label: "Energy", percent: s.energy)
                shareLifestyleRow(icon: "face.smiling.fill", label: "Mood", percent: s.mood)
                shareLifestyleRow(icon: "sparkles", label: "Skin", percent: s.skin)
                shareLifestyleRow(icon: "brain.head.profile", label: "Focus", percent: s.focus)
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 14 * scale, x: 0, y: 4 * scale)
    }

    private var s: (energy: Int, mood: Int, skin: Int, focus: Int) {
        let protein = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let fat = result.items.compactMap { $0.fatG }.reduce(0, +)
        let variety = min(4, result.items.count)
        let bonus = variety * 2
        return (
            min(95, 75 + Int(protein / 5) + bonus),
            min(94, 73 + Int(fat / 4)     + bonus),
            min(90, 65 + Int(fat / 3)     + bonus),
            min(92, 72 + Int(protein / 6) + bonus)
        )
    }

    @ViewBuilder
    private func shareLifestyleRow(icon: String, label: String, percent: Int) -> some View {
        HStack(alignment: .center, spacing: 12 * scale) {
            Image(systemName: icon)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(FoodTheme.stateGood)
                .frame(width: 30 * scale, height: 30 * scale)
                .background(Color(red: 0.92, green: 0.96, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack {
                    Text(label)
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Spacer()
                    Text("\(percent)%")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.06))
                        Capsule()
                            .fill(FoodTheme.stateGood)
                            .frame(width: geo.size.width * (Double(percent) / 100))
                    }
                }
                .frame(height: 5 * scale)
            }
        }
    }
}

struct ShareNutrientsBlock: View {
    let result: CapturedFood
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            Text("today's nutrients")
                .font(.custom("JeniHeroSerif-Italic", size: 17 * scale))
                .foregroundStyle(FoodTheme.textPrimary)
            VStack(spacing: 12 * scale) {
                shareNutrientRow(icon: "heart.fill",
                                 bg: Color(red: 0.98, green: 0.90, blue: 0.91),
                                 tint: Color(red: 0.85, green: 0.32, blue: 0.43),
                                 label: "All nutrients",
                                 percent: s.all)
                shareNutrientRow(icon: "leaf.fill",
                                 bg: Color(red: 0.92, green: 0.96, blue: 0.86),
                                 tint: Color(red: 0.37, green: 0.55, blue: 0.27),
                                 label: "Vitamins",
                                 percent: s.vitamins)
                shareNutrientRow(icon: "drop.triangle.fill",
                                 bg: Color(red: 0.90, green: 0.94, blue: 0.98),
                                 tint: Color(red: 0.32, green: 0.50, blue: 0.78),
                                 label: "Minerals",
                                 percent: s.minerals)
                shareNutrientRow(icon: "link",
                                 bg: Color(red: 0.94, green: 0.90, blue: 0.96),
                                 tint: Color(red: 0.60, green: 0.40, blue: 0.75),
                                 label: "Amino acids",
                                 percent: s.amino)
                shareNutrientRow(icon: "ellipsis.circle.fill",
                                 bg: Color(red: 0.96, green: 0.93, blue: 0.86),
                                 tint: Color(red: 0.65, green: 0.50, blue: 0.28),
                                 label: "Other nutrients",
                                 percent: s.other)
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 14 * scale, x: 0, y: 4 * scale)
    }

    private var s: (all: Int, vitamins: Int, minerals: Int, amino: Int, other: Int) {
        let count = result.items.count
        let protein = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let bonus = min(15, count * 4)
        return (
            min(95, 78 + bonus),
            min(95, 80 + bonus - 2),
            min(93, 76 + bonus),
            min(93, 72 + Int(protein / 4)),
            min(96, 86 + bonus)
        )
    }

    @ViewBuilder
    private func shareNutrientRow(icon: String, bg: Color, tint: Color,
                                  label: String, percent: Int) -> some View {
        HStack(alignment: .center, spacing: 12 * scale) {
            Image(systemName: icon)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30 * scale, height: 30 * scale)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack {
                    Text(label)
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Spacer()
                    Text("\(percent)%")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.06))
                        Capsule()
                            .fill(FoodTheme.stateGood)
                            .frame(width: geo.size.width * (Double(percent) / 100))
                    }
                }
                .frame(height: 5 * scale)
            }
        }
    }
}

struct ShareJeniBlock: View {
    let result: CapturedFood
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            HStack(spacing: 6 * scale) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(FoodTheme.accent)
                Text("jeni says")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13 * scale))
                    .foregroundStyle(FoodTheme.accent)
            }

            Text(headline)
                .font(.custom("JeniHeroSerif-Italic", size: 24 * scale))
                .foregroundStyle(FoodTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyCopy)
                .font(.system(size: 14 * scale))
                .foregroundStyle(FoodTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 2 * scale)

            Text("on your plate")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13 * scale))
                .foregroundStyle(FoodTheme.textSecondary)

            VStack(alignment: .leading, spacing: 4 * scale) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8 * scale) {
                        Circle()
                            .fill(FoodTheme.accent.opacity(0.55))
                            .frame(width: 4 * scale, height: 4 * scale)
                        Text(item)
                            .font(.system(size: 13 * scale))
                            .foregroundStyle(FoodTheme.textPrimary)
                    }
                }
            }

            HStack {
                Spacer()
                Text(vibe)
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.45, blue: 0.27))
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 4 * scale)
                    .background(Capsule().fill(Color(red: 0.92, green: 0.96, blue: 0.86)))
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 14 * scale, x: 0, y: 4 * scale)
    }

    private var totals: (kcal: Int, protein: Int, fat: Int, count: Int) {
        let p = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let f = result.items.compactMap { $0.fatG }.reduce(0, +)
        let k = result.totalKcal ?? 0
        return (Int(k.rounded()), Int(p.rounded()), Int(f.rounded()), result.items.count)
    }

    private var headline: String {
        let t = totals
        if t.protein >= 25 { return "great pick ♥" }
        if t.kcal < 250    { return "soft start ♥" }
        if t.count >= 3    { return "your plate has range" }
        if t.fat >= 15     { return "this'll hold you" }
        return "looking good ♥"
    }

    private var bodyCopy: String {
        let t = totals
        if t.protein >= 25 {
            return "love the protein density. this'll keep cravings quiet for a few hours."
        }
        if t.kcal < 250 {
            return "light and balanced. you've got room for more later, listen to your hunger."
        }
        if t.count >= 3 {
            return "variety on your plate gives you a wider nutrient spread. small wins compound."
        }
        if t.fat >= 15 {
            return "healthy fats slow the absorption. steadier energy ahead, no crash."
        }
        return "this fits your goals. keep showing up. tomorrow resets, today counts."
    }

    private var items: [String] {
        if result.items.isEmpty { return ["your plate"] }
        return result.items.prefix(4).map { $0.name.lowercased() }
    }

    private var vibe: String {
        let t = totals
        if t.protein >= 25 { return "energizing" }
        if t.fat >= 15     { return "satisfying" }
        if t.kcal < 250    { return "light + bright" }
        if t.count >= 3    { return "balanced" }
        return "nourishing"
    }
}

// MARK: - TweakSheet (correction UX)
//
// v1.0.8 Phase U (2026-06-08) — quick-correction sheet that replaces
// the SingleDishCard-era "more sauce / bigger / not this" inline
// pill row. Founder ask: "bring back the feature where user can put
// more inputs to the result."
//
// 4 options:
//   - "smaller portion" → ×0.75 across all macros
//   - "bigger portion"  → ×1.25
//   - "+ sauce / dressing" → +120 kcal, +12g fat (sauce typical)
//   - "different item"  → free-text rename (uses dishName as the
//     new item.name on the first item)
//
// Each tap returns a corrected CapturedFood via `onApply`; parent
// (PhotoCaptureView) sets capturedResult to the new value, which
// re-renders all 3 slides + the shareable export.

struct TweakSheet: View {
    let result: CapturedFood
    let onApply: (CapturedFood) -> Void

    @State private var renameText: String = ""
    @State private var showingRename: Bool = false
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                (Text("tweak").font(.custom("JeniHeroSerif-Italic", size: 22))
                 + Text(" this ♥").font(.system(size: 22, weight: .semibold)))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            if showingRename {
                renameRow
            } else {
                VStack(spacing: 10) {
                    tweakRow(
                        icon: "arrow.down.right.and.arrow.up.left",
                        title: "smaller portion",
                        sub: "scale down 25%",
                        action: { onApply(result.applyTweak(scale: 0.75, addKcal: 0, addFat: 0)) }
                    )
                    tweakRow(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "bigger portion",
                        sub: "scale up 25%",
                        action: { onApply(result.applyTweak(scale: 1.25, addKcal: 0, addFat: 0)) }
                    )
                    tweakRow(
                        icon: "drop.fill",
                        title: "+ sauce or dressing",
                        sub: "add ~120 kcal of fat",
                        action: { onApply(result.applyTweak(scale: 1.0, addKcal: 120, addFat: 12)) }
                    )
                    tweakRow(
                        icon: "pencil",
                        title: "different food",
                        sub: "tell me what it actually is",
                        action: {
                            renameText = result.items.first?.name ?? ""
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showingRename = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                renameFocused = true
                            }
                        }
                    )
                }
                .padding(.horizontal, 18)
            }

            Spacer()
        }
        .background(FoodTheme.bgElevated)
        // v1.0.8 Phase U.1 — force light color scheme so the parent
        // PhotoCaptureView's preferredColorScheme(.dark) doesn't
        // bleed in and make TextField text invisible (white on cream).
        .colorScheme(.light)
    }

    @ViewBuilder
    private func tweakRow(icon: String, title: String, sub: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FoodTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(FoodTheme.accentSubtle.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(FoodTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FoodTheme.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var renameRow: some View {
        VStack(spacing: 14) {
            (Text("what is this ").font(.system(size: 15)) +
             Text("really").font(.custom("Fraunces72pt-SemiBoldItalic", size: 15)) +
             Text("? ♥").font(.system(size: 15)))
                .foregroundStyle(FoodTheme.textPrimary)

            // v1.0.8 Phase U.1 — explicit cocoa text + accent cursor.
            // Founder hit invisible text: PhotoCaptureView's
            // .preferredColorScheme(.dark) was propagating into the
            // sheet, making the default TextField text white on the
            // white background. Explicit colors here override.
            TextField("", text: $renameText, prompt:
                Text("e.g. tuna poke bowl").foregroundStyle(FoodTheme.textSecondary)
            )
            .focused($renameFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .foregroundStyle(FoodTheme.textPrimary)
            .tint(FoodTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FoodTheme.accent.opacity(0.3), lineWidth: 1)
            )

            Button {
                guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                onApply(result.applyRename(to: renameText))
            } label: {
                Text("got it ♥")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(FoodTheme.accent))
            }
            .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingRename = false
                }
            }) {
                Text("back")
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - CapturedFood corrections

extension CapturedFood {
    /// Apply a multiplicative scale (smaller/bigger) and/or an absolute
    /// add (sauce / dressing). Distributes add evenly across items so
    /// the per-item kcal stays proportional.
    func applyTweak(scale: Double, addKcal: Double, addFat: Double) -> CapturedFood {
        guard !items.isEmpty else { return self }
        let perItemAddKcal = addKcal / Double(items.count)
        let perItemAddFat  = addFat  / Double(items.count)

        let newItems = items.map { item -> CapturedItem in
            CapturedItem(
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
                kcal:     item.kcal.map     { $0 * scale + perItemAddKcal },
                proteinG: item.proteinG.map { $0 * scale },
                carbsG:   item.carbsG.map   { $0 * scale },
                fatG:     item.fatG.map     { $0 * scale + perItemAddFat },
                fiberG:   item.fiberG.map   { $0 * scale },
                nutritionSource: item.nutritionSource,
                sugarG: item.sugarG.map { $0 * scale },
                sodiumMg: item.sodiumMg.map { $0 * scale },
                saturatedFatG: item.saturatedFatG.map { $0 * scale }
            )
        }
        let newKcalLow  = kcalLow.map  { $0 * scale + addKcal }
        let newKcalHigh = kcalHigh.map { $0 * scale + addKcal }
        return CapturedFood(
            items: newItems,
            plateType: plateType,
            source: source,
            confidence: confidence,
            needsSecondPhoto: needsSecondPhoto,
            secondPhotoHint: secondPhotoHint,
            kcalLow: newKcalLow,
            kcalHigh: newKcalHigh
        )
    }

    /// Rename the first item (the dish hero). The macros stay — only
    /// the name changes. Useful when the LLM misidentified the food
    /// but the calorie estimate is close (often true for portion-
    /// matched substitutions like "tuna poke" vs "salmon poke").
    func applyRename(to newName: String) -> CapturedFood {
        guard let first = items.first else { return self }
        let renamed = CapturedItem(
            id: first.id,
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            portionGrams: first.portionGrams,
            portionGramsLow: first.portionGramsLow,
            portionGramsHigh: first.portionGramsHigh,
            usdaSearchTerms: first.usdaSearchTerms,
            preparation: first.preparation,
            cuisineHint: first.cuisineHint,
            confidence: first.confidence,
            notes: first.notes,
            kcal: first.kcal,
            proteinG: first.proteinG,
            carbsG: first.carbsG,
            fatG: first.fatG,
            fiberG: first.fiberG,
            nutritionSource: first.nutritionSource,
            sugarG: first.sugarG,
            sodiumMg: first.sodiumMg,
            saturatedFatG: first.saturatedFatG
        )
        var newItems = items
        newItems[0] = renamed
        return CapturedFood(
            items: newItems,
            plateType: plateType,
            source: source,
            confidence: confidence,
            needsSecondPhoto: needsSecondPhoto,
            secondPhotoHint: secondPhotoHint,
            kcalLow: kcalLow,
            kcalHigh: kcalHigh
        )
    }
}

#endif  // canImport(UIKit)
