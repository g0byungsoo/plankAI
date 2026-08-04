import Foundation
import CoreGraphics
import UIKit

// MARK: - WaistCrop (v10.2 — the abdomen band)
//
// The check-in records ONLY the waist region (02_RELAUNCH §2):
// consistency over completeness. Pure math from the pose joints to
// a band rect in Vision-normalized space (0-1, bottom-left origin,
// mirroring the session's joint contract), plus the image-space
// crop. The band spans from just under the ribs to the hip crest —
// derived from the shoulder→hip axis, the two landmarks the gate
// already tracks. No joints (the sim; a headless hold) → a
// centered default band, so the ritual never blocks.
//
// L3 stands: the band is evidence, never a measurement — nothing
// numeric is derived from it. L4 strengthens: the full frame is
// never written; the record holds a band of a torso and nothing
// else.

enum WaistCrop {

    /// Vision-normalized band (bottom-left origin).
    struct Band: Equatable {
        /// Top of the band (higher y = higher on the body).
        let top: Double
        let bottom: Double
        let centerX: Double

        var height: Double { max(0.0001, top - bottom) }
    }

    /// The band when nothing anchors it: the middle of the frame,
    /// where a natural chest-height mirror hold puts the abdomen.
    static let defaultBand = Band(top: 0.62, bottom: 0.38, centerX: 0.5)

    static let minConfidence: Double = 0.3

    /// Joints → the abdomen band. Needs at least one shoulder and
    /// one hip; the band sits on the shoulder→hip axis: from 15%
    /// above the hips (the crest) to 62% of the way toward the
    /// shoulders (under the ribs).
    static func band(
        from joints: [BodyScanAlignment.Key: BodyScanAlignment.Joint]
    ) -> Band? {
        let confident = joints.filter { $0.value.confidence >= minConfidence }
        let shoulders = [confident[.leftShoulder], confident[.rightShoulder]]
            .compactMap { $0 }
        let hips = [confident[.leftHip], confident[.rightHip]]
            .compactMap { $0 }
        guard !shoulders.isEmpty, !hips.isEmpty else { return nil }
        let shoulderY = shoulders.map(\.y).reduce(0, +) / CGFloat(shoulders.count)
        let hipY = hips.map(\.y).reduce(0, +) / CGFloat(hips.count)
        let centerX = (shoulders + hips).map(\.x).reduce(0, +)
            / CGFloat(shoulders.count + hips.count)
        let axis = shoulderY - hipY
        guard axis > 0.02 else { return nil }
        let bottom = Double(hipY - axis * 0.15)
        let top = Double(hipY + axis * 0.62)
        return Band(
            top: min(1, max(0, top)),
            bottom: min(1, max(0, bottom)),
            centerX: Double(min(1, max(0, centerX)))
        )
    }

    /// Horizontal reach around the body's center — wide enough for
    /// the waist and the arms' inner line, no dead camera margins.
    static let halfWidth: Double = 0.33

    /// The crop rect in image space (UIKit orientation, y down) for
    /// a band over an image of the given pixel size: the vertical
    /// band × a centered horizontal window, clamped to the frame.
    static func cropRect(for band: Band, in size: CGSize) -> CGRect {
        let topYDown = (1 - band.top) * size.height
        let height = band.height * size.height
        let left = min(
            max(0, (band.centerX - Self.halfWidth) * size.width),
            size.width - 1
        )
        let width = min(Self.halfWidth * 2 * size.width, size.width - left)
        return CGRect(
            x: left,
            y: min(max(0, topYDown), size.height - 1),
            width: width,
            height: min(height, size.height - topYDown)
        )
    }

    /// Crop a captured still to the band. The still is normalized
    /// to .up FIRST — a real camera photo carries EXIF orientation,
    /// and cropping its raw cg buffer with a portrait-space rect
    /// mangles the frame (the device walk's "halved" scan traced
    /// here; fabricated sim stills are always .up and never caught
    /// it). Failing everything (a degenerate rect), the upright
    /// original returns — the keep never breaks.
    static func image(_ image: UIImage, band: Band) -> UIImage {
        let upright = normalizedUp(image)
        let pixelSize = CGSize(
            width: upright.size.width * upright.scale,
            height: upright.size.height * upright.scale
        )
        let rect = cropRect(for: band, in: pixelSize).integral
        guard rect.width > 16, rect.height > 16,
              let cg = upright.cgImage?.cropping(to: rect) else { return upright }
        return UIImage(cgImage: cg, scale: upright.scale, orientation: .up)
    }

    /// Redraws an image so its cg buffer matches its display
    /// orientation (cg space == UI space). Identity for .up images.
    static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format)
            .image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
    }
}
