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

    /// Live data overrides for rows that derive their subtitle from
    /// telemetry rather than the prescription's static rowSubtitle.
    /// Specifically: snap meal pulls today's calorie total from
    /// FoodLogPersister via this param when non-nil. Defaults to nil
    /// so non-snap rows keep their prescription-driven copy.
    var liveCaloriesToday: Int? = nil
    var liveMealsLoggedToday: Int? = nil

    // v6 fat-row embed data — flows down from PlanView. nil for
    // non-fat rows. v6 simplified the steps + move embeds; no more
    // hourly chart, no more mini-tiles.
    var stepsCurrent: Int = 0
    var stepsTarget: Int = 7500
    var snapMealProteinG: Int = 0
    var snapMealCarbsG: Int = 0
    var snapMealFatG: Int = 0
    var moveExercises: [MoveExerciseEmbed.Exercise]? = nil

    /// v1.0.35 (2026-06-19) Home Phase 1 — true when this row is the
    /// day's archetype anchor (e.g. snapMeal on a protein day). Renders
    /// the 2pt × 32pt vertical hairline at the row's leading edge.
    var isAnchor: Bool = false
    /// Per Panel 2 her75: the 4 sticky pastels — passed by archetype.
    /// nil leaves the leading edge bare (balanced day or non-anchor).
    var anchorAccentColor: Color? = nil
    /// True when viewingDay is set in PlanView — the row is a past-day
    /// view. Drives typographic dim + "kept" trailing stamp + drops the
    /// sticky paper-square's lift shadow.
    var isPastDay: Bool = false
    /// Optional override subtitle (e.g. GLP-1 protein nudge "aim for
    /// 80g+ today ♡"). When set, replaces the default subtitle.
    var overrideSubtitle: String? = nil

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
        // v1.0.35 Home Phase 1 — past-day disabled chrome arrives via
        // typographic dim (title 0.55, drop sticky shadow), trailing
        // italic-Fraunces "kept"/"re-read" stamp instead of the sage
        // checkmark, and lesson-row exception that overrides the dim
        // and stays tappable.
        VStack(alignment: .leading, spacing: 10) {
            headerLine
            if prescription.isFatRow && !isPastDayDimmed {
                fatEmbed
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(anchorAccentBar, alignment: .leading)
        .contentShape(Rectangle())
        // v1.1.1 (2026-06-19) — instant press feedback via a Button
        // wrapper so scroll + tap arbitrate correctly. The Button
        // owns the tap dispatch; .onLongPressGesture attaches below
        // for the unmark gesture.
        .luxuryPressFeedback(enabled: isRowTappable) {
            guard isRowTappable else { return }
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            guard isRowTappable else { return }
            guard canLongPress else { return }
            onLongPress()
        }
        .opacity(rowOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    /// True when this row should accept user taps. Past-day rows are
    /// generally view-only, with the lesson exception (Panel 2 + 4:
    /// lessons are content, not behavior — always re-readable).
    private var isRowTappable: Bool {
        if isPastDay {
            return isLessonRow
        }
        return state.isInteractive
    }

    /// True when the past-day typographic dim applies (everything
    /// EXCEPT the lesson row, which keeps full alpha + shadow).
    private var isPastDayDimmed: Bool {
        isPastDay && !isLessonRow
    }

    private var isLessonRow: Bool {
        if case .lesson = prescription { return true }
        return false
    }

    /// Row-level opacity. 1.0 in normal use. Today's rest-day rows
    /// have the existing 0.5 dim. Past-day non-lesson rows get 1.0
    /// here so the chrome lift stays consistent — the *typographic*
    /// dim (title color, subtitle color, dropped sticky shadow) does
    /// the disabled work, not a blanket .opacity (Panel 2: blanket
    /// opacity reads as "out of focus" and kills the brand mark).
    private var rowOpacity: Double {
        if isPastDay { return 1.0 }
        return state.isInteractive ? 1.0 : 0.5
    }

    /// 2pt × 32pt vertical hairline at the leading edge when this
    /// row is the day's archetype anchor. Color comes from the
    /// archetype's sticky pastel. Inset 4pt from the row's left edge
    /// so it sits inside the card chrome, between the wall and the
    /// sticky note's leading edge.
    @ViewBuilder private var anchorAccentBar: some View {
        if isAnchor, let color = anchorAccentColor, !isPastDay {
            Capsule()
                .fill(color)
                .frame(width: 2, height: 32)
                .padding(.leading, 4)
                .accessibilityHidden(true)
        }
    }

    /// Header line: sticky + title + subtitle + trailing. Identical
    /// composition for compact and fat rows — fat rows just add the
    /// embed underneath.
    private var headerLine: some View {
        HStack(spacing: 16) {
            ProgramStickyNote(prescription: prescription, dropShadow: isPastDayDimmed)

            VStack(alignment: .leading, spacing: 3) {
                Text(prescription.rowTitle)
                    .font(Typo.body)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Text(subtitleCopy)
                    .font(Typo.caption)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
    }

    /// Fat-row embed area — picks the right mini-component per row
    /// type. Indented 56pt (sticky + 16pt gap) so it lines up with
    /// the title column for single-column visual cohesion.
    @ViewBuilder private var fatEmbed: some View {
        switch prescription {
        case .steps:
            StepsProgressEmbed(
                current: stepsCurrent,
                target: stepsTarget
            )
            .padding(.leading, 56)
            .padding(.trailing, 4)

        case .snapMeal:
            SnapMealEmbed(
                kcal: liveCaloriesToday ?? 0,
                proteinG: snapMealProteinG,
                carbsG: snapMealCarbsG,
                fatG: snapMealFatG
            )
            .padding(.leading, 56)
            .padding(.trailing, 4)

        case .workout:
            MoveExerciseEmbed(
                exercises: moveExercises ?? MoveExerciseEmbed.placeholder
            )
            .padding(.leading, 56)
            .padding(.trailing, 4)

        default:
            EmptyView()
        }
    }

    // Progress underbar removed 2026-06-09 per founder QA: the 2pt
    // full-width sage line broke the card's 0.5pt indented-hairline
    // divider rhythm and read as a "double-line glitch" stacked
    // above the row divider below. The trailing numeric label
    // ("4,820 / 7,500" → "*reached* · 7,500" at 100%) carries the
    // progress information on its own; her75's reference register
    // ships no progress bars at all.

    // MARK: - Title + subtitle

    private var titleColor: Color {
        // Past-day disabled chrome: title to cocoaPrimary @ 55% per
        // Panel 2. Lesson row stays at full primary even in past mode
        // (the contrast against the dimmed siblings is the "this one
        // is still alive" signal).
        if isPastDayDimmed { return Palette.cocoaPrimary.opacity(0.55) }
        switch state {
        case .skipped, .restDay: return Palette.cocoaTertiary
        default:                 return Palette.cocoaPrimary
        }
    }

    private var subtitleColor: Color {
        // Subtitle drops one tier on past-day non-lesson rows. Lesson
        // row keeps cocoaSecondary so the row reads as full-tone.
        if isPastDayDimmed { return Palette.cocoaTertiary }
        return Palette.cocoaSecondary
    }

    private var subtitleCopy: String {
        // Cohort-routed override (e.g. GLP-1 protein nudge) takes
        // priority when set.
        if let override = overrideSubtitle, !override.isEmpty {
            return override
        }
        // Live override: snap meal shows today's calorie total when
        // FoodLogPersister has any meals logged. Falls back to the
        // prescription's static "one photo · we read the plate".
        if case .snapMeal = prescription {
            if let kcal = liveCaloriesToday, kcal > 0 {
                let count = max(1, liveMealsLoggedToday ?? 1)
                return count == 1 ? "1 plate today" : "\(count) plates today"
            }
        }

        switch state {
        case .binaryEmpty:
            return prescription.rowSubtitle
        case .binaryComplete:
            return prescription.rowSubtitle
        case .progress:
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

    /// Long-press fires on any binary row state (empty → mark-as-done
    /// sheet, complete → unmark). Progress rows don't accept long-
    /// press (HealthKit is canonical for steps; water is multi-tap).
    private var canLongPress: Bool {
        switch state {
        case .binaryEmpty, .binaryComplete:  return true
        default:                              return false
        }
    }

    // MARK: - Trailing

    @ViewBuilder private var trailing: some View {
        // Past-day trailing replaces the normal state indicator with
        // a quiet italic-Fraunces stamp:
        //   • Lesson row → "re-read ♥" (full cocoaSecondary, accent
        //     heart) — Panel 2's locked exception
        //   • Other completed rows → "kept" (cocoaTertiary, no heart)
        //   • Other incomplete rows → no stamp (the absence IS the
        //     anti-shame answer — never "missed")
        if isPastDay {
            pastDayStamp
        } else {
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
    }

    @ViewBuilder private var pastDayStamp: some View {
        if isLessonRow {
            (Text("re-read ")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
            + Text("\u{2665}\u{FE0E}")
                .font(.system(size: 11, weight: .medium)))
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize()
        } else if state.isCompleted {
            Text("kept")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize()
        } else {
            // Empty past-day non-completed: the absence is the answer.
            Color.clear.frame(width: 26, height: 26)
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

    /// 22pt filled sage circle with white check inside. OS-standard
    /// "completed" badge — obvious at a glance. Founder QA 2026-06-09:
    /// the prior bare 14pt check glyph read as a tick mark, not a
    /// DONE state. We avoid the empty-circle chore-list register by
    /// keeping the EMPTY state minimal (6pt dot); only the COMPLETE
    /// state gets the substantial badge.
    private func stateIndicatorComplete(isAuto: Bool) -> some View {
        HStack(spacing: 4) {
            if isAuto {
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.stateGood)
        }
        .accessibilityHidden(true)
    }

    /// Progress row trailing — JUST the numeric label + sparkle when
    /// 100%. The bar moved UNDER the row content (BetterMe pattern,
    /// see progressUnderbar above). Avoids cramming a bar into the
    /// trailing region which forced the title + label to wrap.
    private func progressTrailing(current: Int, target: Int, unit: String) -> some View {
        let isComplete = current >= target
        let label = unit.isEmpty
            ? "\(current.formatted(.number.grouping(.automatic))) / \(target.formatted(.number.grouping(.automatic)))"
            : "\(current) / \(target) \(unit)"

        return HStack(spacing: 4) {
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
                .lineLimit(1)
                .fixedSize()
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
            } else {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
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
        // Phase 1 (modules unwired): tap + long-press both open the
        // MarkAsDoneSheet for binary rows. Phase 1.B will swap tap
        // to route to the actual module player.
        switch state {
        case .binaryEmpty:
            return "Tap to mark done."
        case .binaryComplete:
            return ""
        case .progress:
            return ""
        case .skipped, .restDay:
            return ""
        }
    }
}

// MARK: - ProgramStickyNote (v8 — sticker over pastel paper)
//
// The Her75 paper-square row marker. 40×40pt rounded-5pt, pastel fill
// keyed by row TYPE (lesson always mint, snap always butter, etc.) for
// cohort recognition. ±1.5° alternating rotation by type's natural
// order. The ONE craft signal per program screen.
//
// v8 (2026-06-09, founder direction): the centered glyph is a JeniFit
// iridescent sticker (gummy-bear-vibe scrapbook pack) when the row has
// one. Rows without a sticker (plank / weigh-in / measurements) fall
// back to the v4 cocoa SF symbol so the row never goes blank.

struct ProgramStickyNote: View {

    let prescription: ProgramDayPrescription
    /// v1.0.35 (2026-06-19) — drops the 3pt lift shadow so the
    /// sticky reads as "pressed flat into the page" (her75 Panel 2
    /// past-day pattern). Sticker saturation unchanged.
    var dropShadow: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(stickyColor)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))
                .shadow(
                    color: Color.black.opacity(dropShadow ? 0 : 0.06),
                    radius: dropShadow ? 0 : 3,
                    x: 0,
                    y: dropShadow ? 0 : 1
                )
            if let asset = prescription.stickerAsset {
                // Sticker centered slightly larger than the SF glyph (32pt
                // vs 16pt) so the iridescent silhouette reads from across
                // the row. Counter-rotated so the sticker itself stays
                // visually upright while the paper square keeps its
                // hand-cut tilt.
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-rotation))
            } else {
                Image(systemName: prescription.stickyGlyph)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.cocoaPrimary)
            }
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
