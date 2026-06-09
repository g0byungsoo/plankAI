import SwiftUI

// MARK: - PlanRow (v4 — retention pattern locked 2026-06-09)
//
// v1.1 program pivot. Per [[feedback-no-checkbox-circle]]:
//   - NO tappable checkbox circle on PlanView rows
//   - Row body tap → enters the module
//   - State indicator (right edge) is render-only — dot when empty,
//     check when complete, sparkle when auto-fired
//   - Long-press on row → presents MarkAsDoneSheet for manual override
//     (the offline-walk / read-on-partner's-phone escape hatch)
//   - Steps stays as a progress row (64pt × 3pt bar + numeric label,
//     no state indicator)
//
// Anatomy (binary rows):
//   [ ProgramStickyNote 40×40 ] [ title + subtitle ] [ state indicator ]
//          leading 20pt           flex, 16pt gap        20pt trailing
//
// Anatomy (progress rows — steps, water):
//   [ ProgramStickyNote 40×40 ] [ title + subtitle ] [ "4,820 / 7,500" + bar ]
//          leading 20pt           flex, 16pt gap        20pt trailing
//
// Founder rules:
//   - Anti-shame voice: no "complete" verb, no strikethrough on title
//   - No em-dashes between words
//   - Long-press sheet copy lives in MarkAsDoneSheet, not here

struct PlanRow: View {

    let prescription: ProgramDayPrescription
    let state: RowState
    let onTap: () -> Void
    let onLongPress: () -> Void

    enum RowState {
        /// Binary row, not yet complete.
        case binaryEmpty
        /// Binary row, complete. `isAuto` = telemetry-fired (sparkle shown);
        /// false = user-marked via long-press.
        case binaryComplete(isAuto: Bool)
        /// Progress row (steps, water). Renders bar + numeric label.
        case progress(current: Int, target: Int, unit: String)
        /// User skipped (Phase 2).
        case skipped
        /// Engine says no module today (Phase 2).
        case restDay

        var isInteractive: Bool {
            switch self {
            case .restDay: return false
            default:       return true
            }
        }

