import AVFoundation
import Vision
import PlankEngine

/// Manages AVCaptureSession and feeds PoseFrames to PlankEngine at the configured FPS.
@Observable
final class CameraManager: NSObject {
    var isRunning = false
    var permissionStatus: AVAuthorizationStatus = .notDetermined

    /// Detected joint positions in normalized Vision coordinates (0–1, bottom-left origin).
    var detectedJoints: [JointName: CGPoint] = [:]

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.plankai.pose", qos: .userInitiated)

    private var frameCount = 0
    private var frameSkip = 3  // process every 3rd frame = 10fps from 30fps

    /// The preview layer — owned by CameraManager so RotationCoordinator can reference it.
    let previewLayer = AVCaptureVideoPreviewLayer()

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    var onPoseFrame: ((PoseFrame) -> Void)?

    // MARK: - Setup

    func requestPermission() async -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionStatus = granted ? .authorized : .denied
        } else {
            permissionStatus = status
        }
        return permissionStatus
    }

    func startSession() {
        guard !isRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Mirror for front camera so joint coordinates match the preview.
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }

        captureSession.commitConfiguration()

        // Wire up the preview layer to this session.
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill

        // Use RotationCoordinator with the preview layer so it gives
        // UI-relative angles (not gravity/horizon-relative).
        let coordinator = AVCaptureDevice.RotationCoordinator(
            device: camera,
            previewLayer: previewLayer
        )
        rotationCoordinator = coordinator

        // Apply initial angles.
        if let previewConnection = previewLayer.connection {
            previewConnection.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        }
        if let captureConnection = videoOutput.connection(with: .video) {
            captureConnection.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        }

        // Observe rotation changes.
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] coord, _ in
            guard let self else { return }
            if let captureConnection = self.videoOutput.connection(with: .video) {
                captureConnection.videoRotationAngle = coord.videoRotationAngleForHorizonLevelCapture
            }
            DispatchQueue.main.async {
                if let previewConnection = self.previewLayer.connection {
                    previewConnection.videoRotationAngle = coord.videoRotationAngleForHorizonLevelPreview
                }
            }
        }

        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
        isRunning = true
    }

    func stopSession() {
        guard isRunning else { return }
        rotationObservation?.invalidate()
        rotationObservation = nil
        rotationCoordinator = nil
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        isRunning = false
    }

    /// Update frame skip based on thermal-adaptive FPS.
    func updateFrameSkip(targetFPS: Int) {
        guard targetFPS > 0 else {
            frameSkip = Int.max  // critical thermal: skip all
            return
        }
        frameSkip = max(1, 30 / targetFPS)
    }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCount += 1
        guard frameCount % frameSkip == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first as? VNHumanBodyPoseObservation else { return }

        let frame = convertToPoseFrame(observation, timestamp: timestamp)

        // Publish joint positions for pose overlay
        var points: [JointName: CGPoint] = [:]
        for (name, data) in frame.joints {
            points[name] = CGPoint(x: data.x, y: data.y)
        }
        DispatchQueue.main.async { [weak self] in
            self?.detectedJoints = points
        }

        onPoseFrame?(frame)
    }

    private func convertToPoseFrame(_ observation: VNHumanBodyPoseObservation, timestamp: TimeInterval) -> PoseFrame {
        var joints: [JointName: JointData] = [:]

        let mapping: [(VNHumanBodyPoseObservation.JointName, JointName)] = [
            (.nose, .nose),
            (.root, .root),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
        ]

        for (vnJoint, engineJoint) in mapping {
            if let point = try? observation.recognizedPoint(vnJoint),
               point.confidence > 0.01 {
                joints[engineJoint] = JointData(
                    x: point.location.x,
                    y: point.location.y,
                    confidence: Double(point.confidence)
                )
            }
        }

        return PoseFrame(timestamp: timestamp, joints: joints)
    }
}
