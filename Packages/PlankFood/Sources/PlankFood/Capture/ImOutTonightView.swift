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

public struct ImOutTonightView: View {

    public let onLogged: (CapturedFood) -> Void
    public let onDismiss: () -> Void

    @State private var selectedCuisine: CuisineChip?
    @State private var isLogging: Bool = false
    @State private var errorMessage: String?

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
                Text("🌸")
                    .font(.system(size: 22))
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

    @ViewBuilder private var cuisineGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: FoodTheme.Space.sm),
            GridItem(.flexible(), spacing: FoodTheme.Space.sm),
            GridItem(.flexible(), spacing: FoodTheme.Space.sm),
        ]
        LazyVGrid(columns: columns, spacing: FoodTheme.Space.sm) {
            ForEach(CuisineChip.allCases) { cuisine in
                cuisineButton(cuisine)
            }
        }
    }

    @ViewBuilder
    private func cuisineButton(_ cuisine: CuisineChip) -> some View {
        let isSelected = selectedCuisine == cuisine
        Button {
            selectedCuisine = isSelected ? nil : cuisine
        } label: {
            Text(cuisine.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FoodTheme.Space.md)
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
        .accessibilityLabel(cuisine.rawValue)
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
            let food = try await dispatcher.dispatch(.imOutTonight(cuisine: selectedCuisine))
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
