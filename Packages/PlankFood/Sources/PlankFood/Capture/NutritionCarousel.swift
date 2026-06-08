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

struct NutritionCarousel: View {

    let result: CapturedFood

    @State private var currentPage: Int = 0
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 3

    /// v1.0.8 Phase R.4 — carousel container height is now driven by
    /// the parent (resultModeOverlay's GeometryReader). Lets the
    /// carousel fill the available vertical room so slide 2's stacked
    /// cards aren't cut at the top and bottom edges. Falls back to
    /// 500pt if no explicit height passed.
    let carouselHeight: CGFloat

    init(result: CapturedFood, carouselHeight: CGFloat = 500) {
        self.result = result
        self.carouselHeight = carouselHeight
    }

    var body: some View {
        // v1.0.8 Phase R.4 — dots overlay inside the carousel frame at
        // the bottom, not below it. Founder direction: "carousel dots
        // on the bottom layer of card (consistent for all 3 slides)."
        // ZStack(alignment: .bottom) pins the dots to the carousel's
        // bottom edge regardless of card content size, so all 3 slides
        // show dots at the exact same vertical position.
        TabView(selection: $currentPage) {
            MealSummaryCard(result: result)
                .padding(.horizontal, 4)
                .padding(.bottom, 28)  // room for dots overlay
                .tag(0)

            PackedDailyCard(
                result: result,
                kcalTarget: kcalTarget,
                proteinTarget: proteinTarget
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 28)
            .tag(1)

            JeniEvaluationCard(result: result)
                .padding(.horizontal, 4)
                .padding(.bottom, 28)
                .tag(2)
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
                    Text(title)
                        .font(.custom("Fraunces72pt-SemiBoldItalic",
                                      size: compact ? 15 : 17))
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.18),
                radius: compact ? 10 : 14, x: 0, y: 4)
    }
}

// MARK: - Meal summary card (page 1)

private struct MealSummaryCard: View {
    let result: CapturedFood

    var body: some View {
        NutritionCardView(
            mealLabel: mealTypeLabel,
            dishName: dishNameLabel,
            totals: nutritionTotals,
            scale: 1.0
        )
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
    let kcalTarget: Int
    let proteinTarget: Int

    var body: some View {
        // v1.0.8 Phase R.5 — compact mode + tight gaps so all 3 cards
        // fit visible. ScrollView still wraps for very small screens
        // (iPhone SE) but on modern iPhones nothing scrolls.
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                DailyTotalsCard(
                    result: result,
                    kcalTarget: kcalTarget,
                    proteinTarget: proteinTarget,
                    compact: true
                )
                LifestyleScoresCard(result: result, compact: true)
                NutrientsBreakdownCard(result: result, compact: true)
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

    /// v1.0.8 Phase S (2026-06-08) — REAL today's kcal total from
    /// FoodLogPersister + the new scan that's about to be logged.
    /// Single-user-per-device so no userId filter. Founder ask:
    /// "can we also check slide 2 data is actually coming from real
    /// data?" — calories is now real, protein remains a heuristic
    /// (the FoodLogPersister Entry struct only stores kcal, not
    /// macros, so true protein totals need a schema migration first).
    private var caloriesNow: Int {
        let loggedToday = Int(FoodLogPersister.todayKcalTotal().rounded())
        return loggedToday + scanTotals.kcal
    }

    /// HEURISTIC — not real. The FoodLogPersister stores kcal only,
    /// not protein. True protein totals require a schema migration.
    /// For now we estimate today's protein from the kcal total at a
    /// typical 18% protein-to-kcal ratio (matches gen-z weight-loss
    /// cohort macro targets), plus this scan's measured protein.
    /// TODO v1.0.9 — extend FoodLogPersister.Entry with macros and
    /// query real protein totals here.
    private var proteinNow: Int {
        let loggedKcal = FoodLogPersister.todayKcalTotal()
        let estProtein = Int((loggedKcal * 0.18 / 4).rounded())
        return estProtein + scanTotals.protein
    }

    private var cravingsScore: Double {
        // Mock: 5.5 base + protein density bonus + fiber bonus. Range
        // ~5.5-8.5. Higher protein/lower kcal → better satiety score.
        let p = Double(scanTotals.protein)
        let k = max(50.0, Double(scanTotals.kcal))
        let density = p / (k / 100)  // grams protein per 100 kcal
        return min(8.5, 5.5 + density * 0.4)
    }

    private func progress(_ now: Int, _ target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(now) / Double(target))
    }
}

// MARK: - Lifestyle scores card (page 3)

private struct LifestyleScoresCard: View {
    let result: CapturedFood
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

    /// V1 mock — varies between mid-70s and high-80s based on scan
    /// macros. Higher protein bumps energy/focus; more fat bumps mood/
    /// skin (fatty acids); more variety bumps everything.
    private var scores: (energy: Int, mood: Int, skin: Int, focus: Int) {
        let protein = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let fat = result.items.compactMap { $0.fatG }.reduce(0, +)
        let variety = min(4, result.items.count)  // more items = more variety
        let varietyBonus = variety * 2

        let energy = min(95, 75 + Int(protein / 5) + varietyBonus)
        let mood   = min(94, 73 + Int(fat / 4)     + varietyBonus)
        let skin   = min(90, 65 + Int(fat / 3)     + varietyBonus)
        let focus  = min(92, 72 + Int(protein / 6) + varietyBonus)

        return (energy, mood, skin, focus)
    }
}

// MARK: - Nutrients breakdown card (page 4)

private struct NutrientsBreakdownCard: View {
    let result: CapturedFood
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

    /// V1 mock — based on item count + macro density. All in 75-95 range.
    private var scores: (all: Int, vitamins: Int, minerals: Int, amino: Int, other: Int) {
        let count = result.items.count
        let protein = result.items.compactMap { $0.proteinG }.reduce(0, +)
        let bonus = min(15, count * 4)

        let all      = min(95, 78 + bonus)
        let vitamins = min(95, 80 + bonus - 2)
        let minerals = min(93, 76 + bonus)
        let amino    = min(93, 72 + Int(protein / 4))
        let other    = min(96, 86 + bonus)
        return (all, vitamins, minerals, amino, other)
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
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
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

    /// V1 canned phrases. Variations chosen by scan macros — protein
    /// density, calorie load, variety. Voice-locked: italic punch
    /// words, lowercase casual, heart as terminal punctuation, never
    /// the "AI" word.
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
            return "light and balanced. you've got room for more later — listen to your hunger."
        }
        if t.count >= 3 {
            return "variety on your plate gives you a wider nutrient spread. small wins compound."
        }
        if t.fat >= 15 {
            return "healthy fats slow the absorption — steadier energy ahead, no crash."
        }
        return "this fits your goals. keep showing up — tomorrow resets, today counts."
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
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17 * scale))
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
                .foregroundStyle(Color(red: 0.37, green: 0.55, blue: 0.27))
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
                            .fill(Color(red: 0.37, green: 0.45, blue: 0.27))
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
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17 * scale))
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
                            .fill(Color(red: 0.37, green: 0.45, blue: 0.27))
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
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24 * scale))
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
            return "light and balanced. you've got room for more later — listen to your hunger."
        }
        if t.count >= 3 {
            return "variety on your plate gives you a wider nutrient spread. small wins compound."
        }
        if t.fat >= 15 {
            return "healthy fats slow the absorption — steadier energy ahead, no crash."
        }
        return "this fits your goals. keep showing up — tomorrow resets, today counts."
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

#endif  // canImport(UIKit)
