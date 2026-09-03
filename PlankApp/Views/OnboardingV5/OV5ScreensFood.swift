import SwiftUI

// p70 — THE V5 SWEEP: the Act II screen flow died with the v5 debug
// escape (the v8 consult owns these beats now). What survives here is
// the wrapping chip layout, which MoveSheet and the side-effect cloud
// still speak.

// MARK: - OV5ChipCloud (wrapping chip layout, text-only)

struct OV5ChipCloud: View {
    let options: [(String, String)]
    @Binding var selection: Set<String>

    var body: some View {
        OV5FlowLayout(hSpacing: 8, vSpacing: 10) {
            ForEach(options, id: \.0) { key, label in
                let isOn = selection.contains(key)
                Button {
                    Haptics.soft()
                    withAnimation(Motion.tap) {
                        if isOn { selection.remove(key) } else { selection.insert(key) }
                    }
                } label: {
                    Text(label)
                        .font(Typo.heroSubpill)
                        .kerning(0.2)
                        .foregroundStyle(isOn ? Palette.textInverse : Palette.textPrimary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isOn ? Palette.cocoaPrimary : Palette.bgElevated)
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isOn ? Color.clear : Palette.hairlineCocoa, lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressFeedbackStyle())
            }
        }
    }
}

/// Greedy left-aligned wrap layout for chips (iOS 16+ Layout).
struct OV5FlowLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowH + vSpacing; rowH = 0 }
            x += size.width + hSpacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > bounds.width && x > bounds.minX {
                x = bounds.minX; y += rowH + vSpacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            rowH = max(rowH, size.height)
        }
    }
}
