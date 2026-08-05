import SwiftUI
import PlankFood

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
            surface
        }
    }

    @ViewBuilder private var surface: some View {
        JeniSurface {
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

// MARK: - HomeDayRecap (v11.5 — the strip's answer for other days)
//
// Selecting a past day re-keys the page to that day's RECORD: what
// landed, in that day's own numbers. Never a report card — quiet
// memory (L10). Future days decline politely.

struct HomeDayRecap: View {
    let date: Date
    let userId: String
    let onOpenRecord: () -> Void
    let onBackToToday: () -> Void

    private var cal: Calendar { Calendar.current }
    private var isFuture: Bool { date > cal.startOfDay(for: .now) }

    private struct DayTotals {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        var plates = 0
    }

    private var totals: DayTotals {
        var t = DayTotals()
        for entry in FoodLogPersister.allEntries(userId: userId)
        where cal.isDate(entry.loggedAt, inSameDayAs: date) {
            t.kcal += entry.kcal
            t.protein += entry.protein
            t.carbs += entry.carbs
            t.fat += entry.fat
            t.plates += 1
        }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                JeniSectionHeader(dayLabel)
                Spacer(minLength: Space.md)
                Button(action: onBackToToday) {
                    Text("today")
                        .font(.custom("DMSans-SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.textPrimary))
                }
                .buttonStyle(JeniPressable())
                .accessibilityLabel("back to today")
            }

            if isFuture {
                JeniSurface {
                    JeniHeadline("not written yet.", italic: ["yet."])
                }
            } else if totals.plates == 0 {
                JeniSurface {
                    VStack(alignment: .leading, spacing: 4) {
                        JeniHeadline("a quiet page.", italic: ["quiet"])
                        Text("nothing was logged this day.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            } else {
                JeniSurface {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(Int(totals.kcal.rounded()).formatted())")
                                .font(Typo.numeralHero)
                                .foregroundStyle(Palette.textPrimary)
                            Text("kcal that day")
                                .font(Typo.numeralMeta)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                            recapPair("plates", "\(totals.plates)")
                            recapPair("protein", "\(Int(totals.protein.rounded())) g")
                            recapPair("carbs", "\(Int(totals.carbs.rounded())) g")
                            recapPair("fat", "\(Int(totals.fat.rounded())) g")
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Button(action: onOpenRecord) {
                HStack(spacing: 6) {
                    Text("the whole record lives in becoming")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.md)
        }
    }

    private var dayLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day()).lowercased()
    }

    private func recapPair(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
        }
    }
}
