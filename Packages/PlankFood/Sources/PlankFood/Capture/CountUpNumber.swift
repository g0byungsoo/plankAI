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
// Used by ResultDecisionCard (slide 1 calorie + protein co-hero).

public struct CountUpNumber: View {

    public let target: Int
    public let fontName: String        // "JeniHeroSerif-Regular"
    public let italicFontName: String  // "JeniHeroSerif-Italic"
    public let size: CGFloat
    public let color: Color
    public var rollDuration: Double = 0.9
    public var curtsyDelay: Double = 0.95   // when after onAppear the curtsy fires
    public var curtsyIn: Double = 0.14      // 140ms italic-in
    public var curtsyHold: Double = 0.06    // 60ms hold
    public var curtsyOut: Double = 0.18     // 180ms roman-out

    @State private var displayedValue: Int = 0
    @State private var italicProgress: Double = 0  // 0 = roman, 1 = italic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        target: Int,
        fontName: String,
        italicFontName: String,
        size: CGFloat,
        color: Color,
        rollDuration: Double = 0.9,
        curtsyDelay: Double = 0.95,
        curtsyIn: Double = 0.14,
        curtsyHold: Double = 0.06,
        curtsyOut: Double = 0.18
    ) {
        self.target = target
        self.fontName = fontName
        self.italicFontName = italicFontName
        self.size = size
        self.color = color
        self.rollDuration = rollDuration
        self.curtsyDelay = curtsyDelay
        self.curtsyIn = curtsyIn
        self.curtsyHold = curtsyHold
        self.curtsyOut = curtsyOut
    }

    public var body: some View {
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
