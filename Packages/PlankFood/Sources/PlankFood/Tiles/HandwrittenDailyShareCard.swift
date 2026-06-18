#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenDailyShareCard
//
// v1.0.13 (2026-06-17) — REBUILT to match the founder's reference
// Pinterest aesthetic (5 mood-board images, 4 of 5 use the same
// pattern): pure 2×2 photo grid filling the entire 1080×1920 canvas,
// no top title strip and no bottom wordmark strip. The ONLY chrome
// is a small light-cream pill centered at the seam between the rows
// with a quiet serif "Day N" label.
//
// Per-cell overlay: a vertical list of ingredients / context lines
// in plain white sans-serif, ~30pt, with a soft shadow for legibility.
// Positions rotate per cell to avoid clustering all labels at the
// same edge (top-right / bottom-left / center-right / bottom-center).
//
// Layout (1080×1920, top-down):
//
//   - 0    →  960pt: top row — 2 cells of 540×960 each, no gap
//   - 960pt: center pill seam (overlay) — small cream pill with
//            serif "Day N" label
//   - 960  → 1920pt: bottom row — 2 cells of 540×960 each, no gap
//
// Cells without an entry render a warm cream block w/ "—" centered.
// Cells without a photo render a soft rose gradient block so the
// label still reads.

public struct HandwrittenDailyShareCard: View {

    let date: Date
    let entries: [FoodLogPersister.FoodLogEntry]
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
    // v1.0.14 (2026-06-18) — grid geometry now derived from
    // entries.count so 6 logs render as 3×2, 8 as 4×2, etc. Hard
    // cap at 8 cells (4 rows × 2 cols) — anything past that risks
    // unreadable cell labels even with the scaled font ladder.
    //
    //  count → (rows, cols)
    //    0,1 → (1, 1)
    //      2 → (2, 1)
    //    3,4 → (2, 2)
    //    5,6 → (3, 2)
    //    7,8 → (4, 2)

    private var visibleEntries: [FoodLogPersister.FoodLogEntry] {
        Array(entries.prefix(8))
    }

    private var gridGeometry: (rows: Int, cols: Int) {
        let count = visibleEntries.count
        switch count {
        case 0, 1: return (1, 1)
        case 2:    return (2, 1)
        case 3, 4: return (2, 2)
        case 5, 6: return (3, 2)
        default:   return (4, 2)
        }
    }

    private var cellSize: (width: CGFloat, height: CGFloat) {
        let g = gridGeometry
        return (1080.0 / CGFloat(g.cols), 1920.0 / CGFloat(g.rows))
    }

