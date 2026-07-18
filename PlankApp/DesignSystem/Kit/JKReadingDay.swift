import SwiftUI
import Auth
import PlankFood
import PlankSync

// MARK: - JKReadingDay (app v3, docs/app_v3/02_DESIGN_LANGUAGE.md)
//
// The reading-first day's components: THE READING (jeni's morning
// note — the screen's hero), THE ONE THING (the single ask, the
// screen's only filled container), THE RHYTHM (hairline rows — the
// day's shape, present but never debt), and the BREAK card.
//
// Register: serif editorial + receipt grammar from onboarding v5.
// No at-rest circles, no locks, no counts. Completion stays her75:
// the strike IS the satisfaction.

// MARK: - JeniNoteView

/// THE NOTE — jeni's full reading as a RECEIVED moment (the minimal
/// correction, 06_MINIMAL_CORRECTION.md). Home carries only her
/// line; tapping it opens this full-screen letter: the dateline, the
/// sentences cascading in line by line with a soft haptic each (the
/// her75 reveal — the app's one cinematic gesture), the mechanism as
/// a caption, her signature, REPLY into the chat, and a quiet keep.
struct JeniNoteView: View {
    let brief: DailyBriefEngine.Brief
    /// Lowercase weekday for the dateline ("sunday").
    var dateline: String = ""
    let onReply: () -> Void
    let onClose: () -> Void

    @State private var tailSettled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        JKScreenChrome {
            VStack(alignment: .leading, spacing: 0) {
                // Dateline
                HStack(spacing: 10) {
                    Text("jeni")
                        .font(Typo.captionTracked)
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                    if !dateline.isEmpty {
                        Text(dateline)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                }
                .padding(.top, Space.hero + 24)

                // The letter — line by line, a breath apart.
                LineCascadeText(
                    lines: cascadeLines,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 28, relativeTo: .title),
                    color: Palette.textPrimary
                )
                .padding(.top, Space.xl)

                if let mechanism = brief.mechanism {
                    Text(mechanism)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .opacity(tailSettled ? 1 : 0)
                        .offset(y: tailSettled ? 0 : 6)
                }

                HStack {
                    Spacer()
                    Text("jeni \u{2665}\u{FE0E}")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .padding(.top, Space.lg)
                .opacity(tailSettled ? 1 : 0)

                Spacer(minLength: 0)

                // The doors: reply leads, keep excuses quietly.
                VStack(spacing: Space.md) {
                    Button {
                        Haptics.soft()
                        onReply()
                    } label: {
                        Text("reply")
                            .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Palette.cocoaPrimary))
                    }
                    .buttonStyle(JKPress())

                    Button {
                        Haptics.light()
                        onClose()
                    } label: {
                        Text("keep it \u{2665}\u{FE0E}")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                            .foregroundStyle(Palette.cocoaSecondary)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, Space.lg)
                .opacity(tailSettled ? 1 : 0)
                .offset(y: tailSettled ? 0 : 8)
            }
            .padding(.horizontal, Space.lg)
        }
        .onAppear {
            if reduceMotion { tailSettled = true; return }
            // The tail (mechanism + signature + doors) follows the
            // cascade: ~0.5s per line + a settling breath.
            let delay = 0.4 + Double(cascadeLines.count) * 0.5
            withAnimation(Motion.entranceSoft.delay(delay)) { tailSettled = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("a note from jeni. \([brief.line, brief.second, brief.mechanism].compactMap { $0 }.joined(separator: " "))")
    }

    private var cascadeLines: [LineCascadeText.Line] {
        var lines: [LineCascadeText.Line] = [
            .composite(base: brief.line, italic: brief.italic)
        ]
        if let second = brief.second {
            lines.append(.composite(base: second, italic: brief.secondItalic))
        }
        return lines
    }
}

// MARK: - JKDayRail

/// THE DAY RAIL (app v5 re-steer, 00_DIRECTION.md §6) — the program
/// week at the top of Home: seven day cells she can actually read
/// and touch. Weekday letters over state marks; today is a filled
/// pill wearing its date; past days open their receipts; the future
/// stays dotted. The caption line names the week and opens the
/// journey. This is the calendar-strip answer, returned as a
/// designed object (the v4 whisper-line ribbon proved too quiet to
/// carry the plan's shape).
struct JKDayRail: View {
    let snapshot: TodaySnapshot
    let onOpen: () -> Void
    /// A past day's cell was tapped — open its receipt.
    var onOpenDay: (Int) -> Void = { _ in }

