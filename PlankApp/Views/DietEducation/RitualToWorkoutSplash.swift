import SwiftUI

/// Phase 9.24 — bridge overlay that hides the cover-dismiss +
/// cover-present animations between a JeniMethod ritual and the
/// routine session. Both `JeniMethodRitualView` and `HomeView`
/// render this view, gated by the same `@AppStorage("ritualToWorkoutTransition")`
/// flag — so when the flag flips true, both stacks show the splash at
/// the same time. The ritual cover then dismisses underneath the
/// already-opaque splash; HomeView's splash is already up to receive
/// the hand-off; the workout cover comes up underneath; once everything
/// has settled the flag flips false and the splash fades out, revealing
/// the routine pre-session.
///
/// Visual: same cream→pink gradient as the ritual background + the
/// breath_bloom asset gently breathing + a quiet loading caption.
/// Reduce-motion gates the bloom animation (still shown, but static).
struct RitualToWorkoutSplash: View {
    @State private var bloomScale: CGFloat = 0.85
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Cream → soft pink gradient. Same colors as
            // JeniMethodRitualView.ritualBackground so the visual
            // continuity from the ritual into the splash is total.
            LinearGradient(
                colors: [
                    Color(hex: "#FDF6F4"),  // bgPrimary (cream)
                    Color(hex: "#F5D5D8"),  // accentSubtle (soft pink)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Phase 9.25 — text removed. The splash is purely a
            // continuation of the ritual's bloom. No loading copy
            // means it reads as "ritual still here, slowly settling"
            // rather than "interstitial screen."
            Image("breath_bloom")
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
                .scaleEffect(bloomScale)
                .shadow(color: Color(hex: "#C4677A").opacity(0.18),
                        radius: 14, x: 0, y: 6)
        }
        .onAppear {
            guard !reduceMotion else {
                bloomScale = 1.0
                return
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                bloomScale = 1.05
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Getting your session ready")
    }
}

#if DEBUG
#Preview {
    RitualToWorkoutSplash()
}
#endif
