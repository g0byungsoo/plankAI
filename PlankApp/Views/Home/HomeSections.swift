import SwiftUI

// MARK: - HomeCalendarStrip (v11 T3)
//
// MFP's top strip in the editorial register: seven day letters,
// today a filled ink disc, past days quiet, future days quieter.
// Past taps open the record (becoming) — the week is orientation,
// never a report card (L10: no missed-day shame states).

struct HomeCalendarStrip: View {
    /// Program day for today (nil pre-enrollment — strip still shows).
    let programDay: Int?
    let onPastDay: () -> Void

    private var week: [(letter: String, dayNumber: Int, isToday: Bool, isPast: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // The week starts on the user's calendar's firstWeekday.
        let start = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        return (0..<7).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let weekdayIndex = cal.component(.weekday, from: day) - 1
            return (
                letter: letters[weekdayIndex],
                dayNumber: cal.component(.day, from: day),
                isToday: cal.isDate(day, inSameDayAs: today),
                isPast: day < today
            )
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                Group {
                    if day.isToday {
                        VStack(spacing: 5) {
                            dayLetter(day.letter, emphasized: true)
                            Text("\(day.dayNumber)")
                                .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .caption))
                                .foregroundStyle(Palette.textInverse)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Palette.textPrimary))
                        }
                        .accessibilityLabel("today, the \(day.dayNumber)")
                    } else if day.isPast {
                        Button(action: onPastDay) {
                            VStack(spacing: 5) {
                                dayLetter(day.letter)
                                Text("\(day.dayNumber)")
                                    .font(.custom("DMSans-Regular", size: 13, relativeTo: .caption))
                                    .foregroundStyle(Palette.textSecondary)
                                    .frame(width: 28, height: 28)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(JKPress())
                        .accessibilityLabel("the \(day.dayNumber). opens your record")
                    } else {
                        VStack(spacing: 5) {
                            dayLetter(day.letter)
                            Text("\(day.dayNumber)")
                                .font(.custom("DMSans-Regular", size: 13, relativeTo: .caption))
                                .foregroundStyle(Palette.cocoaTertiary.opacity(0.55))
                                .frame(width: 28, height: 28)
                        }
                        .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func dayLetter(_ letter: String, emphasized: Bool = false) -> some View {
        Text(letter)
            .font(.custom("DMSans-Medium", size: 10, relativeTo: .caption2))
            .tracking(1.2)
            .foregroundStyle(emphasized ? Palette.textPrimary : Palette.cocoaTertiary)
    }
}

// MARK: - HomeNutritionSummary (v11 T3)
//
// MFP's "today's numbers in three seconds" slot, Jeni's register:
// the kcal numeral counts in (L12), one hairline shows the window,
// protein carries its floor as a thin bar, carbs and fat speak as
// plain grams (no invented denominators — L8). The safety gate
// (targets.numericsSuppressed) drops every numeral for words.
// Over-window is stated as the window being met — never red,
// never minus (L10).

struct HomeNutritionSummary: View {
    let snapshot: TodaySnapshot
    let landedPulse: Int
    let onOpenFood: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            JeniSectionHeader("food")

            if snapshot.targets.numericsSuppressed {
                // The safety gate: words, never numerals.
                Button(action: onOpenFood) {
                    VStack(alignment: .leading, spacing: 4) {
                        JeniHeadline(platesLine.text, italic: platesLine.italic)
                        Text("gentle plates, protein first · numbers off")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
            } else {
                Button(action: onOpenFood) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HStack(alignment: .firstTextBaseline) {
                            JeniCountingNumeral(
                                value: Double(snapshot.kcalEaten),
                                unit: kcalUnitText
                            )
                            // A landed plate re-counts the numeral —
                            // the celebration IS the number moving.
                            .id("kcal-\(landedPulse)")
                            Spacer()
                            if let kcal = snapshot.targets.kcal {
                                Text(remainingText(target: kcal))
                                    .font(Typo.numeralMeta)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }

                        if let kcal = snapshot.targets.kcal, kcal > 0 {
                            windowBar(fraction: min(1, Double(snapshot.kcalEaten) / Double(kcal)))
                        }

                        macroLine
                            .padding(.top, 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(a11ySummary)
            }
        }
    }

    // MARK: pieces

    private var kcalUnitText: String? {
        guard let kcal = snapshot.targets.kcal else { return "kcal today" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let target = f.string(from: NSNumber(value: kcal)) ?? "\(kcal)"
        return "of \(target) kcal"
    }

    private func remainingText(target: Int) -> String {
        let left = target - snapshot.kcalEaten
        if left > 0 { return "\(left.formatted()) left" }
        return "window met"
    }

    private func windowBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 3)
                Capsule()
                    .fill(Palette.textPrimary)
                    .frame(width: max(3, geo.size.width * fraction), height: 3)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var macroLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            if let proteinTarget = snapshot.targets.proteinG {
                macroPair("protein", "\(snapshot.proteinEatenG) / \(proteinTarget) g")
            } else {
                macroPair("protein", "\(snapshot.proteinEatenG) g")
            }
            macroPair("carbs", "\(snapshot.carbsEatenG) g")
            macroPair("fat", "\(snapshot.fatEatenG) g")
            Spacer(minLength: 0)
        }
    }

    private func macroPair(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
        }
    }

    private var platesLine: (text: String, italic: [String]) {
        let n = snapshot.plates.count
        if n == 0 { return ("no plates yet today.", []) }
        if n == 1 { return ("one plate, counted.", ["counted."]) }
        return ("\(n) plates, counted.", ["counted."])
    }

    private var a11ySummary: String {
        var parts = ["\(snapshot.kcalEaten) calories today"]
        if let kcal = snapshot.targets.kcal {
            parts.append(remainingText(target: kcal))
        }
        parts.append("protein \(snapshot.proteinEatenG) grams")
        return parts.joined(separator: ", ") + ". opens food"
    }
}
