import Foundation
import UIKit
import CoreGraphics

// MARK: - BandProfile (v10.4 — the progress read)
//
// Body Progress is the result screen's hero: "am I changing?" beats
// "what percentage am I?". This engine answers it from HER OWN two
// silhouettes and nothing else — the ink-on-paper band she kept this
// week against the one she kept last week.
//
// How it reads: the silhouette is downsampled to a narrow grayscale
// grid; each row's ink coverage is that row's WIDTH as a fraction of
// the plate. Ribs / navel / lower abdomen are the three thirds of
// the band. A third that narrowed beyond the noise floor is change;
// anything under it is "the same".
//
// The laws it keeps:
// • L3 — nothing numeric ever surfaces. The fractions live here, in
//   service of words; no percentage, no measurement, no "you lost X"
//   is ever derived from a photograph.
// • L6 — a fuller week is never scolded. The line names the honest
//   limits of a photograph (light, posture, the hour) instead.
// • The floors are real: both plates must actually hold a body, and
//   only fixed-window (waist-era) plates compare — a pose-derived
//   crop from the older era is not the same window twice.

enum BandProfile {

    /// Ink coverage per row, top → bottom, as a fraction of the
    /// plate's width.
    struct Profile: Equatable {
        let widths: [Double]

        /// Rows that found a body at all — the plate's confidence.
        var coverage: Double {
            guard !widths.isEmpty else { return 0 }
            return Double(widths.filter { $0 > 0.04 }.count) / Double(widths.count)
        }

        /// A plate the read may speak from: a body actually present
        /// across most of the band (empty paper reads 0).
        var isReadable: Bool { coverage >= 0.5 }

        func mean(_ range: Range<Int>) -> Double {
            let slice = widths[range.clamped(to: 0..<widths.count)]
            guard !slice.isEmpty else { return 0 }
            return slice.reduce(0, +) / Double(slice.count)
        }

        /// Under the ribs.
        var upper: Double { mean(0..<(widths.count / 3)) }
        /// The navel line.
        var middle: Double { mean((widths.count / 3)..<(2 * widths.count / 3)) }
        /// The lower abdomen.
        var lower: Double { mean((2 * widths.count / 3)..<widths.count) }
    }

    /// Rows sampled per plate. 24 is finer than the eye reads a band
    /// and cheap enough to run on the keep.
    static let rows = 24
    private static let columns = 96
    /// Below this, a column is ink (paper ≈ 250, ink ≈ 35 — the
    /// threshold sits well clear of both).
    private static let inkThreshold: UInt8 = 140
    /// Relative change under this is the same week: breath, posture
    /// and a hand's shake all live in here.
    static let noiseFloor = 0.03

    /// The plate's width profile. nil when the image can't be read.
    static func profile(of image: UIImage, rows: Int = BandProfile.rows) -> Profile? {
        guard rows > 2, let cg = WaistCrop.normalizedUp(image).cgImage else { return nil }
        let w = columns, h = rows
        var buffer = [UInt8](repeating: 255, count: w * h)
        let ok: Bool = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(
                      data: base, width: w, height: h,
                      bitsPerComponent: 8, bytesPerRow: w,
                      space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }

        // Bitmap rows are stored top-down (proven by the thirds test:
        // a plate that narrows toward the hem must read narrowing).
        var widths: [Double] = []
        widths.reserveCapacity(h)
        for row in 0..<h {
            var ink = 0
            for x in 0..<w where buffer[row * w + x] < inkThreshold { ink += 1 }
            widths.append(Double(ink) / Double(w))
        }
        return Profile(widths: widths)
    }

    // MARK: - The read

    /// The band's three readable regions, top to bottom.
    enum Region: Equatable { case upper, middle, lower }

    struct Read: Equatable {
        /// The hero line — what changed, in her register.
        let headline: String
        /// At most two supporting observations.
        let notes: [String]
        /// False when the plates are legible but the week is close
        /// enough that the honest caveat should ride along.
        let confident: Bool
        /// The region the line is about, so the plate can bring the
        /// eye there (nil = nothing moved, or the week reads fuller
        /// and pointing at a region would be a scolding finger).
        let region: Region?
    }

    /// Today's plate against the last one she kept. nil when the
    /// plates can't honestly be compared — the caller falls back to
    /// the record's date-based line (BodyChangeRead).
    ///
    /// `trendFalling` lets a holding shape speak with the scale: the
    /// preservation story the program already tells elsewhere.
    static func read(
        now: Profile,
        then: Profile,
        trendFalling: Bool = false
    ) -> Read? {
        guard now.isReadable, then.isReadable else { return nil }

        func delta(_ a: Double, _ b: Double) -> Double {
            guard b > 0.0001 else { return 0 }
            return (a - b) / b
        }
        let mid = delta(now.middle, then.middle)
        let low = delta(now.lower, then.lower)
        let up = delta(now.upper, then.upper)
        let moved = [mid, low, up].filter { abs($0) >= noiseFloor }

        // Everything inside the floor: the week held.
        if moved.isEmpty {
            return Read(
                headline: trendFalling
                    ? "your midsection is holding while the scale moves."
                    : "your midsection reads the same as last week.",
                notes: trendFalling
                    ? ["shape holding through a falling week is the good kind of steady."]
                    : ["steady weeks are how the change gets kept."],
                confident: true,
                region: nil
            )
        }

        // A fuller week is never scolded — a photograph carries the
        // light and the hour with it (L6).
        let narrowed = [mid, low, up].contains { $0 <= -noiseFloor }
        guard narrowed else {
            return Read(
                headline: "this week reads a little fuller.",
                notes: ["light, posture and the hour all move a frame.",
                        "one week is never the trend. the record is."],
                confident: false,
                region: nil
            )
        }

        var notes: [String] = []
        let headline: String
        let region: Region
        if mid <= -noiseFloor {
            headline = "your waist reads leaner than last week."
            region = .middle
            if low <= -noiseFloor { notes.append("the lower abdomen came with it.") }
            else if up <= -noiseFloor { notes.append("it reads narrower under the ribs too.") }
        } else if low <= -noiseFloor {
            headline = "your lower abdomen looks tighter."
            region = .lower
            if up <= -noiseFloor { notes.append("under the ribs reads narrower too.") }
            else { notes.append("the waist itself reads about the same.") }
        } else {
            headline = "you read narrower under the ribs."
            region = .upper
            notes.append("the waist and the lower abdomen held.")
        }
        if trendFalling { notes.append("the scale is moving the same way.") }
        return Read(headline: headline, notes: Array(notes.prefix(2)),
                    confident: true, region: region)
    }
}
