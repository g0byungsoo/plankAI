import SwiftUI
import UIKit

// MARK: - JKPlateStrip
//
// Today's plates as a filmstrip — 56×70 photo thumbs (4:5, the
// magazine crop) with the time beneath, plus the [+] tile. Photos
// first, always; text-only entries render as cream recipe-card
// minis (serif initial) so the strip never shows a dead grey icon.

struct JKPlateStripItem: Identifiable, Equatable {
    let id: String
    let time: String            // "12:10"
    let title: String
    let image: UIImage?
    let kcal: Int
}

struct JKPlateStrip: View {
    let items: [JKPlateStripItem]
    let onAdd: () -> Void
    var onTapItem: ((JKPlateStripItem) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // v2.8 — plates arrive like dealt cards: a per-index
                // stagger (60ms) with a soft rise, once per mount.
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        Haptics.light()
                        onTapItem?(item)
                    } label: {
                        VStack(spacing: 5) {
                            thumb(item)
                            Text(item.time)
                                .font(Typo.statLabel)
                                .kerning(0.66)
                                .foregroundStyle(Palette.cocoaTertiary)
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(JKPress())
                    .jkBeat2(extraDelay: 0.06 * Double(index))
                    .accessibilityLabel("\(item.title), \(item.time)")
                }

                addTile
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder private func thumb(_ item: JKPlateStripItem) -> some View {
        Group {
            if let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Palette.bgElevated
                    Text(String(item.title.prefix(1)))
                        .font(.custom("JeniHeroSerif-Italic", size: 22))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .frame(width: 56, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
    }

    private var addTile: some View {
        Button {
            Haptics.light()
            onAdd()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            Palette.cocoaPrimary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    Image(systemName: "camera")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .frame(width: 56, height: 70)
                Text("snap")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("snap a meal")
    }
}
