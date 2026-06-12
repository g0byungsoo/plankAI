#if canImport(UIKit)
import SwiftUI

// MARK: - ImOutTonightView
//
// Per v5 D14 + §Calorie scan Screen 6: single-tap "i'm out tonight"
// placeholder log. NO hunger sliders (rejected in v5 D14 refinement —
// over-engineered for the laziness-averse cohort). Cuisine chip is
// OPTIONAL — it refines the placeholder estimate but skipping it
// still logs a generic ~700 kcal dinner placeholder.
//
// The simplicity IS the feature. Per audience research, the
// restaurant moment is where every other tracker dies. Showing 6
// chips and a "that's about it" CTA respects the social context
// (you're at dinner with friends, you don't want to fiddle).
//
// Cuisine → placeholder kcal map (rough centers; the actual range
// gets surfaced by RestaurantRangeBar in the result card):
//   mexican   → 600
//   italian   → 850
//   asian     → 750
//   american  → 700
//   pizza     → 900
//   other     → 700 (default)
//   (skipped) → 700 (default)

/// Visible chip in the restaurant cloud. v1.0.7 round 18 — many
/// small chips (cuisines + popular fast-casual chains) so the
/// surface reads "this app knows food" instead of "6 vague
/// cuisines." Each chip resolves to one of the 6 backend
/// CuisineChip cases for dispatcher kcal estimation.
private struct RestaurantChip: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let cuisine: CuisineChip
}

public struct ImOutTonightView: View {

    public let onLogged: (CapturedFood) -> Void
    public let onDismiss: () -> Void

    @State private var selectedChip: RestaurantChip?
    @State private var isLogging: Bool = false
    @State private var errorMessage: String?

    /// 36 restaurant chips covering ≥85% of US Gen-Z women dining out
    /// surface per WL program expert ethnographic data. Each chip
    /// maps to one of the 6 backend CuisineChip values for kcal
    /// estimation via FoodCaptureDispatcher's existing cuisine math.
    private static let chips: [RestaurantChip] = [
        // Fast-casual chains (highest log frequency)
        RestaurantChip(id: "chipotle", name: "chipotle", emoji: "🌯", cuisine: .mexican),
        RestaurantChip(id: "sweetgreen", name: "sweetgreen", emoji: "🥗", cuisine: .american),
        RestaurantChip(id: "cava", name: "cava", emoji: "🥙", cuisine: .other),
        RestaurantChip(id: "starbucks", name: "starbucks", emoji: "☕", cuisine: .american),
        RestaurantChip(id: "chickfila", name: "chick-fil-a", emoji: "🐔", cuisine: .american),
        RestaurantChip(id: "panera", name: "panera", emoji: "🥪", cuisine: .american),
        RestaurantChip(id: "shake_shack", name: "shake shack", emoji: "🍔", cuisine: .american),
        RestaurantChip(id: "in_n_out", name: "in-n-out", emoji: "🍔", cuisine: .american),
        RestaurantChip(id: "taco_bell", name: "taco bell", emoji: "🌮", cuisine: .mexican),
        RestaurantChip(id: "mcdonalds", name: "mcdonald's", emoji: "🍟", cuisine: .american),
        RestaurantChip(id: "subway", name: "subway", emoji: "🥖", cuisine: .american),
        RestaurantChip(id: "dunkin", name: "dunkin'", emoji: "🍩", cuisine: .american),
        RestaurantChip(id: "dominos", name: "domino's", emoji: "🍕", cuisine: .pizza),
        RestaurantChip(id: "erewhon", name: "erewhon", emoji: "🥬", cuisine: .american),
        RestaurantChip(id: "jamba", name: "jamba juice", emoji: "🥤", cuisine: .american),
        // Cuisine fallbacks
        RestaurantChip(id: "mexican", name: "mexican", emoji: "🌮", cuisine: .mexican),
        RestaurantChip(id: "italian", name: "italian", emoji: "🍝", cuisine: .italian),
        RestaurantChip(id: "pizza", name: "pizza", emoji: "🍕", cuisine: .pizza),
        RestaurantChip(id: "chinese", name: "chinese", emoji: "🥡", cuisine: .asian),
        RestaurantChip(id: "japanese", name: "japanese", emoji: "🍱", cuisine: .asian),
        RestaurantChip(id: "korean", name: "korean", emoji: "🍜", cuisine: .asian),
        RestaurantChip(id: "thai", name: "thai", emoji: "🍤", cuisine: .asian),
        RestaurantChip(id: "vietnamese", name: "vietnamese", emoji: "🍜", cuisine: .asian),
        RestaurantChip(id: "sushi", name: "sushi", emoji: "🍣", cuisine: .asian),
        RestaurantChip(id: "indian", name: "indian", emoji: "🍛", cuisine: .other),
        RestaurantChip(id: "mediterranean", name: "mediterranean", emoji: "🫒", cuisine: .other),
        RestaurantChip(id: "greek", name: "greek", emoji: "🥗", cuisine: .other),
        RestaurantChip(id: "french", name: "french", emoji: "🥐", cuisine: .other),
        RestaurantChip(id: "american", name: "american", emoji: "🍔", cuisine: .american),
        RestaurantChip(id: "burger", name: "burger spot", emoji: "🍔", cuisine: .american),
        RestaurantChip(id: "salad", name: "salad bar", emoji: "🥗", cuisine: .american),
        RestaurantChip(id: "sandwich", name: "sandwich shop", emoji: "🥪", cuisine: .american),
        RestaurantChip(id: "ramen", name: "ramen", emoji: "🍜", cuisine: .asian),
        RestaurantChip(id: "bbq", name: "bbq", emoji: "🍖", cuisine: .american),
        RestaurantChip(id: "brunch", name: "brunch spot", emoji: "🥞", cuisine: .american),
        RestaurantChip(id: "other", name: "other", emoji: "🍽️", cuisine: .other),
    ]

