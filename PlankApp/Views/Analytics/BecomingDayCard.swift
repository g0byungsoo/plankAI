import SwiftUI
import UIKit

// MARK: - Becoming day card (P3 share artifact)
//
// The her75 day-one card, JeniFit-voiced: a 9:16 export (1080×1920)
// with a paper day-card floating on cream. Facts pull ONLY from her
// real data (provenance rule); the TREND LINE IS NEVER ON THE SHARE
// by default (founder-locked: she never shares her mass — adherence
// + steps + plates are the share-safe numbers). ONE wax-seal sticker,
// corner-anchored, ±8° — the founder-approved share-card sub-register
// beside the scatter-milestone rule.

struct BecomingDayCardView: View {
    let dayNumber: Int
    let totalDays: Int?
    let dateRange: String?
    /// Up to 3 share-safe facts, already formatted ("4 of 7 days kept").
    let facts: [String]

    private var dayWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: dayNumber)) ?? "\(dayNumber)"
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary

            // The paper card — hard rose offset shadow, the scrapbook
            // chrome family at export scale (canvas units are 3x).
            VStack(alignment: .leading, spacing: 0) {
                (Text("day ")
                    .font(.custom("JeniHeroSerif-Regular", size: 110))
                 + Text(dayWord)
                    .font(.custom("JeniHeroSerif-Italic", size: 110)))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let totalDays {
                    Text("of \(totalDays) days")
                        .font(.custom("DMSans-Medium", size: 38))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 8)
                }
                if let dateRange {
                    Text(dateRange)
                        .font(.custom("DMSans-Medium", size: 34))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 4)
                }

                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 160, height: 3)
                    .padding(.vertical, 56)

                VStack(alignment: .leading, spacing: 44) {
                    ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                        HStack(alignment: .firstTextBaseline, spacing: 28) {
                            Text("\(index + 1)")
                                .font(.custom("JeniHeroSerif-Italic", size: 54))
                                .foregroundStyle(Palette.accent)
                            Text(fact)
                                .font(.custom("DMSans-Regular", size: 44))
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }
                }

                Spacer(minLength: 64)

                Text("jenifit")
                    .font(.custom("DMSans-Medium", size: 30))
                    .kerning(5.4)
                    .foregroundStyle(Palette.textSecondary.opacity(0.6))
            }
            .padding(72)
            .frame(width: 780, height: 1100, alignment: .topLeading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 64, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 12, y: 12)
                    RoundedRectangle(cornerRadius: 64, style: .continuous)
                        .fill(Palette.bgElevated)
                }
            )
            // The wax seal — ONE sticker, corner, tilted.
            .overlay(alignment: .topTrailing) {
                Image(StickerName.bowSatin.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(8))
                    .opacity(StickerName.bowSatin.style.opacity)
                    .offset(x: 36, y: -36)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

enum BecomingDayCardRenderer {
    @MainActor
    static func render(
        dayNumber: Int,
        totalDays: Int?,
        dateRange: String?,
        facts: [String]
    ) -> UIImage? {
        let card = BecomingDayCardView(
            dayNumber: dayNumber,
            totalDays: totalDays,
            dateRange: dateRange,
            facts: facts
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

/// Minimal UIActivityViewController host for the rendered card.
struct BecomingShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
