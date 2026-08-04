import AVFoundation
import UIKit
import Vision

// MARK: - BodyCaptureSession
//
// app v9 P1 — the guided scan's camera: the food camera's hardened
// still-capture core (resume-once continuation, freeze frame)
// crossed with the retired plank pose stack (front camera, live
// VNDetectHumanBodyPose at ~10fps). Fully on-device: frames feed
// the alignment engine and nothing else; no frame or photo ever
// touches the network from this layer (L4).
//
// The retired PlankApp/Camera/CameraManager.swift was salvaged into
// this file and deleted (dead-code law) — pose plumbing lives on
// where a live consumer exists.

@MainActor
@Observable
final class BodyCaptureSession: NSObject {

    private(set) var isRunning = false
    private(set) var permissionDenied = false
    /// The latest frame's gate joints, published for the engine +
    /// the ghost/coach chrome.
    private(set) var joints: [BodyScanAlignment.Key: BodyScanAlignment.Joint] = [:]
    /// Fraction of all 14 tracked joints confidently seen on the
    /// latest frame — stored as the record's poseQuality (a capture-
    /// quality fact, never a measurement — L3).
    private(set) var poseQuality: Double = 0
    /// Set at capture: the still, already mirrored to match preview.
    private(set) var frozenFrame: UIImage?

    #if DEBUG
    /// v10 QA (--uitest-scan-simulate-pose): the sim exposes no
    /// camera, so the guided flow's feel (coaching → arming frame →
    /// countdown → develop) was device-only. The pose script injects
    /// synthetic gate joints through the same published property the
    /// live pipeline writes — the engine, arming, and chrome can't
    /// tell the difference.
    func qaInject(joints: [BodyScanAlignment.Key: BodyScanAlignment.Joint], quality: Double) {
        self.joints = joints
        self.poseQuality = quality
    }
    #endif

    let previewLayer = AVCaptureVideoPreviewLayer()

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "app.jeni.bodyscan.pose", qos: .userInitiated)
    /// Confined to processingQueue (the sample-buffer delegate's
    /// queue) — never touched from the MainActor.
    private let frameSkipper = FrameSkipper(every: 3)
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    // MARK: - Lifecycle

    func requestPermissionAndStart() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
        } else {
            permissionDenied = (status != .authorized)
        }
        guard !permissionDenied else { return }
        start()
    }

    private func start() {
        guard !isRunning else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ), let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        // Mirror the pose stream so joint x matches what she sees.
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }
        captureSession.commitConfiguration()

        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill

        let session = captureSession
        processingQueue.async { session.startRunning() }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        let session = captureSession
        processingQueue.async { session.stopRunning() }
        isRunning = false
    }

    // MARK: - Still capture (resume-once funnel)

    /// Captures one still, mirrored to match the preview, and
    /// freezes the frame for the landed moment. nil on failure.
    func captureStill() async -> UIImage? {
        guard isRunning, captureContinuation == nil else { return nil }
        if let connection = photoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func resumeCapture(with image: UIImage?) {
        frozenFrame = image
        captureContinuation?.resume(returning: image)
        captureContinuation = nil
    }
}

// MARK: - Photo delegate

extension BodyCaptureSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage? = {
            guard error == nil, let data = photo.fileDataRepresentation(),
                  let raw = UIImage(data: data) else { return nil }
            return raw
        }()
        Task { @MainActor in
            self.resumeCapture(with: image)
        }
    }
}

// MARK: - Pose stream

extension BodyCaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Every 3rd frame ≈ 10fps of pose from a 30fps stream —
        // enough for coaching, kind to thermals (the salvaged
        // plank-stack cadence).
        guard frameSkipper.shouldProcess(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else {
            Task { @MainActor in
                self.joints = [:]
                self.poseQuality = 0
            }
            return
        }

        let gateMapping: [(VNHumanBodyPoseObservation.JointName, BodyScanAlignment.Key)] = [
            (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
            (.leftHip, .leftHip), (.rightHip, .rightHip),
            (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle),
        ]
        var gate: [BodyScanAlignment.Key: BodyScanAlignment.Joint] = [:]
        for (vn, key) in gateMapping {
            if let p = try? observation.recognizedPoint(vn), p.confidence > 0.01 {
                gate[key] = .init(p.location.x, p.location.y, confidence: Double(p.confidence))
            }
        }

        let allJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
        ]
        let seen = allJoints.filter {
            ((try? observation.recognizedPoint($0))?.confidence ?? 0) > Float(BodyScanAlignment.minConfidence)
        }.count
        let quality = Double(seen) / Double(allJoints.count)

        Task { @MainActor in
            self.joints = gate
            self.poseQuality = quality
        }
    }
}

/// Queue-confined frame counter — the sample-buffer delegate runs on
/// one serial queue, so a plain counter behind a final class is safe
/// and never touches the MainActor per frame.
private final class FrameSkipper: @unchecked Sendable {
    private let every: Int
    private var count = 0
    init(every: Int) { self.every = every }
    func shouldProcess() -> Bool {
        count += 1
        return count % every == 0
    }
}
