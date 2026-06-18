#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenWeeklyShareCard
//
// v1.0.13 (2026-06-17) — REBUILT to match the daily card v6 pattern.
// Pure 2×3 photo grid filling the entire 1080×1920 canvas, no top
// title block and no bottom pull-quote. The only chrome is a small
// cream pill centered horizontally at the row-1/row-2 seam with a
// quiet serif "Week of {month d}" label.
//
// Per-cell overlay: Bradley Hand Bold 34pt label stack with a rough
// hand-drawn arrow pointing from the text-corner toward the cell
// center. Same RoughHandArrow shape as the daily card — corner-
// anchored exit point with deterministic per-cell wobble.
//
// Layout (1080×1920, top-down):
//
//   - 0     →  640pt: top row    — 2 cells of 540×640
//   - 640   → 1280pt: middle row — 2 cells of 540×640 (pill overlays seam)
//   - 1280  → 1920pt: bottom row — 2 cells of 540×640
//
// Cells without an entry render the warm-cream "—" placeholder.
// Cells without a photo render a soft rose gradient so the label
// stays legible.

public struct HandwrittenWeeklyShareCard: View {

    let weekStart: Date
    let cells: [WeeklyShareCell]
    let photos: [String: UIImage]
    var archetype: String? = nil

    public var body: some View {
        ZStack {
            photoGrid
                .frame(width: 1080, height: 1920)

            seamPill
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: 1080, height: 1920)
        .background(Color(red: 0.97, green: 0.94, blue: 0.88))
    }

    // MARK: - Photo grid (dynamic, zero-gap, edge-to-edge)
    //
    // v1.0.14 (2026-06-18) — cap at 10 cells (5 rows × 2 cols, each
    // 540×384). Anything more crowds the labels even at the smallest
    // font ladder; founder asked for a "last N meals" framing rather
    // than a strict week boundary, so 10 is the visible cap and the
    // pill names whatever count actually rendered.

    private var visibleCells: [WeeklyShareCell] {
        Array(cells.prefix(10))
    }

    private var gridGeometry: (rows: Int, cols: Int) {
        let count = visibleCells.count
        switch count {
        case 0, 1: return (1, 1)
        case 2:    return (2, 1)
        case 3, 4: return (2, 2)
        case 5, 6: return (3, 2)
        case 7, 8: return (4, 2)
        default:   return (5, 2)
        }
    }

    private var cellSize: (width: CGFloat, height: CGFloat) {
        let g = gridGeometry
        return (1080.0 / CGFloat(g.cols), 1920.0 / CGFloat(g.rows))
    }

