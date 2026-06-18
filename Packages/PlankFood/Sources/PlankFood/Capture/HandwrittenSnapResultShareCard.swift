#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenSnapResultShareCard
//
// v1.0.11 (2026-06-17) — REBUILT after founder review of v1.0.10.
// Previous cream-card-with-tiny-photo design read as a cute postcard,
// not a TikTok / IG share. Founder reference reel ("feast mode",
// "Seattle food dump", bowl-label posts) shares one principle:
// THE PHOTO IS THE SHARE. Handwriting, labels, and decorations layer
// directly onto the photo — no cream frame, no polaroid matte.
//
// Layout (1080×1920, photo-bleed):
//
//   - Photo fills entire canvas (scaledToFill, clipped)
//   - Top gradient overlay (0 → 700pt): dark→transparent for title
//     legibility against any photo
//   - Bottom gradient overlay (1360 → 1920pt): transparent→dark for
//     wordmark + macro pill legibility
//   - Title: Marker Felt-Wide 96pt white w/ shadow, top-leading,
//     archetype-aware variant pool
//   - Subhead row: "breakfast · 420 cal" Bradley Hand-Bold 28pt white
//   - Primary item label: Bradley Hand-Bold 42pt + hand-drawn curved
//     arrow pointing toward the photo center
//   - Secondary item labels: 28pt with short arrows, lower-left
//   - Macro pill: 26pt Bradley Hand at bottom-leading
//   - Pull quote: 24pt Bradley Hand under the macros
//   - Wordmark: Marker Felt-Wide 38pt + heart, bottom-trailing
//   - Decorative scatter: 3 SF Symbols (sparkle / heart / star),
//     white-with-shadow so they stay legible on any photo
//
// All text gets a black drop shadow at 0.4-0.45 opacity for legibility
// against bright / dark / busy plates. Hand-drawn arrows use cubic
// bezier Paths stroked at 3pt white + matching shadow.

public struct HandwrittenSnapResultShareCard: View {

    public let photo: UIImage
    public let mealLabel: String      // "Breakfast" / "Lunch" / etc.
    public let dishName: String       // "scrambled eggs + avocado toast"
    public let itemNames: [String]    // top 1-4 food item names from the scan
    public let totals: (carbs: Int, protein: Int, fat: Int, kcal: Int)
    /// Optional archetype string ("protein" / "balanced" / "movement"
    /// / "rest"). Drives the title-line variant pool when present.
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
            photoBleed
            gradientOverlays
            decorativeOverlay
            contentOverlay
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }

    // MARK: - Photo + gradients

    @ViewBuilder private var photoBleed: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: 1080, height: 1920)
            .clipped()
    }

    @ViewBuilder private var gradientOverlays: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.50),
                    Color.black.opacity(0.20),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 700)
            Spacer()
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.60),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 560)
        }
        .frame(width: 1080, height: 1920)
        .allowsHitTesting(false)
    }

    // MARK: - Overlay content

    @ViewBuilder private var contentOverlay: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)
            titleBlock.padding(.horizontal, 70)

            Spacer()

            // Primary item label right-aligned w/ hand-drawn arrow
            // curving toward the photo center.
            if let primary = itemNames.first {
                primaryItemRow(name: primary).padding(.horizontal, 70)
            }

            Spacer().frame(height: 40)

            // Secondary item labels — up to 3 small chips left-aligned
            // along the lower-third of the canvas.
            secondaryItemsRow.padding(.horizontal, 70)

            Spacer().frame(height: 40)

            HStack(alignment: .bottom) {
                macroPill
                Spacer()
                wordmark
            }
            .padding(.horizontal, 70)

            Spacer().frame(height: 70)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Title (Marker Felt brush register)

    @ViewBuilder private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleLine)
                .font(.custom("MarkerFelt-Wide", size: 96))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(mealLabel.lowercased())
                    .font(.custom("BradleyHandITCTT-Bold", size: 28))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                Text("·")
                    .font(.custom("BradleyHandITCTT-Bold", size: 28))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                Text("\(totals.kcal) cal")
                    .font(.custom("BradleyHandITCTT-Bold", size: 28))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleLine: String {
        let pool = archetype.flatMap { Self.archetypeTitlePool[$0.lowercased()] }
            ?? Self.universalTitlePool
        let key = (dishName + (archetype ?? "") + mealLabel)
            .reduce(0) { $0 &+ Int($1.asciiValue ?? 0) }
        return pool[abs(key) % pool.count]
    }

    // MARK: - Primary item row

    @ViewBuilder
    private func primaryItemRow(name: String) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Spacer(minLength: 80)
            HandDrawnCurvedArrow(direction: .rightToLeft)
                .stroke(.white,
                        style: StrokeStyle(lineWidth: 3.5,
                                           lineCap: .round,
                                           lineJoin: .round))
                .frame(width: 130, height: 60)
                .shadow(color: .black.opacity(0.40), radius: 3, x: 0, y: 2)
            Text(name.lowercased())
                .font(.custom("BradleyHandITCTT-Bold", size: 44))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 2)
                .lineLimit(2)
        }
    }

    // MARK: - Secondary items row

    @ViewBuilder private var secondaryItemsRow: some View {
        let extras = Array(itemNames.dropFirst().prefix(3))
        if extras.isEmpty {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 30) {
                ForEach(Array(extras.enumerated()), id: \.offset) { _, name in
                    secondaryItemChip(name)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func secondaryItemChip(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HandDrawnCurvedArrow(direction: .leftToRight)
                .stroke(.white,
                        style: StrokeStyle(lineWidth: 2.8,
                                           lineCap: .round,
                                           lineJoin: .round))
                .frame(width: 70, height: 28)
                .shadow(color: .black.opacity(0.40), radius: 2, x: 0, y: 1)
            Text(name.lowercased())
                .font(.custom("BradleyHandITCTT-Bold", size: 30))
                .foregroundStyle(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Macro pill

    @ViewBuilder private var macroPill: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(totals.protein)g protein · \(totals.carbs)g carbs · \(totals.fat)g fat")
                .font(.custom("BradleyHandITCTT-Bold", size: 26))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
            Text(quoteLine)
                .font(.custom("BradleyHandITCTT-Bold", size: 24))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
        }
    }

    private var quoteLine: String {
        let pool = archetype.flatMap { Self.archetypeQuotePool[$0.lowercased()] }
            ?? Self.universalQuotePool
        let key = (dishName + (archetype ?? ""))
            .reduce(0) { $0 &+ Int($1.asciiValue ?? 0) }
        return pool[abs(key) % pool.count]
    }

    // MARK: - Wordmark

    @ViewBuilder private var wordmark: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
            Text("jenifit")
                .font(.custom("MarkerFelt-Wide", size: 40))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Decorative scatter

    @ViewBuilder private var decorativeOverlay: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .rotationEffect(.degrees(-12))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                .position(x: 950, y: 200)

            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.88))
                .rotationEffect(.degrees(16))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                .position(x: 850, y: 380)

            Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.88))
                .rotationEffect(.degrees(-18))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                .position(x: 980, y: 1820)
        }
        .frame(width: 1080, height: 1920)
        .allowsHitTesting(false)
    }
}

