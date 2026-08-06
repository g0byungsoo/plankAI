import Foundation
import CoreGraphics

// MARK: - BodyChangeRead
//
// app v9 P2 — the change language, floor-gated (L3): qualitative
// always, uncertainty spoken, and NEVER a number derived from a
// photo. The mirror agrees with the line only when both actually
// speak: ≥2 scans spanning ≥4 weeks, full-figure quality at both
// ends, an established weight trend. Unmet floors say what they
// need, the WeightAnalytics way. A rising trend is never blamed at
// the mirror (the anti-shame floor).
//
// CompareTransform: the internal-only alignment math (D4/L3 — a
// mechanism, never a surfaced number). Anchors are Vision-normalized
// (bottom-left origin) figure bounds captured by the pose gate; the
// transform scales/offsets "then" so figures coincide with "now".

enum BodyChangeRead {

    struct ScanMeta: Equatable {
        let capturedAt: Date
        /// 0 = unknown (restored / manual sim capture) — treated as
        /// "cannot vouch", which fails the quality floor honestly.
        let poseQuality: Double
    }

    static let spanFloorDays = 28
    static let qualityFloor = 0.5

    /// The body page's one line. nil when no scan exists (the page
    /// doesn't render).
    static func line(
        scans: [ScanMeta],
        trendEstablished: Bool,
        trendDeltaKg: Double?,
        today: Date = .now
    ) -> String? {
        guard let newest = scans.max(by: { $0.capturedAt < $1.capturedAt }),
              let oldest = scans.min(by: { $0.capturedAt < $1.capturedAt })
        else { return nil }

        guard scans.count >= 2 else {
            return "one scan kept. the next one starts the comparison."
        }

        let cal = Calendar.current
        let spanDays = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: oldest.capturedAt),
            to: cal.startOfDay(for: newest.capturedAt)
        ).day ?? 0
        let weeks = max(1, spanDays / 7)

        guard spanDays >= spanFloorDays else {
            return "week \(weeks) of your record. four weeks apart draws real change."
        }
        guard oldest.poseQuality >= qualityFloor,
              newest.poseQuality >= qualityFloor else {
            return "keep scans full-figure. the record compares best that way."
        }
        if trendEstablished, let delta = trendDeltaKg, delta <= -0.1 {
            return "\(weeks) weeks in. the line and the mirror agree."
        }
        if trendEstablished, let delta = trendDeltaKg, delta >= 0.1 {
            // Never blame the mirror for a climbing week.
            return "\(weeks) weeks of record. the mirror holds what the scale can't say."
        }
        return "\(weeks) weeks of evidence, kept."
    }

    // MARK: - The compare transform (internal-only mechanics)

    struct Anchors: Equatable {
        /// Vision-normalized (0-1, bottom-left origin).
        let top: Double
        let bottom: Double
        let centerX: Double

        var height: Double { max(0.0001, top - bottom) }
        var centerY: Double { (top + bottom) / 2 }
    }

    struct Transform: Equatable {
        let scale: CGFloat
        /// Normalized offsets in Vision space; the view flips y for
        /// screen coordinates.
        let offsetXNorm: CGFloat
        let offsetYNorm: CGFloat

        static let identity = Transform(scale: 1, offsetXNorm: 0, offsetYNorm: 0)
    }

    /// Aligns "then" onto "now": match figure heights, then centers.
    /// Clamped near 1 — the capture gate already constrains framing,
    /// so anything extreme means bad anchors, and a barely-wrong
    /// alignment beats a wildly-wrong one (L3: mechanism, not truth).
    static func transform(then: Anchors?, now: Anchors?) -> Transform {
        guard let then, let now else { return .identity }
        var scale = now.height / then.height
        scale = min(1.25, max(0.8, scale))
        let dx = now.centerX - then.centerX * scale
            - (1 - scale) / 2   // scaleEffect is center-anchored
        let dy = now.centerY - then.centerY * scale
            - (1 - scale) / 2
        return Transform(
            scale: CGFloat(scale),
            offsetXNorm: CGFloat(dx),
            offsetYNorm: CGFloat(dy)
        )
    }
}
