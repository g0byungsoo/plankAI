import XCTest
import CoreGraphics
@testable import plankAI

// BodyScanAlignment (v9 P1) — the guided capture's pure gate. Pinned
// law: the whole figure or no coaching (shoulders + hips + an ankle);
// height band 0.60-0.92 of frame; center band 0.38-0.62; twelve
// consecutive aligned frames arm the shutter; any wobble resets.

final class BodyScanAlignmentTests: XCTestCase {

    private typealias A = BodyScanAlignment

    /// A believable standing figure: ankles→shoulders spanning
    /// `height * 0.85` (the engine's span widening), centered on x.
    private func figure(height: CGFloat, centerX: CGFloat = 0.5,
                        confidence: Double = 1) -> [A.Key: A.Joint] {
        let span = height * 0.85
        let bottom: CGFloat = 0.06
        let top = bottom + span
        return [
            .leftAnkle: .init(centerX - 0.05, bottom, confidence: confidence),
            .rightAnkle: .init(centerX + 0.05, bottom, confidence: confidence),
            .leftHip: .init(centerX - 0.06, bottom + span * 0.5, confidence: confidence),
            .rightHip: .init(centerX + 0.06, bottom + span * 0.5, confidence: confidence),
            .leftShoulder: .init(centerX - 0.09, top, confidence: confidence),
            .rightShoulder: .init(centerX + 0.09, top, confidence: confidence),
        ]
    }

    func testEmptyFrameSearches() {
        XCTAssertEqual(A.verdict([:]), .searching)
    }

    func testMissingAnklesSearches() {
        var joints = figure(height: 0.8)
        joints[.leftAnkle] = nil
        joints[.rightAnkle] = nil
        XCTAssertEqual(A.verdict(joints), .searching)
    }

    func testOneAnkleIsEnoughBase() {
        var joints = figure(height: 0.8)
        joints[.rightAnkle] = nil
        XCTAssertEqual(A.verdict(joints), .aligned)
    }

    func testLowConfidenceJointsDoNotCount() {
        XCTAssertEqual(A.verdict(figure(height: 0.8, confidence: 0.1)), .searching)
    }

    func testSmallFigureReadsTooFar() {
        XCTAssertEqual(A.verdict(figure(height: 0.4)), .tooFar)
    }

    func testHugeFigureReadsTooClose() {
        XCTAssertEqual(A.verdict(figure(height: 0.99)), .tooClose)
    }

    func testOffCenterCoachesTheDirection() {
        XCTAssertEqual(A.verdict(figure(height: 0.8, centerX: 0.2)), .offCenter(left: true))
        XCTAssertEqual(A.verdict(figure(height: 0.8, centerX: 0.8)), .offCenter(left: false))
    }

    func testCenteredFullFigureAligns() {
        XCTAssertEqual(A.verdict(figure(height: 0.75)), .aligned)
    }

    // MARK: - Arming

    func testTwelveAlignedFramesArm() {
        var arming = A.Arming()
        for _ in 0..<11 { arming.ingest(.aligned) }
        XCTAssertFalse(arming.isArmed)
        arming.ingest(.aligned)
        XCTAssertTrue(arming.isArmed)
    }

    func testAnyWobbleResetsTheStreak() {
        var arming = A.Arming()
        for _ in 0..<11 { arming.ingest(.aligned) }
        arming.ingest(.tooClose)
        XCTAssertEqual(arming.progress, 0)
        for _ in 0..<11 { arming.ingest(.aligned) }
        XCTAssertFalse(arming.isArmed)
    }

    func testDisarmResetsCleanly() {
        var arming = A.Arming()
        for _ in 0..<12 { arming.ingest(.aligned) }
        XCTAssertTrue(arming.isArmed)
        arming.disarm()
        XCTAssertFalse(arming.isArmed)
        XCTAssertEqual(arming.progress, 0)
    }

    func testEveryVerdictSpeaksOneLine() {
        let verdicts: [A.Verdict] = [.searching, .tooFar, .tooClose,
                                     .offCenter(left: true), .offCenter(left: false), .aligned]
        for v in verdicts {
            XCTAssertFalse(A.coachingLine(v).isEmpty)
        }
    }
}
