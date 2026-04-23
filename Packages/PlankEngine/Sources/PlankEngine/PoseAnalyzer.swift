import Foundation

/// Analyzes raw joint positions to determine form quality.
/// Pure computation, no side effects. Testable with synthetic data.
public struct PoseAnalyzer: Sendable {

    /// Thresholds calibrated from the day-1 spike.
    /// These are starting values, replaced by real data post-spike.
    public struct Thresholds: Sendable {
        public var minConfidence: Double
        public var hipAngleTolerance: Double  // degrees from baseline
        public var shoulderAngleTolerance: Double

        public init(
            minConfidence: Double = 0.5,
            hipAngleTolerance: Double = 10.0,
            shoulderAngleTolerance: Double = 8.0
        ) {
            self.minConfidence = minConfidence
            self.hipAngleTolerance = hipAngleTolerance
            self.shoulderAngleTolerance = shoulderAngleTolerance
        }
    }

    public let thresholds: Thresholds

    public init(thresholds: Thresholds = .init()) {
        self.thresholds = thresholds
    }

    /// The 6 key joints used for confidence averaging.
    private static let keyJoints: [JointName] = [
        .leftShoulder, .rightShoulder,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee
    ]

    /// Analyze a pose frame and return the raw form assessment.
    public func analyze(_ frame: PoseFrame) -> FormAssessment {
        let keyJointData = Self.keyJoints.compactMap { frame.joints[$0] }

        guard keyJointData.count >= 4 else {
            return .notDetected
        }

        let avgConfidence = keyJointData.map(\.confidence).reduce(0, +) / Double(keyJointData.count)

        guard avgConfidence >= thresholds.minConfidence else {
            return .lowConfidence(avgConfidence)
        }

        let hipAngle = computeHipAngle(frame)
        let shoulderAngle = computeShoulderAngle(frame)

        if let hipAngle, abs(hipAngle) > thresholds.hipAngleTolerance {
            return .hipSag(deviation: hipAngle)
        }

        if let shoulderAngle, abs(shoulderAngle) > thresholds.shoulderAngleTolerance {
            return .shoulderCreep(deviation: shoulderAngle)
        }

        return .good(confidence: avgConfidence)
    }

    /// Compute the hip sag angle.
    /// Measures deviation from a straight line between shoulder-hip-ankle.
    private func computeHipAngle(_ frame: PoseFrame) -> Double? {
        guard
            let shoulder = averageJoint(.leftShoulder, .rightShoulder, in: frame),
            let hip = averageJoint(.leftHip, .rightHip, in: frame),
            let ankle = averageJoint(.leftAnkle, .rightAnkle, in: frame)
        else { return nil }

        return angleBetweenPoints(shoulder, hip, ankle) - 180.0
    }

    /// Compute shoulder deviation from neutral.
    /// Measures whether shoulders are creeping forward of the wrists.
    private func computeShoulderAngle(_ frame: PoseFrame) -> Double? {
        guard
            let shoulder = averageJoint(.leftShoulder, .rightShoulder, in: frame),
            let elbow = averageJoint(.leftElbow, .rightElbow, in: frame),
            let wrist = averageJoint(.leftWrist, .rightWrist, in: frame)
        else { return nil }

        return angleBetweenPoints(shoulder, elbow, wrist) - 180.0
    }

    private func averageJoint(_ a: JointName, _ b: JointName, in frame: PoseFrame) -> (x: Double, y: Double)? {
        guard let ja = frame.joints[a], let jb = frame.joints[b] else { return nil }
        return (x: (ja.x + jb.x) / 2.0, y: (ja.y + jb.y) / 2.0)
    }

    private func angleBetweenPoints(
        _ a: (x: Double, y: Double),
        _ b: (x: Double, y: Double),
        _ c: (x: Double, y: Double)
    ) -> Double {
        let ba = (x: a.x - b.x, y: a.y - b.y)
        let bc = (x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let cross = ba.x * bc.y - ba.y * bc.x
        let angle = atan2(cross, dot)
        return angle * 180.0 / .pi
    }
}

public enum FormAssessment: Sendable, Equatable {
    case notDetected
    case lowConfidence(Double)
    case good(confidence: Double)
    case hipSag(deviation: Double)
    case shoulderCreep(deviation: Double)
}
