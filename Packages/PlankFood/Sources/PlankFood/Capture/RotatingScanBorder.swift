#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - RotatingScanBorder
//
// v1.0.8 Phase L (2026-06-08) — hot pink scan border, rewritten per
// founder direction:
//   "stop revolving animation for border and make it hot pink. can we
//    actually mimic this app's camera mode — hot pink and the hot
//    pink revolves when scanning."
//
// Behavior:
//   - Idle: static hot-pink border, no rotation. Calm, says "ready."
//   - Scanning: AngularGradient revolves at one rotation per ~3.5s
//     for clear "working" motion. Speed bumped from the prior 6s
//     because the reference app spins noticeably faster than the
//     plank coach's biomechanical-feedback border.
//   - Error: static hot pink (same as idle — no rotation drama).
//
// Implementation note — TimelineView(.animation(paused:)) is the
// rotation driver. When `isScanning` flips false, the timeline
// freezes its date, the computed rotation locks in place, and the
// view stops doing layout work. No `withAnimation(.repeatForever)`
// state to manage; no animation-cancellation gymnastics on transition.
//
// PlankFood is a leaf SPM package and can't import the main app, so
// the UIScreen.displayCornerRadius extension is duplicated here. Swift's
// per-module extension scope keeps this conflict-free with the
// SessionView copy.

private let hotPink = Color(red: 1.0, green: 0.075, blue: 0.94)  // #FF13F0

struct RotatingScanBorder: View {
    let isScanning: Bool
    let isError: Bool

    init(isScanning: Bool = false, isError: Bool = false) {
        self.isScanning = isScanning
        self.isError = isError
    }

    /// 3.5s per revolution while scanning. Reference app spins this
    /// fast — quick enough to read as "actively working" but slow
    /// enough not to be anxiety-inducing.
    private let rotationDuration: Double = 3.5

    private var borderWidth: CGFloat {
        isScanning ? 10 : 8
    }

    /// Hot pink throughout. Idle stops short of full saturation so the
    /// border feels "ready" rather than "running"; scanning goes full
    /// hot pink + gradient stops for the rotating shimmer.
    private var gradientColors: [Color] {
        if isScanning {
            return [
                hotPink,
                hotPink.opacity(0.35),
                hotPink,
                hotPink.opacity(0.55),
            ]
        } else {
            // Solid saturation when idle — no gradient stops, so
            // rotation (if it ever fired) would be invisible.
            return [hotPink.opacity(0.85), hotPink.opacity(0.85)]
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isScanning)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let phase = (elapsed.truncatingRemainder(dividingBy: rotationDuration))
                        / rotationDuration
            let angle = phase * 360.0

            GeometryReader { _ in
                let screenRadius = UIScreen.main.displayCornerRadius
                RoundedRectangle(cornerRadius: max(screenRadius - borderWidth / 2, 0))
                    .inset(by: borderWidth / 2)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors + gradientColors,
                            center: .center,
                            angle: .degrees(angle)
                        ),
                        lineWidth: borderWidth
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.35), value: isScanning)
    }
}

// MARK: - Screen corner radius

extension UIScreen {
    /// The physical display corner radius. Uses the private
    /// `_displayCornerRadius` key with a safe fallback for devices
    /// where it's unavailable. Duplicated from PlankApp's SessionView
    /// — see file header for why.
    fileprivate var displayCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        guard let radius = value(forKey: key) as? CGFloat, radius > 0 else {
            return 55
        }
        return radius
    }
}

#endif  // canImport(UIKit)
