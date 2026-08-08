#if canImport(UIKit)
import SwiftUI

// v23 THE STILL LIFE — the sweep era ended (Canvas line → Metal band
// → gone): THE DIAL's closing trace is the one reading signal. This
// file keeps only the scan-label rotator that rides under the dial.

// MARK: - ScanLabelRotator
//
// v1.0.8 Phase K (2026-06-08) — rewritten for smoothness. The previous
// version used `.id(idx) + .transition` driven by a TimelineView body
// re-render. SwiftUI doesn't fire `.transition` reliably when the
// driver is a TimelineView (the body re-runs every tick without going
// through the animation system), so the label was hard-cutting on each
// 0.9s rotate instead of crossfading.
//
// New approach:
//   - @State index driven by a `.task(id:)` async loop with explicit
//     `withAnimation(.easeInOut(duration: 0.55))` per phase swap
//   - `.contentTransition(.opacity)` on the Text so the content
//     change cross-fades smoothly without remounting the view
//   - Cadence bumped 0.9s → 1.6s so each phrase has time to BE read
//     before the next one starts fading in — the previous pace was
//     racing the reader

@MainActor
struct ScanLabelRotator: View {

    let isActive: Bool
    /// v23 — the words follow the dial's mode.
    var mode: DialMode = .scan

    @State private var idx: Int = 0

    private struct Phrase {
        let verb: String
        let tail: String
    }
    // v22 ONE HAND — the poetic italics died with v13; the
    // processing line speaks PLAINLY about real steps (the law:
    // intelligent, not loading; specific, never performed).
    private static let scanPhrases: [Phrase] = [
        .init(verb: "reading", tail: " your plate"),
        .init(verb: "naming", tail: " what's on it"),
        .init(verb: "counting", tail: " the protein"),
    ]
    private static let barcodePhrases: [Phrase] = [
        .init(verb: "finding", tail: " the product"),
        .init(verb: "reading", tail: " its label"),
    ]
    private static let labelPhrases: [Phrase] = [
        .init(verb: "reading", tail: " the label"),
        .init(verb: "copying", tail: " the printed values"),
    ]

    private var phrases: [Phrase] {
        switch mode {
        case .scan:    return Self.scanPhrases
        case .barcode: return Self.barcodePhrases
        case .label:   return Self.labelPhrases
        }
    }

    var body: some View {
        let phrase = phrases[min(idx, phrases.count - 1)]
        HStack(spacing: 0) {
            Text(phrase.verb + phrase.tail)
                .font(.custom("DMSans-Medium", size: 14))
        }
        // v23 — the rotator rides the feed under THE DIAL now (white
        // on glass, the caption block carries the shadow).
        .foregroundStyle(.white)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.55), value: idx)
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("reading your plate")
        .task(id: isActive) {
            guard isActive else { return }
            idx = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                if Task.isCancelled { return }
                idx = (idx + 1) % phrases.count
            }
        }
    }
}

#endif  // canImport(UIKit)
