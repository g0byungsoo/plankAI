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
/// Visual: a plain cream→soft-pink gradient, same colors as the lesson and
/// workout backgrounds, so the cover-swap underneath is invisible and the
/// workout reads as gently appearing out of the pink. Phase 10 — the
/// breath_bloom "bubble" was removed: users read it as a stray breathwork
/// screen flashing between the lesson and the workout. No image, no caption.
struct RitualToWorkoutSplash: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FDF6F4"),  // bgPrimary (cream)
                Color(hex: "#F5D5D8"),  // accentSubtle (soft pink)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Getting your session ready")
    }
}

#if DEBUG
#Preview {
    RitualToWorkoutSplash()
}
#endif
