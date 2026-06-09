import SwiftUI

// MARK: - PlanRow (v2 per UX spec §3)
//
// v1.1 program pivot — PlanView redesign. Module-bound checklist row
// adopting BetterMe's dual-affordance mechanic (chevron enters
// module, checkbox marks complete) on her75's clean chrome
// (ProgramStickyNote + no thumbnail).
//
// Anatomy (left → right):
//   [ ProgramStickyNote 56×56 ] [ title + subtitle V-stack ] [ chevron ] [ checkbox ]
//          leading 20pt          flex, gap-16pt              8pt gap     20pt trailing
//
// Tap zones:
//   - row content (sticky + text region) → enters module via `onEnter`
//   - checkbox tap → toggles complete via `onCheckToggle`
//   - chevron is purely visual (its hit area is folded into the row tap)
//
// State visuals (UX spec §3, locked 2026-06-09):
//   .empty         — empty circle, chevron visible, both taps active
//   .inProgress    — half-circle (dotted) checkbox, progress in subtitle
//   .completeUser  — filled green check, chevron stays (re-entry allowed)
//   .completeAuto  — filled green check + 8pt SPARKLE inline, NO chevron,
//                    row & checkbox non-interactive
//   .skipped       — em-dash glyph, 50% opacity, no chevron (Phase 2)
//   .restDay       — em-dash glyph, 50% opacity, "rest day" subtitle (Phase 2)
//
// NO STRIKETHROUGH on completed titles. Anti-shame voice rule:
// strikethrough on "weigh-in" reads as crossing-off-the-scale.

struct PlanRow: View {

    let index: Int
    let prescription: ProgramDayPrescription
    let state: RowState
    let onEnter: () -> Void
    let onCheckToggle: () -> Void

    enum RowState {
        case empty
        case inProgress(currentValue: String?)   // e.g. "4,820 of 7,500"
        case completeUser(completedAt: String?)  // e.g. "logged at 9:42a"
        case completeAuto
        case skipped
        case restDay

        var isCompleted: Bool {
            switch self {
            case .completeUser, .completeAuto: return true
            default: return false
            }
        }

        var isAuto: Bool {
            if case .completeAuto = self { return true }
            return false
        }

        var hidesChevron: Bool {
            switch self {
            case .completeAuto, .skipped, .restDay: return true
            default: return false
            }
        }

        var rowIsInteractive: Bool {
            switch self {
            case .restDay: return false
            default: return true
            }
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Leading: row tap zone covers the sticky + center text.
            // We put both inside a Button with .plain style so the tap
            // is precise to this region — checkbox sits OUTSIDE this
            // button so its tap doesn't propagate to row enter.
            Button(action: {
                guard state.rowIsInteractive else { return }
                onEnter()
            }) {
                HStack(spacing: 16) {
                    ProgramStickyNote(index: index)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prescription.rowTitle)
                            .font(Typo.body)
                            .foregroundStyle(titleColor)
                        Text(subtitleCopy)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(state.rowIsInteractive ? 1.0 : 0.5)

            if !state.hidesChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.cocoaTertiary)
            }

            checkbox
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    private var titleColor: Color {
        switch state {
        case .skipped, .restDay: return Palette.cocoaTertiary
        default: return Palette.cocoaPrimary
        }
    }

    private var subtitleCopy: String {
        switch state {
        case .empty:
            return prescription.rowSubtitle
        case .inProgress(let current):
            return current ?? prescription.rowSubtitle
        case .completeUser(let completedAt):
            return completedAt ?? "done"
        case .completeAuto:
            // Show the row's natural subtitle (e.g. "7,500 of 7,500") + auto tag.
            return prescription.rowSubtitle + " · auto"
        case .skipped:
            return "skipped today"
        case .restDay:
            return "rest day"
        }
    }

    // MARK: - Checkbox

    @ViewBuilder private var checkbox: some View {
        Group {
            switch state {
            case .empty:
                Button(action: handleCheck) {
                    Circle()
                        .strokeBorder(Palette.cocoaTertiary, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            case .inProgress:
                Button(action: handleCheck) {
                    ZStack {
                        Circle()
                            .strokeBorder(Palette.cocoaTertiary, lineWidth: 1.5)
                            .frame(width: 26, height: 26)
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .stroke(Palette.cocoaSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(-90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            case .completeUser:
                Button(action: handleCheck) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Palette.stateGood)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            case .completeAuto:
                // Non-interactive — auto-completed by telemetry.
                // Sparkle glyph signals "system did this" (UX spec §6 innovation #2).
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Palette.stateGood)
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                }

            case .skipped, .restDay:
                Text("—")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .frame(width: 26, height: 26)
            }
        }
        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)  // HIG hit target
    }

    private func handleCheck() {
        Haptics.light()
        onCheckToggle()
    }

    // MARK: - Accessibility

    private var a11yLabel: String {
        let stateLabel: String = {
            switch state {
            case .empty: return "not complete"
            case .inProgress: return "in progress"
            case .completeUser: return "complete"
            case .completeAuto: return "complete, automatic"
            case .skipped: return "skipped"
            case .restDay: return "rest day"
            }
        }()
        return "\(prescription.rowTitle). \(subtitleCopy). \(stateLabel)."
    }

    private var a11yHint: String {
        switch state {
        case .empty, .inProgress: return "Tap row to enter; tap checkbox to mark complete"
        case .completeUser: return "Tap row to re-enter; tap checkbox to uncheck"
        case .completeAuto, .skipped, .restDay: return ""
        }
    }
}

// MARK: - ProgramStickyNote
//
// The Her75 paper-square row marker. 56×56pt rounded-6, italic
// Fraunces numeral, alternating -2/+2 rotation, cycled palette
// stickyMint/Butter/Rose/Olive by index. The ONE craft signal
// per program screen.

struct ProgramStickyNote: View {

    let index: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(stickyColor)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(index.isMultiple(of: 2) ? 2 : -2))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
            Text("\(index)")
                .font(Typo.stickyNumeral)
                .foregroundStyle(Palette.cocoaPrimary)
        }
        .accessibilityHidden(true)  // numeral position conveyed by row order
    }

    private var stickyColor: Color {
        switch (index - 1) % 4 {
        case 0: return Palette.stickyMint
        case 1: return Palette.stickyButter
        case 2: return Palette.stickyRose
        default: return Palette.stickyOlive
        }
    }
}
