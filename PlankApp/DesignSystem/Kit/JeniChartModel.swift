import Foundation
import CoreGraphics

// MARK: - JeniChartModel (v11 T2 — the pure geometry core)
//
// One model feeds every chart in the app (docs/app_v11/00_REBIRTH.md
// §5). Pure and unit-tested: normalization, gap handling, detents,
// staged reveal. The renderer (JeniChart.swift) draws; this decides.
//
// Honesty is geometry here (L8): a nil value is a day that was not
// logged — it splits a line into segments and leaves a bar slot
// empty. It is NEVER interpolated across and NEVER rendered as zero.

struct JeniChartModel: Equatable {
    enum Form: Equatable {
        case line   // trend stroke
        case band   // a filled range between two series
        case bars   // thin vertical hairlines (the simpleness form)
        case spark  // tile-sized line, no labels
    }

    struct Series: Equatable {
        enum Role: Equatable {
            case ink      // the live series — 1.4pt, full ink
            case context  // comparison (EMA, last week) — 1.0pt hairline
        }
        let values: [Double?]
        let role: Role

        init(values: [Double?], role: Role) {
            self.values = values
            self.role = role
        }
    }

    let form: Form
    let series: [Series]
    let yPaddingFraction: Double
    /// Sparse-measurement mode (weigh-ins): connect real points across
    /// nil slots instead of splitting. Every vertex is still a real
    /// measurement at its true x — the line only shows their order.
    /// DAILY series (nutrients, sleep, steps) must keep this false:
    /// there a bridged gap would claim a day that never happened (L8).
    let bridgeGaps: Bool

    init(form: Form, series: [Series], yPaddingFraction: Double = 0.12,
         bridgeGaps: Bool = false) {
        self.form = form
        self.series = series
        self.yPaddingFraction = yPaddingFraction
        self.bridgeGaps = bridgeGaps
    }

    // MARK: - emptiness

    var isEmpty: Bool {
        !series.contains { $0.values.contains { $0 != nil } }
    }

    /// The longest series' count — the x resolution of the chart.
    var slotCount: Int {
        series.map(\.values.count).max() ?? 0
    }

    // MARK: - the shared y domain
    //
    // All series scale to the union of their values so ink and context
    // are comparable on one canvas. A flat domain expands symmetrically
    // (so flat lines center); bars anchor at zero (amounts, not ranges).

    private var rawBounds: (lo: Double, hi: Double)? {
        let all = series.flatMap(\.values).compactMap { $0 }
        guard let lo = all.min(), let hi = all.max() else { return nil }
        return (lo, hi)
    }

    private var lineDomain: ClosedRange<Double> {
        guard var (lo, hi) = rawBounds else { return 0...1 }
        if lo == hi {
            let e = max(1, abs(lo) * 0.05)
            lo -= e; hi += e
        }
        let pad = (hi - lo) * yPaddingFraction
        return (lo - pad)...(hi + pad)
    }

    private var barDomain: ClosedRange<Double> {
        guard let (_, hi) = rawBounds, hi > 0 else { return 0...1 }
        return 0...(hi * (1 + yPaddingFraction))
    }

    private func yPosition(_ value: Double, in size: CGSize,
                           domain: ClosedRange<Double>) -> CGFloat {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return size.height / 2 }
        let t = (value - domain.lowerBound) / span
        return size.height * CGFloat(1 - t)
    }

    // MARK: - line geometry

    /// Points for one series, split into segments at every nil (gaps
    /// are never bridged). A single-point series centers horizontally.
    func points(seriesIndex: Int, in size: CGSize) -> [[CGPoint]] {
        guard series.indices.contains(seriesIndex) else { return [] }
        let values = series[seriesIndex].values
        guard !values.isEmpty else { return [] }
        let domain = lineDomain
        let n = values.count

        func x(_ i: Int) -> CGFloat {
            n > 1 ? size.width * CGFloat(i) / CGFloat(n - 1) : size.width / 2
        }

        if bridgeGaps {
            // Sparse mode: one polyline through every real point,
            // each at its true x position.
            let pts = values.enumerated().compactMap { i, v in
                v.map { CGPoint(x: x(i), y: yPosition($0, in: size, domain: domain)) }
            }
            return pts.isEmpty ? [] : [pts]
        }

        var segments: [[CGPoint]] = []
        var current: [CGPoint] = []
        for (i, v) in values.enumerated() {
            if let v {
                current.append(CGPoint(x: x(i), y: yPosition(v, in: size, domain: domain)))
            } else if !current.isEmpty {
                segments.append(current)
                current = []
            }
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    // MARK: - bar geometry

    /// One rect per slot of the FIRST series; nil slots stay nil (an
    /// unlogged day is a gap, not a zero). Bars anchor at the bottom.
    ///
    /// v12 (the chart craft pass): bars are confident marks, not the
    /// v11 comb — ~55% of the slot, capped at 24pt so the band keeps
    /// its air (mark law: never fill the slot; the leftover is the
    /// separator). 7 days → ~22pt bars; 30 days → ~6pt.
    func barRects(in size: CGSize, gap: CGFloat) -> [CGRect?] {
        guard let values = series.first?.values, !values.isEmpty else { return [] }
        let domain = barDomain
        let slot = size.width / CGFloat(values.count)
        let barWidth = max(4, min(24, slot * 0.55))

        return values.enumerated().map { i, v in
            guard let v else { return nil }
            let top = yPosition(v, in: size, domain: domain)
            return CGRect(
                x: CGFloat(i) * slot + (slot - barWidth) / 2,
                y: top,
                width: barWidth,
                height: max(1, size.height - top)
            )
        }
    }

    // MARK: - scrub detents

    /// The nearest slot index for a drag x, clamped to valid indices.
    func detent(forX x: CGFloat, width: CGFloat) -> Int {
        let n = slotCount
        guard n > 1, width > 0 else { return 0 }
        let t = max(0, min(1, x / width))
        return Int((t * CGFloat(n - 1)).rounded())
    }

    /// The value at a detent for a series (nil if unlogged).
    func value(at index: Int, seriesIndex: Int = 0) -> Double? {
        guard series.indices.contains(seriesIndex) else { return nil }
        let values = series[seriesIndex].values
        guard values.indices.contains(index) else { return nil }
        return values[index]
    }

    /// The last slot holding a real value in the first series — "now"
    /// for the emphasize-today read.
    var lastRealIndex: Int? {
        guard let values = series.first?.values else { return nil }
        return values.lastIndex(where: { $0 != nil })
    }

    // MARK: - staged reveal (bars land one at a time)

    /// How many bars have fully landed at `phase` ∈ [0, 1].
    /// Monotonic in phase; 0 at 0; total at 1.
    func revealCount(phase: Double, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let clamped = max(0, min(1, phase))
        return min(total, Int(floor(clamped * Double(total) + 1e-9)))
    }

    /// Per-bar landing progress at `phase` — bar i grows over its own
    /// window so the row reads as one-at-a-time growth, not popping.
    func barPhase(index: Int, phase: Double, total: Int) -> Double {
        guard total > 0 else { return 0 }
        let raw = phase * Double(total) - Double(index)
        return max(0, min(1, raw))
    }
}
