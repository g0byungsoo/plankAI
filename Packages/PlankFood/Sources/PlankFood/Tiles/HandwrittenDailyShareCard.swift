#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenDailyShareCard
//
// v1.0.12 (2026-06-17) — REBUILT after founder feedback on v1.0.10's
// cream-card-with-pink-panels design ("all shared cards look like
// some cute elementary school design"). Following the same direction
// as the snap card v2 rebuild: PHOTO IS THE SHARE. No polaroid frame,
// no white matte, no pink fallback panels. Photos go full-bleed in
// the cells; handwritten Bradley Hand labels lay directly on the
// photos with curved arrows pointing to specific meals.
//
// Layout (1080×1920, top-down):
//
//   - 0    →  240pt: title strip on warm off-white — Marker Felt-Wide
//                    title + date-mark below
//   - 240  → 1620pt: 2×2 photo grid, ZERO gap between cells, each
//                    cell full-bleed (no white matte). Bottom-gradient
//                    overlay per cell for label legibility.
//   - 1620 → 1920pt: wordmark strip on warm off-white — "♥ jenifit"
//                    + macro summary
//
// Cells without an entry render a warm cream block w/ "—" centered,
// keeping the 2×2 geometry stable. Cells without a photo (quickAdd /
// im-out entries) render a soft rose color block with the meal title
// overlaid in handwriting — better than a flat pink panel.

public struct HandwrittenDailyShareCard: View {

    let date: Date
    let entries: [FoodLogPersister.FoodLogEntry]
    let photos: [String: UIImage]
    var archetype: String? = nil

    private static let titleStripHeight: CGFloat = 240
    private static let bottomStripHeight: CGFloat = 300

    public var body: some View {
        VStack(spacing: 0) {
            titleStrip
                .frame(width: 1080, height: Self.titleStripHeight)
            photoGrid
                .frame(width: 1080, height: 1080)
            bottomStrip
                .frame(width: 1080, height: Self.bottomStripHeight)
        }
        .frame(width: 1080, height: 1920)
        .background(Color(red: 0.97, green: 0.94, blue: 0.88))
    }

    // MARK: - Title strip (top — warm off-white background)

