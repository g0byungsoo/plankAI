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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: 640 - 30)
        }
        .frame(width: 1080, height: 1920)
        .background(Color(red: 0.97, green: 0.94, blue: 0.88))
    }

    // MARK: - Photo grid (2×3, zero-gap, edge-to-edge)

    @ViewBuilder private var photoGrid: some View {
        let top = Array(cells.prefix(6))
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(at: 0, in: top)
                cell(at: 1, in: top)
            }
            HStack(spacing: 0) {
                cell(at: 2, in: top)
                cell(at: 3, in: top)
            }
            HStack(spacing: 0) {
                cell(at: 4, in: top)
                cell(at: 5, in: top)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    @ViewBuilder
    private func cell(at index: Int, in cells: [WeeklyShareCell]) -> some View {
        if cells.indices.contains(index) {
            let cell = cells[index]
            ZStack {
                photoBackground(for: cell)
                cellLabel(for: cell, position: position(for: index))
            }
            .frame(width: 540, height: 640)
            .clipped()
        } else {
            emptyCellPlaceholder
                .frame(width: 540, height: 640)
        }
    }

    @ViewBuilder
    private func photoBackground(for cell: WeeklyShareCell) -> some View {
        if let photo = photos[cell.entryId] {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 540, height: 640)
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
            .frame(width: 540, height: 640)
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

    /// Rotates corner positions across the 6 cells so no two
    /// adjacent cells share a corner. Pattern picks the 4 corners
    /// then repeats — every cell still gets a clean diagonal arrow.
    private func position(for index: Int) -> HandwrittenDailyShareCard.CellLabelPosition {
        switch index {
        case 0: return .topRight     // top row,    left  cell
        case 1: return .bottomLeft   // top row,    right cell
        case 2: return .bottomRight  // middle row, left  cell
        case 3: return .topLeft      // middle row, right cell
        case 4: return .topRight     // bot row,    left  cell
        case 5: return .bottomLeft   // bot row,    right cell
        default: return .topRight
        }
    }

    @ViewBuilder
    private func cellLabel(
        for cell: WeeklyShareCell,
        position: HandwrittenDailyShareCard.CellLabelPosition
    ) -> some View {
        let lines = labelLines(for: cell)
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

        VStack(alignment: stackAlign, spacing: 12) {
            if isTop {
                itemStack(lines, align: textAlign)
                macroCaptionView(macroLine)
            } else {
                macroCaptionView(macroLine)
                itemStack(lines, align: textAlign)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    @ViewBuilder
    private func itemStack(_ lines: [String], align: TextAlignment) -> some View {
        let hAlign: HorizontalAlignment = (align == .leading) ? .leading
                                        : (align == .trailing) ? .trailing
                                        : .center
        VStack(alignment: hAlign, spacing: 5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.custom("BradleyHandITCTT-Bold", size: 28))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(align)
                    .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private func macroCaptionView(_ line: String) -> some View {
        Text(line)
            .font(.custom("BradleyHandITCTT-Bold", size: 18))
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
        if parts.isEmpty { parts = [title] }
        return Array(parts.prefix(5))
    }

    private func macroCaption(for cell: WeeklyShareCell) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let time = timeFmt.string(from: cell.loggedAt).lowercased()
            .replacingOccurrences(of: "am", with: "a")
            .replacingOccurrences(of: "pm", with: "p")
        var parts = [time]
        if cell.kcal > 0 {
            parts.append("\(Int(cell.kcal.rounded()))c")
        }
        if cell.protein > 0 {
            parts.append("\(Int(cell.protein.rounded()))p")
        }
        if cell.fiber > 0 {
            parts.append("\(Int(cell.fiber.rounded()))f")
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

    private var pillLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Week of \(fmt.string(from: weekStart))"
    }
}

// MARK: - Public preview helper

extension HandwrittenWeeklyShareCard {
    /// Mock cell IDs the preview() helper assigns — exposed so the
    /// main-app harness can build a positional photos dict against
    /// the same keys.
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
            "greek yogurt with berries, granola, honey",
            "matcha latte and almond croissant",
            "chipotle bowl with chicken, rice, beans",
            "salmon rice bowl with avocado, edamame",
            "avocado toast with egg, microgreens",
            "chicken caesar with parmesan, croutons",
        ]
        let mockItems: [[String]] = [
            ["greek yogurt", "berries", "granola", "honey"],
            ["matcha latte", "almond croissant"],
            ["chipotle bowl", "chicken", "rice", "beans", "salsa"],
            ["salmon rice bowl", "avocado", "edamame", "tamari"],
            ["avocado toast", "egg", "microgreens"],
            ["chicken caesar", "parmesan", "croutons", "lemon"],
        ]
        let mockMacros: [(Double, Double, Double)] = [
            (430, 22, 6),
            (340, 8, 2),
            (640, 38, 11),
            (580, 32, 8),
            (380, 18, 5),
            (520, 36, 4),
        ]
        let mockCells = (0..<6).map { i -> WeeklyShareCell in
            let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
            let loggedAt = cal.date(
                bySettingHour: 8 + i, minute: 30, second: 0, of: day
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
                WeeklyShareCell(
                    entryId: entry.id,
                    date: day,
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

#endif  // canImport(UIKit)
