#if canImport(UIKit)
import SwiftUI

// MARK: - FoodActs (p65 — ONE speech-arrival grammar in the package)
//
// The package-local mirror of the app's JeniActs law, extracted from
// FoodAIConsentSheet (p64 wrote it privately there; p65's founder
// correction — "when Jeni has something to say, one thing at a time"
// — put a second package surface on the grammar, and two private
// copies of one law is how drift starts).
//
// Laws carried (identical to the app's):
//   · one act per 0.55s beat — a BLOCK of meaning needs air
//   · a tap anywhere lands every remaining act (impatience is a
//     valid input; repeat visitors wait for nothing)
//   · an act that has not arrived is invisible, un-hittable and
//     hidden from VoiceOver — the VALUE flips inside withAnimation,
//     so hit-testing and paint agree (the invisible-door class)
//   · Reduce Motion presents everything immediately
//   · the schedule rides the surface's own `.task`, so leaving the
//     surface cancels the walk

enum FoodActs {
    static let beat: TimeInterval = 0.55

    /// p66 — the mirror of `JeniActs.actionPause`: one absorb breath
    /// after the last thought, then the action arrives as its own
    /// event.
    static let actionPause: TimeInterval = 0.30

    /// Advance `current` one act per beat until `last`. Call from the
    /// surface's `.task`; cancellation ends the walk where it stands.
    /// p66 — each THOUGHT lands with a soft selection tick (the
    /// consult's acknowledgment, mirrored); the final act — the
    /// action — arrives after `actionPause`, silent: its motion says
    /// it is her turn.
    @MainActor
    static func run(
        _ current: Binding<Int>, to last: Int, reduceMotion: Bool
    ) async {
        guard current.wrappedValue < last else { return }
        if reduceMotion {
            current.wrappedValue = last
            return
        }
        let tick = UISelectionFeedbackGenerator()
        while current.wrappedValue < last {
            let isAction = current.wrappedValue == last - 1
            let pause = beat + (isAction ? actionPause : 0)
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard current.wrappedValue < last else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                current.wrappedValue += 1
            }
            if !isAction { tick.selectionChanged() }
        }
    }

    /// Complete every remaining act now (the tap-to-skip half).
    @MainActor
    static func complete(_ current: Binding<Int>, to last: Int) {
        guard current.wrappedValue < last else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            current.wrappedValue = last
        }
    }
}

struct FoodActModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var act: Int
    var current: Int

    func body(content: Content) -> some View {
        let on = current >= act
        content
            .opacity(on ? 1 : 0)
            .offset(y: on || reduceMotion ? 0 : 6)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }
}

extension View {
    /// Join a speech arrival at `act` (0 = with the surface itself).
    func foodAct(_ act: Int, current: Int) -> some View {
        modifier(FoodActModifier(act: act, current: current))
    }
}

#endif  // canImport(UIKit)
