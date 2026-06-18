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

    private func position(for index: Int) -> CellLabelPosition {
        switch index {
        case 0: return .topRight
        case 1: return .bottomLeft
        case 2: return .centerRight
        case 3: return .bottomCenter
        default: return .topRight
        }
    }

    enum CellLabelPosition { case topRight, bottomLeft, centerRight, bottomCenter }

    @ViewBuilder
    private func cellLabel(
        for entry: FoodLogPersister.FoodLogEntry,
        position: CellLabelPosition
    ) -> some View {
        let lines = labelLines(for: entry)
        let alignment: Alignment = {
            switch position {
            case .topRight:      return .topTrailing
            case .bottomLeft:    return .bottomLeading
            case .centerRight:   return .trailing
            case .bottomCenter:  return .bottom
            }
        }()

        VStack(spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
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

// MARK: - v1.0.10 compat shims (used by HandwrittenWeeklyShareCard)
//
// The weekly card still references these types from the v1.0.10
// cream-card design. Weekly is queued for the same edge-to-edge
// rebuild; these stubs keep the package compiling until then.

extension HandwrittenDailyShareCard {
    public enum LabelAnchor: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
}

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

#endif  // canImport(UIKit)
