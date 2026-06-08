#if canImport(UIKit)
import SwiftUI
import AVFoundation
import UIKit

// MARK: - FoodCameraPreviewView
//
// UIViewRepresentable that wraps an `AVCaptureVideoPreviewLayer` so
// the SwiftUI `PhotoCaptureView` can embed the live viewfinder feed.
//
// v1.0.8 Phase O (2026-06-08) — instant freeze via UIView snapshot.
// Previous attempts to draw the captured frame on top of the preview
// produced a visible geometry/aspect shift the moment of tap (CIImage
// from the pixel buffer rendered through SwiftUI .aspectRatio(.fill)
// had subtly different bounds than the Metal-backed preview layer's
// .resizeAspectFill).
//
// New approach: capture the exact rendered pixels via
// `UIView.snapshotView(afterScreenUpdates: false)` and add it as a
// subview at the same frame. The snapshot is a real UIView holding the
// exact compositor output — zero aspect difference, zero scale
// difference, pixel-perfect freeze.
//
// `isFrozen` is driven through FoodCameraManager so SwiftUI state can
// trigger the freeze without a binding.

public struct FoodCameraPreviewView: UIViewRepresentable {

    public let previewLayer: AVCaptureVideoPreviewLayer
    public let isFrozen: Bool

    public init(previewLayer: AVCaptureVideoPreviewLayer, isFrozen: Bool = false) {
        self.previewLayer = previewLayer
        self.isFrozen = isFrozen
    }

    public func makeUIView(context: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.backgroundColor = .black
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        return view
    }

    public func updateUIView(_ uiView: PreviewContainer, context: Context) {
        uiView.setFrozen(isFrozen)
    }
}

// MARK: - PreviewContainer

/// Custom UIView that resizes the AVCaptureVideoPreviewLayer to match
/// its own bounds on every layout pass, and supports adding/removing a
/// snapshot freeze overlay.
public final class PreviewContainer: UIView {
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    /// v1.0.8 Phase O — the snapshot view that visually freezes the
    /// preview during a scan. Held weakly via strong reference here
    /// because removeFromSuperview detaches it; we just clear our
    /// reference too.
    private var freezeOverlay: UIView?

    public override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        freezeOverlay?.frame = bounds
    }

    /// Add or remove the freeze overlay. Idempotent — calling
    /// setFrozen(true) twice replaces the existing snapshot with a
    /// fresh one (useful if the camera repositions between captures).
    func setFrozen(_ frozen: Bool) {
        if frozen {
            // Drop any prior snapshot first so we always show the
            // most-recent frame.
            freezeOverlay?.removeFromSuperview()
            freezeOverlay = nil

            // afterScreenUpdates: false — capture what's currently
            // composited on screen without waiting for any pending
            // UIKit updates. That's the instant-freeze beat: the
            // snapshot reflects the frame the user was looking at
            // at the moment of tap, not whatever lands a runloop
            // later.
            guard let snap = self.snapshotView(afterScreenUpdates: false) else {
                return
            }
            snap.frame = bounds
            snap.isUserInteractionEnabled = false
            freezeOverlay = snap
            addSubview(snap)
        } else {
            freezeOverlay?.removeFromSuperview()
            freezeOverlay = nil
        }
    }
}

#endif  // canImport(UIKit)
