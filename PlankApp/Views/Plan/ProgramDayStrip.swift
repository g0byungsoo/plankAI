import SwiftUI

// MARK: - ProgramDayStrip (v3 — UX redesign 2026-06-09 evening)
//
// v1.1 program pivot — PlanView redesign per UX spec §v3.4.
// Horizontal day-pill strip with TODAY ALWAYS CENTERED at rest.
//
// Founder direction v3 (2026-06-09 evening):
//   - 42pt cells (was 44pt — gives 1.5pt visual breathing at iPhone 15 width)
//   - 7 cells × 42 + 6 gaps × 8 = 342pt content visible inside 345pt safe-edge
//   - Swipe-allowed but SNAPS BACK to centered-on-today (or scrapbook day)
//     on drag release via Motion.snapBack (0.78 damping — slightly bouncy)
//   - Always-on center marker "── today ──" below the strip; replaces
//     the first-launch swipe hint
//   - In scrapbook mode the strip centers on the viewing day and the
//     marker reads "── day 8 ──" instead of "── today ──"
//
// Implementation note: this view uses a custom HStack + offset +
// DragGesture rather than ScrollView. Reason: ScrollView's pan
// gesture is hard to wire to "always snap to a specific cell on
// release"; rolling our own gives full control over the snap-back
// behavior the founder asked for.

struct ProgramDayStrip: View {

    let programDay: Int                  // user's current day
    let totalDays: Int                   // plan duration
    let completionByDay: [Int: Int]      // programDay → completed-row count
    let centeredDay: Int                 // today normally; past day in scrapbook
    let onTap: (Day) -> Void

    enum Day: Equatable {
        case today
        case past(day: Int)
        case locked(day: Int)
        case newProgram
    }

    private static let cellWidth: CGFloat = 42
    private static let cellHeight: CGFloat = 56
    private static let cellGap: CGFloat = 8
    private static let cellStride: CGFloat = cellWidth + cellGap

    /// Past-day completion threshold for ".completed" vs ".partial".
    /// 3 of 5 = forgiving (half + 1).
    private static let completedThreshold: Int = 3

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let screenWidth = geo.size.width
                let settledOffset = centeredOffset(for: centeredDay, screenWidth: screenWidth)

                strip(settledOffset: settledOffset + dragOffset, screenWidth: screenWidth)
            }
            .frame(height: Self.cellHeight)
            .clipped()

            centerMarker
        }
    }

    // MARK: - Strip

    @ViewBuilder
    private func strip(settledOffset: CGFloat, screenWidth: CGFloat) -> some View {
        HStack(spacing: Self.cellGap) {
            ForEach(1...totalDays, id: \.self) { day in
                ProgramDayCell(
                    day: day,
                    state: stateForCell(day: day),
                    onTap: {
                        Haptics.light()
                        onTap(routeFor(day: day))
                    }
                )
                .frame(width: Self.cellWidth, height: Self.cellHeight)
            }
            if programDay > totalDays {
                ProgramDayCell(
                    day: 0,
                    state: .newProgram,
                    onTap: { onTap(.newProgram) }
                )
                .frame(width: Self.cellWidth, height: Self.cellHeight)
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .offset(x: settledOffset)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { _ in
                    withAnimation(Motion.snapBack) {
                        dragOffset = 0
                    }
                }
        )
    }

    private var contentWidth: CGFloat {
        let extraCell: CGFloat = programDay > totalDays ? Self.cellStride : 0
        return CGFloat(totalDays) * Self.cellStride - Self.cellGap + extraCell
    }

    /// Offset that places the given day's cell at the horizontal
    /// center of the visible frame. centeredDay = today normally,
    /// or the scrapbook day when PlanView passes that down.
    private func centeredOffset(for day: Int, screenWidth: CGFloat) -> CGFloat {
        let clamped = max(1, min(day, totalDays))
        let cellCenterFromContentStart = CGFloat(clamped - 1) * Self.cellStride + Self.cellWidth / 2
        return screenWidth / 2 - cellCenterFromContentStart
    }

    // MARK: - Center marker
    //
    // Always-on. "── today ──" when at rest on today; "── day N ──"
    // in scrapbook mode. Italic Fraunces on the descriptor word so
    // the JeniFit voice signal lives in the strip chrome.

    private var centerMarker: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(width: 28, height: 0.5)
            Text(centerMarkerLabel)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(width: 28, height: 0.5)
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private var centerMarkerLabel: String {
        centeredDay == programDay ? "today" : "day \(centeredDay)"
    }

    // MARK: - State derivation

    private func stateForCell(day: Int) -> ProgramDayCell.State {
        if day == programDay { return .today }
        if day > programDay { return .locked }
        let count = completionByDay[day] ?? 0
        if count >= Self.completedThreshold { return .completed }
        if count > 0 { return .partial }
        return .missed
    }

    private func routeFor(day: Int) -> Day {
        if day == programDay { return .today }
        if day > programDay { return .locked(day: day) }
        return .past(day: day)
    }
}

// MARK: - ProgramDayCell
//
// One 42×56pt rounded-10 cell. Pure render — no logic, no state.
// Hit target padded to 44pt via accessibility-style frame.

struct ProgramDayCell: View {

    let day: Int                  // 1-indexed; 0 only for .newProgram
    let state: State
    let onTap: () -> Void

    enum State {
        case today
        case completed
        case partial
        case missed
        case locked
        case newProgram
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var background: some View {
        switch state {
        case .today:
            RoundedRectangle(cornerRadius: 10)
                .fill(Palette.cocoaPrimary)
        case .completed:
            RoundedRectangle(cornerRadius: 10)
                .fill(Palette.programCard)
        case .newProgram:
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Palette.cocoaTertiary, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        case .partial, .missed, .locked:
            Color.clear
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .today:
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.custom("DMSans-SemiBold", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textInverse)
                    .monospacedDigit()
                Circle()
                    .fill(Palette.textInverse)
                    .frame(width: 4, height: 4)
            }
        case .completed:
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Palette.stateGood)
            }
        case .partial:
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                Circle()
                    .fill(Palette.cocoaTertiary)
                    .frame(width: 5, height: 5)
            }
        case .missed:
            Text("\(day)")
                .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                .foregroundStyle(Palette.cocoaTertiary)
                .monospacedDigit()
        case .locked:
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .monospacedDigit()
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        case .newProgram:
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Palette.cocoaSecondary)
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .today:        return "Day \(day), today"
        case .completed:    return "Day \(day), completed"
        case .partial:      return "Day \(day), partial"
        case .missed:       return "Day \(day), missed"
        case .locked:       return "Day \(day), locked"
        case .newProgram:   return "Start a new program"
        }
    }
}
