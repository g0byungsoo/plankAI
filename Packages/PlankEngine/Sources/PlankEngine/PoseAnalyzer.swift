import Foundation

/// Analyzes raw joint positions to determine plank form quality.
///
/// ## Detection Pipeline (based on real coaching methodology)
///
/// 1. **Body detected?** — Need at least shoulder + hip + one lower body joint
/// 2. **In plank posture?** — Body must be roughly horizontal (not standing/sitting).
///    Uses the "broomstick test" concept: shoulder, hip, ankle should be near-collinear
///    and oriented more horizontally than vertically.
/// 3. **Plank type** — Standard (arms straight) vs forearm (elbows bent).
/// 4. **Form faults** (from most to least severe):
///    - **Hip sag**: Hips drop below the shoulder→ankle reference line
///    - **Hip pike**: Butt too high (downward-dog shape)
///    - **Shoulder creep**: Shoulders hunched toward ears or protracted forward
/// 5. **Good form**: Passes all checks → straight line head to heels
///
/// All angle/position checks use the "signed distance from reference line" approach
/// rather than absolute angles — this is more robust to camera perspective.
public struct PoseAnalyzer: Sendable {

    public struct Thresholds: Sendable {
        public var minConfidence: Double
        /// How far hip can drop below shoulder→ankle line (as fraction of body length)
        public var hipSagThreshold: Double
        /// How far hip can rise above shoulder→ankle line
        public var hipPikeThreshold: Double
        /// Max Y-difference between shoulder and ear/head (shoulder shrug detection)
        public var shoulderCreepThreshold: Double

        public init(
            minConfidence: Double = 0.15,
            hipSagThreshold: Double = 0.08,
            hipPikeThreshold: Double = 0.10,
            shoulderCreepThreshold: Double = 0.06
        ) {
            self.minConfidence = minConfidence
            self.hipSagThreshold = hipSagThreshold
            self.hipPikeThreshold = hipPikeThreshold
            self.shoulderCreepThreshold = shoulderCreepThreshold
        }
    }

    public let thresholds: Thresholds

    public init(thresholds: Thresholds = .init()) {
        self.thresholds = thresholds
    }

    // MARK: - Main Analysis

    public func analyze(_ frame: PoseFrame) -> FormAssessment {
        // Step 1: Do we have enough joints?
        let shoulder = avg(.leftShoulder, .rightShoulder, in: frame)
        let hip = joint(.root, in: frame) ?? avg(.leftHip, .rightHip, in: frame)
        let ankle = avg(.leftAnkle, .rightAnkle, in: frame)
        let knee = avg(.leftKnee, .rightKnee, in: frame)

        guard let shoulder, let hip else {
            return .notDetected
        }

        // Need at least one lower body point
        let lowerBody = ankle ?? knee
        guard let lowerBody else {
            return .notDetected
        }

        // Check confidence
        let allJoints = [shoulder, hip, lowerBody]
        let avgConf = allJoints.map(\.confidence).reduce(0, +) / Double(allJoints.count)
        guard avgConf >= thresholds.minConfidence else {
            return .lowConfidence(avgConf)
        }

        // Step 2: Is the body in a plank posture? (horizontal, not standing)
        guard isHorizontal(shoulder: shoulder.pos, lowerBody: lowerBody.pos) else {
            return .notDetected
        }

        // Step 3: Detect plank type
        let plankType = detectPlankType(frame)

        // Step 4: Check form faults using reference line method
        // The reference line goes from shoulder to ankle/knee.
        // Hip should sit ON this line. Above = pike, below = sag.
        let hipDeviation = signedDistanceFromLine(
            point: hip.pos,
            lineStart: shoulder.pos,
            lineEnd: lowerBody.pos
        )

        // Body length for normalization
        let bodyLength = distance(shoulder.pos, lowerBody.pos)
        guard bodyLength > 0.05 else { return .notDetected } // too small to analyze

        let normalizedDeviation = hipDeviation / bodyLength

        // Check for knee drop — in a plank, legs are straight (hip-knee-ankle ~180°).
        // When knees hit the floor, this angle drops sharply (<140°).
        if let knee, let ankle {
            let kneeAngle = abs(angleBetweenPoints(hip.pos, knee.pos, ankle.pos))
            if kneeAngle < 140 {
                return .notDetected  // knees bent = not planking
            }
        }

        // In Vision coords (bottom-left origin), negative = below the line = sag
        // positive = above the line = pike
        if normalizedDeviation < -thresholds.hipSagThreshold {
            return .hipSag(deviation: normalizedDeviation)
        }

        if normalizedDeviation > thresholds.hipPikeThreshold {
            return .hipPike(deviation: normalizedDeviation)
        }

        // Check shoulder creep: are shoulders hunched up toward head?
        if let nose = joint(.nose, in: frame) {
            let shoulderToHead = abs(nose.pos.y - shoulder.pos.y)
            if shoulderToHead < thresholds.shoulderCreepThreshold {
                return .shoulderCreep(deviation: shoulderToHead)
            }
        }

        return .good(confidence: avgConf, plankType: plankType)
    }

