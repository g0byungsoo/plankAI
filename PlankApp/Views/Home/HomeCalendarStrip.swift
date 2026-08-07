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
                        letter: letters[cal.component(.weekday, from: day) - 1]
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func dayCell(day: Date, letter: String) -> some View {
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
                    // the ring warms to berry.
                    if kept, !isSelected {
                        Circle()
                            .strokeBorder(Palette.roseBerry.opacity(0.85), lineWidth: 1.6)
                    } else if isToday, !isSelected {
                        Circle()
                            .strokeBorder(Palette.textPrimary.opacity(0.22), lineWidth: 1.2)
                    }
                    if isSelected {
                        Circle()
                            .fill(Palette.textPrimary)
                            .matchedGeometryEffect(id: "day.disc", in: discNS)
                    }
                    // On the selected day a kept mark replaces the
                    // numeral: the check IS the number's meaning.
                    if isSelected, kept {
                        StripCheck()
                            .trim(from: 0, to: 1)
                            .stroke(Palette.textInverse,
                                    style: StrokeStyle(lineWidth: 1.9, lineCap: .round,
                                                       lineJoin: .round))
                            .frame(width: 11, height: 11)
                    } else {
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
                }
                .frame(width: 32, height: 32)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StripCellPress())
        .accessibilityLabel(a11yLabel(day: day, isToday: isToday, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func a11yLabel(day: Date, isToday: Bool, isSelected: Bool) -> Text {
        let name = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return Text(isToday ? "today, \(name)" : name)
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

/// The strip's kept mark — the same stroke as JeniCheck, sized for a
/// 32pt disc so the two read as one language.
private struct StripCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return p
    }
}
