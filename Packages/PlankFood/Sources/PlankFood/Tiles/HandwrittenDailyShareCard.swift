#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenDailyShareCard
//
// v1.0.10 (2026-06-17) — Pinterest it-girl handwritten share card,
// the second daily-share template ("Mode B" per founder's reference
// reel). Lives alongside DailyShareCard (the editorial typography
// register from earlier in this session); the two share the same
// 1080×1920 canvas + ImageRenderer pipeline so the share button can
// switch between them with no other code changes.
//
// Founder direction: "handwritten style labeling with arrows ... is
// this something achievable without any extra cost." Answer encoded
// here: yes — every glyph below is one of:
//
//   - iOS-bundled handwritten font (Bradley Hand / Noteworthy /
//     Snell Roundhand — shipped with iOS, OFL-equivalent license,
//     zero asset cost).
//   - SF Symbols (sparkle / heart / cloud) — system-tinted via
//     `.foregroundStyle`, no extra image asset weight.
//   - SwiftUI Path bezier curves for the squiggly arrows (drawn at
//     render time, no SVG / PNG dependency).
//
// Visual register (per founder's reference images 7-9):
//
//   - Cream/butter background w/ subtle paper grain
//   - Handwritten title at top in cursive script ("good morning ♡")
//   - 2×2 photo grid w/ per-cell labels positioned at the cell's
//     outer edge; squiggly Path arrows curve in toward the food
//   - Doodle scatter: hearts, sparkles, stars in soft rose + cream
//   - Bottom: italic pull-quote + jenifit wordmark + date stamp
//
// Designed for ImageRenderer offscreen rendering. Never mounted in
// the user's live view hierarchy — only by HandwrittenDailyShareRenderer.

public struct HandwrittenDailyShareCard: View {

