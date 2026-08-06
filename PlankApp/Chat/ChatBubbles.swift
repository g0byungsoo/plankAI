import SwiftUI

// MARK: - Chat bubbles (1.1.5 — iMessage-grade, JeniFit-warm)
//
// The jeni tab used to render as editorial letters (jeni's words bare on
// the cream). The founder asked for a real chat: bubbles with tails, a
// spring pop on every message, a typing indicator, and haptics. This is
// that system — but kept in the brand's register, not iOS chrome: soft
// white for jeni (serif-italic prose inside), a warm blush for her own
// words, one continuous tail per run. No blue, no gray.

// MARK: - ChatBubbleShape

/// A continuous rounded bubble with a small tail curling out of the
/// bottom corner on the sender's side. `hasTail` is true only for the
/// last bubble of a run, so a burst of messages reads as one voice with
/// a single tail (the iMessage grouping rule). Built as one filled path
/// — no background-colored cutout — so it composes over the grain.
struct ChatBubbleShape: Shape {
    var isFromUser: Bool
    var hasTail: Bool
    var radius: CGFloat = 19

    func path(in rect: CGRect) -> Path {
        let base = receivedPath(in: rect)
        guard isFromUser else { return base }
        // Mirror horizontally so the tail sits on the trailing corner.
        return base.applying(
            CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -rect.width, y: 0)
        )
    }

    /// The received (leading-tail) bubble. The tail dips ~5pt below the
    /// body and hooks back in, so give the bubble a hair of bottom room.
    private func receivedPath(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, r = min(radius, min(w, h) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h - r))
        p.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))
        if hasTail {
            p.addLine(to: CGPoint(x: r, y: h))
            p.addQuadCurve(to: CGPoint(x: 1, y: h + 5), control: CGPoint(x: 7, y: h + 3))
            p.addQuadCurve(to: CGPoint(x: 8, y: h - 3), control: CGPoint(x: 3.5, y: h + 1))
            p.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h - 3))
        } else {
            p.addLine(to: CGPoint(x: r, y: h))
            p.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
        }
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Bubble backgrounds (v11.5 — the bubbles return, in material)
//
// The mission-2 pass typeset both voices bare on the cream and left
// ChatBubbleShape orphaned. The founder's Lovi steer brings the
// bubbles back — but as MATERIAL, not iOS chrome: jeni speaks from a
// soft white surface with the kit's own diffuse depth, and her words
// answer from a blush fill that still carries her rose italic. Two
// voices, two materials, one tail per run (the grouping rule).

struct JeniBubbleBackground: ViewModifier {
    var hasTail: Bool
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ChatBubbleShape(isFromUser: false, hasTail: hasTail)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.05), radius: 12, y: 5)
                    .shadow(color: Palette.textPrimary.opacity(0.03), radius: 2, y: 1)
            )
            // The tail dips ~5pt below the body; give the run room so
            // neighbours never clip it.
            .padding(.bottom, hasTail ? 5 : 0)
    }
}

struct UserBubbleBackground: ViewModifier {
    var hasTail: Bool
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Palette.jeweledRose)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ChatBubbleShape(isFromUser: true, hasTail: hasTail)
                    .fill(Palette.accentSubtle)
            )
            .padding(.bottom, hasTail ? 5 : 0)
    }
}

extension View {
    func jeniBubble(hasTail: Bool) -> some View {
        modifier(JeniBubbleBackground(hasTail: hasTail))
    }
    func userBubble(hasTail: Bool) -> some View {
        modifier(UserBubbleBackground(hasTail: hasTail))
    }
}

// MARK: - Typing indicator

/// The loading state: jeni's bubble with three dots riding a wave. Shows
/// the instant she starts composing, before the first token lands, so a
/// reply never appears from nothing.
struct ChatTypingDots: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.cocoaTertiary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1 : 0.55)
                    .opacity(animating ? 0.95 : 0.4)
                    .animation(
                        reduceMotion ? nil
                            : .easeInOut(duration: 0.62)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.16),
                        value: animating
                    )
            }
        }
        .padding(.vertical, 2)
        .onAppear { animating = true }
        .accessibilityLabel("jeni is typing")
    }
}

// MARK: - Entrance transition

extension AnyTransition {
    /// The iMessage pop: a bubble scales up from its sender corner with a
    /// touch of rise, so it looks launched from the composer / her side.
    static func bubblePop(fromUser: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.55, anchor: fromUser ? .bottomTrailing : .bottomLeading)
                .combined(with: .opacity)
                .combined(with: .offset(y: 12)),
            removal: .opacity
        )
    }
}
