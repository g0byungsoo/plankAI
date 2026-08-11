import SwiftUI

// MARK: - JeniDesk (v11.5 — the chat's opening)
//
// The founder's Lovi reference: the mark, a greeting, "start a chat"
// bubbles, then what came before. Built in paper and ink.
//
// One honest departure. Lovi lists past CONVERSATIONS because it
// threads them; Jeni keeps ONE continuous transcript with day seams,
// so the history section shows her real days and the line each one
// opened with. Nothing is invented, and no "new chat" button appears
// that would imply a thread she could throw away (L8).

struct JeniDesk: View {
    /// Provenance-backed openers, computed upstream from live state.
    let starters: [String]
    /// Recent days, newest first: (day label, the line she opened with).
    let past: [(day: String, line: String)]
    /// v25 E6 — what she already has on file, composed upstream from
    /// the same snapshot the starters read.
    var awareness: JeniAwarenessLine = .init(
        text: "your coach, day to day.", isProof: false
    )
    let onStart: (String) -> Void

    @State private var arrived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mark
                .frame(maxWidth: .infinity)
                .padding(.top, Space.hero)
                .jeniArrive(arrived, index: 0)

            JeniHeadline("hi. i'm jeni.", italic: ["jeni."], register: .page)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, Space.blockGap)
                .jeniArrive(arrived, index: 1)

            // Her actual opening line leads when there is one — the
            // desk should say something true, not a tagline.
            // ONE quiet line under the name. Her daily reading is a
            // paragraph — centred and full it became a wall of serif
            // that read as a run-on (frame-caught, twice). The reading
            // belongs in the conversation, one tap away; the desk's
            // job is to greet and to offer.
            // v25 E4 (G9): "between visits" implies clinician visits
            // — true only for care-connected users. Consumers get the
            // plain claim; the identity footnote below carries the
            // rest.
            // v25 E6 THE DESK — this line used to be the tagline
            // "your coach, day to day.", a CLAIM in the one place a
            // person looks before deciding whether jeni is worth
            // talking to. E3 gave her eight reads over the same engines
            // every surface renders from and the desk exposed none of
            // it at rest. It now carries what she ALREADY HAS on file,
            // and falls back to the claim only when the record is
            // genuinely empty (JeniDeskAwareness, table-tested).
            Text(awareness.text)
                .font(Typo.body)
                .foregroundStyle(
                    awareness.isProof ? Palette.textPrimary : Palette.textSecondary
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Space.lg)
                .padding(.top, 6)
                .jeniArrive(arrived, index: 2)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("start a chat")
                StarterBubbles(starters: starters, onStart: onStart)
            }
            .jeniArrive(arrived, index: 3)

            if !past.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    JeniSectionHeader("what you've talked about")
                    VStack(spacing: 10) {
                        ForEach(Array(past.enumerated()), id: \.offset) { _, item in
                            Button { onStart(item.line) } label: {
                                JeniSurface(radius: 20, padding: Space.md) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.line)
                                            .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                                            .foregroundStyle(Palette.textPrimary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Text(item.day)
                                            .font(Typo.caption)
                                            .foregroundStyle(Palette.cocoaTertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(JeniPressable())
                            .accessibilityLabel("\(item.day). \(item.line). ask it again")
                        }
                    }
                }
                .jeniArrive(arrived, index: 4)
            }

            // The disclaimer is a footnote to the OPENERS, not a page
            // footer: it belongs under the thing it qualifies. (Two
            // attempts at pinning it to the foot fought the scroll
            // geometry for no gain — the block sitting in the upper
            // two-thirds with the composer anchoring the bottom is
            // the reference's own proportion.)
            Text("jeni is a digital coach. not a person, not your clinician.")
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .jeniArrive(arrived, index: 5)
                // The bubbles' tails hang BELOW their frames, so a
                // flush footnote collided with them (frame-caught).
                .padding(.top, Space.md)
                .padding(.bottom, Space.blockGap)
        }
        .padding(.horizontal, Space.gutter)
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
            arrived = true
        }
    }

    /// The hand-drawn j on a soft disc — the brand mark, at rest.
    private var mark: some View {
        ZStack {
            Circle()
                .fill(Palette.bgElevated)
                .frame(width: 96, height: 96)
                .shadow(color: Palette.textPrimary.opacity(0.06), radius: 18, y: 8)
            JeniMark(height: 44, color: Palette.textPrimary)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - StarterBubbles
//
// Lovi's speech bubbles, wrapped: each opener is the shape of the
// thing it starts. They lay out on real lines rather than a
// horizontal rail, so nothing important hides off-screen.

private struct StarterBubbles: View {
    let starters: [String]
    let onStart: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 10, lineSpacing: 10) {
            ForEach(starters, id: \.self) { text in
                Button {
                    JeniHaptic.tick()
                    onStart(text)
                } label: {
                    HStack(spacing: 8) {
                        Text(text)
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Palette.textPrimary))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        // A bubble, not a pill: the tail says this is
                        // something you SAY.
                        BubbleShape()
                            .fill(Palette.bgElevated)
                            .shadow(color: Palette.textPrimary.opacity(0.05),
                                    radius: 10, y: 4)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(JeniPressable())
                .accessibilityLabel("start: \(text)")
            }
        }
    }
}

/// A rounded bubble with a small tail at the lower-left.
private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        var p = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        let tail = CGRect(x: rect.minX + 6, y: rect.maxY - 5, width: 11, height: 9)
        p.addEllipse(in: tail)
        p.addEllipse(in: CGRect(x: tail.minX - 4, y: tail.maxY - 2, width: 5, height: 4))
        return p
    }
}

// MARK: - FlowLayout
//
// Wraps children onto lines. iOS 16+ Layout, so the bubbles size to
// their own words rather than to a grid that would clip the long ones.

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