        var isCompleted: Bool {
            switch self {
            case .binaryComplete:                              return true
            case .progress(let c, let t, _) where c >= t:      return true
            default:                                           return false
            }
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ProgramStickyNote(prescription: prescription)

            VStack(alignment: .leading, spacing: 3) {
                Text(prescription.rowTitle)
                    .font(Typo.body)
                    .foregroundStyle(titleColor)
                Text(subtitleCopy)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            guard state.isInteractive else { return }
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            guard state.isInteractive else { return }
            guard canLongPress else { return }
            onLongPress()
        }
        .opacity(state.isInteractive ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    // MARK: - Title + subtitle

    private var titleColor: Color {
        switch state {
        case .skipped, .restDay: return Palette.cocoaTertiary
        default:                 return Palette.cocoaPrimary
        }
    }

    private var subtitleCopy: String {
        switch state {
        case .binaryEmpty:
            return prescription.rowSubtitle
        case .binaryComplete:
            return prescription.rowSubtitle
        case .progress(let current, let target, let unit):
            // Subtitle carries the context line; numeric goes trailing.
            // For steps: "your daily walk". For water: "small sips throughout the day".
            if unit.isEmpty {
                return progressContextCopy
            }
            return progressContextCopy
        case .skipped:
            return "skipped today"
        case .restDay:
            return "rest day"
        }
    }

    private var progressContextCopy: String {
        switch prescription {
        case .steps:
            return "your daily walk"
        case .water:
            return "small sips throughout the day"
        default:
            return prescription.rowSubtitle
        }
    }

    /// Long-press override only applies to binary rows. Progress rows
    /// don't accept manual override (HealthKit is canonical for steps;
    /// water is multi-tap by design).
    private var canLongPress: Bool {
        switch state {
        case .binaryEmpty:    return true
        default:              return false
        }
    }

    // MARK: - Trailing

    @ViewBuilder private var trailing: some View {
        switch state {
        case .binaryEmpty:
            stateIndicatorEmpty
        case .binaryComplete(let isAuto):
            stateIndicatorComplete(isAuto: isAuto)
        case .progress(let current, let target, let unit):
            progressTrailing(current: current, target: target, unit: unit)
        case .skipped, .restDay:
            Text("—")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Palette.cocoaTertiary)
                .frame(width: 26)
        }
    }

    /// 6pt cocoa-tertiary dot. NOT a tappable circle (the chrome that
    /// reads as "chore list" — founder ruled it out 2026-06-09).
    private var stateIndicatorEmpty: some View {
        Circle()
            .fill(Palette.cocoaTertiary)
            .frame(width: 6, height: 6)
            .frame(width: 26, height: 26, alignment: .center)
            .accessibilityHidden(true)
    }

    /// 14pt sage check. Sparkle (8pt) when telemetry-fired.
    private func stateIndicatorComplete(isAuto: Bool) -> some View {
        HStack(spacing: 4) {
            if isAuto {
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.stateGood)
        }
        .accessibilityHidden(true)
    }

    /// Progress row (steps, water). Numeric label + 64pt × 3pt bar +
    /// sparkle when 100%. Per [[feedback-no-checkbox-circle]] §progress.
    private func progressTrailing(current: Int, target: Int, unit: String) -> some View {
        let isComplete = current >= target
        let fraction = target > 0 ? min(1.0, max(0.0, Double(current) / Double(target))) : 0.0
        let label = unit.isEmpty
            ? "\(current.formatted(.number.grouping(.automatic))) / \(target.formatted(.number.grouping(.automatic)))"
            : "\(current) / \(target) \(unit)"

        return HStack(spacing: 8) {
            if isComplete {
                (
                    Text("reached")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
                        .foregroundStyle(Palette.cocoaSecondary)
                    +
                    Text(" · \(target.formatted(.number.grouping(.automatic)))")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                )
            } else {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .monospacedDigit()
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.hairlineCocoa)
                    .frame(width: 64, height: 3)
                Capsule()
                    .fill(Palette.stateGood)
                    .frame(width: 64 * CGFloat(fraction), height: 3)
            }
            if isComplete {
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Accessibility

    private var a11yLabel: String {
        let stateLabel: String = {
            switch state {
            case .binaryEmpty:
                return "not done"
            case .binaryComplete(let isAuto):
                return isAuto ? "done, automatic" : "done"
            case .progress(let c, let t, let unit):
                let unitLabel = unit.isEmpty ? "" : " \(unit)"
                return "\(c) of \(t)\(unitLabel)"
            case .skipped:
                return "skipped"
            case .restDay:
                return "rest day"
            }
        }()
        return "\(prescription.rowTitle). \(subtitleCopy). \(stateLabel)."
    }

    private var a11yHint: String {
        switch state {
        case .binaryEmpty:
            return "Tap to begin. Long-press to mark done."
        case .binaryComplete:
            return "Tap to re-open."
        case .progress:
            return "Tap to see today's detail."
        case .skipped, .restDay:
            return ""
        }
    }
}

// MARK: - ProgramStickyNote (v4 — type-keyed, 40pt, SF glyph)
//
// The Her75 paper-square row marker. 40×40pt rounded-5pt, type-glyph
// centered (replaces the v3 integer numeral), pastel fill keyed by
// row TYPE (lesson always mint, snap always butter, etc.) for cohort
// recognition. ±1.5° alternating rotation by type's natural order.
// The ONE craft signal per program screen.

struct ProgramStickyNote: View {

    let prescription: ProgramDayPrescription

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(stickyColor)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
            Image(systemName: prescription.stickyGlyph)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.cocoaPrimary)
        }
        .accessibilityHidden(true)
    }

    private var stickyColor: Color {
        switch prescription.stickyColorKind {
        case .mint:   return Palette.stickyMint
        case .butter: return Palette.stickyButter
        case .rose:   return Palette.stickyRose
        case .olive:  return Palette.stickyOlive
        }
    }

    /// Alternating rotation by type order — gives 5 stacked stickies
    /// a hand-cut variation without each one needing a per-instance
    /// random seed. Deterministic.
    private var rotation: Double {
        switch prescription {
        case .lesson, .workout, .breath, .water:
            return -1.5
        case .snapMeal, .steps, .weighIn, .measurements, .plank:
            return 1.5
        }
    }
}
