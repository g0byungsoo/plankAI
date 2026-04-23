import Foundation

/// The 6 form states from the session pipeline spec.
public enum FormState: String, Sendable, Equatable {
    case notInPosition
    case cameraBad
    case goodForm
    case hipSag
    case shoulderCreep
    case shaking // Phase 2 stretch goal
}

/// Events emitted by the session engine.
public enum SessionEvent: Sendable, Equatable {
    case stateChanged(FormState)
    case formFault(FormState)
    case recovery
    case sessionStart
    case sessionEnd(holdTime: TimeInterval, qualityScore: Double)
    case milestone(seconds: Int)
    case countdown(seconds: Int)
}

/// A single frame of pose data from the camera.
public struct PoseFrame: Sendable {
    public let timestamp: TimeInterval
    public let joints: [JointName: JointData]

    public init(timestamp: TimeInterval, joints: [JointName: JointData]) {
        self.timestamp = timestamp
        self.joints = joints
    }
}

public enum JointName: String, Sendable, Hashable, CaseIterable {
    case leftShoulder, rightShoulder
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
    case leftElbow, rightElbow
    case leftWrist, rightWrist
}

public struct JointData: Sendable {
    public let x: Double
    public let y: Double
    public let confidence: Double

    public init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}
