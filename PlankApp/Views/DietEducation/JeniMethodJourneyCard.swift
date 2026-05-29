import SwiftUI

/// Horizontal pager over the 14-day JeniFit Method arc, used as the home
/// hero when a lesson is due. Today's lesson is the focused page; swipe
/// right for completed lessons (re-readable), left for upcoming ones
/// (a readable glimpse, but locked until she shows up).
///
/// Engagement-gated: a day past `currentDay` is locked — and `currentDay`
/// only advances when she completes a session, so the lock is honest
/// ("show up today to unlock"), never an arbitrary gate.
///
/// Restrained register per the clean/luxury bar: one card at a time, a
/// thin progress line (not 14 dots), soft lock chrome — a glimpse of the
/// journey, not a gamified path map.
struct JeniMethodJourneyCard: View {
    /// The active engagement day (clamped to the 1...14 arc).
    let currentDay: Int
    /// Open a lesson. `isReread` is true for a completed (past) lesson, so
    /// the caller routes it through the no-progress re-read path instead of
    /// the live workout-handoff path.
    let onOpen: (LessonID, _ isReread: Bool) -> Void

    @State private var selection: Int
    private let days = Array(1...14)
    private let cardHeight: CGFloat = 188
    private let illustrationSize: CGFloat = 70

    init(currentDay: Int, onOpen: @escaping (LessonID, Bool) -> Void) {
        let clamped = min(max(currentDay, 1), 14)
        self.currentDay = clamped
        self.onOpen = onOpen
        _selection = State(initialValue: clamped)
    }

    private enum PageState { case past, today, locked }
    private func state(for day: Int) -> PageState {
        if day < currentDay { return .past }
        if day == currentDay { return .today }
        return .locked
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            TabView(selection: $selection) {
                ForEach(days, id: \.self) { day in
                    pageCard(day: day, lesson: LessonID(rawValue: day) ?? .day1)
                        .padding(.horizontal, Space.screenPadding)
                        .tag(day)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: cardHeight)
            .onChange(of: selection) { _, _ in Haptics.soft() }

            progressBar
                .padding(.horizontal, Space.screenPadding)
        }
    }

    // MARK: - Page

    @ViewBuilder
    private func pageCard(day: Int, lesson: LessonID) -> some View {
        let st = state(for: day)
        // No middle Spacer — content stacks as one block and the .frame
        // leading-center alignment (vertical) below distributes any extra
        // card space as balanced padding above + below, instead of a
        // single dead gap in the middle.
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 6) {
                Text("the jenifit method")
                    .font(Typo.eyebrow)
                    .foregroundStyle(Palette.textSecondary)
                Text("·")
                    .font(Typo.eyebrow)
                    .foregroundStyle(Palette.textSecondary.opacity(0.6))
                Text(st == .past ? "day \(day) · done" : "day \(day) of 14")
                    .font(Typo.eyebrow)
                    .foregroundStyle(st == .today ? Palette.accent : Palette.textSecondary)
            }

            Text(lesson.headline)
                .font(Typo.heading)
                .foregroundStyle(st == .locked ? Palette.textSecondary : Palette.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            // CTA / lock row on the left, illustration on the right —
            // baseline-aligned. The illustration sits fully inside the
            // card (no overhang, no edge clipping).
            HStack(alignment: .bottom) {
                footer(state: st, lesson: lesson)
                Spacer(minLength: Space.md)
                illustrationView(state: st, lesson: lesson)
            }
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(st == .locked ? Palette.bgElevated : Palette.accentSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(st == .locked ? Palette.accent.opacity(0.4) : Palette.accent, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Palette.bgInverse.opacity(st == .locked ? 0.06 : 0.15), radius: 0, x: 3, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(state: st, day: day, lesson: lesson))
    }

    /// Per-lesson illustration anchored bottom-right INSIDE the card (no
    /// overhang, no edge clipping). Asset comes from
    /// `LessonID.coverIllustration` — currently the existing ritual art as
    /// a placeholder; purpose-built card art (square, ~85pt-friendly
    /// framing) is on the to-generate list and can be swapped in by
    /// replacing the imageset contents or remapping the switch.
    /// Locked tiles blur + lock-seal in the Loewenstein info-gap idiom.
    @ViewBuilder
    private func illustrationView(state st: PageState, lesson: LessonID) -> some View {
        ZStack {
            Image(lesson.coverIllustration)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: illustrationSize, height: illustrationSize)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .blur(radius: st == .locked ? 6 : 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(st == .locked ? 0.10 : 0))
                )
            if st == .locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.opacity(0.9))
                    .padding(7)
                    .background(Circle().fill(Palette.bgElevated.opacity(0.95)))
            }
        }
        .frame(width: illustrationSize, height: illustrationSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func footer(state st: PageState, lesson: LessonID) -> some View {
        switch st {
        case .today:
            Button { onOpen(lesson, false) } label: {
                pill(text: "today's lesson", fill: Palette.bgInverse, fg: Palette.textInverse)
            }
            .buttonStyle(JourneyPressStyle())
            .accessibilityLabel("Open today's lesson: \(lesson.headline)")
        case .past:
            Button { onOpen(lesson, true) } label: {
                pill(text: "re-read", fill: Palette.accentSubtle, fg: Palette.accent, outlined: true)
            }
            .buttonStyle(JourneyPressStyle())
            .accessibilityLabel("Re-read this lesson: \(lesson.headline)")
        case .locked:
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("show up today to unlock")
                    .font(Typo.caption)
            }
            .foregroundStyle(Palette.textSecondary)
            .accessibilityHidden(true)
        }
    }

    private func pill(text: String, fill: Color, fg: Color, outlined: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(fill)
        .overlay(outlined ? Capsule().stroke(Palette.accent, lineWidth: 1.5) : nil)
        .clipShape(Capsule())
    }

    // MARK: - Progress line (thin, calm — not 14 dots)

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.divider).frame(height: 3)
                Capsule().fill(Palette.accent)
                    .frame(width: max(8, geo.size.width * CGFloat(selection) / 14), height: 3)
            }
        }
        .frame(height: 3)
        .animation(Motion.gentleSpring, value: selection)
        .accessibilityHidden(true)
    }

    private func accessibilityLabel(state st: PageState, day: Int, lesson: LessonID) -> String {
        switch st {
        case .today:  return "Day \(day) of 14, today. \(lesson.headline)"
        case .past:   return "Day \(day) of 14, completed. \(lesson.headline)"
        case .locked: return "Day \(day) of 14, locked. \(lesson.headline). Unlocks when you show up."
        }
    }
}

/// Gentle press feedback for the journey card pills — matches the restrained
/// motion register of the rest of home.
private struct JourneyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
