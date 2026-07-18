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

// MARK: - JKStepsBarChart

/// The movement page's hero: today's count as the numeral, and the week
/// as height-proportional bars so the *amount* each day reads at a
/// glance (the rhythm-dots version only said hit / half / missed). A
/// dashed goal line anchors the scale; tapping a bar lifts its exact
/// count into a pill above it — a TAP, never a drag, because a drag
/// would fight the Becoming pager's page swipes (mounted-tabs lesson).
/// Today's bar is the brightest; goal-reached days sit at half weight,
/// quiet days faint — magnitude and status in one read.
struct JKStepsBarChart: View {
    let todayCount: Int
    let weeklyCounts: [Int]
    let goal: Int
    /// Weekday letters under the bars (oldest → today).
    var letters: [String] = []
    /// Pager choreography: bars grow in on page arrival.
    var armed: Bool = true

    @State private var shown = false
    @State private var tapped: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let chartHeight: CGFloat = 128
    private let barSpacing: CGFloat = 10

    private var todayIndex: Int { max(0, weeklyCounts.count - 1) }
    /// Bars normalize against the taller of the goal or the week's peak,
    /// so the goal line keeps a stable position and over-goal days rise
    /// above it instead of everything flattening to the max.
    private var ceiling: Double { Double(max(goal, weeklyCounts.max() ?? goal, 1)) }
    private var goalFraction: CGFloat { CGFloat(min(1, Double(goal) / ceiling)) }

    var body: some View {
        VStack(spacing: Space.lg) {
            headline
            chart
        }
        .onAppear {
            if armed { arm() }
            #if DEBUG
            // Audit the tap-a-bar callout without a tap.
            if ProcessInfo.processInfo.arguments.contains("--uitest-steps-tap-demo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { tapped = 3 }
                }
            }
            #endif
        }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else { disarm() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(todayCount) steps today, seven-day rhythm")
    }

    private var headline: some View {
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
    }

    private var chart: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                goalLine
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(Array(weeklyCounts.enumerated()), id: \.offset) { idx, count in
                        barColumn(idx: idx, count: count)
                    }
                }
            }
            .frame(height: chartHeight)

            HStack(spacing: barSpacing) {
                ForEach(Array(weeklyCounts.enumerated()), id: \.offset) { idx, _ in
                    Text(idx < letters.count ? letters[idx] : "")
                        .font(.custom("DMSans-Medium", size: 10, relativeTo: .caption2))
                        .kerning(0.66)
                        .foregroundStyle(idx == todayIndex ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var goalLine: some View {
        GeometryReader { geo in
            let y = geo.size.height * (1 - goalFraction)
            Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .foregroundStyle(Palette.cocoaTertiary.opacity(0.55))
            .overlay(alignment: .topTrailing) {
                Text(goal.formatted())
                    .font(.custom("DMSans-Medium", size: 10, relativeTo: .caption2))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaTertiary)
                    .offset(y: y - 15)
            }
        }
        .frame(height: chartHeight)
        .opacity(shown ? 1 : 0)
        .animation(Motion.entranceSoft.delay(0.1), value: shown)
    }

    private func barColumn(idx: Int, count: Int) -> some View {
        let frac = ceiling > 0 ? CGFloat(min(1, Double(count) / ceiling)) : 0
        let isToday = idx == todayIndex
        let reached = count >= goal
        let isTapped = tapped == idx
        // A non-zero day always shows at least a sliver; zero stays flat.
        let target = count > 0 ? max(5, frac * chartHeight) : 0
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(barFill(isToday: isToday, reached: reached))
            .frame(maxWidth: .infinity)
            .frame(height: shown ? target : 0, alignment: .bottom)
            .scaleEffect(x: isTapped ? 1.14 : 1, anchor: .bottom)
            .overlay(alignment: .top) {
                if isTapped {
                    Text(count.formatted())
                        .font(.custom("DMSans-SemiBold", size: 10, relativeTo: .caption2))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textInverse)
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.cocoaPrimary))
                        .offset(y: -22)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .animation(
                reduceMotion ? nil
                    : .spring(response: 0.52, dampingFraction: 0.82)
                        .delay(0.1 + Double(idx) * 0.05),
                value: shown
            )
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.light()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                    tapped = isTapped ? nil : idx
                }
            }
    }

    private func barFill(isToday: Bool, reached: Bool) -> AnyShapeStyle {
        if isToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Palette.cocoaPrimary, Palette.cocoaPrimary.opacity(0.76)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(Palette.cocoaPrimary.opacity(reached ? 0.55 : 0.22))
    }

    private func arm() {
        if reduceMotion { shown = true; return }
        withAnimation { shown = true }
    }

    private func disarm() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { shown = false; tapped = nil }
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

