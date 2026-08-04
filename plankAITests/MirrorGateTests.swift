import XCTest
@testable import plankAI

// v10.1 — the mirror check-in's fire decision under test: a person
// holding steady fires in ~a second; absence, drift, and partial
// figures never fire; the latch holds until reset.
final class MirrorGateTests: XCTestCase {

    private func person(
        x: CGFloat = 0.5, y: CGFloat = 0.5
    ) -> [BodyScanAlignment.Key: BodyScanAlignment.Joint] {
        [
            .leftShoulder: .init(x - 0.08, y + 0.22),
            .rightShoulder: .init(x + 0.08, y + 0.22),
            .leftHip: .init(x - 0.06, y),
            .rightHip: .init(x + 0.06, y)
        ]
    }

    func testEmptyFramesNeverFire() {
        var gate = MirrorGate()
        for _ in 0..<40 { gate.ingest([:]) }
        XCTAssertFalse(gate.shouldFire)
        XCTAssertFalse(gate.personSeen)
        XCTAssertEqual(gate.progress, 0)
    }

    func testShouldersAloneAreNotAPerson() {
        var gate = MirrorGate()
        let torsoless: [BodyScanAlignment.Key: BodyScanAlignment.Joint] = [
            .leftShoulder: .init(0.42, 0.7),
            .rightShoulder: .init(0.58, 0.7)
        ]
        for _ in 0..<40 { gate.ingest(torsoless) }
        XCTAssertFalse(gate.shouldFire)
    }

    func testSteadyPersonFiresAfterTheStreak() {
        var gate = MirrorGate()
        for _ in 0..<MirrorGate.framesToFire { gate.ingest(person()) }
        XCTAssertTrue(gate.shouldFire)
    }

    func testLowConfidenceJointsAreIgnored() {
        var gate = MirrorGate()
        let ghost: [BodyScanAlignment.Key: BodyScanAlignment.Joint] = [
            .leftShoulder: .init(0.42, 0.7, confidence: 0.1),
            .rightShoulder: .init(0.58, 0.7, confidence: 0.1),
            .leftHip: .init(0.44, 0.5, confidence: 0.1),
            .rightHip: .init(0.56, 0.5, confidence: 0.1)
        ]
        for _ in 0..<40 { gate.ingest(ghost) }
        XCTAssertFalse(gate.shouldFire)
    }

    func testDriftResetsTheStreak() {
        var gate = MirrorGate()
        for _ in 0..<(MirrorGate.framesToFire - 2) { gate.ingest(person()) }
        gate.ingest(person(x: 0.62))   // a step sideways
        XCTAssertFalse(gate.shouldFire)
        XCTAssertEqual(gate.steadyStreak, 1)
        // Settling again earns the fire from the new spot.
        for _ in 0..<(MirrorGate.framesToFire - 1) { gate.ingest(person(x: 0.62)) }
        XCTAssertTrue(gate.shouldFire)
    }

    func testMicroSwayStaysSteady() {
        var gate = MirrorGate()
        for i in 0..<MirrorGate.framesToFire {
            gate.ingest(person(x: 0.5 + CGFloat(i % 2) * 0.01))
        }
        XCTAssertTrue(gate.shouldFire)
    }

    func testFireLatchesUntilReset() {
        var gate = MirrorGate()
        for _ in 0..<MirrorGate.framesToFire { gate.ingest(person()) }
        XCTAssertTrue(gate.shouldFire)
        gate.ingest([:])   // absence must not clear a latched fire
        XCTAssertTrue(gate.shouldFire)
        gate.reset()
        XCTAssertFalse(gate.shouldFire)
        XCTAssertEqual(gate.progress, 0)
    }

    func testProgressClimbsWithTheStreak() {
        var gate = MirrorGate()
        gate.ingest(person())
        gate.ingest(person())
        XCTAssertEqual(gate.progress, 2.0 / Double(MirrorGate.framesToFire), accuracy: 0.001)
    }
}
