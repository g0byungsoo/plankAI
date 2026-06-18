#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenSnapResultShareCard
//
// v1.0.13 (2026-06-17) — REBUILT to match the daily/weekly card
// pattern. Founder direction: photo IS the share, drop all chrome.
// Previous v1.0.11 had a Marker Felt 96pt title strip + gradient
// strips + macro pill + pull quote + wordmark + sparkle scatter —
// founder rejected the same chrome stack on the daily card; same
// fix here.
//
// New layout (1080×1920, single-photo):
//
//   - Photo fills entire canvas (scaledToFill, clipped).
//   - One Bradley Hand label stack — dish name + detected food
//     items as a vertical list — anchored in a deterministic corner
//     picked from the dish-name hash so the same meal renders to
//     the same position across re-renders.
//   - One RoughHandArrow (reused from the daily card via the shared
//     CellLabelPosition + textBox geometry) from the label corner
//     to the photo's geometric center, where the food typically
//     sits. Same Posca-pen aesthetic as daily/weekly.
//   - NO header strip, NO footer strip, NO wordmark, NO sparkles,
//     NO subhead, NO macro pill, NO pull quote.

public struct HandwrittenSnapResultShareCard: View {

    public let photo: UIImage
    public let mealLabel: String      // unused in v1.0.13, kept for caller compat
    public let dishName: String       // "avocado toast with egg"
    public let itemNames: [String]    // detected food items (top 1-4)
    public let totals: (carbs: Int, protein: Int, fat: Int, kcal: Int)
    public var archetype: String? = nil

    public init(
        photo: UIImage,
        mealLabel: String,
        dishName: String,
        itemNames: [String],
        totals: (carbs: Int, protein: Int, fat: Int, kcal: Int),
        archetype: String? = nil
    ) {
        self.photo = photo
        self.mealLabel = mealLabel
        self.dishName = dishName
        self.itemNames = itemNames
        self.totals = totals
        self.archetype = archetype
    }

    public var body: some View {
        ZStack {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1920)
                .clipped()

            labelOverlay
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }

    // MARK: - Label overlay

    /// Deterministic per-dish corner so the same meal always renders
    /// the label to the same position. Hash → 4 corners.
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
        // Prefer the structured itemNames list when available — that's
        // the vertical ingredient stack the founder's references use
        // ("chia seeds / coconut milk / vanilla protein / ..."). Falls
        // back to splitting dishName on common separators if no items.
        let cleaned = itemNames
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !cleaned.isEmpty { return Array(cleaned.prefix(6)) }

        let splitChars = CharacterSet(charactersIn: ",+&")
        let raw = dishName.isEmpty ? "kept plate" : dishName.lowercased()
        var parts = raw
            .components(separatedBy: splitChars)
            .flatMap { $0.components(separatedBy: " with ") }
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if parts.isEmpty { parts = [raw] }
        return Array(parts.prefix(6))
    }

    @ViewBuilder private var labelOverlay: some View {
        let lines = labelLines
        let alignment: Alignment = {
            switch position {
            case .topLeft:     return .topLeading
            case .topRight:    return .topTrailing
            case .bottomLeft:  return .bottomLeading
            case .bottomRight: return .bottomTrailing
            }
        }()
        let seed = UInt64(bitPattern: Int64(dishName.hashValue & 0x7FFFFFFF))
        let textHeight: CGFloat = CGFloat(lines.count) * 64 + 12
        let longest = lines.map(\.count).max() ?? 8
        let textWidth: CGFloat = min(CGFloat(longest) * 26 + 48, 720)

        ZStack {
            RoughHandArrow(
                position: position,
                seed: seed,
                textWidth: textWidth,
                textHeight: textHeight
            )
            .stroke(
                .white,
                style: StrokeStyle(
                    lineWidth: 5,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: 1080, height: 1920)
            .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)

            VStack(spacing: 12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.custom("BradleyHandITCTT-Bold", size: 48))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 100)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
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
            itemNames: ["scrambled eggs", "avocado toast", "raspberries", "matcha latte"],
            totals: (carbs: 42, protein: 28, fat: 22, kcal: 420),
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
        totals: (carbs: Int, protein: Int, fat: Int, kcal: Int),
        archetype: String? = nil
    ) -> UIImage? {
        let card = HandwrittenSnapResultShareCard(
            photo: photo,
            mealLabel: mealLabel,
            dishName: dishName,
            itemNames: itemNames,
            totals: totals,
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