    @ViewBuilder private var titleStrip: some View {
        ZStack {
            Color(red: 0.97, green: 0.94, blue: 0.88)
            VStack(alignment: .leading, spacing: 6) {
                Spacer().frame(height: 60)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(titleLine)
                        .font(.custom("MarkerFelt-Wide", size: 90))
                        .foregroundStyle(Color(red: 0.20, green: 0.10, blue: 0.12))
                    Image(systemName: "sparkle")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color(red: 0.78, green: 0.32, blue: 0.40))
                        .offset(y: -22)
                }
                Text(dateMark)
                    .font(.custom("BradleyHandITCTT-Bold", size: 26))
                    .foregroundStyle(Color(red: 0.42, green: 0.22, blue: 0.26).opacity(0.85))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 80)
        }
    }

    private var titleLine: String {
        let pool = archetype.flatMap { Self.archetypeTitlePool[$0.lowercased()] }
            ?? Self.universalTitlePool
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[day % pool.count]
    }

    private var dateMark: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date).lowercased() + " · " + entryCountWord
    }

    private var entryCountWord: String {
        switch entries.count {
        case 0:  return "a quieter day"
        case 1:  return "1 plate kept"
        default: return "\(entries.count) plates kept"
        }
    }

    // MARK: - Photo grid (2×2, zero-gap, full-bleed cells)

    @ViewBuilder private var photoGrid: some View {
        let top = Array(entries.prefix(4))
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(at: 0, in: top)
                cell(at: 1, in: top)
            }
            HStack(spacing: 0) {
                cell(at: 2, in: top)
                cell(at: 3, in: top)
            }
        }
        .frame(width: 1080, height: 1080)
    }

    @ViewBuilder
    private func cell(
        at index: Int,
        in entries: [FoodLogPersister.FoodLogEntry]
    ) -> some View {
        if entries.indices.contains(index) {
            let entry = entries[index]
            ZStack(alignment: .bottomLeading) {
                photoBackground(for: entry)
                bottomGradient
                cellLabel(for: entry, position: position(for: index))
            }
            .frame(width: 540, height: 540)
            .clipped()
        } else {
            emptyCellPlaceholder
                .frame(width: 540, height: 540)
        }
    }

    @ViewBuilder
    private func photoBackground(for entry: FoodLogPersister.FoodLogEntry) -> some View {
        if let photo = photos[entry.id] {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 540, height: 540)
                .clipped()
        } else {
            // No-photo cell (quickAdd / im-out entry): warm rose gradient
            // so it still feels like a photo cell, not a flat panel.
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.78, blue: 0.79),
                    Color(red: 0.85, green: 0.55, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 540, height: 540)
        }
    }

    @ViewBuilder private var bottomGradient: some View {
        LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 260)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    /// Per-cell label position so they don't all crowd the same
    /// corner. Top-left / top-right / bottom-left / bottom-right.
    private func position(for index: Int) -> LabelPosition {
        switch index {
        case 0: return .bottomLeft
        case 1: return .bottomRight
        case 2: return .bottomLeft
        case 3: return .bottomRight
        default: return .bottomLeft
        }
    }

    enum LabelPosition { case bottomLeft, bottomRight }

    /// v1.0.10 compat type — kept public for now because the legacy
    /// HandwrittenWeeklyShareCard still references it. Weekly is
    /// queued for the same photo-bleed rebuild; once that lands this
    /// enum can be deleted.
    public enum LabelAnchor: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    @ViewBuilder
    private func cellLabel(
        for entry: FoodLogPersister.FoodLogEntry,
        position: LabelPosition
    ) -> some View {
        let title = entry.title.isEmpty ? "kept plate" : entry.title.lowercased()
        let alignment: Alignment = position == .bottomLeft ? .bottomLeading : .bottomTrailing

        VStack(alignment: position == .bottomLeft ? .leading : .trailing, spacing: 6) {
            HandDrawnDailyArrow(direction: position == .bottomLeft ? .upRight : .upLeft)
                .stroke(
                    .white,
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 70, height: 50)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            Text(title)
                .font(.custom("BradleyHandITCTT-Bold", size: 28))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.50), radius: 4, x: 0, y: 2)
                .lineLimit(2)
                .multilineTextAlignment(position == .bottomLeft ? .leading : .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    @ViewBuilder private var emptyCellPlaceholder: some View {
        ZStack {
            Color(red: 0.95, green: 0.91, blue: 0.85)
            Text("\u{2014}")
                .font(.custom("BradleyHandITCTT-Bold", size: 56))
                .foregroundStyle(Color(red: 0.42, green: 0.22, blue: 0.26).opacity(0.35))
        }
    }

    // MARK: - Bottom strip (warm off-white wordmark + pull quote)

    @ViewBuilder private var bottomStrip: some View {
        ZStack {
            Color(red: 0.97, green: 0.94, blue: 0.88)
            VStack(spacing: 14) {
                Spacer().frame(height: 60)
                Text(quoteLine)
                    .font(.custom("BradleyHandITCTT-Bold", size: 36))
                    .foregroundStyle(Color(red: 0.20, green: 0.10, blue: 0.12))
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.78, green: 0.32, blue: 0.40))
                    Text("jenifit")
                        .font(.custom("MarkerFelt-Wide", size: 42))
                        .foregroundStyle(Color(red: 0.20, green: 0.10, blue: 0.12))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var quoteLine: String {
        let pool = archetype.flatMap { Self.archetypeQuotePool[$0.lowercased()] }
            ?? Self.universalQuotePool
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[day % pool.count]
    }
}

// MARK: - Title / quote pools

private extension HandwrittenDailyShareCard {

    static let universalTitlePool: [String] = [
        "today fits",
        "she ate well",
        "kept the table set",
        "soft + steady",
        "another good one",
    ]

    static let archetypeTitlePool: [String: [String]] = [
        "protein": [
            "anchored",
            "protein kept",
            "muscle stays",
        ],
        "balanced": [
            "balanced + whole",
            "a little of everything",
        ],
        "movement": [
            "fueled the lift",
            "strength on the plate",
        ],
        "rest": [
            "softer today",
            "permission day",
        ],
    ]

    static let universalQuotePool: [String] = [
        "today fits ♡",
        "kept it ♡",
        "she ate well",
        "becoming, quietly",
        "one plate at a time",
        "another good one ♡",
    ]

    static let archetypeQuotePool: [String: [String]] = [
        "protein": [
            "anchored ♡",
            "muscle kept",
            "lean + steady ♡",
        ],
        "balanced": [
            "balanced enough ♡",
            "varied + whole",
        ],
        "movement": [
            "fueled the work ♡",
            "powered forward ♡",
        ],
        "rest": [
            "softer today ♡",
            "permission ♡",
        ],
    ]
}

// MARK: - SquigglyArrow (legacy compat stub)
//
// v1.0.10 had a `SquigglyArrow` shape used by the cream-card cells in
// the daily + weekly handwritten cards. The daily card was rebuilt
// v1.0.12 with a new shape (`HandDrawnDailyArrow`); the weekly card
// is queued for the same rebuild but still references SquigglyArrow.
// This stub keeps the package compiling until the weekly rebuild
// lands; the shape is intentionally simple — straight S-curve to a
// corner — and won't be visually visible on the rebuilt cards.

struct SquigglyArrow: Shape {
    let anchor: HandwrittenDailyShareCard.LabelAnchor

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let target = CGPoint(x: rect.midX, y: rect.midY)
        let origin: CGPoint = {
            switch anchor {
            case .topLeft:     return CGPoint(x: rect.minX + 30, y: rect.minY + 30)
            case .topRight:    return CGPoint(x: rect.maxX - 30, y: rect.minY + 30)
            case .bottomLeft:  return CGPoint(x: rect.minX + 30, y: rect.maxY - 30)
            case .bottomRight: return CGPoint(x: rect.maxX - 30, y: rect.maxY - 30)
            }
        }()
        path.move(to: origin)
        path.addCurve(
            to: target,
            control1: CGPoint(x: (origin.x + target.x) / 2, y: origin.y),
            control2: CGPoint(x: target.x, y: (origin.y + target.y) / 2)
        )
        return path
    }
}