    public init(
        onLogged: @escaping (CapturedFood) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onLogged = onLogged
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: FoodTheme.Space.lg) {
            topBar
            header
            cuisineGrid
            Spacer(minLength: 0)
            justLogItLink
            primaryButton
        }
        .padding(FoodTheme.Space.screenPadding)
        .background(FoodTheme.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .padding(.horizontal, FoodTheme.Space.md)
                    .padding(.vertical, FoodTheme.Space.sm)
                    .background(Capsule().fill(FoodTheme.textPrimary))
                    .padding(.top, 60)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("back")
            Spacer()
        }
    }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("you're out tonight")
                    .font(.custom("Fraunces72pt-SemiBold", size: 24))
                    .foregroundStyle(FoodTheme.textPrimary)
                // v1.1 design pass — brand flower sticker replaces the
                // emoji per the no-emoji rule + sticker vocabulary.
                Image("sticker_flower_3d", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(8))
                    .accessibilityHidden(true)
            }
            Text("logging a rough estimate.")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)

            Text("what kind of place?")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary)
                .padding(.top, FoodTheme.Space.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// v1.0.7 round 18 — 6 large cuisine pills replaced with a
    /// scrolling chip cloud of 36 restaurant/cuisine chips. Per
    /// founder feedback the user shouldn't feel like the app
    /// "doesn't know food." Each chip resolves to one of the 6
    /// backend CuisineChip cases via RestaurantChip.cuisine.
    @ViewBuilder private var cuisineGrid: some View {
        ScrollView {
            ChipCloudLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(Self.chips) { chip in
                    chipButton(chip)
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(_ chip: RestaurantChip) -> some View {
        let isSelected = selectedChip == chip
        Button {
            selectedChip = isSelected ? nil : chip
        } label: {
            HStack(spacing: 5) {
                Text(chip.emoji)
                    .font(.system(size: 13))
                Text(chip.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isSelected ? FoodTheme.textPrimary : FoodTheme.bgElevated
                )
            )
            .overlay(
                Capsule().stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.name)
    }

    @ViewBuilder private var justLogItLink: some View {
        Button {
            Task { await logTapped() }
        } label: {
            Text("or just log it →")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .disabled(isLogging)
    }

    @ViewBuilder private var primaryButton: some View {
        Button {
            Task { await logTapped() }
        } label: {
            HStack(spacing: 8) {
                if isLogging {
                    ProgressView()
                        .tint(FoodTheme.bgPrimary)
                }
                Text(isLogging ? "logging…" : "that's about it")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(FoodTheme.textPrimary))
        }
        .disabled(isLogging)
    }

    // MARK: - Actions

    private func logTapped() async {
        guard !isLogging else { return }
        isLogging = true
        defer { isLogging = false }

        let dispatcher = FoodCaptureDispatcher()
        do {
            let food = try await dispatcher.dispatch(.imOutTonight(cuisine: selectedChip?.cuisine))
            onLogged(food)
        } catch FoodCaptureError.notImplemented(let ticket, let message, _) {
            #if DEBUG
            errorMessage = "[\(ticket)] \(message)"
            #else
            errorMessage = "give us a few hours — we're catching our breath."
            #endif
        } catch {
            #if DEBUG
            errorMessage = "log failed: \(error)"
            #else
            errorMessage = "couldn't log just now. try again?"
            #endif
        }
    }
}

// MARK: - Preview

#Preview("ImOutTonightView") {
    ImOutTonightView(
        onLogged: { _ in print("logged") },
        onDismiss: { print("dismiss") }
    )
}

#endif  // canImport(UIKit)
