#if canImport(UIKit)
import SwiftUI

// MARK: - Food rail delight motion
//
// Reusable, reduce-motion-gated entrance moments for the snap-food
// result. Kept here (public) so both the in-package cards and the
// app-target debug harness share one definition.

public extension View {
    /// Card-land — the floating card settles in with a soft spring
    /// (subtle scale + fade) so it reads as *arriving over* the photo,
    /// not just being there. Layers under the per-zone content cascade.
    func cardLand() -> some View { modifier(CardLand()) }
}

struct CardLand: ViewModifier {
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(landed ? 1 : 0.965, anchor: .center)
            .opacity(landed ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { landed = true; return }
                withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) { landed = true }
            }
    }
}
#endif
