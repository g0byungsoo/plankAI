import Foundation
import CoreGraphics

// MARK: - MirrorGate (v10.1 — the mirror check-in's fire decision)
//
// The guided pose gate optimized for a staged photograph: whole
// figure, height band, centering, countdown. The mirror ritual
// optimizes for a HABIT: she is at her bathroom mirror, phone in
// hand, glancing at the mirror — the shutter should fire the
// moment there is a person holding steady, and never make her
// wait through theater. Pure math so the decision lives under
// test; the view feeds frames and speaks the result.
//
// Person = at least one shoulder and one hip confidently seen (a
// mirror's crop may cut ankles — the record accepts what her
// mirror shows; anchors + pose quality still ride along when the
// whole figure is visible, per L3).
// Steady = the confident-joint centroid drifting less than the
// tolerance frame-over-frame for ~a second at the 10fps cadence.

struct MirrorGate: Equatable {

    static let framesToFire = 10
    static let driftTolerance: CGFloat = 0.035
    static let minConfidence: Double = 0.3

    private(set) var steadyStreak = 0
    /// Latches once earned; the view fires and then resets.
    private(set) var shouldFire = false
    private var lastCentroid: CGPoint?

    var personSeen: Bool { lastCentroid != nil }

    var progress: Double {
        min(1, Double(steadyStreak) / Double(Self.framesToFire))
    }

    mutating func ingest(_ joints: [BodyScanAlignment.Key: BodyScanAlignment.Joint]) {
        guard !shouldFire else { return }
        let confident = joints.filter { $0.value.confidence >= Self.minConfidence }
        let hasPerson =
            (confident[.leftShoulder] != nil || confident[.rightShoulder] != nil)
            && (confident[.leftHip] != nil || confident[.rightHip] != nil)
        guard hasPerson else {
            lastCentroid = nil
            steadyStreak = 0
            return
        }
        let xs = confident.values.map(\.x)
        let ys = confident.values.map(\.y)
        let centroid = CGPoint(
            x: xs.reduce(0, +) / CGFloat(xs.count),
            y: ys.reduce(0, +) / CGFloat(ys.count)
        )
        defer { lastCentroid = centroid }
        guard let last = lastCentroid else {
            steadyStreak = 1
            return
        }
        let drift = hypot(centroid.x - last.x, centroid.y - last.y)
        if drift <= Self.driftTolerance {
            steadyStreak += 1
            if steadyStreak >= Self.framesToFire { shouldFire = true }
        } else {
            steadyStreak = 1
        }
    }

    mutating func reset() {
        steadyStreak = 0
        shouldFire = false
        lastCentroid = nil
    }
}
