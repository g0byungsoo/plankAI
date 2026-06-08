#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - RotatingScanBorder
//
// v1.0.8 (2026-06-07) — full-screen rotating AngularGradient border,
// mirrors the plank coach session signature. Founder override of the
// prior corner-bracket choice: "i wanted the revolving pink border
// like plank coach AI instead of the design we have now."
//
// Same construction as PlankApp/Views/Session/SessionView.swift —
// uses the device's actual physical screen corner radius so the
// stroke sits flush against the iPhone's curved edges. PlankFood is a
// leaf SPM package and can't import the main app, so the UIScreen
// extension is duplicated here (Swift's per-module extension scope
// keeps this conflict-free with the SessionView copy).
//
// Color logic for the food camera (one-shot capture, not continuous
// biomechanics like plank):
//   - idle    → light brand pink (accentSubtle), 0.6 opacity
//   - scanning → bright brand rose (accent), 0.95 opacity
//   - error   → bright brand rose, 0.95 opacity
//
// Plank coach uses neon green/pink because pose state changes mid-hold
// and the user is glancing at the chrome peripherally. Food capture is
// a one-shot decision where the camera FRAME is the subject — so we
// keep the brand pink palette here. The motion (rotating gradient) is
// the recognizable signal; the color stays JeniFit coquette.

struct RotatingScanBorder: View {
    let rotation: Double
    let isScanning: Bool
    let isError: Bool

    init(rotation: Double, isScanning: Bool = false, isError: Bool = false) {
        self.rotation = rotation
        self.isScanning = isScanning
        self.isError = isError
    }

    private var borderColors: [Color] {
        if isError {
            return [FoodTheme.accent, FoodTheme.accent.opacity(0.4), FoodTheme.accent, FoodTheme.accent.opacity(0.6)]
        } else if isScanning {
            return [FoodTheme.accent, FoodTheme.accent.opacity(0.4), FoodTheme.accent, FoodTheme.accent.opacity(0.6)]
        } else {
            return [FoodTheme.accentSubtle, FoodTheme.accentSubtle.opacity(0.2), FoodTheme.accentSubtle, FoodTheme.accentSubtle.opacity(0.4)]
        }
    }

    private var borderWidth: CGFloat {
        isScanning ? 10 : 8
    }

    var body: some View {
        GeometryReader { _ in
            let screenRadius = UIScreen.main.displayCornerRadius
            RoundedRectangle(cornerRadius: max(screenRadius - borderWidth / 2, 0))
                .inset(by: borderWidth / 2)
                .stroke(
                    AngularGradient(
                        colors: borderColors + borderColors,
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: borderWidth
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
