#if canImport(UIKit)
import SwiftUI

// MARK: - FoodOnboardingSheet
//
// First-scan onboarding sheet. Fires the first time a user opens the
// food camera, AFTER the AI consent sheet but BEFORE the camera UI.
// Collects three cohort-accuracy signals in one screen so the vision
// pipeline has cohort context from scan #1:
//
//   1. Dietary pattern   — single select. Drives result-card framing
//                          (e.g. "this looks omnivore-friendly").
//   2. Cuisine profile   — multi select. Feeds FoodVisionService system
//                          prompt as anti-cultural-bias accuracy lift.
//                          Only shown when not already set in onboarding
//                          v2 (case 169) — v1-onboarded retro users see
//                          this section; new v2 users skip it.
//   3. Exclusions        — multi select. Drives allergen heads-up on
//                          result card ("this dish has shellfish ♥").
//
// All sections support skip — the answer is optional, not gated. Users
// who skip get the no-seed path (same as pre-1.0.7 behavior). Settings
// → food lets them edit later.
//
// One-time fire: gated on AppStorage `foodOnboardingComplete`. Tapping
// "continue ♥" stamps the flag regardless of fields filled — once
// dismissed, the sheet never re-appears (re-edits live in Settings).

@MainActor
public struct FoodOnboardingSheet: View {

    public let onContinue: () -> Void

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    @AppStorage("foodDietaryPattern") private var dietaryPattern: String = ""
    @AppStorage("foodExclusionsCSV") private var exclusionsCSV: String = ""
    @AppStorage("onboardingCuisinePreference") private var cuisineCSV: String = ""

    // MARK: - Lookups

    private static let dietaryOptions: [(key: String, label: String)] = [
        ("omnivore",     "omnivore"),
        ("pescatarian",  "pescatarian"),
        ("vegetarian",   "vegetarian"),
        ("vegan",        "vegan"),
    ]

    private static let exclusionOptions: [(key: String, label: String)] = [
        ("dairy",     "dairy"),
        ("gluten",    "gluten"),
        ("nuts",      "nuts"),
        ("shellfish", "shellfish"),
        ("eggs",      "eggs"),
        ("soy",       "soy"),
    ]

    private static let cuisineOptions: [(key: String, label: String)] = [
        ("american",      "american"),
        ("italian",       "italian"),
        ("mexican",       "mexican"),
        ("korean",        "korean"),
        ("japanese",      "japanese"),
        ("chinese",       "chinese"),
        ("mediterranean", "mediterranean"),
        ("other",         "other"),
    ]

    /// Whether to surface the cuisine section. Only v1-onboarded users
    /// who didn't see case 169 hit this branch; new v2 users already
    /// set their cuisine in onboarding and skip the section here.
    private var needsCuisineRetro: Bool {
        cuisineCSV.isEmpty
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(title: "what you eat",
                        subtitle: "the tone changes — softer cues if you skip animal foods.") {
                    chipRow(
                        options: Self.dietaryOptions,
                        isSelected: { $0 == dietaryPattern },
                        onTap: { key in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dietaryPattern = (dietaryPattern == key) ? "" : key
                        }
                    )
                }

                if needsCuisineRetro {
                    section(title: "your *cuisine* mix",
                            italic: ["cuisine"],
                            subtitle: "multi-pick — helps jeni read your meals better.") {
                        chipRow(
                            options: Self.cuisineOptions,
                            isSelected: { csvSet(cuisineCSV).contains($0) },
                            onTap: { key in
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                var set = csvSet(cuisineCSV)
                                if set.contains(key) { set.remove(key) } else { set.insert(key) }
                                cuisineCSV = set.sorted().joined(separator: ",")
                            }
                        )
                    }
                }

                section(title: "anything to avoid?",
                        subtitle: "we'll flag it when it shows up on your plate.") {
                    chipRow(
                        options: Self.exclusionOptions,
                        isSelected: { csvSet(exclusionsCSV).contains($0) },
                        onTap: { key in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            var set = csvSet(exclusionsCSV)
                            if set.contains(key) { set.remove(key) } else { set.insert(key) }
                            exclusionsCSV = set.sorted().joined(separator: ",")
                        }
                    )
                }
            }
            .padding(.horizontal, FoodTheme.Space.lg)
            .padding(.top, FoodTheme.Space.md)
            .padding(.bottom, FoodTheme.Space.lg)
        }
        .background(FoodTheme.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: onContinue) {
                    Text("continue ♥")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(FoodTheme.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FoodTheme.textPrimary)
                        .clipShape(Capsule())
                }
                Text("you can edit any of this later in settings → food.")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
            .padding(.horizontal, FoodTheme.Space.lg)
            .padding(.bottom, 16)
            .background(FoodTheme.bgPrimary)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ItalicAccentText(
                "before your first plate ♥",
                italic: ["first"],
                baseFont: .custom("Fraunces72pt-SemiBold", size: 26),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                color: FoodTheme.textPrimary,
                alignment: .leading
            )
            Text("three soft questions. each is optional.")
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        italic: [String] = [],
        subtitle: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if italic.isEmpty {
                Text(title)
                    .font(.custom("Fraunces72pt-SemiBold", size: 18))
                    .foregroundStyle(FoodTheme.textPrimary)
            } else {
                ItalicAccentText(
                    title.replacingOccurrences(of: "*", with: ""),
                    italic: italic,
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 18),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 18),
                    color: FoodTheme.textPrimary,
                    alignment: .leading
                )
            }
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(FoodTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    // MARK: - Chip row

    private func chipRow(
        options: [(key: String, label: String)],
        isSelected: @escaping (String) -> Bool,
        onTap: @escaping (String) -> Void
    ) -> some View {
        FoodOnboardingChipFlow(spacing: 8) {
            ForEach(options, id: \.key) { opt in
                let selected = isSelected(opt.key)
                Button {
                    onTap(opt.key)
                } label: {
                    Text(opt.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected ? FoodTheme.textPrimary
                                           : FoodTheme.accentSubtle.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - CSV helper

    private func csvSet(_ csv: String) -> Set<String> {
        Set(csv.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
}

// MARK: - Flow Layout

private struct FoodOnboardingChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                totalHeight += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Storage helper

public enum FoodOnboardingFlag {
    public static let completedKey = "foodOnboardingComplete"
    public static func hasCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }
    public static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}

#endif  // canImport(UIKit)
