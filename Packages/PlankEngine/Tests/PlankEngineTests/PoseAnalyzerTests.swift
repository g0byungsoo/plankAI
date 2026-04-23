import Testing
@testable import PlankEngine

@Suite("PoseAnalyzer")
struct PoseAnalyzerTests {

    let analyzer = PoseAnalyzer()

    // MARK: - Helper

    func makeFrame(
        confidence: Double = 0.9,
        hipDeviation: Double = 0,  // 0 = straight line (good form)
        timestamp: TimeInterval = 0
    ) -> PoseFrame {
        // Simulate a plank: body roughly horizontal
        // Shoulder at (0.2, 0.5), Hip at (0.5, 0.5), Ankle at (0.8, 0.5)
        // Hip deviation moves the hip y-position up or down
        let hipY = 0.5 + (hipDeviation * 0.01)  // scale deviation to small pixel offsets

        let joints: [JointName: JointData] = [
            .leftShoulder: JointData(x: 0.2, y: 0.5, confidence: confidence),
            .rightShoulder: JointData(x: 0.2, y: 0.5, confidence: confidence),
            .leftHip: JointData(x: 0.5, y: hipY, confidence: confidence),
            .rightHip: JointData(x: 0.5, y: hipY, confidence: confidence),
            .leftKnee: JointData(x: 0.65, y: 0.5, confidence: confidence),
            .rightKnee: JointData(x: 0.65, y: 0.5, confidence: confidence),
            .leftAnkle: JointData(x: 0.8, y: 0.5, confidence: confidence),
            .rightAnkle: JointData(x: 0.8, y: 0.5, confidence: confidence),
            .leftElbow: JointData(x: 0.1, y: 0.5, confidence: confidence),
            .rightElbow: JointData(x: 0.1, y: 0.5, confidence: confidence),
            .leftWrist: JointData(x: 0.05, y: 0.5, confidence: confidence),
            .rightWrist: JointData(x: 0.05, y: 0.5, confidence: confidence),
        ]
        return PoseFrame(timestamp: timestamp, joints: joints)
    }

    // MARK: - Tests

    @Test("Good form returns .good assessment")
    func goodForm() {
        let frame = makeFrame(confidence: 0.9, hipDeviation: 0)
        let result = analyzer.analyze(frame)
        if case .good = result {
            // pass
        } else {
            Issue.record("Expected .good, got \(result)")
        }
    }

    @Test("Low confidence returns .lowConfidence")
    func lowConfidence() {
        let frame = makeFrame(confidence: 0.3)
        let result = analyzer.analyze(frame)
        if case .lowConfidence = result {
            // pass
        } else {
            Issue.record("Expected .lowConfidence, got \(result)")
        }
    }

    @Test("Missing joints returns .notDetected")
    func missingJoints() {
        let frame = PoseFrame(timestamp: 0, joints: [
            .leftShoulder: JointData(x: 0.2, y: 0.5, confidence: 0.9),
        ])
        let result = analyzer.analyze(frame)
        #expect(result == .notDetected)
    }

    @Test("Hip sag beyond threshold returns .hipSag")
    func hipSag() {
        // Large hip deviation
        let frame = makeFrame(confidence: 0.9, hipDeviation: 20)
        let result = analyzer.analyze(frame)
        if case .hipSag = result {
            // pass
        } else {
            Issue.record("Expected .hipSag, got \(result)")
        }
    }
}
