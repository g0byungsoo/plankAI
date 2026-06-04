#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - PortionStepper
//
// Per v5 D51 §Calorie scan Screen 7 (correction sheet): portion
// slider with 3 haptic stops at Small / Medium / Large. Anchored
// to the LLM's portion_grams_low/high so the slider's range
// matches the model's actual uncertainty band (not an arbitrary
// 0-1000g range).
//
// Stops map to:
//   .small  = portionGramsLow
//   .medium = portionGrams (the LLM's point estimate)
//   .large  = portionGramsHigh
//
// Haptic feedback fires on stop crossings. Slider is continuous
// inside the range (rounded to integer grams for display) but the
// stops give the user obvious anchors.

public struct PortionStepper: View {

    public let initialGrams: Double
    public let lowGrams: Double
    public let highGrams: Double
    public let onChange: (Double) -> Void

    @State private var grams: Double
    @State private var lastStop: Stop = .medium

    public init(
        initialGrams: Double,
        lowGrams: Double,
        highGrams: Double,
        onChange: @escaping (Double) -> Void
    ) {
        self.initialGrams = initialGrams
        self.lowGrams = lowGrams
        self.highGrams = highGrams
        self.onChange = onChange
        self._grams = State(initialValue: initialGrams)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.sm) {
            HStack {
                Text("portion")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer()
                Text("\(Int(grams.rounded()))g")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
            }

            Slider(
                value: $grams,
                in: lowGrams...highGrams
            ) {
                Text("portion grams")
            } minimumValueLabel: {
                Text("S")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FoodTheme.textSecondary)
            } maximumValueLabel: {
                Text("L")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
            .tint(FoodTheme.accent)
            .onChange(of: grams) { _, newValue in
                handleStopHaptic(for: newValue)
                onChange(newValue)
            }
            .accessibilityLabel("portion in grams")
            .accessibilityValue("\(Int(grams.rounded())) grams")

            HStack {
                Text("about \(approximation)")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Haptics

    private enum Stop: Hashable {
        case small, medium, large
    }

    private func handleStopHaptic(for value: Double) {
        let span = highGrams - lowGrams
        guard span > 0 else { return }

        let normalized = (value - lowGrams) / span  // 0 ... 1
        let currentStop: Stop
        switch normalized {
        case ..<0.25:      currentStop = .small
        case 0.25..<0.75:  currentStop = .medium
        default:           currentStop = .large
        }

        if currentStop != lastStop {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            lastStop = currentStop
        }
    }

    // MARK: - Display helpers

    private var approximation: String {
        let cups = grams / 240  // rough conversion for liquids; matches the cohort's
                                // mental model for beverages + bowls. v1.0.8 may
                                // ship better unit conversions per food category.
        if cups >= 0.875 {
            return "\(Int(cups.rounded())) cup\(cups >= 1.5 ? "s" : "")"
        } else if cups >= 0.375 {
            return "half a cup"
        } else {
            return "a small bite"
        }
    }
}

// MARK: - Preview

#Preview("PortionStepper") {
    PortionStepper(
        initialGrams: 350,
        lowGrams: 250,
        highGrams: 450,
        onChange: { print("portion: \($0)") }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
