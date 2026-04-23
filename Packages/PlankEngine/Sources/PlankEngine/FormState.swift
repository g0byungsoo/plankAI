import Foundation

/// Form states for the session pipeline.
public enum FormState: String, Sendable, Equatable {
    case notInPosition   // not detected or not in plank posture
    case cameraBad       // low confidence / can't see body
    case goodForm        // proper plank alignment
    case hipSag          // hips dropping below shoulder-ankle line
    case hipPike         // butt too high (inverted V / downward dog)
    case shoulderCreep   // shoulders hunched up / forward
    case shaking         // Phase 2 stretch goal
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
    case nose
    case leftShoulder, rightShoulder
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case root  // center hip point
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
