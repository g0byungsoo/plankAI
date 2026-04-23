import Testing
@testable import PlankEngine

@Suite("PlankSessionEngine State Machine")
struct StateMachineTests {

    // MARK: - Helper

    func makeGoodFrame(at time: TimeInterval) -> PoseFrame {
        let joints: [JointName: JointData] = [
            .leftShoulder: JointData(x: 0.2, y: 0.5, confidence: 0.9),
            .rightShoulder: JointData(x: 0.2, y: 0.5, confidence: 0.9),
            .leftHip: JointData(x: 0.5, y: 0.5, confidence: 0.9),
            .rightHip: JointData(x: 0.5, y: 0.5, confidence: 0.9),
            .leftKnee: JointData(x: 0.65, y: 0.5, confidence: 0.9),
            .rightKnee: JointData(x: 0.65, y: 0.5, confidence: 0.9),
            .leftAnkle: JointData(x: 0.8, y: 0.5, confidence: 0.9),
            .rightAnkle: JointData(x: 0.8, y: 0.5, confidence: 0.9),
            .leftElbow: JointData(x: 0.1, y: 0.5, confidence: 0.9),
            .rightElbow: JointData(x: 0.1, y: 0.5, confidence: 0.9),
            .leftWrist: JointData(x: 0.05, y: 0.5, confidence: 0.9),
            .rightWrist: JointData(x: 0.05, y: 0.5, confidence: 0.9),
        ]
        return PoseFrame(timestamp: time, joints: joints)
    }

    func makeLowConfidenceFrame(at time: TimeInterval) -> PoseFrame {
        let joints: [JointName: JointData] = [
            .leftShoulder: JointData(x: 0.2, y: 0.5, confidence: 0.2),
            .rightShoulder: JointData(x: 0.2, y: 0.5, confidence: 0.2),
            .leftHip: JointData(x: 0.5, y: 0.5, confidence: 0.2),
            .rightHip: JointData(x: 0.5, y: 0.5, confidence: 0.2),
            .leftKnee: JointData(x: 0.65, y: 0.5, confidence: 0.2),
            .rightKnee: JointData(x: 0.65, y: 0.5, confidence: 0.2),
            .leftAnkle: JointData(x: 0.8, y: 0.5, confidence: 0.2),
            .rightAnkle: JointData(x: 0.8, y: 0.5, confidence: 0.2),
            .leftElbow: JointData(x: 0.1, y: 0.5, confidence: 0.2),
            .rightElbow: JointData(x: 0.1, y: 0.5, confidence: 0.2),
            .leftWrist: JointData(x: 0.05, y: 0.5, confidence: 0.2),
            .rightWrist: JointData(x: 0.05, y: 0.5, confidence: 0.2),
        ]
        return PoseFrame(timestamp: time, joints: joints)
    }

    func makeEmptyFrame(at time: TimeInterval) -> PoseFrame {
        PoseFrame(timestamp: time, joints: [:])
    }

    // MARK: - Tests

    @Test("Engine starts in notInPosition state")
    func initialState() async {
        let engine = PlankSessionEngine()
        var events: [SessionEvent] = []

        Task {
            for await event in await engine.events {
                events.append(event)
            }
        }

        // Feed empty frames (no person detected)
        for i in 0..<5 {
            await engine.processFrame(makeEmptyFrame(at: Double(i) * 0.1))
        }

        // No state change events should fire (already in notInPosition)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(events.isEmpty)
    }

    @Test("Transition to goodForm after debounce period fires sessionStart")
    func transitionToGoodForm() async {
        let config = PlankSessionEngine.Config(debounceInterval: 0.5)
        let engine = PlankSessionEngine(config: config)
        var events: [SessionEvent] = []

        Task {
            for await event in await engine.events {
                events.append(event)
            }
        }

        // Feed good frames for >0.5s (debounce)
        for i in 0..<10 {
            await engine.processFrame(makeGoodFrame(at: Double(i) * 0.1))
        }

        try? await Task.sleep(for: .milliseconds(200))

        let hasSessionStart = events.contains { event in
            if case .sessionStart = event { return true }
            return false
        }
        #expect(hasSessionStart)
    }

    @Test("Brief wobble within debounce window does NOT trigger state change")
    func debounceFiltersWobble() async {
        let config = PlankSessionEngine.Config(debounceInterval: 2.0)
        let engine = PlankSessionEngine(config: config)
        var events: [SessionEvent] = []

        Task {
            for await event in await engine.events {
                events.append(event)
            }
        }

        // Establish good form first (>2s)
        for i in 0..<30 {
            await engine.processFrame(makeGoodFrame(at: Double(i) * 0.1))
        }

        // Brief low-confidence wobble (only 1s, below 2s debounce)
        for i in 30..<40 {
            await engine.processFrame(makeLowConfidenceFrame(at: Double(i) * 0.1))
        }

        // Back to good form
        for i in 40..<50 {
            await engine.processFrame(makeGoodFrame(at: Double(i) * 0.1))
        }

        try? await Task.sleep(for: .milliseconds(200))

        // Should NOT have a cameraBad state change (wobble was within debounce)
        let hasCameraBad = events.contains { event in
            if case .stateChanged(.cameraBad) = event { return true }
            return false
        }
        #expect(!hasCameraBad)
    }
}
