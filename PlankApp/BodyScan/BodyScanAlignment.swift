import Foundation
import CoreGraphics

// MARK: - BodyScanAlignment
//
// app v9 P1 — the pure heart of the guided capture. Every frame's
// pose joints reduce to ONE verdict; consecutive aligned frames arm
// the shutter. Pure math so the bands live under test — the camera
// layer feeds it, the view speaks it.
//
// Coordinate contract: Vision-normalized joints (0-1, bottom-left
// origin), mirrored to match the preview. The bands were chosen for
// a full-body front scan at arm-to-mirror distance: her figure
// should fill 60-92% of the frame height, centered within the
// middle ~quarter.

enum BodyScanAlignment {

    struct Joint: Equatable {
        let x: CGFloat
        let y: CGFloat
        let confidence: Double
        init(_ x: CGFloat, _ y: CGFloat, confidence: Double = 1) {
            self.x = x
            self.y = y
            self.confidence = confidence
        }
    }

    /// The named joints the gate needs (subset of the 14 tracked).
    enum Key: String, CaseIterable {
        case leftShoulder, rightShoulder, leftHip, rightHip
        case leftAnkle, rightAnkle
    }

    enum Verdict: Equatable {
        /// Not enough of her in frame to coach yet.
        case searching
        /// Figure too small — she should come closer.
        case tooFar
        /// Figure too tall — a step back.
        case tooClose
        /// Off the horizontal center band.
        case offCenter(left: Bool)
        case aligned
    }

    static let minConfidence: Double = 0.3
    static let heightBand: ClosedRange<CGFloat> = 0.60...0.92
    static let centerBand: ClosedRange<CGFloat> = 0.38...0.62

    /// One frame → one verdict.
    static func verdict(_ joints: [Key: Joint]) -> Verdict {
        let confident = joints.filter { $0.value.confidence >= minConfidence }
        // The gate needs both shoulders, both hips, and at least one
        // ankle — the whole figure, not a torso crop.
        let hasCore = confident[.leftShoulder] != nil && confident[.rightShoulder] != nil
            && confident[.leftHip] != nil && confident[.rightHip] != nil
        let hasBase = confident[.leftAnkle] != nil || confident[.rightAnkle] != nil
        guard hasCore, hasBase else { return .searching }

        let ys = confident.values.map(\.y)
        let xs = confident.values.map(\.x)
        guard let minY = ys.min(), let maxY = ys.max(),
              let minX = xs.min(), let maxX = xs.max() else { return .searching }

        // Head isn't a tracked gate joint; ankles-to-shoulders is
        // ~85% of standing height, so widen the measured span.
        let height = (maxY - minY) / 0.85
        if height < heightBand.lowerBound { return .tooFar }
        if height > heightBand.upperBound { return .tooClose }

        let centerX = (minX + maxX) / 2
        if !centerBand.contains(centerX) {
            return .offCenter(left: centerX < centerBand.lowerBound)
        }
        return .aligned
    }

    /// The shutter arms after N consecutive aligned frames (~1.2s at
    /// the 10fps pose cadence); any other verdict resets. The VIEW
    /// owns the countdown once `.armed` fires — this struct only
    /// decides when stillness has been earned.
    struct Arming: Equatable {
        static let framesToArm = 12

        private(set) var alignedStreak = 0
        private(set) var isArmed = false

        mutating func ingest(_ verdict: Verdict) {
            guard !isArmed else { return }
            if verdict == .aligned {
                alignedStreak += 1
                if alignedStreak >= Self.framesToArm { isArmed = true }
            } else {
                alignedStreak = 0
            }
        }

        /// A countdown interrupted by movement disarms cleanly.
        mutating func disarm() {
            alignedStreak = 0
            isArmed = false
        }

        var progress: Double {
            min(1, Double(alignedStreak) / Double(Self.framesToArm))
        }
    }

    /// The figure bounds a frame's confident joints draw — captured
    /// beside the still as the compare's alignment anchors (P2).
    /// nil when the gate couldn't see the whole figure.
    static func anchors(_ joints: [Key: Joint]) -> (top: Double, bottom: Double, centerX: Double)? {
        let confident = joints.filter { $0.value.confidence >= minConfidence }
        guard confident.count >= 4 else { return nil }
        let ys = confident.values.map(\.y)
        let xs = confident.values.map(\.x)
        guard let minY = ys.min(), let maxY = ys.max(),
              let minX = xs.min(), let maxX = xs.max(), maxY > minY else { return nil }
        return (Double(maxY), Double(minY), Double((minX + maxX) / 2))
    }

    /// The coaching line per verdict — the register is clinical-calm,
    /// lowercase, one instruction at a time (L6/L7: one line, no
    /// stacked chrome).
    static func coachingLine(_ verdict: Verdict) -> String {
        switch verdict {
        case .searching: return "stand where I can see all of you"
        case .tooFar: return "a touch closer"
        case .tooClose: return "a step back"
        case .offCenter(let left): return left ? "a little to your right" : "a little to your left"
        case .aligned: return "hold there"
        }
    }
}
