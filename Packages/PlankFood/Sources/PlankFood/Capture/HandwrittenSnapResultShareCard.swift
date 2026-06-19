#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenSnapResultShareCard
//
// v1.0.17 (2026-06-18) — aligned to the daily/weekly card pattern.
// Drops the v1.0.13 RoughHandArrow + a-single-stack layout in favor
// of the same items + macro caption block that daily/weekly use,
// pulled into the 1-row CellMetrics tier (90pt items, 42pt macro)
// since the snap card is the full 1080×1920 single-photo register.
// Founder direction is uniform across all 3 share surfaces: photo
// IS the share, items + JeniFit-voice macro caption, no arrows.
//
// New layout (1080×1920, single photo):
//
//   - Photo bleeds full canvas.
//   - One label stack in a deterministic corner picked from the
//     dish-name hash so the same meal renders to the same corner
//     across re-renders.
//   - Items in BradleyHandITCTT-Bold (handwriting signature).
//   - Macro caption "8:42am · 380 calories · 18g protein · 7g fiber"
//     in DMSans-Medium (JeniFit voice).
//   - NO arrows, NO header strip, NO footer strip, NO sparkles.

public struct HandwrittenSnapResultShareCard: View {

    public let photo: UIImage
    public let mealLabel: String      // unused since v1.0.13, kept for caller compat
    public let dishName: String       // "avocado toast with egg"
    public let itemNames: [String]    // detected food items (top 1-4)
    public let totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int)
    public let loggedAt: Date
    public var archetype: String? = nil
    /// v1.0.30 (2026-06-19) — when false, the embedded photo is
    /// skipped and the background goes transparent. NutritionCarousel
    /// uses this mode so the underlying camera frame shows through
    /// (no photo-over-photo). The share PNG renderer keeps the
    /// default `true` so exported artifacts still embed the photo.
    public var embedsPhoto: Bool = true

    public init(
        photo: UIImage,
        mealLabel: String,
        dishName: String,
        itemNames: [String],
        totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int),
        loggedAt: Date = Date(),
        archetype: String? = nil,
        embedsPhoto: Bool = true
    ) {
        self.photo = photo
        self.mealLabel = mealLabel
        self.dishName = dishName
        self.itemNames = itemNames
        self.totals = totals
        self.loggedAt = loggedAt
        self.archetype = archetype
        self.embedsPhoto = embedsPhoto
    }

    public var body: some View {
        ZStack {
            if embedsPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 1080, height: 1920)
                    .clipped()
            } else {
                Color.clear
            }

            labelOverlay
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }

    // MARK: - Label overlay

    private var position: HandwrittenDailyShareCard.CellLabelPosition {
        let h = abs(dishName.hashValue) % 4
        switch h {
        case 0: return .topRight
        case 1: return .bottomLeft
        case 2: return .topLeft
        default: return .bottomRight
        }
    }

    private var labelLines: [String] {
        let cleaned = itemNames
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !cleaned.isEmpty { return cleaned }

        let splitChars = CharacterSet(charactersIn: ",+&")
        let raw = dishName.isEmpty ? "kept plate" : dishName.lowercased()
        var parts = raw
            .components(separatedBy: splitChars)
            .flatMap { $0.components(separatedBy: " with ") }
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !HandwrittenDailyShareCard.isCountMorePlaceholder($0) }
        if parts.isEmpty { parts = [raw] }
        return parts
    }

    private var macroCaption: String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let time = timeFmt.string(from: loggedAt).lowercased()
        var parts = [time]
        if totals.kcal > 0 {
            parts.append("\(totals.kcal) calories")
        }
        if totals.protein > 0 {
            parts.append("\(totals.protein)g protein")
        }
        if totals.fiber > 0 {
            parts.append("\(totals.fiber)g fiber")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var labelOverlay: some View {
        // v1.0.17 — share the 1-row CellMetrics tier with daily/weekly
        // so the snap card stays on the same font ladder when the
        // founder bumps sizes elsewhere.
        let metrics = HandwrittenDailyShareCard.cellMetrics(forRows: 1)
        let lines = Array(labelLines.prefix(metrics.maxItems))
        let macroLine = macroCaption
        let alignment: Alignment = {
            switch position {
            case .topLeft:     return .topLeading
            case .topRight:    return .topTrailing
            case .bottomLeft:  return .bottomLeading
            case .bottomRight: return .bottomTrailing
            }
        }()
        let isTop = position == .topLeft || position == .topRight
        let textAlign: TextAlignment = (position == .topLeft || position == .bottomLeft)
            ? .leading : .trailing
        let hAlign: HorizontalAlignment = (position == .topLeft || position == .bottomLeft)
            ? .leading : .trailing

        VStack(alignment: hAlign, spacing: metrics.stackSpacing) {
            if isTop {
                itemStack(lines, align: textAlign, metrics: metrics)
                macroCaptionView(macroLine, metrics: metrics)
            } else {
                macroCaptionView(macroLine, metrics: metrics)
                itemStack(lines, align: textAlign, metrics: metrics)
            }
        }
        .padding(.horizontal, metrics.hPad)
        .padding(.vertical, metrics.vPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    @ViewBuilder
    private func itemStack(
        _ lines: [String],
        align: TextAlignment,
        metrics: HandwrittenDailyShareCard.CellMetrics
    ) -> some View {
        let hAlign: HorizontalAlignment = (align == .leading) ? .leading
                                        : (align == .trailing) ? .trailing
                                        : .center
        VStack(alignment: hAlign, spacing: metrics.itemsSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.custom("BradleyHandITCTT-Bold", size: metrics.itemsFont))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(align)
            }
        }
    }

    @ViewBuilder
    private func macroCaptionView(
        _ line: String,
        metrics: HandwrittenDailyShareCard.CellMetrics
    ) -> some View {
        Text(line)
            .font(.custom("DMSans-Medium", size: metrics.macroFont))
            .foregroundStyle(.white.opacity(0.92))
    }
}

