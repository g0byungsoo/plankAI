import SwiftUI

// MARK: - EarnedStickerCluster
//
// A tasteful CLUSTER (not a scatter) of 2-3 glossy signature stickers
// that bloom + settle in, staggered, with a slight rotation and spring.
// The earned-moment accent for activation peaks (a kept promise, a
// commitment locked). Glossy same-register only: it draws exclusively
// from `StickerName.signature`.
//
// The cluster is a SELF-CONTAINED, bounded view sized `diameter` x
// `diameter`. That bound IS the keep-out contract: place it in a corner
// (via the `.earnedStickerCluster(...)` overlay helper or your own
// `.position`/alignment) and it can never bleed into a centered text
// column. Nothing inside ever draws outside the frame.
//
// Reduce Motion: the stickers appear at their resting transform with no
// bloom (scatter motion is the first thing to drop on the a11y flag).
//
// Usage - corner overlay (recommended, keep-out by placement):
//
//   someText
//       .earnedStickerCluster(animate: appeared, alignment: .topTrailing)
//
// Usage - manual:
//
//   EarnedStickerCluster(animate: appeared)
//       .position(x: ..., y: ...)
struct EarnedStickerCluster: View {
    /// Flip to true to bloom the cluster in. While false the stickers
    /// are hidden, so the caller can stage the earned moment.
    var animate: Bool

    /// 2-3 glossy signature stickers. Defaults to a flower + heart +
    /// sparkle trio. A precondition guards against non-signature picks.
    var stickers: [StickerName] = [.flower3D, .heartGlossy, .sparkleGlossy]

    /// The square bound of the whole cluster. Stickers lay out inside.
    var diameter: CGFloat = 116

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloomed = false

    /// A small triangular constellation in unit space (0..1). Index 0 is
    /// the anchor (largest), 1 + 2 tuck around it. Rotations are gentle.
    private struct Node { let unit: CGPoint; let scale: CGFloat; let rotation: Double }
    private let layout: [Node] = [
        Node(unit: CGPoint(x: 0.60, y: 0.42), scale: 1.00, rotation: -6),
        Node(unit: CGPoint(x: 0.30, y: 0.66), scale: 0.74, rotation: 8),
        Node(unit: CGPoint(x: 0.74, y: 0.74), scale: 0.50, rotation: -3),
    ]

    var body: some View {
        let picks = sanitized
        ZStack {
            ForEach(Array(picks.enumerated()), id: \.offset) { index, name in
                let node = layout[min(index, layout.count - 1)]
                stickerView(name: name, node: node, index: index)
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { trigger() }
        .onChange(of: animate) { _, _ in trigger() }
    }

    @ViewBuilder
    private func stickerView(name: StickerName, node: Node, index: Int) -> some View {
        let base = diameter * 0.42 * node.scale
        let shown = reduceMotion || bloomed
        Image(name.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: base, height: base)
            .opacity(name.style.opacity * (shown ? 1 : 0))
            .scaleEffect(shown ? 1.0 : 0.4, anchor: .center)
            .rotationEffect(.degrees(shown ? node.rotation : node.rotation - 10))
            .position(x: node.unit.x * diameter, y: node.unit.y * diameter)
            .animation(
                reduceMotion ? nil
                    : .spring(response: 0.5, dampingFraction: 0.62)
                        .delay(Double(index) * Motion.cascadeTight),
                value: bloomed
            )
    }

    private func trigger() {
        guard animate else { return }
        if reduceMotion {
            bloomed = true
            return
        }
        bloomed = true
        // A light playful landing when the anchor settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            ActivationHaptics.shared.stickerSettle()
        }
    }

    /// Keep only signature stickers, cap at 3. DEBUG-asserts on a bad
    /// pick so a non-glossy sticker can't sneak into an earned moment.
    private var sanitized: [StickerName] {
        let filtered = stickers.filter { name in
            let ok = name.isSignature
            assert(ok, "EarnedStickerCluster only renders StickerName.signature; \(name) rejected.")
            return ok
        }
        let result = filtered.isEmpty ? [.flower3D, .heartGlossy, .sparkleGlossy] : filtered
        return Array(result.prefix(3))
    }
}

// MARK: - Corner overlay helper (keep-out by placement)

extension View {
    /// Overlay an `EarnedStickerCluster` in a corner of the receiver,
    /// inset from the edges. Because the cluster is bounded + corner-
    /// anchored, it stays clear of centered content (the keep-out).
    func earnedStickerCluster(
        animate: Bool,
        stickers: [StickerName] = [.flower3D, .heartGlossy, .sparkleGlossy],
        diameter: CGFloat = 116,
        alignment: Alignment = .topTrailing,
        inset: CGFloat = 4
    ) -> some View {
        overlay(alignment: alignment) {
            EarnedStickerCluster(animate: animate, stickers: stickers, diameter: diameter)
                .padding(inset)
                .allowsHitTesting(false)
        }
    }
}

#if DEBUG
#Preview("EarnedStickerCluster") {
    struct Demo: View {
        @State private var go = false
        var body: some View {
            ZStack {
                GrainfieldBackground()
                EarnedStickerCluster(animate: go, diameter: 160)
                Button("replay") { go = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { go = true } }
                    .offset(y: 140)
            }
            .onAppear { go = true }
        }
    }
    return Demo()
}
#endif