    private struct RailDay: Identifiable {
        let id: Int              // programDay
        let date: Date
        let standing: DayStanding
        let isToday: Bool
        let isFuture: Bool
        let isPaused: Bool
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(railDays) { day in
                    cell(day)
                        .frame(maxWidth: .infinity)
                }
            }

            Button {
                Haptics.light()
                onOpen()
            } label: {
                HStack(spacing: 6) {
                    if let intent = snapshot.weekIntent {
                        ItalicAccentText(
                            "\(intent.name) · week \(snapshot.programWeek) of \(snapshot.totalWeeks)",
                            italic: [intent.name],
                            baseFont: .custom("DMSans-Regular", size: 13, relativeTo: .footnote),
                            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 13.5, relativeTo: .footnote),
                            color: Palette.textSecondary,
                            alignment: .leading
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityIdentifier("today.weekRibbon")
            .accessibilityLabel(a11y)
            .accessibilityHint("opens the journey")
        }
    }

    @ViewBuilder
    private func cell(_ day: RailDay) -> some View {
        let content = VStack(spacing: 7) {
            Text(letter(day.date))
                .font(.custom(day.isToday ? "DMSans-SemiBold" : "DMSans-Medium",
                              size: 11, relativeTo: .caption2))
                .kerning(0.66)
                .foregroundStyle(day.isToday ? Palette.cocoaPrimary : Palette.cocoaTertiary)
            mark(day)
                .frame(height: 30)
        }

        if !day.isToday && !day.isFuture {
            Button {
                Haptics.light()
                onOpenDay(day.id)
            } label: {
                content.contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityIdentifier("today.rail.day.\(day.id)")
            .accessibilityLabel("day \(day.id), \(standingWord(day))")
            .accessibilityHint("opens the day's receipt")
        } else {
            content
                .accessibilityLabel(day.isToday ? "today, day \(day.id)" : "day \(day.id), to come")
        }
    }

    @ViewBuilder
    private func mark(_ day: RailDay) -> some View {
        if day.isToday {
            ZStack {
                Circle()
                    .fill(Palette.cocoaPrimary)
                    .frame(width: 30, height: 30)
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.custom("DMSans-SemiBold", size: 13))
                    .foregroundStyle(Palette.textInverse)
                    .monospacedDigit()
            }
        } else if day.isPaused {
            JKMark(kind: .moon, size: 10, color: Palette.cocoaTertiary)
        } else if day.isFuture {
            Circle()
                .strokeBorder(
                    Palette.hairlineCocoa,
                    style: StrokeStyle(lineWidth: 1.2, dash: [2, 2.6])
                )
                .frame(width: 12, height: 12)
        } else {
            switch day.standing {
            case .kept:
                Circle().fill(Palette.cocoaSecondary)
                    .frame(width: 12, height: 12)
            case .partial:
                Circle().fill(Palette.cocoaSecondary.opacity(0.55))
                    .frame(width: 10, height: 10)
            case .quiet:
                Circle().fill(Palette.cocoaTertiary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func letter(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE"
        return fmt.string(from: date).lowercased()
    }

    private func standingWord(_ day: RailDay) -> String {
        if day.isPaused { return "held" }
        switch day.standing {
        case .kept: return "kept"
        case .partial: return "some of it landed"
        case .quiet: return "quiet"
        }
    }

    private var railDays: [RailDay] {
        let week = max(snapshot.programWeek, 1)
        let firstDay = (week - 1) * 7 + 1
        guard let start = snapshot.plan?.startDate else { return [] }
        let cal = Calendar.current
        let startOfPlan = cal.startOfDay(for: start)
        return (firstDay...(firstDay + 6)).map { programDay in
            let date = cal.date(byAdding: .day, value: programDay - 1, to: startOfPlan) ?? .now
            let isToday = programDay == snapshot.programDay
            let standing: DayStanding = isToday
                ? DayStanding.from(completedCount: snapshot.completedBeatCount)
                : DayStanding.from(completedCount: snapshot.completionWindow[programDay])
            return RailDay(
                id: programDay,
                date: date,
                standing: standing,
                isToday: isToday,
                isFuture: programDay > snapshot.programDay,
                isPaused: BreakState.covers(dayKey: TodayStateService.dayKey(for: date))
            )
        }
    }

    private var a11y: String {
        let name = snapshot.weekIntent?.name ?? "this week"
        return "\(name), week \(snapshot.programWeek) of \(snapshot.totalWeeks)"
    }
}

// MARK: - jkTapWithLongPress

/// Tap-enters + long-press-overrides with the v1.1.4 tap-swallow fix
/// (Button fires on release regardless of hold length; the flag eats
/// the follow-up tap and self-resets). Shared by the one-thing card
/// and rhythm rows; JKBeatRow keeps its own identical copy.
private struct JKTapWithLongPress: ViewModifier {
    let onTap: () -> Void
    var onLongPress: (() -> Void)?

    @State private var longPressJustFired = false

    func body(content: Content) -> some View {
        Button {
            if longPressJustFired {
                longPressJustFired = false
                return
            }
            Haptics.light()
            onTap()
        } label: {
            content
        }
        .buttonStyle(JKPress())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard let onLongPress else { return }
                longPressJustFired = true
                onLongPress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    longPressJustFired = false
                }
            }
        )
    }
}

// MARK: - JKOneThingCard

/// The single ask — the screen's ONE dark object (04_PREMIUM_PASS
/// move B). Cocoa field, cream serif, the italic punch word tinted
/// accent-subtle; the strike draws in cream. Done: the card exhales
/// into a cream kept-receipt row, so the dark anchor literally
/// leaves the screen once the ask is met. Permission days stay
/// cream — dark means an ask exists.
struct JKOneThingCard: View {
    let title: String
    var italic: [String] = []
    var subtitle: String? = nil
    /// The ritual's glossy sticker as a wax seal, floating top-right
    /// on the cocoa field — the ask carries its object.
    var sealAsset: String? = nil
    var isDone: Bool = false
    /// Permission days (rest-with-no-ask / break) render statement-only.
    var isPermission: Bool = false
    var onTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let onTap, !isDone, !isPermission {
                cardBody.modifier(
                    JKTapWithLongPress(onTap: onTap, onLongPress: onLongPress)
                )
            } else {
                cardBody
            }
        }
        .animation(reduceMotion ? nil : Motion.easedFinal, value: isDone)
    }