// MARK: - Public preview helper

extension HandwrittenSnapResultShareCard {
    public static func preview(
        archetype: String? = "protein"
    ) -> HandwrittenSnapResultShareCard {
        let placeholder = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920))
            .image { ctx in
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor(red: 0.94, green: 0.78, blue: 0.79, alpha: 1).cgColor,
                        UIColor(red: 0.85, green: 0.55, blue: 0.62, alpha: 1).cgColor,
                    ] as CFArray,
                    locations: [0, 1]
                )!
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 1080, y: 1920),
                    options: []
                )
            }
        return HandwrittenSnapResultShareCard(
            photo: placeholder,
            mealLabel: "Breakfast",
            dishName: "avocado toast with egg",
            itemNames: ["avocado toast", "scrambled eggs", "raspberries", "matcha latte"],
            totals: (carbs: 42, protein: 28, fat: 22, fiber: 7, kcal: 420),
            loggedAt: Date(),
            archetype: archetype
        )
    }
}

// MARK: - HandwrittenSnapResultShareRenderer
//
// MainActor-bound renderer that produces the 1080×1920 PNG for the
// share sheet / save-to-Photos pipeline. Matches the daily / weekly
// card render contract.

@MainActor
public enum HandwrittenSnapResultShareRenderer {

    public static func render(
        photo: UIImage,
        mealLabel: String,
        dishName: String,
        itemNames: [String],
        totals: (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int),
        loggedAt: Date = Date(),
        archetype: String? = nil
    ) -> UIImage? {
        let card = HandwrittenSnapResultShareCard(
            photo: photo,
            mealLabel: mealLabel,
            dishName: dishName,
            itemNames: itemNames,
            totals: totals,
            loggedAt: loggedAt,
            archetype: archetype
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

#endif  // canImport(UIKit)
