import SwiftUI

// MARK: - The story grammar (app v5 re-steer, 00_DIRECTION.md §6)
//
// Becoming is a horizontally swipeable insight story: one page, one
// idea, one large visual — jeni walking her through her own body
// and plan. These are the story's shared pieces: the page scaffold,
// the page dots, the two big day-rhythm visuals, and the her-weeks
// timeline that keeps plan history one level in.

// MARK: - JKStoryPage

/// One story page: eyebrow → serif insight headline → large visual →
/// caption → quiet doors. The rhythm is identical page to page; the
/// content is the only thing that changes.
struct JKStoryPage<Visual: View, Doors: View>: View {
    let eyebrow: String
    let headline: String
    var headlineItalic: [String] = []
    var caption: String? = nil
    @ViewBuilder var visual: () -> Visual
    @ViewBuilder var doors: () -> Doors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            ItalicAccentText(
                headline,
                italic: headlineItalic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title),
                italicFont: .custom("JeniHeroSerif-Italic", size: 30, relativeTo: .title),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .lineSpacing(-2)
            .padding(.top, 12)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Space.lg)

            visual()
                .frame(maxWidth: .infinity)

            Spacer(minLength: Space.lg)

            if let caption {
                Text(caption)
                    .font(Typo.caption)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.sm)
            }

            doors()
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
    }
}

// MARK: - JKPageDots

/// The story's position — quiet dots, cocoa where she stands.
struct JKPageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index
                          ? Palette.cocoaPrimary
                          : Palette.cocoaTertiary.opacity(0.28))
                    .frame(width: i == index ? 6 : 5,
                           height: i == index ? 6 : 5)
                    .animation(Motion.entranceSoft, value: index)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("page \(index + 1) of \(count)")
    }
}

// MARK: - JKWeekDotsVisual

/// The week as seven large day marks with weekday letters — the
/// plan page's hero. Same ink caste as JKStandingDots, at stage
/// size: solid kept, half-tone partial, faint quiet, dotted future,
/// a moon for held days; today largest.
struct JKWeekDotsVisual: View {
    let days: [JKStandingDots.Day]
    /// Weekday letter per day, same order ("f", "s", "s", "m"…).
    let letters: [String]
    /// v5 pager choreography: cells cascade in on page arrival.
    var armed: Bool = true

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                VStack(spacing: 10) {
                    Text(idx < letters.count ? letters[idx] : "")
                        .font(.custom(day.isToday ? "DMSans-SemiBold" : "DMSans-Medium",
                                      size: 11, relativeTo: .caption2))
                        .kerning(0.66)
                        .foregroundStyle(day.isToday ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                    mark(day)
                        .frame(height: 18)
                }
                .frame(maxWidth: .infinity)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 4)
                .animation(Motion.entranceSoft.delay(Double(idx) * 0.04), value: shown)
            }
        }
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else { disarm() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    private func arm() {
        if reduceMotion { shown = true; return }
        withAnimation { shown = true }
    }

    private func disarm() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { shown = false }
    }

    @ViewBuilder
    private func mark(_ day: JKStandingDots.Day) -> some View {
        if day.isPaused {
            JKMark(kind: .moon, size: 12, color: Palette.cocoaTertiary)
        } else if day.isFuture {
            Circle()
                .strokeBorder(
                    Palette.hairlineCocoa,
                    style: StrokeStyle(lineWidth: 1.2, dash: [2, 2.6])
                )
                .frame(width: 13, height: 13)
        } else {
            switch day.standing {
            case .kept:
                Circle()
                    .fill(Palette.cocoaPrimary)
                    .frame(width: day.isToday ? 16 : 13, height: day.isToday ? 16 : 13)
            case .partial:
                Circle()
                    .fill(Palette.cocoaSecondary.opacity(0.55))
                    .frame(width: day.isToday ? 14 : 11, height: day.isToday ? 14 : 11)
            case .quiet:
                Circle()
                    .fill(day.isToday ? Palette.cocoaSecondary.opacity(0.6)
                                      : Palette.cocoaTertiary.opacity(0.35))
                    .frame(width: day.isToday ? 11 : 7, height: day.isToday ? 11 : 7)
            }
        }
    }

    private var a11y: String {
        let kept = days.filter { !$0.isFuture && !$0.isPaused && $0.standing == .kept }.count
        return kept == 1 ? "one day kept this week" : "\(kept) days kept this week"
    }
}

// MARK: - JKStepsRhythmVisual

