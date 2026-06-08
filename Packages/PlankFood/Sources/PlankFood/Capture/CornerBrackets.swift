#if canImport(UIKit)
import SwiftUI

// MARK: - CornerBrackets
//
// v1.0.8 Phase H (2026-06-08) — adaptive corner brackets for the
// full-bleed food-scan camera. UX expert verdict:
//
//   "Drop the rotating AngularGradient border [from plank coach].
//    It's the right move for the plank coach (continuous biomechanical
//    feedback — eyes on body, peripheral check on chrome) and the
//    wrong move for food (a one-shot capture decision — eyes on
//    plate, then card).
//
//    Brackets say 'aim here'; borders say 'system status.' Food
//    capture is a composition decision — the user is choosing what
//    to include. Brackets give a target. A pulsing ring gives
//    anxiety on a one-shot moment."
//
// Spec from the expert:
//   - 4 L-shaped brackets at the safe-area corners
//   - 28pt arm length × 2pt stroke
//   - 16pt inset from safe-area edges
//   - State-driven color (cocoa idle / sage success / amber error)
//   - No neon — that signature stays with the plank coach
//
// Plank coach keeps its iconic rotating AngularGradient border.
// Food gets its own grammar. Two surfaces, two languages — both
// unmistakably JeniFit via shared palette + Fraunces voice.

struct CornerBrackets: View {

    enum State {
        /// Default — viewfinder is composing. Cocoa, 70% opacity,
        /// no animation.
        case idle
        /// During capture — soft sweep + cream interior glow.
        case scanning
        /// Just after a successful scan landed — sage, brief scale
        /// pop. Auto-decays back to idle after the result card mounts.
        case success
        /// On a no-food / failed scan — cocoa with a brief shake.
        case noFood
        /// On a transient error (network, server). Amber.
        case error
    }

    let state: State
    let inset: CGFloat
    let armLength: CGFloat
    let lineWidth: CGFloat

    init(
        state: State = .idle,
        inset: CGFloat = 16,
        armLength: CGFloat = 28,
        lineWidth: CGFloat = 2
    ) {
        self.state = state
        self.inset = inset
        self.armLength = armLength
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                bracket(.topLeading, in: geo.size)
                bracket(.topTrailing, in: geo.size)
                bracket(.bottomLeading, in: geo.size)
                bracket(.bottomTrailing, in: geo.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Color + opacity

    private var bracketColor: Color {
        switch state {
        case .idle, .scanning, .noFood:
            return FoodTheme.textPrimary
        case .success:
            return FoodTheme.stateGood
        case .error:
            return FoodTheme.stateWarn
        }
    }

    private var bracketOpacity: Double {
        switch state {
        case .idle, .noFood: return 0.7
        case .scanning, .error: return 0.9
        case .success: return 1.0
        }
    }

    // MARK: - Individual bracket

    /// L-shaped path at one of the four corners. Drawn as a single
    /// stroked Path so the corner kink reads as a clean miter instead
    /// of two separate lines meeting at right angles.
    private func bracket(_ corner: Corner, in size: CGSize) -> some View {
        let path = bracketPath(for: corner, in: size)
        return path
            .stroke(
                bracketColor,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .miter
                )
            )
            .opacity(bracketOpacity)
            .animation(.easeInOut(duration: 0.4), value: state)
    }

    private func bracketPath(for corner: Corner, in size: CGSize) -> Path {
        Path { p in
            switch corner {
            case .topLeading:
                p.move(to: CGPoint(x: inset, y: inset + armLength))
                p.addLine(to: CGPoint(x: inset, y: inset))
                p.addLine(to: CGPoint(x: inset + armLength, y: inset))
            case .topTrailing:
                p.move(to: CGPoint(x: size.width - inset - armLength, y: inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: inset + armLength))
            case .bottomLeading:
                p.move(to: CGPoint(x: inset, y: size.height - inset - armLength))
                p.addLine(to: CGPoint(x: inset, y: size.height - inset))
                p.addLine(to: CGPoint(x: inset + armLength, y: size.height - inset))
            case .bottomTrailing:
                p.move(to: CGPoint(x: size.width - inset - armLength, y: size.height - inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                p.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset - armLength))
            }
        }
    }

    private enum Corner {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }
}

#endif  // canImport(UIKit)
