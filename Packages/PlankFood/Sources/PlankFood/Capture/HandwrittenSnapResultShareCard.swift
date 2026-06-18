#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenSnapResultShareCard
//
// v1.0.10 (2026-06-17) — Pinterest it-girl variant of the snap-food
// share carousel. Replaces the 3-slide editorial sequence (meal /
// packed-daily / jeni-evaluation) with a single 1080×1920 handwritten
// card built on the same typography family as the daily / weekly /
// lesson handwritten share cards.
//
// Layout (1080×1920 top-down):
//   - 0    →  240pt: "she ate well ✨" Snell Roundhand title + subhead
//   - 240  →  300pt: hand-drawn hairline divider
//   - 300  → 1240pt: photo polaroid hero (760×760 frame, slight tilt)
//                     with per-corner labels for the top food items,
//                     each connected to the polaroid center by a
//                     SquigglyArrow Path
//   - 1240 → 1500pt: 4-column macro row (carbs / protein / fat / kcal)
//                     in Bradley Hand-Bold
//   - 1500 → 1920pt: pull-quote (Noteworthy 44pt) + jenifit wordmark
//                     + 3-symbol decorative scatter
//
// Designed for ImageRenderer offscreen rendering. Never mounted in
// the user's live view hierarchy — invoked from PhotoCaptureView's
// renderAllShareableSlides path when `--handwritten-share` flag is on.

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
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                titleBlock.padding(.horizontal, 80)
                Spacer().frame(height: 14)
                hairlineDivider.padding(.horizontal, 80)
                Spacer().frame(height: 60)
                photoBlock
                Spacer().frame(height: 50)
                macroRow.padding(.horizontal, 80)
                Spacer()
                pullQuote.padding(.horizontal, 90)
                Spacer().frame(height: 24)
                wordmark
                Spacer().frame(height: 76)
            }

            decorativeOverlay
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Background (shared register w/ other handwritten cards)

    @ViewBuilder private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.945, blue: 0.880),
                    Color(red: 0.972, green: 0.917, blue: 0.864),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { ctx, size in
                var rng = HandwrittenSnapSplitMix64(seed: 4_217_900)
                for _ in 0..<300 {
                    let x = CGFloat(rng.nextDouble()) * size.width
                    let y = CGFloat(rng.nextDouble()) * size.height
                    let r = 0.6 + CGFloat(rng.nextDouble()) * 1.2
                    let opacity = 0.04 + CGFloat(rng.nextDouble()) * 0.06
                    var path = Path()
                    path.addEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                    ctx.fill(path, with: .color(.black.opacity(opacity)))
                }
            }
            .blendMode(.multiply)
        }
    }

    // MARK: - Title

    @ViewBuilder private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(titleLine)
                    .font(.custom("SnellRoundhand-Bold", size: 86))
                    .foregroundStyle(Color(red: 0.65, green: 0.30, blue: 0.40))
                Image(systemName: "sparkle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50))
                    .offset(y: -26)
            }
            Text(mealLabel.lowercased() + " · " + nowLabel)
                .font(.custom("BradleyHandITCTT-Bold", size: 22))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30).opacity(0.85))
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleLine: String {
        let pool = archetype.flatMap { Self.archetypeTitlePool[$0.lowercased()] }
            ?? Self.universalTitlePool
        let hash = abs(dishName.hashValue) % pool.count
        return pool[hash]
    }

    private var nowLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: Date())
    }

    @ViewBuilder private var hairlineDivider: some View {
        HandwrittenSnapWavyLine()
            .stroke(
                Color(red: 0.50, green: 0.30, blue: 0.30).opacity(0.30),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(height: 14)
    }

    // MARK: - Photo polaroid + handwritten labels w/ arrows

    @ViewBuilder private var photoBlock: some View {
        ZStack {
            // Polaroid frame containing the food photo. White matte +
            // cocoa stroke + offset shadow mirrors the in-app polaroid
            // chrome so the share card and the result hero feel like
            // the same surface.
            VStack(spacing: 8) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 760, height: 760)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack {
                    Text(dishName.lowercased())
                        .font(.custom("BradleyHandITCTT-Bold", size: 32))
                        .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.30))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
            }
            .padding(20)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(red: 0.40, green: 0.22, blue: 0.30), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 0, x: 8, y: 8)
            .rotationEffect(.degrees(-1.5))

            // Per-corner food labels with squiggly arrows pointing to
            // the polaroid center. Up to 4 items rendered; positions
            // chosen so labels don't crowd each other.
            labelOverlay
        }
        .frame(width: 940, height: 920)
    }

    /// Place up to 4 item-name labels around the polaroid edge, each
    /// connected to the photo center by a SquigglyArrow. Uses anchor-
    /// based offsets and the same per-anchor curve geometry as the
    /// daily-share-card label system.
    @ViewBuilder private var labelOverlay: some View {
        let anchors: [HandwrittenDailyShareCard.LabelAnchor] = [
            .topLeft, .topRight, .bottomLeft, .bottomRight
        ]
        let trimmed = Array(itemNames.prefix(4))

        ForEach(Array(trimmed.enumerated()), id: \.offset) { i, name in
            handwrittenLabel(text: name.lowercased(), anchor: anchors[i])
        }
    }

    @ViewBuilder
    private func handwrittenLabel(
        text: String,
        anchor: HandwrittenDailyShareCard.LabelAnchor
    ) -> some View {
        let labelRotation: Double = {
            switch anchor {
            case .topLeft:     return -6
            case .topRight:    return 5
            case .bottomLeft:  return 4
            case .bottomRight: return -5
            }
        }()
        let labelOffset: CGSize = {
            switch anchor {
            case .topLeft:     return CGSize(width: -30, height: -22)
            case .topRight:    return CGSize(width: 30,  height: -22)
            case .bottomLeft:  return CGSize(width: -30, height: 22)
            case .bottomRight: return CGSize(width: 30,  height: 22)
            }
        }()

        ZStack(alignment: alignmentFor(anchor)) {
            SquigglyArrow(anchor: anchor)
                .stroke(
                    Color(red: 0.92, green: 0.52, blue: 0.62).opacity(0.85),
                    style: StrokeStyle(
                        lineWidth: 2.6,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 940, height: 920)

            Text(text)
                .font(.custom("BradleyHandITCTT-Bold", size: 30))
                .foregroundStyle(Color(red: 0.50, green: 0.22, blue: 0.32))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.82))
                )
                .rotationEffect(.degrees(labelRotation))
                .offset(labelOffset)
        }
    }

    private func alignmentFor(_ anchor: HandwrittenDailyShareCard.LabelAnchor) -> Alignment {
        switch anchor {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    // MARK: - Macro row

    @ViewBuilder private var macroRow: some View {
        HStack(spacing: 0) {
            macroColumn(value: "\(totals.carbs)g", label: "carbs")
            macroDivider
            macroColumn(value: "\(totals.protein)g", label: "protein")
            macroDivider
            macroColumn(value: "\(totals.fat)g", label: "fat")
            macroDivider
            kcalColumn(value: "\(totals.kcal)")
        }
    }

    @ViewBuilder
    private func macroColumn(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("BradleyHandITCTT-Bold", size: 40))
                .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.30))
            Text(label)
                .font(.custom("BradleyHandITCTT-Bold", size: 22))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30).opacity(0.80))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func kcalColumn(value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("BradleyHandITCTT-Bold", size: 40))
                .foregroundStyle(Color(red: 0.55, green: 0.32, blue: 0.20))
            Text("kcal")
                .font(.custom("BradleyHandITCTT-Bold", size: 22))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30).opacity(0.80))
        }
        .frame(maxWidth: .infinity)
    }

    private var macroDivider: some View {
        Rectangle()
            .fill(Color(red: 0.50, green: 0.30, blue: 0.30).opacity(0.18))
            .frame(width: 1, height: 44)
    }

    // MARK: - Pull quote + wordmark

    @ViewBuilder private var pullQuote: some View {
        HStack {
            Spacer(minLength: 0)
            Text(quoteLine)
                .font(.custom("Noteworthy-Bold", size: 42))
                .foregroundStyle(Color(red: 0.40, green: 0.22, blue: 0.30))
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    private var quoteLine: String {
        let pool = archetype.flatMap { Self.archetypeQuotePool[$0.lowercased()] }
            ?? Self.universalQuotePool
        let hash = abs(dishName.hashValue) % pool.count
        return pool[hash]
    }

    @ViewBuilder private var wordmark: some View {
        HStack(spacing: 8) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.65).opacity(0.55))
            Text("jenifit")
                .font(.custom("SnellRoundhand-Bold", size: 38))
                .foregroundStyle(Color(red: 0.70, green: 0.30, blue: 0.42).opacity(0.62))
            Spacer()
        }
    }

    // MARK: - Decorative scatter

    @ViewBuilder private var decorativeOverlay: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50).opacity(0.78))
                .rotationEffect(.degrees(-14))
                .position(x: 100, y: 240)

            Image(systemName: "cloud.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.78))
                .position(x: 980, y: 310)

            Image(systemName: "heart.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70).opacity(0.78))
                .rotationEffect(.degrees(16))
                .position(x: 120, y: 1750)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Title / quote pools

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
            "balanced + whole",
            "a little of everything",
            "the middle path",
        ],
        "movement": [
            "fueled the lift",
            "strength on the plate",
            "earned every bite",
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

    /// Generates a single 760×760 cream + rose gradient placeholder so
    /// the preview harness has a "plate" to render. Real shares ship
    /// with the camera-captured UIImage; this is debug-only.
    private static func renderPlaceholderPhoto() -> UIImage {
        let size = CGSize(width: 760, height: 760)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.97, green: 0.88, blue: 0.89, alpha: 1.0).cgColor,
                UIColor(red: 0.99, green: 0.94, blue: 0.78, alpha: 1.0).cgColor,
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            // A soft circular plate hint in the center.
            cg.setFillColor(UIColor(red: 0.92, green: 0.78, blue: 0.78, alpha: 0.6).cgColor)
            cg.fillEllipse(in: CGRect(x: 130, y: 130, width: 500, height: 500))
        }
    }
}

// MARK: - HandwrittenSnapResultShareRenderer

@MainActor
public enum HandwrittenSnapResultShareRenderer {

    /// Synchronous ImageRenderer pass. Returns nil on memory pressure
    /// (rare). Mirrors the existing renderAllShareableSlides return
    /// shape — a single 1080×1920 UIImage instead of three.
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

// MARK: - HandwrittenSnapWavyLine (private — same shape as the
//        WavyLine used by the lesson card, kept package-local).

private struct HandwrittenSnapWavyLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: mid))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: mid),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: mid - 6),
            control2: CGPoint(x: rect.minX + rect.width * 0.25, y: mid + 6)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: mid),
            control1: CGPoint(x: rect.midX + rect.width * 0.25, y: mid - 6),
            control2: CGPoint(x: rect.midX + rect.width * 0.25, y: mid + 6)
        )
        return path
    }
}

// MARK: - HandwrittenSnapSplitMix64

private struct HandwrittenSnapSplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / Double(1 << 53))
    }
}

#endif  // canImport(UIKit)
