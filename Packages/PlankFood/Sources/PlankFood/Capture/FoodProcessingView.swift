#if canImport(UIKit)
import SwiftUI

// MARK: - FoodProcessingView
//
// Transparent processing overlay during the 1.5–3s food scan call.
// Apple 5.1.2(i) wants users to understand when AI is processing their
// data; the 3-line streaming copy makes the model pipeline literal
// instead of opaque, so the user can connect "I tapped" → "model is
// reading" → "result is on its way."
//
// Per sprint W5-T4 + plan §AI disclosure copy:
//   line 1: "*looking* at your plate"
//   line 2: "*matching* ingredients"
//   line 3: "*estimating* portions"
//
// Each line advances at a fixed-pace tick; final state holds at line 3
// until the host (PhotoCaptureView.captureTapped) tears down the view
// when the vision call returns. The view never "completes" on its own
// — completion is owned by the caller's await.
//
// Visual register mirrors the AffirmationLoaderScreen / BuildingPlan
// loader family so the food-rail in-flight UI reads as one app: cream
// bg, central rose bloom, italic-Fraunces punch word, hearts ♥ only as
// terminal punctuation.

@MainActor
public struct FoodProcessingView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stepIndex: Int = 0
    @State private var bloomScale: CGFloat = 0.92
    @State private var bloomVisible: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            centralBloom

            VStack(alignment: .leading, spacing: 14) {
                Spacer()

                ForEach(0..<Self.steps.count, id: \.self) { i in
                    let step = Self.steps[i]
                    let isDone = i < stepIndex
                    let isActive = i == stepIndex

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isDone ? FoodTheme.accent : FoodTheme.textSecondary.opacity(0.4))
                            .animation(.easeOut(duration: 0.3), value: isDone)
                        ItalicAccentText(
                            step.base,
                            italic: step.italic,
                            baseFont: .custom("Fraunces72pt-Regular", size: 16),
                            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                            color: (isDone || isActive) ? FoodTheme.textPrimary : FoodTheme.textSecondary.opacity(0.5)
                        )
                    }
                    .opacity((isDone || isActive) ? 1 : 0.55)
                }

                Spacer()
            }
            .padding(.horizontal, FoodTheme.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await runChoreography()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("looking at your plate, matching ingredients, estimating portions")
    }

    // MARK: - Bloom

    private var centralBloom: some View {
        ZStack {
            Circle()
                .fill(FoodTheme.accent.opacity(0.07))
                .frame(width: 200, height: 200)
                .scaleEffect(bloomScale)
                .blur(radius: 22)
            Circle()
                .fill(FoodTheme.accent.opacity(0.14))
                .frame(width: 120, height: 120)
                .scaleEffect(bloomScale)
                .blur(radius: 9)
            Circle()
                .fill(FoodTheme.accent.opacity(0.20))
                .frame(width: 60, height: 60)
                .scaleEffect(bloomScale)
                .blur(radius: 3)
        }
        .opacity(bloomVisible ? 1 : 0)
        .accessibilityHidden(true)
    }

    // MARK: - Choreography

    /// Step ~0.55s each: ~1.6s total for the 3 phases. Final phase
    /// holds at index 2 until the caller dismisses the view (when the
    /// vision call resolves). If the call resolves faster than 1.6s,
    /// the user sees a partial reveal which is fine — the view tears
    /// down underneath them.
    private func runChoreography() async {
        withAnimation(.easeOut(duration: 0.5)) { bloomVisible = true }
        if reduceMotion {
            bloomScale = 1.0
        } else {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                bloomScale = 1.08
            }
        }

        // Advance through steps 0 → 1 → 2 with ~0.55s dwell each.
        // Step 2 is the final state and never advances; the view is
        // expected to be replaced by the caller when the model
        // returns.
        for _ in 0..<2 {
            try? await Task.sleep(nanoseconds: 550_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) {
                stepIndex += 1
            }
        }
    }

    // MARK: - Steps

    private static let steps: [(base: String, italic: [String])] = [
        ("looking at your plate",   ["looking"]),
        ("matching ingredients",    ["matching"]),
        ("estimating portions",     ["estimating"]),
    ]
}

#endif  // canImport(UIKit)
