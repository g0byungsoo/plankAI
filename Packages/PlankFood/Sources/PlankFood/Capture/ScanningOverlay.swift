#if canImport(UIKit)
import SwiftUI

// v1.2 snap-food rebuild (2026-07-01) — the Canvas laser sweep
// (`ScanningOverlay`) was superseded by the Metal pass in
// SnapShaders.metal + SnapSweepOverlay.swift (diagonal warm band +
// sparkle grain, additive over the preview). This file keeps only the
// scan-label rotator that rides over it.

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

    @State private var idx: Int = 0

    private struct Phrase {
        let verb: String
        let tail: String
    }
    private static let phrases: [Phrase] = [
        // v22 ONE HAND — the poetic italics died with v13; the
        // processing line speaks PLAINLY about real steps (the law:
        // intelligent, not loading; specific, never performed).
        .init(verb: "reading", tail: " your plate"),
        .init(verb: "naming", tail: " what's on it"),
        .init(verb: "counting", tail: " the protein"),
    ]

    var body: some View {
        let phrase = Self.phrases[idx]
        HStack(spacing: 0) {
            Text(phrase.verb + phrase.tail)
                .font(.custom("DMSans-Medium", size: 14))
        }
        .foregroundStyle(FoodTheme.textPrimary)
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
                idx = (idx + 1) % Self.phrases.count
            }
        }
    }
}

#endif  // canImport(UIKit)
