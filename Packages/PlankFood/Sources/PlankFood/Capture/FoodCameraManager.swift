#if canImport(UIKit)
import AVFoundation
import UIKit
import Vision

// MARK: - FoodCameraManager
//
// Owns an `AVCaptureSession` configured for back-camera still photo
// capture. Distinct session from the existing pose-detection
// CameraManager in PlankApp/Camera/ (which is front-camera + continuous
// frame output for plank-form analysis) — keeping food capture in its
// own session avoids touching shipped plank code (v3 risk-isolation).
//
// Camera permission is shared at the OS level (single
// NSCameraUsageDescription Info.plist key + single `.video` auth
// status), so the existing plank flow's authorization grant covers
// food capture too. No new permission prompt for existing users.
//
// Output pipeline (per v3 §Architecture):
//   1. AVCapturePhotoOutput → AVCapturePhoto
//   2. fileDataRepresentation() → original JPEG bytes
//   3. resize to 1024px long edge + JPEG q0.8 (Edge Function input shape)
//   4. EXIF stripped by UIImage.jpegData (no metadata round-trip)

@MainActor
@Observable
public final class FoodCameraManager: NSObject {

    // MARK: - Public state

    public private(set) var isRunning = false
    public private(set) var permissionStatus: AVAuthorizationStatus = .notDetermined
    public private(set) var captureError: String?
    /// v1.0.7 in-viewfinder scan magic. After shutter tap, the
    /// captured photo is decoded into this UIImage and overlaid on top
    /// of the still-running AVCaptureVideoPreviewLayer so the user
    /// sees their actual photo "frozen" while the ScanningOverlay
    /// runs animations on top — no full-screen takeover, no preview
    /// flicker. Cleared when the result card dismisses.
    public private(set) var frozenFrame: UIImage?

    /// Surfaced for `FoodCameraPreviewView` (UIViewRepresentable).
    public let previewLayer = AVCaptureVideoPreviewLayer()

    // MARK: - Private

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    /// Holds the continuation so the async capture API can resume from
    /// the AVCapturePhotoCaptureDelegate callback.
    private var pendingCapture: CheckedContinuation<Data, Error>?
    private var rotationObservation: NSKeyValueObservation?

    /// v1.0.7 — post-completion debounce. The shutter Button's
    /// `.disabled(isCapturing)` guard covers in-flight taps; this
    /// covers the smaller window between capture completion and
    /// result-card render, AND covers any UI bug that programmatically
    /// fires `captureStill()` in a loop (animation tick, gesture
    /// recognizer, etc.). 3s is the smallest interval that gives the
    /// user time to see the freeze + scanning overlay before the next
    /// tap could plausibly be intentional.
    private var lastCaptureCompletedAt: Date?
    private static let captureDebounceInterval: TimeInterval = 3

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - Permission