// MARK: - Pools

private extension HandwrittenSnapResultShareCard {

    static let universalTitlePool: [String] = [
        "she ate well",
        "kept the table set",
        "today fits",
        "a plate kept",
        "she made this",
    ]

    static let archetypeTitlePool: [String: [String]] = [
        "protein": [
            "anchored",
            "protein kept",
            "muscle stays",
            "lean and steady",
        ],
        "balanced": [
            "a little of everything",
            "the middle path",
            "balanced + whole",
        ],
        "movement": [
            "fueled the lift",
            "earned every bite",
            "strength on the plate",
        ],
        "rest": [
            "softer today",
            "permission",
            "quiet plates",
        ],
    ]

    static let universalQuotePool: [String] = [
        "today fits ♡",
        "kept it ♡",
        "she ate well",
        "one plate at a time ♡",
        "soft + steady",
        "becoming, quietly",
    ]

    static let archetypeQuotePool: [String: [String]] = [
        "protein": [
            "anchored ♡",
            "muscle kept",
            "lean and steady ♡",
        ],
        "balanced": [
            "balanced enough ♡",
            "varied + whole",
            "middle path ♡",
        ],
        "movement": [
            "fueled the work ♡",
            "carbs did the work",
            "powered forward ♡",
        ],
        "rest": [
            "softer today ♡",
            "permission ♡",
            "quiet plates",
        ],
    ]
}

// MARK: - HandDrawnCurvedArrow

/// Single cubic-bezier curved arrow with a stroked arrowhead. Designed
/// to look hand-pulled — slight S-curve, rounded line caps. Two
/// directions cover the right-anchored primary label (`rightToLeft`)
/// and the left-anchored secondary chips (`leftToRight`).
struct HandDrawnCurvedArrow: Shape {
    enum Direction { case leftToRight, rightToLeft }
    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY

        switch direction {
        case .leftToRight:
            let start = CGPoint(x: rect.minX + 4, y: mid)
            let end = CGPoint(x: rect.maxX - 4, y: mid)
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: rect.midX - 10, y: mid - rect.height * 0.5),
                control2: CGPoint(x: rect.midX + 10, y: mid + rect.height * 0.3)
            )
            // Arrowhead
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - 12, y: end.y - 8))
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - 12, y: end.y + 8))

        case .rightToLeft:
            let start = CGPoint(x: rect.maxX - 4, y: mid)
            let end = CGPoint(x: rect.minX + 4, y: mid)
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: rect.midX + 10, y: mid - rect.height * 0.5),
                control2: CGPoint(x: rect.midX - 10, y: mid + rect.height * 0.3)
            )
            // Arrowhead
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + 12, y: end.y - 8))
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + 12, y: end.y + 8))
        }
        return path
    }
}

// MARK: - Public preview helper

extension HandwrittenSnapResultShareCard {
    public static func preview(archetype: String? = "protein") -> HandwrittenSnapResultShareCard {
        let placeholder = renderPlaceholderPhoto()
        return HandwrittenSnapResultShareCard(
            photo: placeholder,
            mealLabel: "Breakfast",
            dishName: "scrambled eggs + avocado toast",
            itemNames: [
                "scrambled eggs",
                "avocado toast",
                "raspberries",
                "matcha latte",
            ],
            totals: (carbs: 42, protein: 28, fat: 22, kcal: 420),
            archetype: archetype
        )
    }

    /// 1080×1920 placeholder photo. Used only when the founder hasn't
    /// loaded a real food image via the harness PhotosPicker — gives
    /// the layout SOMETHING photo-shaped to scaledToFill against so
    /// the gradients + overlays still read.
    private static func renderPlaceholderPhoto() -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.36, green: 0.28, blue: 0.22, alpha: 1.0).cgColor,
                UIColor(red: 0.62, green: 0.42, blue: 0.30, alpha: 1.0).cgColor,
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }
}

// MARK: - HandwrittenSnapResultShareRenderer

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