    let date: Date
    let entries: [FoodLogPersister.FoodLogEntry]
    /// entryId → stored food photo. Entries without a photo (quick-add,
    /// im-out) render as a tinted text panel with the title in
    /// handwriting in the same cell slot.
    let photos: [String: UIImage]
    /// Optional archetype string ("protein" / "balanced" / "movement"
    /// / "rest"). Drives the title-line variant pool when present;
    /// nil falls back to a universal greeting set.
    var archetype: String? = nil

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 96)
                titleBlock
                    .padding(.horizontal, 80)
                Spacer().frame(height: 28)
                dateLine
                    .padding(.horizontal, 80)
                Spacer().frame(height: 56)
                photoGrid
                Spacer().frame(height: 56)
                pullQuote
                    .padding(.horizontal, 90)
                Spacer()
                wordmark
                    .padding(.bottom, 72)
            }

            // Decorative scatter — placed in a separate layer so the
            // doodles can drift outside the title/grid columns.
            decorativeOverlay
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Background

    @ViewBuilder private var background: some View {
        ZStack {
            // Soft butter → cream linear sweep — warmer than the
            // editorial card's flat #F7F1E8 cream, matches the
            // photographed-at-golden-hour mood of the reference reel.
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.945, blue: 0.880),
                    Color(red: 0.972, green: 0.917, blue: 0.864),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Paper grain — a very light noise overlay via repeated
            // tiny dots gives the "printed photo" feel of the
            // reference images without requiring an asset.
            Canvas { ctx, size in
                let seed: UInt64 = 19_780_417  // deterministic — same
                                                // dots every render
                var rng = SplitMix64(seed: seed)
                for _ in 0..<320 {
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

    // MARK: - Title block

    @ViewBuilder private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Big cursive script — Snell Roundhand-Bold is the iOS-
            // bundled "cursive script" register. ~92pt sets it
            // comfortably as the masthead.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(titleLine)
                    .font(.custom("SnellRoundhand-Bold", size: 92))
                    .foregroundStyle(Color(red: 0.65, green: 0.30, blue: 0.40))
                Image(systemName: "sparkle")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50))
                    .offset(y: -32)
            }
            // Subhead in Noteworthy — looser print handwriting, picks
            // up the casual diary tone of the reference reel.
            Text(subheadLine)
                .font(.custom("Noteworthy-Light", size: 30))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30).opacity(0.88))
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Archetype-aware title rotation. Day-of-year mod variant-count
    /// picks the line so a returning sharer doesn't see the same
    /// greeting two days in a row.
    private var titleLine: String {
        let pool = archetype.flatMap { Self.archetypeTitlePool[$0.lowercased()] }
            ?? Self.universalTitlePool
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[day % pool.count]
    }

    private var subheadLine: String {
        let pool = archetype.flatMap { Self.archetypeSubheadPool[$0.lowercased()] }
            ?? Self.universalSubheadPool
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[day % pool.count]
    }

    @ViewBuilder private var dateLine: some View {
        HStack(spacing: 14) {
            // Pill stamp w/ date — italic Bradley Hand inside a
            // cream cloud-shape capsule, matches the reference
            // "Day 4" / "Day 6" stamps.
            HStack(spacing: 4) {
                Text(weekdayPart)
                    .font(.custom("BradleyHandITCTT-Bold", size: 22))
                    .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30))
                Text(", " + monthDayPart)
                    .font(.custom("BradleyHandITCTT-Bold", size: 22))
                    .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.72))
                    .overlay(
                        Capsule().stroke(
                            Color(red: 0.85, green: 0.55, blue: 0.62).opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                        )
                    )
            )

            Image(systemName: "heart.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70))
            Spacer()
        }
    }

    private var weekdayPart: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date).lowercased()
    }

    private var monthDayPart: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: date).lowercased()
    }

    // MARK: - Photo grid + handwritten labels with arrows
    //
    // 2×2 photo grid. Each cell has a handwritten label positioned
    // at the cell's OUTER edge (away from the centerline), with a
    // squiggly arrow curving from the label toward the cell center.
    // For cells without an entry, a soft rose panel fills the slot
    // with a centered handwritten "—" so the grid stays geometrically
    // stable even on partial days.

    @ViewBuilder private var photoGrid: some View {
        let cells = Array(entries.prefix(4))
        let rotations: [Double] = [-2.5, 2.0, -1.5, 3.0]
        let labelAnchors: [LabelAnchor] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

        VStack(spacing: 36) {
            HStack(spacing: 32) {
                photoCellWithArrow(entryAt: 0, in: cells, rotation: rotations[0], labelAnchor: labelAnchors[0])
                photoCellWithArrow(entryAt: 1, in: cells, rotation: rotations[1], labelAnchor: labelAnchors[1])
            }
            HStack(spacing: 32) {
                photoCellWithArrow(entryAt: 2, in: cells, rotation: rotations[2], labelAnchor: labelAnchors[2])
                photoCellWithArrow(entryAt: 3, in: cells, rotation: rotations[3], labelAnchor: labelAnchors[3])
            }
        }
    }

    enum LabelAnchor { case topLeft, topRight, bottomLeft, bottomRight }

    @ViewBuilder
    private func photoCellWithArrow(
        entryAt index: Int,
        in cells: [FoodLogPersister.FoodLogEntry],
        rotation: Double,
        labelAnchor: LabelAnchor
    ) -> some View {
        ZStack {
            if cells.indices.contains(index) {
                let entry = cells[index]
                photoCell(entry: entry, rotation: rotation)
                    .overlay(alignment: alignment(for: labelAnchor)) {
                        handwrittenLabel(
                            title: entry.title.isEmpty ? "kept plate" : entry.title.lowercased(),
                            anchor: labelAnchor
                        )
                    }
            } else {
                emptyCell(rotation: rotation)
            }
        }
        .frame(width: 420, height: 480)
    }

    private func alignment(for anchor: LabelAnchor) -> Alignment {
        switch anchor {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    @ViewBuilder
    private func photoCell(
        entry: FoodLogPersister.FoodLogEntry,
        rotation: Double
    ) -> some View {
        Group {
            if let photo = photos[entry.id] {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 380, height: 440)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ZStack {
                    Color(red: 0.96, green: 0.84, blue: 0.85)
                    Text(entry.title.isEmpty ? "kept" : entry.title.lowercased())
                        .font(.custom("BradleyHandITCTT-Bold", size: 30))
                        .foregroundStyle(Color(red: 0.50, green: 0.25, blue: 0.30))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .frame(width: 380, height: 440)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 6)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 2, y: 8)
        .rotationEffect(.degrees(rotation))
    }

    @ViewBuilder
    private func emptyCell(rotation: Double) -> some View {
        ZStack {
            Color(red: 0.98, green: 0.93, blue: 0.88)
            Text("\u{2014}")
                .font(.custom("BradleyHandITCTT-Bold", size: 56))
                .foregroundStyle(Color(red: 0.50, green: 0.30, blue: 0.30).opacity(0.45))
        }
        .frame(width: 380, height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color(red: 0.65, green: 0.45, blue: 0.45).opacity(0.30),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
        )
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Handwritten label + arrow

    @ViewBuilder
    private func handwrittenLabel(title: String, anchor: LabelAnchor) -> some View {
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
            case .topLeft:     return CGSize(width: -26, height: -18)
            case .topRight:    return CGSize(width: 26,  height: -18)
            case .bottomLeft:  return CGSize(width: -26, height: 18)
            case .bottomRight: return CGSize(width: 26,  height: 18)
            }
        }()

        ZStack(alignment: alignment(for: anchor)) {
            SquigglyArrow(anchor: anchor)
                .stroke(
                    Color(red: 0.92, green: 0.52, blue: 0.62).opacity(0.88),
                    style: StrokeStyle(
                        lineWidth: 2.4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 380, height: 440)

            Text(title)
                .font(.custom("BradleyHandITCTT-Bold", size: 26))
                .foregroundStyle(Color(red: 0.50, green: 0.22, blue: 0.32))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.78))
                )
                .rotationEffect(.degrees(labelRotation))
                .offset(labelOffset)
        }
    }

    // MARK: - Pull quote

    @ViewBuilder private var pullQuote: some View {
        HStack {
            Spacer(minLength: 0)
            Text(quoteLine)
                .font(.custom("Noteworthy-Bold", size: 44))
                .foregroundStyle(Color(red: 0.40, green: 0.22, blue: 0.30))
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    private var quoteLine: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return Self.handwrittenQuotePool[day % Self.handwrittenQuotePool.count]
    }

    // MARK: - Wordmark

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

    // MARK: - Decorative overlay
    //
    // Three SF Symbol doodles scattered at the edges of the canvas
    // outside the photo grid. Same scatter-3-only rule as the
    // typography card per [[feedback-scatter-milestone-rule]]: this
    // is the daily share, an earned moment.

    @ViewBuilder private var decorativeOverlay: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50).opacity(0.78))
                .rotationEffect(.degrees(-14))
                .position(x: 110, y: 230)

            Image(systemName: "cloud.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.white.opacity(0.78))
                .position(x: 980, y: 320)

            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70).opacity(0.78))
                .rotationEffect(.degrees(16))
                .position(x: 130, y: 1740)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Title / subhead / quote pools

