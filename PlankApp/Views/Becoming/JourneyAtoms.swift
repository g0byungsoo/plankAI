import SwiftUI

// MARK: - Journey atoms (app v4, docs/app_v4/02_JOURNEY.md)
//
// The week-chaptered ledger's pieces: standing dots (the ink caste —
// solid past, distinct today, faint quiet, dashed future), the week
// receipt card, the adaptation stamp, the quiet seam, the future
// shape card. Law: past renders what HAPPENED, never what didn't —
// quiet days take less ink, not an absence mark.

// MARK: - JKStandingDots

struct JKStandingDots: View {
    struct Day: Identifiable {
        let id: Int              // programDay
        let standing: DayStanding
        let isToday: Bool
        let isFuture: Bool
        let isPaused: Bool
    }

    let days: [Day]
    var spacing: CGFloat = 7

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(days) { day in
                dot(day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    @ViewBuilder
    private func dot(_ day: Day) -> some View {
        if day.isPaused {
            // A held place, not a hole.
            JKMark(kind: .moon, size: 7, color: Palette.cocoaTertiary)
                .frame(width: 9, height: 9)
        } else if day.isFuture {
            Circle()
                .strokeBorder(
                    Palette.hairlineCocoa,
                    style: StrokeStyle(lineWidth: 1, dash: [1.6, 2.2])
                )
                .frame(width: 8, height: 8)
        } else {
            switch day.standing {
            case .kept:
                Circle()
                    .fill(day.isToday ? Palette.cocoaPrimary : Palette.cocoaSecondary)
                    .frame(width: day.isToday ? 9 : 8, height: day.isToday ? 9 : 8)
            case .partial:
                Circle()
                    .fill(Palette.cocoaSecondary.opacity(0.55))
                    .frame(width: 7, height: 7)
            case .quiet:
                // Less ink, never an absence mark.
                Circle()
                    .fill(day.isToday ? Palette.cocoaSecondary.opacity(0.6)
                                      : Palette.cocoaTertiary.opacity(0.35))
                    .frame(width: day.isToday ? 6.5 : 4, height: day.isToday ? 6.5 : 4)
            }
        }
    }

    private var a11y: String {
        let kept = days.filter { !$0.isFuture && !$0.isPaused && $0.standing == .kept }.count
        return kept == 1 ? "one day kept this week" : "\(kept) days kept this week"
    }
}

// MARK: - JKWeekCard

/// One week of the ledger — a receipt of what happened. Current
/// weeks lead with the intent (the week is still being written);
/// past weeks lead with the story (it's been written).
struct JKWeekCard: View {
    let entry: JourneyModel.WeekEntry
    let isCurrent: Bool
    let onOpen: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.name)
                        .font(.custom("JeniHeroSerif-Regular", size: isCurrent ? 21 : 17,
                                      relativeTo: isCurrent ? .title3 : .body))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text("week \(entry.weekIndex)")
                        .font(Typo.captionTracked)
                        .kerning(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                }

                if isCurrent, let intentLine = entry.intentLine {
                    Text(intentLine)
                        .font(Typo.caption)
                        .lineSpacing(2)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .center) {
                    JKStandingDots(days: entry.dotDays)
                    Spacer(minLength: 8)
                    // v5: the week's trend movement as the receipt's
                    // quiet total — neutral ink, a fact not a grade.
                    if let delta = entry.weightDeltaLine {
                        Text(delta)
                            .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                }
                .padding(.top, 2)

                Text(entry.story)
                    .font(Typo.caption)
                    .foregroundStyle(isCurrent ? Palette.cocoaSecondary : Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let stamp = entry.record {
                    VStack(alignment: .leading, spacing: 5) {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                            .padding(.top, 2)
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            JKMark(kind: .door, size: 11,
                                   color: Palette.accent)
                            (Text("signed · ")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.cocoaTertiary)
                            + Text(stamp.stampLine)
                                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13,
                                              relativeTo: .caption))
                                .foregroundStyle(Palette.cocoaSecondary))
                        }
                    }
                }
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(
                        isCurrent ? Palette.cocoaSecondary.opacity(0.28) : Palette.hairlineCocoa,
                        lineWidth: isCurrent ? 1 : 0.66
                    )
            )
            .shadow(color: .black.opacity(isCurrent ? 0.05 : 0.03),
                    radius: isCurrent ? 9 : 6, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(JKPress())
        .accessibilityIdentifier("journey.week.\(entry.weekIndex)")
        .accessibilityLabel("\(entry.name), week \(entry.weekIndex). \(entry.story)")
        .accessibilityHint("opens the week")
    }
}

// MARK: - JKQuietSeam

/// Stretches of quiet compress into one seam — absence absorbed,
/// never rendered day by day. Mission 3 (03_EDITORIAL.md §5): the
/// seam is a print day-break — centered small caps between SHORT
/// hairlines, air on both sides.
struct JKQuietSeam: View {
    let line: String

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Rectangle().fill(Palette.hairlineCocoa).frame(width: 26, height: 0.5)
            Text(line)
                .font(.custom("DMSans-Medium", size: 10.5, relativeTo: .caption2))
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize()
            Rectangle().fill(Palette.hairlineCocoa).frame(width: 26, height: 0.5)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line)
    }
}

// MARK: - JKFutureShapeCard

/// Next week, as SHAPE — dotted ink, a name, the week's rhythm in
/// one line. Never a locked list (the whole industry converged on
/// preview-or-nothing).
struct JKFutureShapeCard: View {
    let name: String
    let shapeLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                Spacer(minLength: 8)
                Text("next")
                    .font(Typo.captionTracked)
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Text(shapeLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(
                    Palette.cocoaTertiary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 4])
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - JKJourneyDoor

/// The archive doors under the ledger — quiet rows, one hairline.
struct JKJourneyDoor: View {
    let lead: String
    let punch: String
    let italic: [String]
    var showsRule: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 0) {
                if showsRule {
                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                }
                HStack(spacing: 6) {
                    Text(lead)
                        .font(Typo.captionTracked)
                        .kerning(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                    ItalicAccentText(
                        punch,
                        italic: italic,
                        baseFont: .custom("DMSans-Medium", size: 15, relativeTo: .body),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16, relativeTo: .body),
                        color: Palette.textPrimary,
                        alignment: .leading
                    )
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .padding(.vertical, 14)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(lead) \(punch)")
    }
}