    private var isDark: Bool { !isDone && !isPermission }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: isDone ? 4 : 10) {
            HStack(alignment: .top) {
                Text(isDone ? "kept" : "the one thing")
                    .font(Typo.captionTracked)
                    .kerning(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        isDone ? Palette.cocoaSecondary
                               : (isDark ? Palette.textInverse.opacity(0.55)
                                         : Palette.cocoaTertiary)
                    )
                Spacer(minLength: 0)
                if !isDone, let sealAsset {
                    Image(sealAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(isDark ? 0.25 : 0.10),
                                radius: 4, y: 2)
                        .padding(.top, -6)
                        .padding(.trailing, -4)
                        .accessibilityHidden(true)
                }
            }

            if isDone {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                        .strikethrough(true, color: Palette.textPrimary.opacity(0.55))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\u{2665}\u{FE0E}")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.accent)
                }
                .transition(.opacity)
            } else {
                ItalicAccentText(
                    title,
                    italic: italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 23, relativeTo: .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 23, relativeTo: .title3),
                    color: isDark ? Palette.textInverse : Palette.textPrimary,
                    italicColor: isDark ? Palette.accentSubtle : nil,
                    alignment: .leading
                )
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)

                if let subtitle {
                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(
                            isDark ? Palette.textInverse.opacity(0.62)
                                   : Palette.textSecondary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, isDone ? 14 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // v6.2 material: the cocoa field is top-lit — a whisper of
            // luminance falling down the card so it reads as milled
            // surface, not flat fill (the chat cards' paper-glass
            // treatment, adapted to the dark hero).
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isDark ? Palette.cocoaPrimary : Palette.bgElevated)
                if isDark {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), .clear, .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
            }
        )
        .overlay(
            // The specular lip: light catching the card's shoulder.
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(
                    isDark
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        : AnyShapeStyle(Palette.hairlineCocoa),
                    lineWidth: isDark ? 1 : 0.66
                )
        )
        .shadow(
            color: isDark ? Palette.cocoaPrimary.opacity(0.22) : .black.opacity(0.03),
            radius: isDark ? 12 : 7,
            y: isDark ? 5 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(isDone || isPermission ? "" : "opens \(title)")
    }

    private var a11yLabel: String {
        if isDone { return "the one thing, \(title), done" }
        if isPermission { return title }
        return "the one thing, \(title)\(subtitle.map { ", \($0)" } ?? "")"
    }
}

// MARK: - JKRhythmRow