/// The movement page's hero: today's count as the numeral, the week
/// as seven rhythm marks (goal solid, real-walk ring, quiet dash) —
/// rhythm, never magnitude bars.
struct JKStepsRhythmVisual: View {
    let todayCount: Int
    let weeklyCounts: [Int]
    let goal: Int
    /// Weekday letters under the marks (oldest → today). Optional so
    /// legacy callers stay letter-free.
    var letters: [String] = []
    /// v5 pager choreography: dots cascade in on page arrival.
    var armed: Bool = true

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Space.lg) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(todayCount.formatted())
                    .font(.custom("JeniHeroSerif-Regular", size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("today")
                    .font(.custom("JeniHeroSerif-Italic", size: 20, relativeTo: .title3))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(4)
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 5)
            .animation(Motion.entranceSoft, value: shown)

            HStack(spacing: 16) {
                ForEach(Array(weeklyCounts.enumerated()), id: \.offset) { idx, count in
                    VStack(spacing: 8) {
                        Group {
                            if count >= goal {
                                Circle()
                                    .fill(Palette.cocoaPrimary)
                                    .frame(width: 12, height: 12)
                            } else if count >= goal / 2 {
                                Circle()
                                    .strokeBorder(Palette.cocoaSecondary, lineWidth: 1.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Capsule()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(width: 12, height: 2.5)
                            }
                        }
                        .frame(height: 12)
                        if idx < letters.count {
                            Text(letters[idx])
                                .font(.custom("DMSans-Medium", size: 10, relativeTo: .caption2))
                                .kerning(0.66)
                                .foregroundStyle(idx == weeklyCounts.count - 1
                                                 ? Palette.cocoaPrimary
                                                 : Palette.cocoaTertiary)
                        }
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 4)
                    .animation(Motion.entranceSoft.delay(0.08 + Double(idx) * 0.04), value: shown)
                }
            }
        }
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else { disarm() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(todayCount) steps today")
    }

    private func arm() {
        if reduceMotion { shown = true; return }
        withAnimation { shown = true }
    }

    private func disarm() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { shown = false }
    }
}

// MARK: - JKProteinWeekBand

/// Seven quiet marks under the food page's arc — which days the
/// floor landed. Solid = landed, ring = plates seen, dash = quiet.
struct JKProteinWeekBand: View {
    /// (proteinG, hadPlates) per day, oldest → newest, 7 entries.
    let days: [(proteinG: Double, hadPlates: Bool)]
    let targetG: Int?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Group {
                    if let target = targetG, day.proteinG >= Double(target) {
                        Circle()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 8, height: 8)
                    } else if day.hadPlates {
                        Circle()
                            .strokeBorder(Palette.cocoaSecondary, lineWidth: 1.2)
                            .frame(width: 8, height: 8)
                    } else {
                        Capsule()
                            .fill(Palette.hairlineCocoa)
                            .frame(width: 8, height: 2)
                    }
                }
                .frame(height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - JourneyTimelineView (her weeks)

/// Plan history, one level in: this week's receipt, past weeks as
/// receipt cards with quiet seams, the future's shape at the foot.
/// The story stays up front; the record is here when she wants it.
struct JourneyTimelineView: View {
    let journey: JourneyModel
    let onOpenWeek: (JourneyModel.WeekEntry) -> Void
    let onDismiss: () -> Void

    var body: some View {
        JKScreenChrome {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Text("her weeks")
                            .font(.custom("JeniHeroSerif-Italic", size: 28, relativeTo: .title2))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer(minLength: 8)
                        JKQuietMark(systemName: "xmark", accessibilityLabel: "close") {
                            onDismiss()
                        }
                    }
                    .padding(.top, Space.hero)

                    Text("every week, kept as a receipt")
                        .font(Typo.captionTracked)
                        .kerning(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.top, 4)

                    VStack(spacing: Space.md) {
                        if let current = journey.currentWeek {
                            JKWeekCard(
                                entry: current,
                                isCurrent: true,
                                onOpen: { onOpenWeek(current) }
                            )
                        }
                        ForEach(journey.pastWeeks) { entry in
                            if entry.slice.elapsedDays.isEmpty
                                || (entry.slice.keptCount == 0
                                    && entry.slice.plateCount == 0
                                    && entry.slice.weighCount == 0
                                    && entry.record == nil) {
                                JKQuietSeam(line: "week \(entry.weekIndex) passed quietly")
                                    .padding(.vertical, 2)
                            } else {
                                JKWeekCard(
                                    entry: entry,
                                    isCurrent: false,
                                    onOpen: { onOpenWeek(entry) }
                                )
                            }
                        }
                        if journey.earlierWeekCount > 0 {
                            JKQuietSeam(line: "\(journey.earlierWeekCount) earlier \(journey.earlierWeekCount == 1 ? "week" : "weeks")")
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.top, Space.lg)

                    if let name = journey.nextWeekName,
                       let shape = journey.nextWeekShape {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text("ahead")
                                .font(Typo.captionTracked)
                                .kerning(1.98)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                            JKFutureShapeCard(name: name, shapeLine: shape)
                        }
                        .padding(.top, Space.section)
                    }

                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.lg)
            }
            .scrollIndicators(.hidden)
        }
    }
}
