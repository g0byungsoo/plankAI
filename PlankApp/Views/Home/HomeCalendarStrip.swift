import SwiftUI

// MARK: - HomeCalendarStrip (v11.5 — the first-class selector)
//
// docs/app_v11/03_MODERNITY.md: the strip is a component you LIVE in,
// not a printed header. Weeks page horizontally; any day is
// selectable; the ink disc MORPHS between days (matched geometry +
// tick); the page below re-keys to the selection. No shame states —
// past days are memory, future days decline politely (L10).

struct HomeCalendarStrip: View {
    /// Start-of-day of the selected day; today by default.
    @Binding var selectedDate: Date
    /// Days she kept something. The reference screens both mark the
    /// week's days; ours marks only what actually happened (L8).
    var keptDays: Set<Date> = []

    @State private var weekPage: Int = 0
    @Namespace private var discNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// p75 — the record draws itself in at the page's arrival: each
    /// kept ring traces closed left-to-right on the visible week (the
    /// reference grammar — a week's marks arriving in sequence reads
    /// as "this happened", not wallpaper). One flip per mount; paging
    /// to other weeks later renders them settled.
    @Environment(\.jeniArrived) private var arrived
    @State private var ringsDrawn = false

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: .now) }

    var body: some View {
        TabView(selection: $weekPage) {
            // Two months back, one week forward — the lived range.
            ForEach(-8...1, id: \.self) { offset in
                weekRow(offset: offset)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 52)
        // Calendar cells are fixed-geometry chrome (32pt discs in a
        // 52pt strip): scaling their type past XXXL clips the digits
        // against their own discs (frame-caught at XXXL). Apple's
        // calendars clamp here too; the page's content keeps scaling.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // v14 haptic law: paging a week is SCROLLING — scrolling never
        // vibrates. The tick belongs to selecting a day.
        .onChange(of: selectedDate) { _, newDate in
            // Selecting via tap on a visible page never needs a page
            // jump; programmatic returns (back to today) might.
            let target = weekOffset(of: newDate)
            if target != weekPage {
                withAnimation(reduceMotion ? nil : JeniMotion.morph) {
                    weekPage = target
                }
            }
        }
        .onChange(of: arrived) { _, now in
            if now { ringsDrawn = true }
        }
        .onAppear {
            // Hosts without an arrival sequence (env default true)
            // render the record settled from frame one.
            if arrived { ringsDrawn = true }
        }
        .accessibilityElement(children: .contain)
    }

    private func weekOffset(of date: Date) -> Int {
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let thatWeek = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let days = cal.dateComponents([.day], from: thisWeek, to: thatWeek).day ?? 0
        return Int((Double(days) / 7.0).rounded())
    }

    private func weekRow(offset: Int) -> some View {
        let base = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let start = cal.date(byAdding: .day, value: offset * 7, to: base) ?? base
        let letters = ["S", "M", "T", "W", "T", "F", "S"]

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                if let day = cal.date(byAdding: .day, value: i, to: start) {
                    dayCell(
                        day: day,
                        letter: letters[cal.component(.weekday, from: day) - 1],
                        column: i
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func dayCell(day: Date, letter: String, column: Int) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDate(day, inSameDayAs: today)
        let kept = keptDays.contains(cal.startOfDay(for: day))
        let isFuture = day > today
        let number = cal.component(.day, from: day)

        return Button {
            guard !isSelected else { return }
            JeniHaptic.tick()
            withAnimation(reduceMotion ? nil : JeniMotion.morph) {
                selectedDate = cal.startOfDay(for: day)
            }
        } label: {
            VStack(spacing: 5) {
                Text(letter)
                    .font(.custom("DMSans-Medium", size: 10, relativeTo: .caption2))
                    .tracking(1.2)
                    .foregroundStyle(isToday ? Palette.textPrimary : Palette.cocoaTertiary)
                ZStack {
                    // A kept day wears a closed ring — her record,
                    // drawn (both references mark the week; ours marks
                    // only what happened). v21: the record is DATA, so
                    // the ring warms to berry. p75: the ring TRACES
                    // closed at the page's arrival, left-to-right
                    // across the week; later weeks render settled.
                    if kept, !isSelected {
                        keptRing(column: column)
                    } else if isToday, !isSelected {
                        Circle()
                            .strokeBorder(Palette.textPrimary.opacity(0.22), lineWidth: 1.2)
                    }
                    if isSelected {
                        Circle()
                            .fill(Palette.textPrimary)
                            .matchedGeometryEffect(id: "day.disc", in: discNS)
                        // p75 — the kept mark used to REPLACE the
                        // numeral with a check, so at 9:41am today's
                        // cell read as "day complete" while the dial
                        // said 83 g to go, and the selected cell was
                        // the one day whose DATE you could not read.
                        // The record now rides the disc's rim (rose =
                        // data, ink = selection — the v21 split) and
                        // the number stays: identity and state, both.
                        if kept {
                            keptRing(column: column)
                        }
                    }
                    Text("\(number)")
                        .font(.custom(
                            isSelected ? "DMSans-SemiBold" : "DMSans-Regular",
                            size: 13, relativeTo: .caption
                        ))
                        .monospacedDigit()
                        .foregroundStyle(
                            isSelected ? Palette.textInverse
                                : isFuture ? Palette.cocoaTertiary.opacity(0.5)
                                : Palette.textSecondary
                        )
                }
                .frame(width: 32, height: 32)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StripCellPress())
        .accessibilityLabel(a11yLabel(day: day, isToday: isToday, kept: kept))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The kept ring, drawn: traces closed on arrival (12 o'clock
    /// start, the dial's own convention), each column one small beat
    /// after the last. Reduce Motion renders it settled.
    private func keptRing(column: Int) -> some View {
        Circle()
            .inset(by: 0.8)
            .trim(from: 0, to: ringsDrawn || reduceMotion ? 1 : 0)
            .stroke(Palette.roseBerry.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(
                reduceMotion ? nil
                    : JeniMotion.draw.delay(Double(column) * 0.05),
                value: ringsDrawn
            )
    }

    private func a11yLabel(day: Date, isToday: Bool, kept: Bool) -> Text {
        let name = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let base = isToday ? "today, \(name)" : name
        return Text(kept ? "\(base), kept" : base)
    }
}


/// v12 — every date is touchable: the cell compresses under the
/// finger like every other pressed surface (§5.1).
private struct StripCellPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(JeniMotion.press, value: configuration.isPressed)
    }
}