private extension HandwrittenDailyShareCard {

    static let universalTitlePool: [String] = [
        "good morning",
        "soft day",
        "kept plates",
        "today fits",
        "she ate well",
        "another good one",
    ]

    static let archetypeTitlePool: [String: [String]] = [
        "protein": [
            "anchored",
            "kept the work",
            "protein led",
            "muscle kept",
        ],
        "balanced": [
            "a little of everything",
            "the middle path",
            "varied and whole",
            "balanced enough",
        ],
        "movement": [
            "fueled the lift",
            "strength day",
            "earned every bite",
            "powered through",
        ],
        "rest": [
            "softer today",
            "permission day",
            "quiet plates",
            "rest as recovery",
        ],
    ]

    static let universalSubheadPool: [String] = [
        "kept the table set ♡",
        "a little of everything",
        "soft + steady",
        "one plate at a time",
    ]

    static let archetypeSubheadPool: [String: [String]] = [
        "protein": [
            "1g per pound, gently ♡",
            "muscle stays",
            "anchored, on purpose",
        ],
        "balanced": [
            "no macro running the show",
            "variety is the brief ♡",
            "eat what feels right",
        ],
        "movement": [
            "carbs around the work",
            "lift, don't just sweat ♡",
            "fuel + strength",
        ],
        "rest": [
            "listen, don't earn ♡",
            "soup + slower days",
            "rest is recovery",
        ],
    ]

