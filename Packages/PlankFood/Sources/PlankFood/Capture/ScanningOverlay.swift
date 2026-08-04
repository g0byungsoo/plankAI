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
        // v1.0.9 D2 — UX expert pick. Tightens the rhythm of the
        // rotator + adds a heart on the last beat as a soft "almost
        // there" tell. "looking" is gentler than "reading" — less
        // clinical, more friend-energy.
        .init(verb: "looking", tail: " at your plate"),
        .init(verb: "finding", tail: " the good stuff"),
        .init(verb: "tallying", tail: " portions"),
    ]

    var body: some View {
        let phrase = Self.phrases[idx]
        HStack(spacing: 0) {
            Text(phrase.verb)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
            Text(phrase.tail)
                .font(.custom("Fraunces72pt-Regular", size: 16))
        }
        .foregroundStyle(FoodTheme.textPrimary)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.55), value: idx)
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("looking at your plate")
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
