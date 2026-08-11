import SwiftUI
import UIKit

// MARK: - WeeklyReceiptCard (v2.6 — the week, kept)
//
// docs/app_v2/25_WEEKLY_RECEIPT_ARTIFACT.md. The week translated
// into an artifact she might keep, send to a friend, or post if
// she's proud. Register: the wax-seal receipt — cream field, tracked
// eyebrow, serif week range, hairline receipt rows, jeni's line in
// serif italic, the wordmark, ONE glossy heart as the seal (share
// artifacts are earned moments; one sticker, ≤10% canvas, per the
// Direction-A guardrails). No gradients, no template energy.
//
// 4:5 portrait at 1080×1350 via ImageRenderer(scale: 3) — the size
// Instagram treats kindly and Messages renders full-width.

struct WeeklyReceiptCard: View {
    struct Model {
        let weekRange: String          // "june 27 – july 3"
        let plates: Int
        let loggedDays: Int
        let proteinDaysHit: Int
        let stepsTotal: Int?
        let trendLine: String?         // "eased down 400g" / "held its ground"
        let resets: Int                // breath sessions
        let jeniLine: String
    }

    let model: Model

    private let canvas = CGSize(width: 360, height: 450)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.bgPrimary

            // The seal — one glossy heart, overhanging the top-right
            // corner like it was pressed on after the fact.
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(11))
                .offset(x: -26, y: 22)

            VStack(alignment: .leading, spacing: 0) {
                Text("the week, kept")
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                Text(model.weekRange)
                    .font(.custom("JeniHeroSerif-Regular", size: 30))
                    .kerning(-0.4)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, 10)

                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.66)
                    .padding(.top, 20)

                VStack(spacing: 0) {
                    if model.plates > 0 {
                        row("plates seen", "\(model.plates), across \(model.loggedDays) days")
                    }
                    if model.proteinDaysHit > 0 {
                        row("protein landed", "\(model.proteinDaysHit) of 7 days")
                    }
                    if let steps = model.stepsTotal, steps > 0 {
                        row("their legs", "\(steps.formatted()) steps")
                    }
                    if let trend = model.trendLine {
                        row("the line", trend, italic: true)
                    }
                    if model.resets > 0 {
                        row("resets", model.resets == 1 ? "one breath taken" : "\(model.resets) breaths taken")
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)

                Text(model.jeniLine)
                    .font(.custom("JeniHeroSerif-Italic", size: 17))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Text("jeni")
                        .font(.custom("Fraunces72pt-SemiBold", size: 14))
                    Text("·")
                        .font(.custom("Fraunces72pt-SemiBold", size: 14))
                        .padding(.horizontal, 1)
                    Text("fit")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                }
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 18)
            }
            .padding(28)
        }
        .frame(width: canvas.width, height: canvas.height)
    }

    private func row(_ lead: String, _ punch: String, italic: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(lead)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.cocoaSecondary)
                Spacer(minLength: 12)
                Text(punch)
                    .font(italic
                          ? .custom("JeniHeroSerif-Italic", size: 16)
                          : .custom("DMSans-Medium", size: 14))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
            }
            .padding(.vertical, 11)
            Rectangle()
                .fill(Palette.hairlineCocoa.opacity(0.6))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Export

enum WeeklyReceiptRenderer {
    /// 1080×1350 PNG via ImageRenderer. MainActor because the view
    /// tree touches UIKit-backed font loading.
    @MainActor
    static func render(_ model: WeeklyReceiptCard.Model) -> UIImage? {
        let renderer = ImageRenderer(content: WeeklyReceiptCard(model: model))
        renderer.scale = 3
        return renderer.uiImage
    }
}