// MARK: - HandDrawnDailyArrow

/// Curved arrow shape used inside cell labels — points up-and-out
/// from where the handwritten text sits, drawing the eye to the food.
/// Two directions cover the bottom-left / bottom-right label
/// placements; arrowhead drawn as two short lines.
struct HandDrawnDailyArrow: Shape {
    enum Direction { case upLeft, upRight }
    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .upRight:
            let start = CGPoint(x: rect.minX + 4, y: rect.maxY - 4)
            let end = CGPoint(x: rect.maxX - 4, y: rect.minY + 4)
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY - rect.height * 0.65),
                control2: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.60)
            )
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - 14, y: end.y + 3))
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - 3, y: end.y + 14))
        case .upLeft:
            let start = CGPoint(x: rect.maxX - 4, y: rect.maxY - 4)
            let end = CGPoint(x: rect.minX + 4, y: rect.minY + 4)
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY - rect.height * 0.65),
                control2: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.60)
            )
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + 14, y: end.y + 3))
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + 3, y: end.y + 14))
        }
        return path
    }
}

// MARK: - Public preview helper

extension HandwrittenDailyShareCard {
    public static let previewEntryIds: [String] = [
        "preview-1", "preview-2", "preview-3", "preview-4",
    ]

    public static func preview(
        archetype: String? = "protein",
        date: Date = Date(),
        photos: [UIImage] = []
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
        var photosDict: [String: UIImage] = [:]
        for (i, photo) in photos.prefix(4).enumerated() {
            photosDict[previewEntryIds[i]] = photo
        }
        return HandwrittenDailyShareCard(
            date: date,
            entries: mock,
            photos: photosDict,
            archetype: archetype
        )
    }
}

#endif  // canImport(UIKit)