    @ViewBuilder private var photoGrid: some View {
        let cells = visibleCells
        let g = gridGeometry
        let metrics = HandwrittenDailyShareCard.cellMetrics(forRows: g.rows)
        VStack(spacing: 0) {
            ForEach(0..<g.rows, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<g.cols, id: \.self) { colIdx in
                        let index = rowIdx * g.cols + colIdx
                        cell(
                            at: index,
                            rowIdx: rowIdx, colIdx: colIdx,
                            in: cells,
                            metrics: metrics
                        )
                    }
                }
            }
        }
        .frame(width: 1080, height: 1920)
    }

    @ViewBuilder
    private func cell(
        at index: Int,
        rowIdx: Int,
        colIdx: Int,
        in cells: [WeeklyShareCell],
        metrics: HandwrittenDailyShareCard.CellMetrics
    ) -> some View {
        let size = cellSize
        if cells.indices.contains(index) {
            let cell = cells[index]
            ZStack {
                photoBackground(for: cell, size: size)
                cellLabel(
                    for: cell,
                    position: HandwrittenDailyShareCard.position(
                        rowIdx: rowIdx, colIdx: colIdx
                    ),
                    metrics: metrics
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        } else {
            emptyCellPlaceholder
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func photoBackground(
        for cell: WeeklyShareCell,
        size: (width: CGFloat, height: CGFloat)
    ) -> some View {
        if let photo = photos[cell.entryId] {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.78, blue: 0.79),
                    Color(red: 0.85, green: 0.55, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder private var emptyCellPlaceholder: some View {
        ZStack {
            Color(red: 0.95, green: 0.91, blue: 0.85)
            Text("\u{2014}")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color(red: 0.42, green: 0.22, blue: 0.26).opacity(0.35))
        }
    }

    // MARK: - Per-cell label

    @ViewBuilder
    private func cellLabel(
        for cell: WeeklyShareCell,
        position: HandwrittenDailyShareCard.CellLabelPosition,
        metrics: HandwrittenDailyShareCard.CellMetrics
    ) -> some View {
        let lines = Array(labelLines(for: cell).prefix(metrics.maxItems))
        let macroLine = macroCaption(for: cell)
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
        let stackAlign: HorizontalAlignment = (position == .topLeft || position == .bottomLeft)
            ? .leading : .trailing

        VStack(alignment: stackAlign, spacing: metrics.stackSpacing) {
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
                    .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private func macroCaptionView(
        _ line: String,
        metrics: HandwrittenDailyShareCard.CellMetrics
    ) -> some View {
        Text(line)
            // v1.0.16 — JeniFit-style caption per founder direction;
            // see HandwrittenDailyShareCard.macroCaptionView for the
            // typeface rationale.
            .font(.custom("DMSans-Medium", size: metrics.macroFont))
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
    }

    /// Same fallback ladder as the daily card: prefer the persisted
    /// `items` array (every scanned food in vision-ranked order);
    /// fall back to splitting `title` for legacy entries.
    private func labelLines(for cell: WeeklyShareCell) -> [String] {
        if let items = cell.items, !items.isEmpty {
            return items
                .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(5)
                .map { String($0) }
        }
        let title = cell.title.isEmpty ? "kept plate" : cell.title.lowercased()
        let splitChars = CharacterSet(charactersIn: ",+&")
        var parts = title
            .components(separatedBy: splitChars)
            .flatMap { $0.components(separatedBy: " with ") }
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            // Legacy title heuristic stuffs "+ N more" placeholders;
            // drop them so we never render "2 more" as if it were a
            // food name. Shared filter lives on the daily card.
            .filter { !HandwrittenDailyShareCard.isCountMorePlaceholder($0) }
        if parts.isEmpty { parts = [title] }
        return Array(parts.prefix(5))
    }

    private func macroCaption(for cell: WeeklyShareCell) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let time = timeFmt.string(from: cell.loggedAt).lowercased()
        var parts = [time]
        if cell.kcal > 0 {
            parts.append("\(Int(cell.kcal.rounded())) calories")
        }
        if cell.protein > 0 {
            parts.append("\(Int(cell.protein.rounded()))g protein")
        }
        if cell.fiber > 0 {
            parts.append("\(Int(cell.fiber.rounded()))g fiber")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Seam pill

    @ViewBuilder private var seamPill: some View {
        Text(pillLabel)
            .font(.custom("Fraunces72pt-Regular", size: 26))
            .foregroundStyle(Color(red: 0.20, green: 0.10, blue: 0.12).opacity(0.85))
            .tracking(0.5)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.92))
            )
    }

    /// v1.0.14 (2026-06-18) — "last N meals" framing per founder
    /// request: the card no longer pretends to enforce a strict week
    /// boundary (one entry per day) — it's just whatever recent meals
    /// have photos, capped at 10. Pill names whatever count actually
    /// rendered.
    private var pillLabel: String {
        let count = visibleCells.count
        return count == 1 ? "last meal" : "last \(count) meals"
    }
}

// MARK: - Public preview helper

extension HandwrittenWeeklyShareCard {
    /// Mock cell IDs the preview() helper assigns — exposed so the
    /// main-app harness can build a positional photos dict against
    /// the same keys.
    public static let previewCellIds: [String] = [
        "preview-0", "preview-1", "preview-2", "preview-3", "preview-4",
        "preview-5", "preview-6", "preview-7", "preview-8", "preview-9",
    ]

    public static func preview(
        archetype: String? = "protein",
        photos: [UIImage] = []
    ) -> HandwrittenWeeklyShareCard {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let titles = [
            "greek yogurt", "matcha latte", "chipotle bowl",
            "salmon rice bowl", "avocado toast", "chicken caesar",
            "scrambled eggs", "berry smoothie", "tofu stir fry",
            "pesto pasta",
        ]
        let mockItems: [[String]] = [
            ["greek yogurt", "berries", "granola", "honey"],
            ["matcha latte", "almond croissant"],
            ["chipotle bowl", "chicken", "rice", "beans", "salsa"],
            ["salmon rice bowl", "avocado", "edamame", "tamari"],
            ["avocado toast", "egg", "microgreens"],
            ["chicken caesar", "parmesan", "croutons", "lemon"],
            ["scrambled eggs", "spinach", "feta"],
            ["berry smoothie", "banana", "spinach", "almond milk"],
            ["tofu stir fry", "bok choy", "ginger", "rice"],
            ["pesto pasta", "tomato", "parmesan", "basil"],
        ]
        let mockMacros: [(Double, Double, Double)] = [
            (430, 22, 6), (340, 8, 2), (640, 38, 11), (580, 32, 8),
            (380, 18, 5), (520, 36, 4), (310, 24, 3), (260, 12, 6),
            (490, 26, 7), (610, 20, 5),
        ]
        let mockCells = (0..<10).map { i -> WeeklyShareCell in
            let day = cal.date(byAdding: .day, value: i / 2, to: weekStart) ?? weekStart
            let loggedAt = cal.date(
                bySettingHour: 8 + (i * 2), minute: 30, second: 0, of: day
            ) ?? day
            let (k, p, f) = mockMacros[i]
            return WeeklyShareCell(
                entryId: previewCellIds[i],
                date: day,
                title: titles[i],
                loggedAt: loggedAt,
                kcal: k,
                protein: p,
                fiber: f,
                items: mockItems[i]
            )
        }
        var photosDict: [String: UIImage] = [:]
        for (i, photo) in photos.prefix(10).enumerated() where i < previewCellIds.count {
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
        // v1.0.14 (2026-06-18) — "last 10 meals" framing per founder
        // request. Previous renderer enforced one-photo-per-day across
        // the week (max 6 cells); the new framing drops the day
        // constraint and just pulls the 10 most recent photo-backed
        // entries (sorted oldest→newest for display order). Caller's
        // referenceDate parameter is kept for API parity but no longer
        // gates the window.
        _ = referenceDate

        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { FoodPhotoStore.hasPhoto(entryId: $0.id) }
        // allEntries returns newest first; take the 10 most recent
        // then flip to chronological so the share reads earliest →
        // latest left-to-right top-to-bottom.
        let recent = Array(entries.prefix(10).reversed())
        guard !recent.isEmpty else { return nil }

        let chronological = recent.map { entry -> WeeklyShareCell in
            WeeklyShareCell(
                entryId: entry.id,
                date: Calendar.current.startOfDay(for: entry.loggedAt),
                title: entry.title,
                loggedAt: entry.loggedAt,
                kcal: entry.kcal,
                protein: entry.protein,
                fiber: entry.fiber,
                items: entry.items
            )
        }

        var photos: [String: UIImage] = [:]
        for cell in chronological {
            if let img = FoodPhotoStore.photo(entryId: cell.entryId) {
                photos[cell.entryId] = img
            }
        }

        let weekStart = recent.first.map {
            Calendar.current.startOfDay(for: $0.loggedAt)
        } ?? Date()

        let card = HandwrittenWeeklyShareCard(
            weekStart: weekStart,
            cells: chronological,
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

#endif  // canImport(UIKit)