    public func requestPermission() async -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionStatus = granted ? .authorized : .denied
        } else {
            permissionStatus = status
        }
        return permissionStatus
    }

    // MARK: - Session

    public func startSession() {
        guard !isRunning else { return }
        guard permissionStatus == .authorized else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Back camera, wide angle — food is in front of the user.
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            captureError = "no_camera_available"
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // v1.0.8 Phase C (2026-06-07) — apply iOS 17 ZSL stack.
        // Without these the default AVCapturePhotoOutput pipeline
        // triggers Deep Fusion / multi-frame fusion on every capture
        // (500-1500ms) plus lazy buffer allocation on first tap
        // (100-400ms). With ZSL + Responsive Capture + Fast Capture
        // + .speed prioritization, total tap → JPEG drops from 2-3s
        // to ~150-300ms on iPhone 12+. Quality is undetectable after
        // 768px downsample for GPT-5 vision.
        //
        // maxPhotoQualityPrioritization is the load-bearing cap —
        // settings.photoQualityPrioritization can't exceed it. Set
        // to .speed here, then re-set on each capture's settings
        // (Apple requires both).
        photoOutput.maxPhotoQualityPrioritization = .speed
        if photoOutput.isZeroShutterLagSupported {
            photoOutput.isZeroShutterLagEnabled = true
        }
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
        }
        if photoOutput.isFastCapturePrioritizationSupported {
            photoOutput.isFastCapturePrioritizationEnabled = true
        }

        session.commitConfiguration()

        // Pre-allocate the photo pipeline buffers with the settings
        // we'll actually use. Skipping this adds 100-400ms to the
        // FIRST tap (the only one that matters for first impressions).
        let warm = AVCapturePhotoSettings()
        warm.flashMode = .off
        warm.photoQualityPrioritization = .speed
        photoOutput.setPreparedPhotoSettingsArray([warm]) { _, _ in }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        // Sensible default rotation (portrait); RotationCoordinator could
        // be added later if landscape support matters. Food capture is
        // overwhelmingly portrait so deferring landscape is fine.
        if let previewConnection = previewLayer.connection {
            previewConnection.videoRotationAngle = 90
        }

        // Start session on a background queue to avoid blocking main.
        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = true
            }
        }
    }

    public func stopSession() {
        guard isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = false
            }
        }
    }

    // MARK: - Capture

    /// Capture a single still photo. Returns 768px JPEG @ q0.85 with
    /// EXIF stripped (the input shape food-vision Edge Function expects).
    ///
    /// v1.0.8 Phase A (2026-06-07):
    /// - 1024px/q0.8 → 768px/q0.85. OpenAI's hi-res vision pipeline
    ///   downsamples the short side to 768px regardless, so anything
    ///   larger is wasted upload bytes (–30-50% upload size on slow
    ///   networks). Quality bump to 0.85 retains ice/condensation detail
    ///   on transparent drinks (the Starbucks iced latte failure mode).
    /// - Image resize + JPEG encode moved OFF the main actor into a
    ///   detached background task. Previously these CPU-bound steps ran
    ///   synchronously on main and blocked the UI for 2-3s on older
    ///   devices, which is what made the shutter feel laggy.
    /// - Debounce timestamp moved AFTER the user has actually seen a
    ///   result (or never set, if the pipeline throws). The new
    ///   `recordCaptureFailed()` callback resets `lastCaptureCompletedAt`
    ///   to nil so the next intentional tap goes through immediately —
    ///   no more 3s wait after a network blip.
    ///
    /// Throws `CameraError.notReady` if called before `startSession()`,
    /// `CameraError.captureInProgress` if a capture is already in flight,
    /// `CameraError.captureTooSoon` if called within the debounce window
    /// after a SUCCESSFUL capture (3s — protects against UI loops on the
    /// happy path; cleared by recordCaptureFailed on the unhappy path),
    /// `CameraError.captureFailed` if the AVFoundation callback errors,
    /// `CameraError.encodingFailed` if image processing fails after capture.
    public func captureStill() async throws -> Data {
        guard isRunning else { throw CameraError.notReady }
        guard pendingCapture == nil else { throw CameraError.captureInProgress }
        if let last = lastCaptureCompletedAt,
           Date().timeIntervalSince(last) < Self.captureDebounceInterval {
            throw CameraError.captureTooSoon
        }

        let rawData: Data = try await withCheckedThrowingContinuation { continuation in
            self.pendingCapture = continuation

            // v1.0.8 Phase C — explicit .speed prioritization on every
            // capture. The output's maxPhotoQualityPrioritization caps
            // this, but Apple's API requires the setting to also be set
            // here per-call (the output ceiling alone doesn't propagate
            // to settings that don't ask for it). Defaults that we
            // intentionally LEAVE UNSET to keep the path fast:
            //   - isHighResolutionPhotoEnabled (off → smaller capture)
            //   - isDepthDataDeliveryEnabled (off → no LiDAR latency)
            //   - rawPhotoPixelFormatType (off → no DNG)
            //   - livePhotoMovieFileURL (off → no Live Photo)
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.photoQualityPrioritization = .speed
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // v1.0.8 — resize + re-encode + EXIF strip OFF the main actor.
        // UIGraphicsImageRenderer.image() + UIImage.jpegData() are both
        // CPU-bound and previously blocked main for 2-3s on older
        // devices. Captured-data → detached task → jpeg returns to caller.
        //
        // v1.0.8 Phase B (2026-06-07) — saliency crop BEFORE resize.
        // The original 4032×3024 still from AVCapturePhotoOutput has
        // way more pixel detail than the 768px GPT-5 input. By running
        // Vision's attention-based saliency detector on the full image
        // and cropping to the most-salient region (with 15% padding)
        // BEFORE we down-sample to 768px, the output JPEG contains a
        // 768px-tall crop of just the cup/plate/bowl — 2-3× more
        // pixels-on-food at the same token cost.
        //
        // Falls through to plain resize if saliency finds nothing
        // useful (e.g., a very busy frame or a CIImage conversion
        // failure). Adds ~80-150ms but that's compute we're already
        // doing on a background queue.
        let jpeg = try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: rawData) else {
                throw CameraError.encodingFailed
            }
            let cropped = Self.centerCropToSaliency(image) ?? image
            let resized = Self.resize(cropped, longestEdge: 768)
            guard let jpeg = resized.jpegData(compressionQuality: 0.85) else {
                throw CameraError.encodingFailed
            }
            return jpeg
        }.value

        // Stamp completion time AFTER the (successful) encode. If the
        // dispatcher downstream throws, PhotoCaptureView calls
        // recordCaptureFailed() to clear this so the user's next tap
        // isn't blocked by the debounce.
        lastCaptureCompletedAt = Date()

        return jpeg
    }

    /// v1.0.7 in-viewfinder magic — capture + decode + freeze in one
    /// call. Publishes the resized UIImage to `frozenFrame` so the
    /// SwiftUI overlay can paint it on top of the still-running
    /// AVCaptureVideoPreviewLayer. Same JPEG return value as
    /// `captureStill()` so `FoodCaptureDispatcher` doesn't change.
    ///
    /// v1.0.8 Phase C (2026-06-07) — INSTANT preview snapshot.
    /// Cal AI's signature trick: the viewfinder appears to freeze the
    /// exact moment of tap, even though AVCapturePhotoOutput hasn't
    /// returned yet. We render the current AVCaptureVideoPreviewLayer
    /// into a UIImage synchronously (~5-10ms), set frozenFrame from
    /// it INSTANTLY, then run the real capture in the background. By
    /// the time the user's eye registers the tap, the viewfinder is
    /// already showing a static still — perception of "instant
    /// capture" achieved even though the actual JPEG arrives 200ms
    /// later (or 2-3s on older devices without ZSL).
    ///
    /// When the real capture completes, frozenFrame is updated to the
    /// higher-fidelity decoded JPEG — the swap is invisible since both
    /// images are pixel-similar (preview frame and ZSL photo come from
    /// adjacent moments in the same ring buffer).
    public func captureStillAndFreeze() async throws -> Data {
        // INSTANT snapshot — synchronous, ~5-10ms.
        if let instant = snapshotPreviewLayer() {
            self.frozenFrame = instant
        }

        // Real capture runs in background. Sub-300ms with the iOS 17
        // ZSL stack applied in startSession(); upgrades frozenFrame
        // to the higher-fidelity decoded JPEG once it arrives.
        let jpeg = try await captureStill()
        let image = await Task.detached(priority: .userInitiated) {
            UIImage(data: jpeg)
        }.value
        self.frozenFrame = image
        return jpeg
    }

    /// v1.0.8 Phase C — render the current AVCaptureVideoPreviewLayer
    /// into a UIImage. The same frames the user is looking at right
    /// now, no AVFoundation pipeline involved. Used for the instant
    /// freeze so the viewfinder appears to stop the moment of tap.
    ///
    /// Performance: ~5-10ms on iPhone 12+, well below the 16ms frame
    /// budget. Returns nil if the layer hasn't yet drawn a frame
    /// (only possible on the very first tap immediately after
    /// startSession() — extremely rare since the user usually spends
    /// 1-2s composing before tapping).
    private func snapshotPreviewLayer() -> UIImage? {
        let bounds = previewLayer.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { ctx in
            previewLayer.render(in: ctx.cgContext)
        }
    }

    /// Clear the frozen overlay. Called from CaptureFlowView when the
    /// result phase dismisses or the user backs out to retake.
    public func clearFrozenFrame() {
        self.frozenFrame = nil
    }

    /// v1.0.8 — call after a failed scan (network blip, EF 5xx,
    /// no-food-in-frame) to clear the post-completion debounce. Lets
    /// the user immediately re-tap the shutter without waiting 3s.
    /// Founder bug: tap → 502 → tap again → 3s wait was crushing the
    /// retry loop on cafe wifi. No-op if there's no stamp to clear.
    public func recordCaptureFailed() {
        lastCaptureCompletedAt = nil
    }

    // MARK: - Helpers

    /// v1.0.8 Phase B (2026-06-07) — saliency-driven center crop.
    /// Runs Vision's attention-based saliency detector on `image` and
    /// returns a crop tight on the most-salient region plus 15% padding.
    /// Returns nil if saliency finds nothing (caller falls through to
    /// the un-cropped image).
    ///
    /// Why attention-based, not objectness-based: VNGenerateAttentionBased
    /// SaliencyImageRequest is calibrated for "what would a human look
    /// at first" — for our cohort food photos that's almost always the
    /// cup / plate / bowl. The objectness variant is calibrated for
    /// generic object detection and tends to fragment a single plate
    /// into several small bounding boxes.
    ///
    /// Padding rationale: 15% is enough to recover the cup rim,
    /// straw, garnish, or surrounding plate edge that the saliency
    /// box trims tightly. Without the pad, GPT-5 sometimes loses the
    /// container-shape signal that disambiguates cold-brew-in-a-Venti
    /// from cold-brew-in-a-rocks-glass.
    ///
    /// nonisolated so the detached-task path in captureStill() can
    /// call it off the main actor.
    private nonisolated static func centerCropToSaliency(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first as? VNSaliencyImageObservation,
              let salient = observation.salientObjects?.first else {
            return nil
        }
        // Vision returns normalized coordinates in the standard Vision
        // origin (lower-left). Convert to UIImage pixel coordinates
        // (upper-left origin) at the original cgImage resolution.
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let bbox = salient.boundingBox
        var crop = CGRect(
            x: bbox.minX * w,
            y: (1 - bbox.maxY) * h,
            width: bbox.width * w,
            height: bbox.height * h
        )
        // Add 15% padding on each side, clamped to image bounds.
        let padX = crop.width * 0.15
        let padY = crop.height * 0.15
        crop = crop.insetBy(dx: -padX, dy: -padY)
        crop = crop.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        // Sanity floor: if the crop is too tiny (< 10% of image area),
        // the saliency detector probably grabbed noise, not the subject.
        let croppedArea = crop.width * crop.height
        let fullArea = w * h
        guard croppedArea / fullArea > 0.10 else { return nil }
        guard let croppedCG = cgImage.cropping(to: crop) else { return nil }
        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // nonisolated so the v1.0.8 detached-task path in captureStill()
    // can call it off the main actor (UIGraphicsImageRenderer is
    // thread-safe; the only main-actor surface here was the @MainActor
    // class isolation, which doesn't apply to pure-function statics).
    private nonisolated static func resize(_ image: UIImage, longestEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > longestEdge else { return image }
        let scale = longestEdge / longest
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension FoodCameraManager: AVCapturePhotoCaptureDelegate {
    public nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // AVFoundation delivers this on a background queue. Hop to main
        // to resume the continuation since pendingCapture is MainActor.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let continuation = self.pendingCapture else { return }
            self.pendingCapture = nil

            if let error {
                continuation.resume(throwing: CameraError.captureFailed(underlying: error))
                return
            }
            guard let data = photo.fileDataRepresentation() else {
                continuation.resume(throwing: CameraError.encodingFailed)
                return
            }
            continuation.resume(returning: data)
        }
    }
}

// MARK: - CameraError

public enum CameraError: Error, Sendable {
    case notReady
    case captureInProgress
    /// Caller invoked `captureStill()` within the post-completion
    /// debounce window. Treated as a silent no-op at the UI layer —
    /// no error banner, no scan attempt. Protects against UI loops
    /// and back-to-back shutter taps the Button.disabled gate
    /// can't catch.
    case captureTooSoon
    case captureFailed(underlying: Error)
    case encodingFailed
}

#endif  // canImport(UIKit)
