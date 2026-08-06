import SwiftUI

// MARK: - V8 type registers
//
// jeni's written voice. One serif register for the whole transcript
// (30pt — the letter, staged); the reference's single-size column is
// what makes it read as conversation, not layout.

enum V8Type {
    static let message = Font.custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title)
    static let messageItalic = Font.custom("JeniHeroSerif-Italic", size: 30, relativeTo: .title)
    /// her75 negative leading, scaled to the 30pt cut (−0.3×).
    static let messageLineGap: CGFloat = -9
    static let caption = Font.custom("DMSans-Regular", size: 14, relativeTo: .footnote)
}

// MARK: - V8Msg

struct V8Msg: Identifiable, Equatable {
    let id: Int
    var line: V8Line
    var revealed: Int
}

// MARK: - V8Transcript
//
// One column, one motion. Every message lives in a single VStack whose
// vertical offset keeps the ACTIVE (last) message's top edge at
// `anchorY`; history stacks above, dimming by distance (1 → 0.42 →
// 0.16 → removed). Because the whole column moves together on one
// spring, the advance is a single connected gesture — never two
// animations fighting.
//
// Heights are measured per message so the offset math is exact even
// mid-type (the clear-painted suffix means a message's height is
// final from its first frame — no jitter as ink arrives).

struct V8Transcript<Input: View>: View {
    let messages: [V8Msg]
    let anchorY: CGFloat
    /// The input composes INTO the column, under the active message —
    /// layout owns the seating, never manual math (loop-1 lesson: the
    /// measured-bottom approach went stale and overlapped the question).
    @ViewBuilder var input: () -> Input

    @Environment(\.v8OnInk) private var onInk
    @State private var heights: [Int: CGFloat] = [:]

    private let gap: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { idx, msg in
                let done = msg.revealed >= msg.line.text.count
                VStack(alignment: .leading, spacing: 10) {
                    V8LineText(
                        line: msg.line,
                        revealed: msg.revealed,
                        font: V8Type.message,
                        italicFont: V8Type.messageItalic,
                        color: V8InkAware.text(onInk)
                    )
                    .lineSpacing(V8Type.messageLineGap)

                    if let citation = msg.line.citation {
                        Text(citation)
                            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption2))
                            .foregroundStyle(V8InkAware.tertiary(onInk))
                            .opacity(done ? 1 : 0)
                            .animation(.easeOut(duration: 0.3), value: done)
                    }

                    if let figure = msg.line.figure, done {
                        V8FigureView(figure: figure)
                            .padding(.top, 4)
                            .padding(.trailing, Space.sm)
                            .transition(.opacity)
                    }
                }
                .opacity(opacity(forIndex: idx))
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    heights[msg.id] = newHeight
                }
                .transition(.opacity)
            }

            input()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .offset(y: columnOffset)
        .animation(V8Tempo.advance, value: offsetKey)
        .accessibilityElement(children: .contain)
    }

    // MARK: geometry

    private var activeID: Int? { messages.last?.id }

    private var historyHeight: CGFloat {
        guard messages.count > 1 else { return 0 }
        return messages.dropLast().reduce(CGFloat(0)) { acc, msg in
            acc + (heights[msg.id] ?? 0) + gap
        }
    }

    private var activeHeight: CGFloat {
        guard let activeID else { return 0 }
        return heights[activeID] ?? 0
    }

    private var columnOffset: CGFloat { anchorY - historyHeight }

    /// One value that changes whenever layout-relevant state does, so
    /// the offset animates as a single spring per advance.
    private var offsetKey: String {
        "\(messages.count)-\(Int(historyHeight))-\(Int(anchorY))"
    }

    private func opacity(forIndex idx: Int) -> Double {
        let fromEnd = messages.count - 1 - idx
        switch fromEnd {
        case 0: return 1.0
        case 1: return V8Tempo.dim1
        default: return V8Tempo.dim2
        }
    }
}