/// The day's shape, one quiet line at a time: glyph · title · inline
/// note · live trailing state. No circles, no cards. The strike is
/// the done state (pen speed + tick cascade, the her75 gesture).
struct JKRhythmRow: View {
    let title: String
    var note: String? = nil
    /// The glossy ritual sticker on its pastel tile — THE app's own
    /// icon language (founder direction 2026-07-06: the iridescent
    /// peach / candy / balloon dog / mary-jane / heart-lock / bubble
    /// ARE the identity). 34pt: present, never loud.
    var sticker: (asset: String, tile: Color)? = nil
    /// Fallback line mark when a row has no sticker.
    var mark: JKMarkKind? = nil
    var state: JKBeatState = .empty
    /// Live trailing text for auto rows (steps count).
    var liveTrailing: String? = nil
    /// v6.4 (founder call, reversing the v3 no-at-rest-circles law):
    /// required rows wear a visible trailing check ring so the day
    /// reads as a checkable list at a glance. Optional/quiet rows
    /// keep the old render-only grammar.
    var showsCheckRing: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var strike: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            if let sticker {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(sticker.tile.opacity(state.isDone ? 0.45 : 0.85))
                    Image(sticker.asset)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                }
                .frame(width: 34, height: 34)
                .saturation(state.isDone ? 0.4 : 1)
            } else if let mark {
                JKMark(
                    kind: mark,
                    size: 18,
                    color: Palette.cocoaSecondary.opacity(state.isDone ? 0.5 : 0.85)
                )
                .frame(width: 20)
            }
            HStack(spacing: 6) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let note {
                    Text("· \(note)")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Palette.textPrimary.opacity(0.55))
                        .frame(width: geo.size.width * strike, height: 1.5)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)
            }

            Spacer(minLength: 8)

            if let liveTrailing {
                Text(liveTrailing)
                    .font(Typo.caption.monospacedDigit())
                    .foregroundStyle(state.isDone ? Palette.cocoaSecondary : Palette.textSecondary)
            } else if !showsCheckRing, state.isDone, state.isAuto {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.cocoaSecondary)
            }

            if showsCheckRing {
                ZStack {
                    Circle()
                        .strokeBorder(
                            state.isDone ? Color.clear : Palette.cocoaPrimary.opacity(0.28),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if state.isDone {
                        Circle()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 22, height: 22)
                        Image(systemName: state.isAuto ? "sparkle" : "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Motion.gentleSpring, value: state.isDone)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .opacity(state.isDone ? 0.62 : 1)
        .modifier(JKTapWithLongPress(onTap: onTap, onLongPress: onLongPress))
        .animation(Motion.entranceSoft, value: state.isDone)
        .onChange(of: state.isDone) { _, done in
            guard done else {
                withAnimation(Motion.exit) { strike = 0 }
                return
            }
            if reduceMotion { strike = 1; return }
            withAnimation(.easeOut(duration: 0.34).delay(0.28)) { strike = 1 }
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28 + 0.09 * Double(i)) {
                    Haptics.tick()
                }
            }
        }
        .onAppear { strike = state.isDone ? 1 : 0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)\(state.isDone ? ", done" : (note.map { ", \($0)" } ?? ""))")
        .accessibilityHint(state.isDone ? "" : "opens \(title)")
    }
}

// MARK: - JKBreakCard

/// The "on a break" state — permission, not absence. One gentle
/// return door; ending the break is warm, never a catch-up.
struct JKBreakCard: View {
    let onReturn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ItalicAccentText(
                "on a break.",
                italic: ["break"],
                baseFont: .custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3),
                italicFont: .custom("JeniHeroSerif-Italic", size: 24, relativeTo: .title3),
                color: Palette.textPrimary,
                alignment: .leading
            )
            Text("the rhythm and the reminders are asleep. coming back is one tap.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.soft()
                onReturn()
            } label: {
                Text("i'm back")
                    .font(.custom("DMSans-SemiBold", size: 14, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(JKPress())
            .padding(.top, 4)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
        )
    }
}

// MARK: - JKFlowLayout
//
// A wrapping row layout: lays children left-to-right and wraps to a new
// line the moment the next child would overflow the proposed width. Each
// child keeps its ideal size, so chips hug their labels and never
// truncate (the fix for the breathwork occasion chips that got squeezed
// into one HStack). iOS 16+. Left-aligned; equal spacing horizontally
// and between lines.
struct JKFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        let total = y + rowHeight
        return CGSize(width: min(maxWidth, widest), height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > maxX {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