    // MARK: - Plank Posture Detection

    /// Body is horizontal if the vertical spread is less than the horizontal spread.
    private func isHorizontal(shoulder: (x: Double, y: Double), lowerBody: (x: Double, y: Double)) -> Bool {
        let dx = abs(shoulder.x - lowerBody.x)
        let dy = abs(shoulder.y - lowerBody.y)

        // Need some horizontal spread to be a plank
        guard dx > 0.08 else { return false }

        // Vertical spread should be less than horizontal (body is more flat than upright)
        return dy < dx * 0.9
    }

    // MARK: - Plank Type

    private func detectPlankType(_ frame: PoseFrame) -> PlankType {
        guard let shoulder = avg(.leftShoulder, .rightShoulder, in: frame),
              let elbow = avg(.leftElbow, .rightElbow, in: frame),
              let wrist = avg(.leftWrist, .rightWrist, in: frame)
        else { return .unknown }

        let angle = abs(angleBetweenPoints(shoulder.pos, elbow.pos, wrist.pos))
        if angle > 150 { return .standard }
        if angle < 140 { return .forearm }
        return .unknown
    }

    // MARK: - Geometry Helpers

    /// Signed perpendicular distance from a point to a line.
    /// Positive = above the line, negative = below (in Vision coordinate space).
    private func signedDistanceFromLine(
        point: (x: Double, y: Double),
        lineStart: (x: Double, y: Double),
        lineEnd: (x: Double, y: Double)
    ) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return 0 }
        // Cross product gives signed area, divide by length for distance
        return ((point.x - lineStart.x) * dy - (point.y - lineStart.y) * dx) / len
    }

    private func distance(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
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
        return atan2(cross, dot) * 180.0 / .pi
    }

    // MARK: - Joint Access

    private struct DetectedJoint {
        let pos: (x: Double, y: Double)
        let confidence: Double
    }

    private func joint(_ name: JointName, in frame: PoseFrame) -> DetectedJoint? {
        guard let j = frame.joints[name], j.confidence > 0.01 else { return nil }
        return DetectedJoint(pos: (x: j.x, y: j.y), confidence: j.confidence)
    }

    private func avg(_ a: JointName, _ b: JointName, in frame: PoseFrame) -> DetectedJoint? {
        let ja = frame.joints[a]
        let jb = frame.joints[b]
        // Use whichever we have, prefer both
        if let ja, let jb, ja.confidence > 0.01, jb.confidence > 0.01 {
            return DetectedJoint(
                pos: (x: (ja.x + jb.x) / 2.0, y: (ja.y + jb.y) / 2.0),
                confidence: (ja.confidence + jb.confidence) / 2.0
            )
        }
        if let ja, ja.confidence > 0.01 { return DetectedJoint(pos: (x: ja.x, y: ja.y), confidence: ja.confidence) }
        if let jb, jb.confidence > 0.01 { return DetectedJoint(pos: (x: jb.x, y: jb.y), confidence: jb.confidence) }
        return nil
    }
}

/// Detected plank type.
public enum PlankType: String, Sendable, Equatable {
    case standard   // high plank — arms extended
    case forearm    // elbow plank — forearms on ground
    case unknown
}

public enum FormAssessment: Sendable, Equatable {
    case notDetected
    case lowConfidence(Double)
    case good(confidence: Double, plankType: PlankType)
    case hipSag(deviation: Double)
    case hipPike(deviation: Double)
    case shoulderCreep(deviation: Double)
}
