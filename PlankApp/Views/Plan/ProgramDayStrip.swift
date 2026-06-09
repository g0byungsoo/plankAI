import SwiftUI

// MARK: - ProgramDayStrip
//
// v1.1 program pivot — PlanView redesign per UX spec §2.
// Horizontal day-pill strip rendered between hero and checklist.
//
// Design picks (locked in spec):
//   - 7-cell visible window (44pt × 56pt cells, 8pt gap)
//   - All plan.totalDays cells horizontally scrollable
//   - Snap behavior: .scrollTargetBehavior(.viewAligned) — cell-by-cell
//     scroll. Founder might want paging-by-7 later; revisit then.
//   - On first appear: scroll today into center
//   - Locked cells (future) show a small SF lock.fill at 48% cocoa
//     — wistful, not punitive (founder rule: lock as commitment
//     device, not shame trigger)
//   - The strip is OUTSIDE any card chrome — lives naked on the
//     pink scroll, like her75 rows do on cream
//
// Tap routing handled by PlanView via the onTap callback:
//   - today → no-op (haptic)
//   - past (completed/partial/missed) → swap PlanView to that day's snapshot
//   - locked → ProgramLockSheet
//   - +new program (post-goal) → next program picker / ChapterCompleteView

struct ProgramDayStrip: View {

    let programDay: Int          // user's current day (1-indexed)
    let totalDays: Int           // plan duration from ProgramPlanRecord
    let completionByDay: [Int: Int]  // programDay → count of completed rows (0-5)
    let onTap: (Day) -> Void

    enum Day: Equatable {
        case today
        case past(day: Int)
        case locked(day: Int)
        case newProgram   // post-goal: + cell after totalDays
    }

    @State private var didScrollToToday: Bool = false

    /// Threshold for "completed" — 3 of 5 rows. Below that = partial.
    /// 0 = missed. Tuned to feel forgiving (3/5 is half + 1).
    private static let completedThreshold: Int = 3

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(1...totalDays, id: \.self) { day in
                        ProgramDayCell(
                            day: day,
                            state: stateForCell(day: day),
                            onTap: { onTap(routeFor(day: day)) }
                        )
                        .id(day)
                    }
                    // Post-goal "+ new program" cell. Always rendered;
                    // tap routes to ChapterCompleteView via PlanView.
                    if programDay > totalDays {
                        ProgramDayCell(
                            day: 0,
                            state: .newProgram,
                            onTap: { onTap(.newProgram) }
                        )
                        .id(-1)  // sentinel
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Space.lg)
            }
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                guard !didScrollToToday else { return }
                // Scroll today into center on first appear. ScrollViewReader's
                // scrollTo(_:anchor:) animates by default; wrap with no
                // animation so we land instantly without a swoop that
                // competes with PlanView's modernEntrance.
                let anchor = min(max(programDay, 1), totalDays)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(anchor, anchor: .center)
                    didScrollToToday = true
                }
            }
        }
        .frame(height: 56)
    }

    private func stateForCell(day: Int) -> ProgramDayCell.State {
        if day == programDay { return .today }
        if day > programDay { return .locked }
        // past day: derive completion state from the dict
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
// One 44×56pt rounded-10 cell. Pure render — no logic, no state.

struct ProgramDayCell: View {

    let day: Int                  // 1-indexed; 0 only for .newProgram
    let state: State
    let onTap: () -> Void

    enum State {
        case today
        case completed   // past, ≥3 of 5 rows done
        case partial     // past, 1–2 of 5 done
        case missed      // past, 0 done
        case locked      // future
        case newProgram  // post-goal "+ new program" cell
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                content
            }
            .frame(width: 44, height: 56)
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