    @ViewBuilder private var photoGrid: some View {
        let entries = visibleEntries
        let g = gridGeometry
        let metrics = cellMetrics(forRows: g.rows)
        VStack(spacing: 0) {
            ForEach(0..<g.rows, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<g.cols, id: \.self) { colIdx in
                        let index = rowIdx * g.cols + colIdx
                        cell(
                            at: index,
                            rowIdx: rowIdx, colIdx: colIdx,
                            in: entries,
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
        in entries: [FoodLogPersister.FoodLogEntry],
        metrics: CellMetrics
    ) -> some View {
        let size = cellSize
        if entries.indices.contains(index) {
            let entry = entries[index]
            ZStack {
                photoBackground(for: entry, size: size)
                cellLabel(
                    for: entry,
                    position: position(rowIdx: rowIdx, colIdx: colIdx),
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
        for entry: FoodLogPersister.FoodLogEntry,
        size: (width: CGFloat, height: CGFloat)
    ) -> some View {
        if let photo = photos[entry.id] {
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
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color(red: 0.42, green: 0.22, blue: 0.26).opacity(0.35))
        }
    }

    // MARK: - Cell metrics
    //
    // Per-row font + padding ladder so denser grids stay readable.
    // Item count caps with the rows too — a 4-row grid only has
    // ~480pt of cell height, can't fit 6 ingredients without
    // overflow.

    struct CellMetrics {
        let itemsFont: CGFloat
        let macroFont: CGFloat
        let itemsSpacing: CGFloat
        let stackSpacing: CGFloat
        let hPad: CGFloat
        let vPad: CGFloat
        let maxItems: Int
    }

    /// Static so the weekly card (same module, different type) can
    /// reuse the same row-count → font/padding ladder without
    /// duplicating the table.
    ///
    /// v1.0.15 (2026-06-18) — font ladder bumped so every cell stays
    /// legible on a phone-sized display (founder reference: TikTok's
    /// minimum readable caption size, relative to canvas). Worst-case
    /// 5-row cell is 540×384 — items at 28pt = 7.3% of cell height,
    /// macro caption 20pt = 5.2%. Both comfortably above TikTok's
    /// ~1.5% feed-text floor. maxItems also trims at higher row
    /// counts so denser grids drop the long tail rather than shrink
    /// to fit.
    static func cellMetrics(forRows rows: Int) -> CellMetrics {
        switch rows {
        case 1: return CellMetrics(
            itemsFont: 60, macroFont: 36, itemsSpacing: 14, stackSpacing: 24,
            hPad: 72, vPad: 120, maxItems: 8
        )
        case 2: return CellMetrics(
            itemsFont: 44, macroFont: 28, itemsSpacing: 8, stackSpacing: 18,
            hPad: 32, vPad: 56, maxItems: 5
        )
        case 3: return CellMetrics(
            itemsFont: 36, macroFont: 24, itemsSpacing: 6, stackSpacing: 14,
            hPad: 24, vPad: 38, maxItems: 4
        )
        case 4: return CellMetrics(
            itemsFont: 32, macroFont: 22, itemsSpacing: 5, stackSpacing: 12,
            hPad: 22, vPad: 28, maxItems: 3
        )
        default: return CellMetrics(
            itemsFont: 28, macroFont: 20, itemsSpacing: 5, stackSpacing: 11,
            hPad: 20, vPad: 22, maxItems: 3
        )
        }
    }

    private func cellMetrics(forRows rows: Int) -> CellMetrics {
        Self.cellMetrics(forRows: rows)
    }

    // MARK: - Per-cell text label
    //
    // Rotates label position per cell so labels don't all clump in
    // the same corner — matches the reference's variable-placement
    // feel where the writer puts the text wherever there's empty
    // negative space on the photo.

    /// 4-corner rotation indexed by (rowIdx, colIdx) so no two
    /// vertically- or horizontally-adjacent cells share a corner.
    /// Generalized from the v1.0.12 4-cell hardcoded mapping so the
    /// dynamic grid (1–4 rows × 1–2 cols) gets the same visual
    /// variety without per-count special cases.
    static func position(rowIdx: Int, colIdx: Int) -> CellLabelPosition {
        let key = (rowIdx * 2 + colIdx) % 4
        switch key {
        case 0: return .topRight
        case 1: return .bottomLeft
        case 2: return .topLeft
        default: return .bottomRight
        }
    }

    private func position(rowIdx: Int, colIdx: Int) -> CellLabelPosition {
        Self.position(rowIdx: rowIdx, colIdx: colIdx)
    }

    public enum CellLabelPosition: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    @ViewBuilder
    private func cellLabel(
        for entry: FoodLogPersister.FoodLogEntry,
        position: CellLabelPosition,
        metrics: CellMetrics
    ) -> some View {
        let lines = Array(labelLines(for: entry).prefix(metrics.maxItems))
        let macroLine = macroCaption(for: entry)
        let alignment: Alignment = {
            switch position {
            case .topLeft:      return .topLeading
            case .topRight:     return .topTrailing
            case .bottomLeft:   return .bottomLeading
            case .bottomRight:  return .bottomTrailing
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
        metrics: CellMetrics
    ) -> some View {
        VStack(alignment: alignFor(align), spacing: metrics.itemsSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.custom("BradleyHandITCTT-Bold", size: metrics.itemsFont))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(align)
                    .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
            }
        }
    }

    private func alignFor(_ a: TextAlignment) -> HorizontalAlignment {
        switch a {
        case .leading:  return .leading
        case .trailing: return .trailing
        case .center:   return .center
        @unknown default: return .leading
        }
    }

    @ViewBuilder
    private func macroCaptionView(_ line: String, metrics: CellMetrics) -> some View {
        Text(line)
            .font(.custom("BradleyHandITCTT-Bold", size: metrics.macroFont))
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
    }

    /// Builds the per-cell vertical ingredient stack. Prefers the
    /// `items` array persisted at scan time (every detected food in
    /// vision-ranked order — what the founder asked for); falls back
    /// to splitting `title` on common separators for legacy entries
    /// written before items was persisted (v1.0.12 and earlier).
    /// Caller (cellLabel) clamps the final count via CellMetrics.maxItems
    /// so a denser grid drops the long tail rather than overflowing.
    private func labelLines(for entry: FoodLogPersister.FoodLogEntry) -> [String] {
        if let items = entry.items, !items.isEmpty {
            return items
                .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let title = entry.title.isEmpty ? "kept plate" : entry.title.lowercased()
        let splitChars = CharacterSet(charactersIn: ",+&")
        var parts = title
            .components(separatedBy: splitChars)
            .flatMap { $0.components(separatedBy: " with ") }
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            // Legacy titles bake the "+ N more" placeholder into the
            // string itself ("guacamole + 2 more"). Splitting yields
            // ["guacamole", "2 more"] — we don't actually have those
            // N items, so drop the placeholder rather than pretend
            // "2 more" is a food.
            .filter { !Self.isCountMorePlaceholder($0) }
        if parts.isEmpty { parts = [title] }
        return parts
    }

    /// Matches "N more" / "+N more" / "+ 2 more" — the count-then-more
    /// placeholder PersistLog drops into legacy titles. New (v1.0.13+)
    /// entries store the real items array and never hit this path.
    static func isCountMorePlaceholder(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "+"))
            .trimmingCharacters(in: .whitespaces)
        guard let spaceIdx = trimmed.firstIndex(of: " ") else { return false }
        let head = trimmed[..<spaceIdx]
        let tail = trimmed[trimmed.index(after: spaceIdx)...]
            .trimmingCharacters(in: .whitespaces)
        return Int(head) != nil && tail == "more"
    }

    /// Macro caption per cell. Founder direction (2026-06-18): spell
    /// the macros out — no single-letter abbreviations. Reads
    /// "8:42am · 380 calories · 18g protein · 7g fiber". Fiber omitted
    /// when 0 since most legacy entries lack it; calories/protein
    /// always show (zero plates are filtered upstream).
    private func macroCaption(for entry: FoodLogPersister.FoodLogEntry) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let time = timeFmt.string(from: entry.loggedAt).lowercased()

        var parts = [time]
        if entry.kcal > 0 {
            parts.append("\(Int(entry.kcal.rounded())) calories")
        }
        if entry.protein > 0 {
            parts.append("\(Int(entry.protein.rounded()))g protein")
        }
        if entry.fiber > 0 {
            parts.append("\(Int(entry.fiber.rounded()))g fiber")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Seam pill (the only chrome — matches reference exactly)

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
        let day = Calendar.current.component(.day, from: date)
        return "Day \(day)"
    }
}

// MARK: - Public preview helper

extension HandwrittenDailyShareCard {
    public static let previewEntryIds: [String] = [
        "preview-1", "preview-2", "preview-3",
        "preview-4", "preview-5", "preview-6",
    ]

    public static func preview(
        archetype: String? = "protein",
        date: Date = Date(),
        photos: [UIImage] = []
    ) -> HandwrittenDailyShareCard {
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: date) ?? date
        }
        let mock: [FoodLogPersister.FoodLogEntry] = [
            FoodLogPersister.FoodLogEntry(
                id: "preview-1",
                loggedAt: at(8, 42),
                title: "avocado toast",
                kcal: 380, protein: 18, carbs: 28, fat: 22,
                fiber: 7,
                items: ["avocado toast", "egg", "chili flakes", "microgreens"],
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-2",
                loggedAt: at(10, 30),
                title: "matcha latte",
                kcal: 180, protein: 6, carbs: 22, fat: 7,
                fiber: 2,
                items: ["matcha", "oat milk", "vanilla"],
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-3",
                loggedAt: at(12, 15),
                title: "greek salad",
                kcal: 240, protein: 14, carbs: 22, fat: 14,
                fiber: 6,
                items: ["greek salad", "feta", "olives", "cucumber", "tomato"],
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-4",
                loggedAt: at(15, 30),
                title: "dates",
                kcal: 180, protein: 6, carbs: 28, fat: 8,
                fiber: 4,
                items: ["dates", "almond butter", "coconut"],
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-5",
                loggedAt: at(17, 10),
                title: "kombucha",
                kcal: 60, protein: 0, carbs: 14, fat: 0,
                fiber: 0,
                items: ["kombucha", "ginger"],
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-6",
                loggedAt: at(19, 45),
                title: "chicken teriyaki",
                kcal: 540, protein: 38, carbs: 58, fat: 18,
                fiber: 9,
                items: ["chicken teriyaki", "broccoli", "rice"],
                source: "photo"
            ),
        ]
        var photosDict: [String: UIImage] = [:]
        for (i, photo) in photos.prefix(8).enumerated() where i < previewEntryIds.count {
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

// MARK: - RoughHandArrow (DEAD — kept public for snap card compat)
//
// v1.0.13 (2026-06-18) — arrows were removed from the daily card per
// founder direction ("get rid of arrows, this feels difficult to make
// it point to the actual food"). The shape itself stays in this file
// because HandwrittenSnapResultShareCard still uses RoughHandArrow
// for the single-photo snap render. When snap drops arrows too, this
// whole block + SplitMix64 should come out.
//
// Per-cell rough hand-drawn arrow. Starts near the label corner and
// curves toward the cell center (where the food sits). The curve
// path picks up a deterministic per-entry seed so the same entry
// always renders the same wobble — re-renders don't flicker the
// arrow shape — but different entries get visually distinct strokes
// (jittered control points, wobbly arrowhead angles). Matches the
// reference's "drawn with a Posca pen" feel.

struct RoughHandArrow: Shape {
    let position: HandwrittenDailyShareCard.CellLabelPosition
    let seed: UInt64
    /// Bounding box of the text label so the arrow starts OUTSIDE
    /// the text. Without this the bezier passes through letters and
    /// reads as a strikethrough. Caller supplies these dimensions
    /// based on Bradley Hand 34pt metrics and the line count.
    let textWidth: CGFloat
    let textHeight: CGFloat

    /// Pixel gap between the text-block edge and the arrow's start
    /// point — keeps the stroke visually clear of letter ascenders /
    /// descenders even at jitter peaks.
    private static let separation: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var rng = SplitMix64(seed: seed)
        let jitter: (CGFloat) -> CGFloat = { range in
            let r = CGFloat(rng.nextUnitDouble()) * 2 - 1
            return r * range
        }

        // Padding the cellLabel VStack uses to inset its frame.
        let hPad: CGFloat = 28
        let vPad: CGFloat = 50

        // Text-block bounds inside the cell (alignment-aware). We
        // anchor the label at whichever rect corner matches its
        // position; the rect describes WHERE THE TEXT IS, not where
        // the arrow goes.
        let textBox: CGRect = {
            switch position {
            case .topLeft:
                return CGRect(
                    x: rect.minX + hPad,
                    y: rect.minY + vPad,
                    width: textWidth, height: textHeight
                )
            case .topRight:
                return CGRect(
                    x: rect.maxX - hPad - textWidth,
                    y: rect.minY + vPad,
                    width: textWidth, height: textHeight
                )
            case .bottomLeft:
                return CGRect(
                    x: rect.minX + hPad,
                    y: rect.maxY - vPad - textHeight,
                    width: textWidth, height: textHeight
                )
            case .bottomRight:
                return CGRect(
                    x: rect.maxX - hPad - textWidth,
                    y: rect.maxY - vPad - textHeight,
                    width: textWidth, height: textHeight
                )
            }
        }()

        // Arrow exits the INNER CORNER of the textBox (the corner
        // facing the cell center) pushed diagonally outward by
        // `separation`. Every cell now sees an arrow that travels a
        // clean diagonal of similar length to its center, killing
        // the v5 fish-hook squiggle on the bottom row.
        let labelAnchor: CGPoint = {
            switch position {
            case .topLeft:
                return CGPoint(
                    x: textBox.maxX + Self.separation,
                    y: textBox.maxY + Self.separation
                )
            case .topRight:
                return CGPoint(
                    x: textBox.minX - Self.separation,
                    y: textBox.maxY + Self.separation
                )
            case .bottomLeft:
                return CGPoint(
                    x: textBox.maxX + Self.separation,
                    y: textBox.minY - Self.separation
                )
            case .bottomRight:
                return CGPoint(
                    x: textBox.minX - Self.separation,
                    y: textBox.minY - Self.separation
                )
            }
        }()

        // Target lands ~40pt short of the cell's geometric center on
        // the side the arrow came from — gives the head room to sit
        // ON the food rather than past it. Tiny jitter only so the
        // direction stays predictable and the head reads as an arrow.
        let dirX: CGFloat = target_dirX(position: position)
        let dirY: CGFloat = target_dirY(position: position)
        let target = CGPoint(
            x: rect.midX + dirX * 40 + jitter(18),
            y: rect.midY + dirY * 40 + jitter(18)
        )

        var path = Path()
        path.move(to: labelAnchor)

        // Single gentle S-curve — control points biased ~30%/70% of
        // the way along the labelAnchor→target line with small
        // perpendicular wobble. Less jitter than v5 (was 80/60); the
        // all-corner geometry already varies arrows cell-to-cell.
        let span = CGPoint(
            x: target.x - labelAnchor.x,
            y: target.y - labelAnchor.y
        )
        let perpJitter = jitter(50)
        let control1 = CGPoint(
            x: labelAnchor.x + span.x * 0.35 - span.y * 0.10 + perpJitter * 0.6,
            y: labelAnchor.y + span.y * 0.35 + span.x * 0.10 - perpJitter * 0.6
        )
        let control2 = CGPoint(
            x: labelAnchor.x + span.x * 0.70 + span.y * 0.08,
            y: labelAnchor.y + span.y * 0.70 - span.x * 0.08
        )
        path.addCurve(to: target, control1: control1, control2: control2)

        // Arrowhead — symmetric ~30° wings off the tangent at the
        // tip. The tangent direction is computed from control2→target
        // so it always tracks the curve's final heading; symmetry +
        // small length wobble keeps it reading as a hand-drawn arrow
        // without the fish-hook asymmetry from v5.
        let dx = target.x - control2.x
        let dy = target.y - control2.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        let nx = dx / len
        let ny = dy / len
        let headLength: CGFloat = 26 + jitter(3)
        let headAngle: CGFloat = 0.52

        let leftTip = CGPoint(
            x: target.x - headLength * (nx * cos(headAngle) + ny * sin(headAngle)),
            y: target.y - headLength * (ny * cos(headAngle) - nx * sin(headAngle))
        )
        let rightTip = CGPoint(
            x: target.x - headLength * (nx * cos(-headAngle) + ny * sin(-headAngle)),
            y: target.y - headLength * (ny * cos(-headAngle) - nx * sin(-headAngle))
        )
        path.move(to: target)
        path.addLine(to: leftTip)
        path.move(to: target)
        path.addLine(to: rightTip)
        return path
    }

    /// Direction signs for shifting the target away from cell center
    /// toward where the label sits. Negative x = label-on-left side,
    /// positive x = label-on-right; same for y.
    private func target_dirX(position: HandwrittenDailyShareCard.CellLabelPosition) -> CGFloat {
        switch position {
        case .topLeft, .bottomLeft:   return -1
        case .topRight, .bottomRight: return  1
        }
    }
    private func target_dirY(position: HandwrittenDailyShareCard.CellLabelPosition) -> CGFloat {
        switch position {
        case .topLeft, .topRight:       return -1
        case .bottomLeft, .bottomRight: return  1
        }
    }
}

/// SplitMix64 — small deterministic PRNG. Identical seed → identical
/// stream, so the arrow path is stable across re-renders of the same
/// entry (no flicker on state changes). Used inside RoughHandArrow.
private struct SplitMix64 {
    var state: UInt64

    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }

    mutating func nextUnitDouble() -> Double {
        return Double(next() &>> 11) / Double(1 &<< 53)
    }
}

#endif  // canImport(UIKit)
