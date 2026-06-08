#if canImport(UIKit)
import AVFoundation
import UIKit

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

        session.commitConfiguration()

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

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // v1.0.8 — resize + re-encode + EXIF strip OFF the main actor.
        // UIGraphicsImageRenderer.image() + UIImage.jpegData() are both
        // CPU-bound and previously blocked main for 2-3s on older
        // devices. Captured-data → detached task → jpeg returns to caller.
        let jpeg = try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: rawData) else {
                throw CameraError.encodingFailed
            }
            let resized = Self.resize(image, longestEdge: 768)
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
    public func captureStillAndFreeze() async throws -> Data {
        let jpeg = try await captureStill()
        // Decode off the main actor; assign back on @MainActor.
        let image = await Task.detached(priority: .userInitiated) {
            UIImage(data: jpeg)
        }.value
        self.frozenFrame = image
        return jpeg
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
