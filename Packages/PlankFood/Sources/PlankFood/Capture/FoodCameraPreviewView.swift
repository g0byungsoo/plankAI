#if canImport(UIKit)
import SwiftUI
import AVFoundation
import UIKit

// MARK: - FoodCameraPreviewView
//
// UIViewRepresentable that wraps an `AVCaptureVideoPreviewLayer` so
// the SwiftUI `PhotoCaptureView` can embed the live viewfinder feed
// inside the scrapbook frame chrome.
//
// Why a custom UIView instead of SwiftUI's `Camera` (when available)
// or `PhotosPicker`: the v5 D37 lock requires a custom scrapbook frame
// around the viewfinder (NOT iOS's default black camera UI), and we
// need direct access to the preview layer to size + position it
// inside the brand chrome.

public struct FoodCameraPreviewView: UIViewRepresentable {

    public let previewLayer: AVCaptureVideoPreviewLayer

    public init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
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
        // Layout pass keeps the preview layer matching the container's
        // current bounds. SwiftUI doesn't push layout to the UIView
        // synchronously; PreviewContainer.layoutSubviews handles it.
    }
}

// MARK: - PreviewContainer

/// Custom UIView that resizes the AVCaptureVideoPreviewLayer to match
/// its own bounds on every layout pass. Without this, the preview
/// layer is fixed at its initial size and doesn't reflow when SwiftUI
/// re-lays-out the parent.
public final class PreviewContainer: UIView {
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    public override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

#endif  // canImport(UIKit)
