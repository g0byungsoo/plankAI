import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - BodySilhouetteRenderer
//
// app v9 P1 — her figure as an ink drawing on paper: on-device
// person segmentation (Vision, .accurate) rendered in the one-colour
// identity law — ink #2A1F1E on paper #FCFAF7, nothing else. The
// silhouette is the DEFAULT face of every scan (D2); the pixels
// never leave the device (L4), and no number is ever derived from
// the mask (L3 — it is a picture, not a measurement).
//
// Graceful empties: a frame with no person (sim, mis-fire) renders
// plain paper — never an error state on a body surface.

enum BodySilhouetteRenderer {

    /// Matches Palette.ink / Palette.bgPrimary (locked tokens).
    private static let ink = CIColor(red: 42/255, green: 31/255, blue: 30/255)
    private static let paper = CIColor(red: 252/255, green: 250/255, blue: 247/255)

    /// Renders the ink-on-paper silhouette for a captured still.
    /// Runs Vision + CoreImage off the caller's actor; call from a
    /// background task.
    static func render(from photo: UIImage) -> UIImage {
        guard let cgImage = photo.cgImage else { return paperCanvas(size: photo.size) }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let mask = request.results?.first?.pixelBuffer else {
            return paperCanvas(size: photo.size)
        }

        let source = CIImage(cgImage: cgImage)
        var maskImage = CIImage(cvPixelBuffer: mask)
        // The mask arrives at model resolution; scale to the photo.
        let scaleX = source.extent.width / maskImage.extent.width
        let scaleY = source.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let inkField = CIImage(color: ink).cropped(to: source.extent)
        let paperField = CIImage(color: paper).cropped(to: source.extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = inkField
        blend.backgroundImage = paperField
        blend.maskImage = maskImage
        guard let output = blend.outputImage else { return paperCanvas(size: photo.size) }

        let context = CIContext()
        guard let rendered = context.createCGImage(output, from: source.extent) else {
            return paperCanvas(size: photo.size)
        }
        return UIImage(cgImage: rendered, scale: photo.scale, orientation: photo.imageOrientation)
    }

    private static func paperCanvas(size: CGSize) -> UIImage {
        let safe = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        let renderer = UIGraphicsImageRenderer(size: safe)
        return renderer.image { ctx in
            UIColor(red: 252/255, green: 250/255, blue: 247/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: safe))
        }
    }
}