// MARK: - JKNightWindowRing

/// The overnight window as a 24-hour ring: the quiet stretch drawn
/// as a cocoa arc, a moon at its heart, the hours as the numeral.
/// Rhythm made visible — never a rule, never a timer.
struct JKNightWindowRing: View {
    let hours: Double
    var diameter: CGFloat = 150
    var armed: Bool = true

    @State private var awakened = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double { min(1, max(0, hours / 24)) }
    private var shownFraction: Double { awakened ? fraction : 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.hairlineCocoa,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.02, shownFraction))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.accentSubtle, Palette.cocoaSecondary]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * fraction)
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Motion.easedFinal, value: shownFraction)

            VStack(spacing: 2) {
                JKMark(kind: .moon, size: 15, color: Palette.cocoaSecondary)
                Text("\(Int(hours.rounded()))")
                    .font(.custom("JeniHeroSerif-Regular", size: 34, relativeTo: .title))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("hours fasted")
                    .font(Typo.numeralMeta)
                    .kerning(0.1)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { awakened = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("you fasted about \(Int(hours.rounded())) hours overnight")
    }

    private func arm() {
        if reduceMotion { awakened = true; return }
        withAnimation(.easeOut(duration: 0.9).delay(0.2)) { awakened = true }
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

// MARK: - JKPlatesGallery
//
// Today's plates, moved off Home into their own becoming page (founder
// 1.1.5): the day's photos as a gentle fan of polaroids on the table,
// each rotated a touch so it reads as a scrapbook, not a grid. Tap one
// to open its detail. Deliberately NON-scrolling — a horizontal scroll
// here would fight the story pager's page swipes (mounted-tabs lesson) —
// so it fans up to three of the day's plates and lets the door carry the
// rest. Cards fan in staggered on page arrival.
struct JKPlatesGallery: View {
    struct Plate: Identifiable, Equatable {
        let id: String
        let time: String
        let title: String
        let kcal: Int
        let image: UIImage?
    }

    let plates: [Plate]
    var armed: Bool = true
    let onTap: (String) -> Void
    let onSnap: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fan the three most recent; the door speaks the full count.
    private var shownPlates: [Plate] { Array(plates.prefix(3)) }
    /// Gentle, deterministic tilt per slot — a scatter, never chaos.
    private func tilt(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let spread = [-5.0, 2.5, -2.0, 4.0]
        return spread[index % spread.count]
    }

    var body: some View {
        Group {
            if shownPlates.isEmpty {
                emptyState
            } else {
                HStack(spacing: shownPlates.count > 2 ? 2 : 12) {
                    ForEach(Array(shownPlates.enumerated()), id: \.element.id) { idx, plate in
                        polaroid(plate)
                            .rotationEffect(.degrees(shown ? tilt(idx, of: shownPlates.count) : 0))
                            .scaleEffect(shown ? 1 : 0.86)
                            .opacity(shown ? 1 : 0)
                            .offset(y: shown ? 0 : 14)
                            .zIndex(idx == 1 ? 1 : 0)   // center card sits over its neighbors
                            .animation(
                                reduceMotion ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.76)
                                        .delay(0.1 + Double(idx) * 0.08),
                                value: shown
                            )
                            .onTapGesture {
                                Haptics.light()
                                onTap(plate.id)
                            }
                    }
                }
            }
        }
        .onAppear { if armed { shown = true } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { shown = true }
            else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { shown = false }
            }
        }
    }

    private func polaroid(_ plate: Plate) -> some View {
        VStack(spacing: 7) {
            Group {
                if let image = plate.image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Palette.accentSubtle.opacity(0.5)
                        Text(String(plate.title.prefix(1)).lowercased())
                            .font(.custom("JeniHeroSerif-Italic", size: 30))
                            .foregroundStyle(Palette.jeweledRose)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(spacing: 1) {
                Text(plate.time)
                    .font(.custom("DMSans-Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(plate.kcal) kcal")
                    .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .padding(7)
        .padding(.bottom, 3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white)
                .shadow(color: Palette.cocoaPrimary.opacity(0.14), radius: 9, x: 0, y: 5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plate.title), \(plate.kcal) calories, \(plate.time)")
        .accessibilityAddTraits(.isButton)
    }

    private var emptyState: some View {
        Button {
            Haptics.light()
            onSnap()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            Palette.cocoaPrimary.opacity(0.22),
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )
                    Image(systemName: "camera")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                .frame(width: 96, height: 96)
                Text("snap your first plate")
                    .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
        }
        .buttonStyle(JKPress())
    }
}
