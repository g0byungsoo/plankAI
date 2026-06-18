#if canImport(UIKit)
import SwiftUI

// MARK: - CountUpNumber
//
// v1.0.19 (2026-06-18) — the her75 + iOS panel's locked design move
// for the calorie hero: count-up from 0 → final via the native iOS 17
// `contentTransition(.numericText())` digit-roll, then a 140ms italic
// "curtsy" flourish at landing (her75 designer's pick — single best
// magical detail), then a 60ms hold, then a 180ms settle back to
// roman. Total apex grace: 380ms.
//
// Used by ResultDecisionCard (slide 1 calorie hero) and
// ResultDayInContextCard (slide 3 kcal-left / protein-today hero).
// Both surfaces want the same beat so the brand voice is consistent
// across slides.

struct CountUpNumber: View {

    let target: Int
    let fontName: String        // "JeniHeroSerif-Regular"
    let italicFontName: String  // "JeniHeroSerif-Italic"
    let size: CGFloat
    let color: Color
    var rollDuration: Double = 0.9
    var curtsyDelay: Double = 0.95   // when after onAppear the curtsy fires
    var curtsyIn: Double = 0.14      // 140ms italic-in
    var curtsyHold: Double = 0.06    // 60ms hold
    var curtsyOut: Double = 0.18     // 180ms roman-out

    @State private var displayedValue: Int = 0
    @State private var italicProgress: Double = 0  // 0 = roman, 1 = italic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Roman layer
            Text("\(displayedValue)")
                .font(.custom(fontName, size: size))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .opacity(1 - italicProgress)

            // Italic layer (overlaid for the curtsy moment)
            Text("\(displayedValue)")
                .font(.custom(italicFontName, size: size))
                .foregroundStyle(color)
                .monospacedDigit()
                .opacity(italicProgress)
        }
        .kerning(-(size * 0.012))  // -1.2% size — her75 display tracking
        .onAppear { runReveal() }
    }

    private func runReveal() {
        if reduceMotion {
            displayedValue = target
            return
        }
        // Beat 1: count-up roll via numericText contentTransition.
        // A single withAnimation block on the value drives the
        // native digit roll; .monospacedDigit avoids reflow.
        withAnimation(.easeOut(duration: rollDuration)) {
            displayedValue = target
        }

        // Beat 2: italic curtsy. Fires AFTER the value lands so the
        // flourish reads as a "settled-in" gesture, not part of the
        // roll. Three sub-beats:
        //   curtsyIn  → roman→italic crossfade
        //   curtsyHold → italic holds
        //   curtsyOut → italic→roman crossfade settle
        DispatchQueue.main.asyncAfter(deadline: .now() + curtsyDelay) {
            withAnimation(.easeInOut(duration: curtsyIn)) {
                italicProgress = 1
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + curtsyIn + curtsyHold
            ) {
                withAnimation(.easeOut(duration: curtsyOut)) {
                    italicProgress = 0
                }
            }
        }
    }
}

#endif  // canImport(UIKit)
