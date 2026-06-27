#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - SnapShareFont
//
// The curated, Instagram-style font set for the shareable card.
// Anchored on the app's own faces so a shared card always reads as
// JeniFit. Each case is a distinct mood; the picker pill renders its
// own label in its own face (the pill IS the preview).
public enum SnapShareFont: String, CaseIterable, Sendable {
    case editorial   // Playfair italic (JeniHeroSerif) — the her75 default
    case classic     // Fraunces optical serif — warm, bookish
    case clean       // DM Sans — minimal, Tiffany-restraint
    case statement   // Bodoni Moda — high-contrast didone, magazine drama

    public var label: String { rawValue }

    /// Exact PostScript name. All four ship in the app bundle and are
    /// registered process-wide at launch (CTFontManagerRegisterFontsForURL).
    var postScript: String {
        switch self {
        case .editorial: return "JeniHeroSerif-Italic"
        case .classic:   return "Fraunces72pt-SemiBold"
        case .clean:     return "DMSans-Medium"
        case .statement: return "BodoniModa-Regular"
        }
    }

    /// Per-face optical compensation so every option reads at a similar
    /// visual weight on the card (Bodoni's thin verticals want a touch
    /// more size; DM Sans a touch less than the swashy serifs).
    var sizeMultiplier: CGFloat {
        switch self {
        case .editorial: return 1.0
        case .classic:   return 0.96
        case .clean:     return 0.86
        case .statement: return 1.06
        }
    }
}

// MARK: - SnapShareCard
//
// The premium shareable card. Photo is the hero; the dish + stats are
// a legible overlay anchored to a bottom corner over an always-on
// gradient scrim (so white text reads on ANY plate). The dish text
// renders in the user-chosen SnapShareFont; the stats line stays
// DMSans (the constant factual layer) so the font choice reads as the
// expressive layer. A tiny jeni·fit wordmark signs the corner.
//
// One component, two roles:
//   - in-app preview  (embedsPhoto: false) — overlay only, the frozen
//     camera shows through the carousel slot.
//   - PNG export      (embedsPhoto: true)  — 1080×1920 canvas with the
//     photo embedded, rendered by SnapShareRenderer.
public struct SnapShareCard: View {

    public let photo: UIImage
    public let dishName: String
    public let itemNames: [String]
    public let totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int)
    public let loggedAt: Date
    public var font: SnapShareFont = .editorial
    /// Anchor the text block bottom-leading (false) or bottom-trailing (true).
    public var trailing: Bool = false
    public var embedsPhoto: Bool = true
    /// Extra on-screen bottom padding (NOT scaled) so the in-app preview
    /// lifts the text above the font-picker rail. 0 for the PNG export.
    public var bottomInset: CGFloat = 0

    public init(
        photo: UIImage,
        dishName: String,
        itemNames: [String],
        totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int),
        loggedAt: Date = Date(),
        font: SnapShareFont = .editorial,
        trailing: Bool = false,
        embedsPhoto: Bool = true,
        bottomInset: CGFloat = 0
    ) {
        self.photo = photo
        self.dishName = dishName
        self.itemNames = itemNames
        self.totals = totals
        self.loggedAt = loggedAt
        self.font = font
        self.trailing = trailing
        self.embedsPhoto = embedsPhoto
        self.bottomInset = bottomInset
    }

    public var body: some View {
        if embedsPhoto {
            ZStack {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 1080, height: 1920)
                    .clipped()
                scrim(scale: 1.0)
                overlay(scale: 1.0)
            }
            .frame(width: 1080, height: 1920)
            .clipped()
        } else {
            GeometryReader { geo in
                let scale = max(0.18, geo.size.width / 1080)
                ZStack {
                    scrim(scale: scale)
                    overlay(scale: scale)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    // MARK: Scrim — legibility guarantee on any photo

    @ViewBuilder private func scrim(scale: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.0),  location: 0.40),
                .init(color: .black.opacity(0.22), location: 0.66),
                .init(color: .black.opacity(0.72), location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: Overlay — dish (chosen font) + stats + wordmark

    private var dishLines: [String] {
        let cleaned = itemNames
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !cleaned.isEmpty { return Array(cleaned.prefix(3)) }
        let raw = dishName.isEmpty ? "kept plate" : dishName.lowercased()
        return [raw]
    }

    private var statsLine: String {
        let f = DateFormatter(); f.dateFormat = "h:mma"
        var parts = [f.string(from: loggedAt).lowercased()]
        if totals.kcal > 0 { parts.append("\(totals.kcal) cal") }
        if totals.protein > 0 { parts.append("\(totals.protein)g protein") }
        if totals.fiber > 0 { parts.append("\(totals.fiber)g fiber") }
        return parts.joined(separator: "  \u{00B7}  ")
    }

    @ViewBuilder private func overlay(scale: CGFloat) -> some View {
        let hAlign: HorizontalAlignment = trailing ? .trailing : .leading
        let tAlign: TextAlignment = trailing ? .trailing : .leading
        let dishSize = 80 * scale * font.sizeMultiplier
        VStack(alignment: hAlign, spacing: 14 * scale) {
            VStack(alignment: hAlign, spacing: 4 * scale) {
                ForEach(Array(dishLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.custom(font.postScript, size: dishSize))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(tAlign)
                        .shadow(color: .black.opacity(0.22), radius: 8 * scale, y: 1)
                }
            }
            Text(statsLine)
                .font(.custom("DMSans-Medium", size: 30 * scale))
                .foregroundStyle(.white.opacity(0.96))
                .multilineTextAlignment(tAlign)
                .shadow(color: .black.opacity(0.35), radius: 6 * scale, y: 1)
            Text("jeni\u{00B7}fit")
                .font(.custom("Fraunces72pt-Regular", size: 26 * scale))
                .foregroundStyle(.white.opacity(0.82))
                .shadow(color: .black.opacity(0.3), radius: 5 * scale, y: 1)
                .padding(.top, 4 * scale)
        }
        .padding(.horizontal, 64 * scale)
        .padding(.bottom, 96 * scale + bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: trailing ? .bottomTrailing : .bottomLeading)
        .allowsHitTesting(false)
    }
}

// MARK: - SnapShareRenderer  (PNG export at 1080×1920)

@MainActor
public enum SnapShareRenderer {
    public static func render(
        photo: UIImage,
        dishName: String,
        itemNames: [String],
        totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int),
        loggedAt: Date = Date(),
        font: SnapShareFont = .editorial,
        trailing: Bool = false
    ) -> UIImage? {
        let card = SnapShareCard(
            photo: photo, dishName: dishName, itemNames: itemNames,
            totals: totals, loggedAt: loggedAt, font: font,
            trailing: trailing, embedsPhoto: true
        )
        .frame(width: 1080, height: 1920)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}
#endif
