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

    /// Capture a single still photo. Returns 1024px JPEG @ q0.8 with
    /// EXIF stripped (the input shape food-vision Edge Function expects).
    ///
    /// Throws `CameraError.notReady` if called before `startSession()`,
    /// `CameraError.captureFailed` if the AVFoundation callback errors,
    /// `CameraError.encodingFailed` if image processing fails after capture.
    public func captureStill() async throws -> Data {
        guard isRunning else { throw CameraError.notReady }
        guard pendingCapture == nil else { throw CameraError.captureInProgress }

        let rawData: Data = try await withCheckedThrowingContinuation { continuation in
            self.pendingCapture = continuation

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // Resize + re-encode + EXIF strip.
        guard let image = UIImage(data: rawData) else {
            throw CameraError.encodingFailed
        }
        let resized = Self.resize(image, longestEdge: 1024)
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            throw CameraError.encodingFailed
        }
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

    // MARK: - Helpers

    private static func resize(_ image: UIImage, longestEdge: CGFloat) -> UIImage {
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
    case captureFailed(underlying: Error)
    case encodingFailed
}

#endif  // canImport(UIKit)
