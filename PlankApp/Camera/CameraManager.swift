import AVFoundation
import Vision
import PlankEngine

/// Manages AVCaptureSession and feeds PoseFrames to PlankEngine at the configured FPS.
@Observable
final class CameraManager: NSObject {
    var isRunning = false
    var permissionStatus: AVAuthorizationStatus = .notDetermined

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.plankai.pose", qos: .userInitiated)

    private var frameCount = 0
    private var frameSkip = 3  // process every 3rd frame = 10fps from 30fps

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
        captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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

        captureSession.commitConfiguration()

        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
        isRunning = true
    }

    func stopSession() {
        guard isRunning else { return }
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

    /// The AVCaptureSession for SwiftUI's camera preview layer.
    var previewSession: AVCaptureSession { captureSession }
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

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard error == nil,
                  let observation = request.results?.first as? VNHumanBodyPoseObservation
            else { return }

            let frame = self?.convertToPoseFrame(observation, timestamp: timestamp)
            if let frame {
                self?.onPoseFrame?(frame)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func convertToPoseFrame(_ observation: VNHumanBodyPoseObservation, timestamp: TimeInterval) -> PoseFrame {
        var joints: [JointName: JointData] = [:]

        let mapping: [(VNHumanBodyPoseObservation.JointName, JointName)] = [
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
            if let point = try? observation.recognizedPoint(vnJoint) {
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
