import SwiftUI

// MARK: - JKTabBar
//
// Three lowercase words and a dot. No icons, no glass slab — the
// editorial move: the labels ARE the icons. The active label swaps
// to the serif italic (the her75 punch register) and a 3.5pt cocoa
// dot slides beneath it with matched geometry. A soft haptic marks
// the switch; content cross-fades in the shell above.
//
// The bar is chrome: cream with a 0.33pt hairline top rule and a
// gentle gradient dissolve so scrolling content sinks beneath it
// instead of hard-clipping. Height 50 + safe area.

enum JKTab: String, CaseIterable, Identifiable {
    case today
    case jeni
    case becoming

    var id: String { rawValue }
    var label: String { rawValue }
}

struct JKTabBar: View {
    @Binding var selection: JKTab
    /// Quiet attention dot (e.g. jeni answered while she was away).
    var badge: JKTab? = nil

    @Namespace private var dotSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(JKTab.allCases) { tab in
                tabItem(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 50)
        .background(alignment: .top) {
            // The dissolve rides ABOVE the bar so content sinks into
            // cream before it reaches the labels.
            LinearGradient(
                colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            .offset(y: -24)
            .allowsHitTesting(false)
        }
        .background(Palette.bgPrimary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.33)
        }
    }

    @ViewBuilder private func tabItem(_ tab: JKTab) -> some View {
        let isActive = selection == tab
        Button {
            guard !isActive else { return }
            Haptics.soft()
            if reduceMotion {
                selection = tab
            } else {
                withAnimation(Motion.gentleSpring) { selection = tab }
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if isActive {
                            Text(tab.label)
                                .font(.custom("JeniHeroSerif-Italic", size: 17))
                        } else {
                            Text(tab.label)
                                .font(.custom("DMSans-Medium", size: 14))
                        }
                    }
                    .foregroundStyle(isActive ? Palette.textPrimary : Palette.cocoaTertiary)

                    if badge == tab && !isActive {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 5, height: 5)
                            .offset(x: 8, y: -1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                // Fixed-height dot slot so labels never shift vertically.
                ZStack {
                    Color.clear.frame(height: 4)
                    if isActive {
                        Circle()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 3.5, height: 3.5)
                            .matchedGeometryEffect(id: "jk.tab.dot", in: dotSpace)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