    /// Bottom pull-quote pool — bigger emotional moment, italic
    /// Noteworthy. Day-of-year mod 8 to rotate.
    static let handwrittenQuotePool: [String] = [
        "today fits ♡",
        "soft + steady",
        "she ate well",
        "kept the table set",
        "another good one",
        "one plate at a time ♡",
        "permission ♡",
        "becoming, quietly",
    ]
}

// MARK: - Preview helper
//
// Public so the main app can mount the card with deterministic mock
// data via a debug launch flag without round-tripping through
// FoodLogPersister. The handwritten card's only state-bearing input
// is the entries array — everything else is computed from `date` and
// the archetype string — so a mock entries array is enough to render
// a realistic IG-Story preview.

extension HandwrittenDailyShareCard {
    public static func preview(
        archetype: String? = "protein",
        date: Date = Date()
    ) -> HandwrittenDailyShareCard {
        let mock: [FoodLogPersister.FoodLogEntry] = [
            FoodLogPersister.FoodLogEntry(
                id: "preview-1",
                loggedAt: date,
                title: "avocado toast",
                kcal: 380, protein: 18, carbs: 28, fat: 22,
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-2",
                loggedAt: date,
                title: "matcha latte",
                kcal: 180, protein: 6, carbs: 22, fat: 7,
                source: "quickAdd"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-3",
                loggedAt: date,
                title: "chipotle bowl",
                kcal: 720, protein: 52, carbs: 64, fat: 28,
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-4",
                loggedAt: date,
                title: "berry bowl",
                kcal: 240, protein: 14, carbs: 32, fat: 5,
                source: "photo"
            ),
        ]
        return HandwrittenDailyShareCard(
            date: date,
            entries: mock,
            photos: [:],
            archetype: archetype
        )
    }
}

// MARK: - SquigglyArrow

/// Hand-drawn arrow shape. Path runs from the label's anchor corner
/// inward toward the cell center, with two cubic bezier humps to
/// give the squiggle a real-marker feel. Arrowhead is a simple
/// chevron drawn into the same Path so a single stroke style covers
/// the whole shape.
struct SquigglyArrow: Shape {
    let anchor: HandwrittenDailyShareCard.LabelAnchor

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let (start, control1, control2, end, head) = endpoints(in: rect)

        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)

        // Arrowhead — two short lines meeting at the end point.
        for offset in head {
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + offset.x, y: end.y + offset.y))
        }
        return path
    }

    /// Per-anchor geometry: start near the label corner, end at the
    /// center-ish of the cell, with control points that pull the
    /// curve into a soft S-shape.
    private func endpoints(
        in rect: CGRect
    ) -> (CGPoint, CGPoint, CGPoint, CGPoint, [CGPoint]) {
        let w = rect.width
        let h = rect.height
        let mid = CGPoint(x: w * 0.5, y: h * 0.5)
        switch anchor {
        case .topLeft:
            let start = CGPoint(x: w * 0.12, y: h * 0.12)
            return (
                start,
                CGPoint(x: w * 0.30, y: h * 0.05),
                CGPoint(x: w * 0.20, y: h * 0.42),
                mid,
                [CGPoint(x: -12, y: -8), CGPoint(x: 4, y: -12)]
            )
        case .topRight:
            let start = CGPoint(x: w * 0.88, y: h * 0.12)
            return (
                start,
                CGPoint(x: w * 0.70, y: h * 0.05),
                CGPoint(x: w * 0.80, y: h * 0.42),
                mid,
                [CGPoint(x: 12, y: -8), CGPoint(x: -4, y: -12)]
            )
        case .bottomLeft:
            let start = CGPoint(x: w * 0.12, y: h * 0.88)
            return (
                start,
                CGPoint(x: w * 0.30, y: h * 0.95),
                CGPoint(x: w * 0.20, y: h * 0.58),
                mid,
                [CGPoint(x: -12, y: 8), CGPoint(x: 4, y: 12)]
            )
        case .bottomRight:
            let start = CGPoint(x: w * 0.88, y: h * 0.88)
            return (
                start,
                CGPoint(x: w * 0.70, y: h * 0.95),
                CGPoint(x: w * 0.80, y: h * 0.58),
                mid,
                [CGPoint(x: 12, y: 8), CGPoint(x: -4, y: 12)]
            )
        }
    }
}

// MARK: - SplitMix64 (deterministic RNG for paper-grain dots)

private struct SplitMix64 {
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
