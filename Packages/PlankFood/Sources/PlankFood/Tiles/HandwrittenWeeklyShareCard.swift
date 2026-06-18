#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenWeeklyShareCard
//
// v1.0.10 (2026-06-17) — Pinterest it-girl variant of the weekly
// 9:16 share card. Same typography family as HandwrittenDailyShareCard
// (Snell Roundhand title, Noteworthy subhead, Bradley Hand body
// labels, butter-cream gradient with deterministic paper grain) but
// stretched across a 2×3 photo grid covering the week. Designed to
// feel like a TikTok meals-i-cooked-this-week post — earned, lived-
// in, slightly chaotic. Companion to the editorial WeeklyShareCard
// already shipping in PlankFood.
//
// Layout (1080×1920 top-down):
//   - 0    →  240pt: title block "her week ✨" + date range capsule
//   - 240  → 1600pt: 2×3 photo grid w/ rotated cells + corner labels
//                     connected to cell centers by SquigglyArrows
//   - 1600 → 1920pt: bottom pull-quote + jenifit wordmark
//
// Render is deterministic — same inputs (entries, date) produce
// byte-identical PNGs across runs via the SplitMix64-seeded paper
// grain.

public struct HandwrittenWeeklyShareCard: View {

    let weekStart: Date
    let cells: [WeeklyShareCell]
    let photos: [String: UIImage]
    var archetype: String? = nil

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                titleBlock.padding(.horizontal, 80)
                Spacer().frame(height: 16)
                dateRangeCapsule.padding(.horizontal, 80)
                Spacer().frame(height: 60)
                grid
                Spacer().frame(height: 36)
                pullQuote.padding(.horizontal, 90)
                Spacer()
                wordmark.padding(.bottom, 72)
            }

            decorativeOverlay
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Background (shared with daily card)

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
                var rng = HandwrittenSplitMix64(seed: 11_240_512)
                for _ in 0..<340 {
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
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(titleLine)
                    .font(.custom("SnellRoundhand-Bold", size: 86))
                    .foregroundStyle(Color(red: 0.65, green: 0.30, blue: 0.40))
                Image(systemName: "sparkle")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50))
                    .offset(y: -28)
            }
            Text(subheadLine)
                .font(.custom("Noteworthy-Light", size: 28))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30).opacity(0.88))
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleLine: String {
        let pool = archetype.flatMap { Self.archetypeTitlePool[$0.lowercased()] }
            ?? Self.universalTitlePool
        let week = Calendar.current.component(.weekOfYear, from: weekStart)
        return pool[week % pool.count]
    }

    private var subheadLine: String {
        let week = Calendar.current.component(.weekOfYear, from: weekStart)
        return Self.universalSubheadPool[week % Self.universalSubheadPool.count]
    }

    @ViewBuilder private var dateRangeCapsule: some View {
        HStack(spacing: 14) {
            Text(dateRangeLabel)
                .font(.custom("BradleyHandITCTT-Bold", size: 22))
                .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.30))
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

    private var dateRangeLabel: String {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let fmt = DateFormatter()
        if cal.component(.month, from: weekStart) == cal.component(.month, from: weekEnd) {
            fmt.dateFormat = "MMMM d"
            let start = fmt.string(from: weekStart).lowercased()
            fmt.dateFormat = "d"
            let end = fmt.string(from: weekEnd)
            return "\(start)\u{2013}\(end)"
        } else {
            fmt.dateFormat = "MMM d"
            let start = fmt.string(from: weekStart).lowercased()
            let end = fmt.string(from: weekEnd).lowercased()
            return "\(start) \u{2013} \(end)"
        }
    }

    // MARK: - 2×3 grid w/ labels + arrows

    @ViewBuilder private var grid: some View {
        let rotations: [Double] = [-3, 3, -2, 2, -4, 4]
        let anchors: [HandwrittenDailyShareCard.LabelAnchor] = [
            .topLeft, .topRight, .bottomLeft, .bottomRight, .topLeft, .topRight
        ]
        let padded: [WeeklyShareCell?] = (0..<6).map { i in
            cells.indices.contains(i) ? cells[i] : nil
        }
        VStack(spacing: 30) {
            HStack(spacing: 28) {
                cellView(padded[0], rotation: rotations[0], anchor: anchors[0])
                cellView(padded[1], rotation: rotations[1], anchor: anchors[1])
            }
            HStack(spacing: 28) {
                cellView(padded[2], rotation: rotations[2], anchor: anchors[2])
                cellView(padded[3], rotation: rotations[3], anchor: anchors[3])
            }
            HStack(spacing: 28) {
                cellView(padded[4], rotation: rotations[4], anchor: anchors[4])
                cellView(padded[5], rotation: rotations[5], anchor: anchors[5])
            }
        }
    }

    @ViewBuilder
    private func cellView(
        _ cell: WeeklyShareCell?,
        rotation: Double,
        anchor: HandwrittenDailyShareCard.LabelAnchor
    ) -> some View {
        ZStack {
            if let cell {
                photoCell(cell: cell, rotation: rotation)
                    .overlay(alignment: alignmentFor(anchor)) {
                        labelWithArrow(
                            title: weekdayLabel(for: cell.date),
                            anchor: anchor
                        )
                    }
            } else {
                emptyCell(rotation: rotation)
            }
        }
        .frame(width: 420, height: 410)
    }

    private func alignmentFor(_ anchor: HandwrittenDailyShareCard.LabelAnchor) -> Alignment {
        switch anchor {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    @ViewBuilder
    private func photoCell(
        cell: WeeklyShareCell,
        rotation: Double
    ) -> some View {
        Group {
            if let photo = photos[cell.entryId] {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 380, height: 370)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ZStack {
                    Color(red: 0.96, green: 0.84, blue: 0.85)
                    Text(cell.title.isEmpty ? "kept" : cell.title.lowercased())
                        .font(.custom("BradleyHandITCTT-Bold", size: 26))
                        .foregroundStyle(Color(red: 0.50, green: 0.25, blue: 0.30))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(width: 380, height: 370)
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
                .font(.custom("BradleyHandITCTT-Bold", size: 48))
                .foregroundStyle(Color(red: 0.50, green: 0.30, blue: 0.30).opacity(0.45))
        }
        .frame(width: 380, height: 370)
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

    @ViewBuilder
    private func labelWithArrow(
        title: String,
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
            case .topLeft:     return CGSize(width: -22, height: -16)
            case .topRight:    return CGSize(width: 22,  height: -16)
            case .bottomLeft:  return CGSize(width: -22, height: 16)
            case .bottomRight: return CGSize(width: 22,  height: 16)
            }
        }()

        ZStack(alignment: alignmentFor(anchor)) {
            SquigglyArrow(anchor: anchor)
                .stroke(
                    Color(red: 0.92, green: 0.52, blue: 0.62).opacity(0.88),
                    style: StrokeStyle(
                        lineWidth: 2.4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 380, height: 370)

            Text(title)
                .font(.custom("BradleyHandITCTT-Bold", size: 26))
                .foregroundStyle(Color(red: 0.50, green: 0.22, blue: 0.32))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.78)))
                .rotationEffect(.degrees(labelRotation))
                .offset(labelOffset)
        }
    }

    private func weekdayLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).lowercased()
    }

    // MARK: - Pull quote

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
        let week = Calendar.current.component(.weekOfYear, from: weekStart)
        return Self.quotePool[week % Self.quotePool.count]
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

    @ViewBuilder private var decorativeOverlay: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.50).opacity(0.78))
                .rotationEffect(.degrees(-14))
                .position(x: 96, y: 246)

            Image(systemName: "cloud.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.78))
                .position(x: 988, y: 314)

            Image(systemName: "heart.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70).opacity(0.78))
                .rotationEffect(.degrees(16))
                .position(x: 116, y: 1746)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Pools

private extension HandwrittenWeeklyShareCard {

    static let universalTitlePool: [String] = [
        "her week",
        "kept plates",
        "this week",
        "the week, kept",
    ]

    static let archetypeTitlePool: [String: [String]] = [
        "protein": [
            "anchored week",
            "protein-led week",
            "muscle kept",
        ],
        "balanced": [
            "a balanced week",
            "varied + whole",
            "the middle path",
        ],
        "movement": [
            "moved this week",
            "lift week",
            "fueled the work",
        ],
        "rest": [
            "softer week",
            "permission week",
            "quiet plates",
        ],
    ]

    static let universalSubheadPool: [String] = [
        "kept the table set ♡",
        "one plate at a time",
        "soft + steady",
        "becoming, quietly",
    ]

    static let quotePool: [String] = [
        "another good one ♡",
        "kept it ♡",
        "she ate well",
        "becoming, quietly",
        "soft + steady ♡",
        "the work, kept",
        "no skipping, just being",
        "every plate counted",
    ]
}

// MARK: - Public preview helper

extension HandwrittenWeeklyShareCard {
    /// Mock cell IDs the preview() helper assigns — exposed so the
    /// main-app harness can build a positional photos dict against the
    /// same keys.
    public static let previewCellIds: [String] = [
        "preview-0", "preview-1", "preview-2",
        "preview-3", "preview-4", "preview-5",
    ]

    public static func preview(
        archetype: String? = "protein",
        photos: [UIImage] = []
    ) -> HandwrittenWeeklyShareCard {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let titles = [
            "yogurt + berries",
            "matcha latte",
            "chipotle bowl",
            "salmon rice bowl",
            "avocado toast",
            "chicken caesar",
        ]
        let mockCells = (0..<6).map { i -> WeeklyShareCell in
            let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
            return WeeklyShareCell(
                entryId: previewCellIds[i],
                date: day,
                title: titles[i]
            )
        }
        // Map up to 6 supplied images into the photos dict keyed by the
        // mock cell IDs. Cells without a supplied photo render the soft
        // pink text-fallback panel as before.
        var photosDict: [String: UIImage] = [:]
        for (i, photo) in photos.prefix(6).enumerated() {
            photosDict[previewCellIds[i]] = photo
        }
        return HandwrittenWeeklyShareCard(
            weekStart: weekStart,
            cells: mockCells,
            photos: photosDict,
            archetype: archetype
        )
    }
}

// MARK: - HandwrittenWeeklyShareRenderer

@MainActor
public enum HandwrittenWeeklyShareRenderer {

    public static func render(
        for referenceDate: Date = Date(),
        userId: String,
        archetype: String? = nil
    ) -> UIImage? {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? cal.startOfDay(for: referenceDate)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? referenceDate

        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= weekStart && $0.loggedAt < weekEnd }

        var perDay: [Date: FoodLogPersister.FoodLogEntry] = [:]
        for entry in entries {
            guard FoodPhotoStore.hasPhoto(entryId: entry.id) else { continue }
            let day = cal.startOfDay(for: entry.loggedAt)
            if let prior = perDay[day], prior.loggedAt >= entry.loggedAt { continue }
            perDay[day] = entry
        }

        guard !perDay.isEmpty else { return nil }

        let chronological = perDay
            .sorted { $0.key < $1.key }
            .prefix(6)
            .map { (day, entry) in
                WeeklyShareCell(entryId: entry.id, date: day, title: entry.title)
            }

        var photos: [String: UIImage] = [:]
        for cell in chronological {
            if let img = FoodPhotoStore.photo(entryId: cell.entryId) {
                photos[cell.entryId] = img
            }
        }

        let card = HandwrittenWeeklyShareCard(
            weekStart: weekStart,
            cells: Array(chronological),
            photos: photos,
            archetype: archetype
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

// MARK: - SplitMix64 (renamed to avoid clashing with daily card's copy)

private struct HandwrittenSplitMix64 {
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
