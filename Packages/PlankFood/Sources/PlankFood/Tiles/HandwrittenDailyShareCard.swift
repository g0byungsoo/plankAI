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

    // MARK: - Photo grid (2×2, zero-gap, edge-to-edge)

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
        .frame(width: 1080, height: 1920)
    }

    @ViewBuilder
    private func cell(
        at index: Int,
        in entries: [FoodLogPersister.FoodLogEntry]
    ) -> some View {
        if entries.indices.contains(index) {
            let entry = entries[index]
            ZStack {
                photoBackground(for: entry)
                cellLabel(for: entry, position: position(for: index))
            }
            .frame(width: 540, height: 960)
            .clipped()
        } else {
            emptyCellPlaceholder
                .frame(width: 540, height: 960)
        }
    }

    @ViewBuilder
    private func photoBackground(for entry: FoodLogPersister.FoodLogEntry) -> some View {
        if let photo = photos[entry.id] {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 540, height: 960)
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
            .frame(width: 540, height: 960)
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

    // MARK: - Per-cell text label
    //
    // Rotates label position per cell so labels don't all clump in
    // the same corner — matches the reference's variable-placement
    // feel where the writer puts the text wherever there's empty
    // negative space on the photo.

    /// Each cell gets a CORNER position so the arrow can travel a
    /// consistent diagonal (~300pt) from text-edge to cell-center
    /// without the fish-hook squiggle that happened on v5's bottom
    /// row when text sat at center-right / bottom-center (arrow had
    /// no room and rendered as a hook).
    private func position(for index: Int) -> CellLabelPosition {
        switch index {
        case 0: return .topRight     // top-left  cell of grid
        case 1: return .bottomLeft   // top-right cell of grid
        case 2: return .topLeft      // bot-left  cell of grid
        case 3: return .bottomRight  // bot-right cell of grid
        default: return .topRight
        }
    }

    public enum CellLabelPosition: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    @ViewBuilder
    private func cellLabel(
        for entry: FoodLogPersister.FoodLogEntry,
        position: CellLabelPosition
    ) -> some View {
        let lines = labelLines(for: entry)
        let alignment: Alignment = {
            switch position {
            case .topLeft:      return .topLeading
            case .topRight:     return .topTrailing
            case .bottomLeft:   return .bottomLeading
            case .bottomRight:  return .bottomTrailing
            }
        }()
        let seed: UInt64 = UInt64(bitPattern: Int64(entry.id.hashValue & 0x7FFFFFFF))
        // Approximate bounding box of the text block — the arrow shape
        // uses this to start OUTSIDE the text so the stroke never
        // crosses through letters. Each line is roughly Bradley Hand
        // Bold 34pt + 8pt spacing = ~48pt of vertical run; text width
        // estimated from the longest line at ~18pt per char.
        let textHeight: CGFloat = CGFloat(lines.count) * 48 + 8
        let longestLine = lines.map(\.count).max() ?? 8
        let textWidth: CGFloat = min(CGFloat(longestLine) * 18 + 32, 460)

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
                    lineWidth: 3.6,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: 540, height: 960)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)

            VStack(spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.custom("BradleyHandITCTT-Bold", size: 34))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
    }

    /// Splits the entry title into the overlay-friendly multi-line
    /// stack the reference uses. Real food logs are typically
    /// "avocado toast with egg" — split on "with" / "and" / "," to
    /// give the multi-line ingredient feel.
    private func labelLines(for entry: FoodLogPersister.FoodLogEntry) -> [String] {
        let title = entry.title.isEmpty ? "kept plate" : entry.title.lowercased()
        let splitChars = CharacterSet(charactersIn: ",+&")
        var parts = title
            .components(separatedBy: splitChars)
            .flatMap { $0.components(separatedBy: " with ") }
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if parts.isEmpty { parts = [title] }
        return Array(parts.prefix(6))
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
                title: "avocado toast with egg, chili flakes, microgreens",
                kcal: 380, protein: 18, carbs: 28, fat: 22,
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-2",
                loggedAt: date,
                title: "greek salad with feta, olives, cucumber, tomato",
                kcal: 240, protein: 14, carbs: 22, fat: 14,
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-3",
                loggedAt: date,
                title: "dates with almond butter and coconut",
                kcal: 180, protein: 6, carbs: 28, fat: 8,
                source: "photo"
            ),
            FoodLogPersister.FoodLogEntry(
                id: "preview-4",
                loggedAt: date,
                title: "chicken teriyaki with broccoli and rice",
                kcal: 540, protein: 38, carbs: 58, fat: 18,
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

// MARK: - RoughHandArrow
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
