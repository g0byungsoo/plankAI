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
        .frame(height: 58)
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
                    if isSelected {
                        Circle()
                            .fill(Palette.textPrimary)
                            .matchedGeometryEffect(id: "day.disc", in: discNS)
                    } else if isToday {
                        // Today keeps a quiet ring when the selection
                        // is elsewhere — the anchor never vanishes.
                        Circle()
                            .strokeBorder(Palette.textPrimary.opacity(0.25), lineWidth: 1.2)
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
                .frame(width: 30, height: 30)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel(day: day, isToday: isToday, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func a11yLabel(day: Date, isToday: Bool, isSelected: Bool) -> Text {
        let name = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return Text(isToday ? "today, \(name)" : name)
    }
}
