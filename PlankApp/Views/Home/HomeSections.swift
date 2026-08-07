import SwiftUI
import PlankFood

// MARK: - HomeNutritionSummary (v12 — the centerpiece)
//
// docs/app_v12/00_CRAFT.md §2.2: the three-second read. The kcal
// numeral leads with its remaining clause; the ring gives the
// fraction at a glance (R2's number-left / visual-right); the macro
// tri-column carries landing bars (protein alone owns a floor — D2);
// fiber · sugar intake · sodium whisper beneath (sodium summed from
// the day's plates — D3). A landed plate MORPHS the numeral and the
// ring forward — addition, never a reset.
//
// The safety gate (targets.numericsSuppressed) still drops every
// numeral for words. Over-window is "window met" — never red, never
// minus (law §11.4).

struct HomeNutritionSummary: View {
    let snapshot: TodaySnapshot
    let onOpenFood: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            JeniSectionHeader("food")
            Button(action: onOpenFood) {
                JeniSurface {
                    if snapshot.targets.numericsSuppressed {
                        gateFace
                    } else {
                        numericFace
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JeniPressable())
            .accessibilityLabel(a11ySummary)
            .accessibilityHint("opens food")
        }
    }

    // MARK: the safety-gate face (words, never numerals)

    private var gateFace: some View {
        VStack(alignment: .leading, spacing: 4) {
            JeniHeadline(platesLine.text, italic: platesLine.italic)
            Text("gentle plates, protein first · numbers off")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: the numeric face

    private var numericFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Space.blockGap) {
                VStack(alignment: .leading, spacing: 2) {
                    JeniCountingNumeral(value: Double(snapshot.kcalEaten))
                    Text(kcalMetaLine)
                        .font(Typo.numeralMeta)
                        .foregroundStyle(Palette.textSecondary)
                        // "613 left" counts down as the numeral counts
                        // up — one connected motion, never a swap.
                        .contentTransition(.numericText(countsDown: true))
                        .animation(JeniMotion.morph, value: kcalMetaLine)
                }
                Spacer(minLength: Space.sm)
                if let kcal = snapshot.targets.kcal, kcal > 0 {
                    JeniRing(
                        fraction: Double(snapshot.kcalEaten) / Double(kcal),
                        size: 74, lineWidth: 5.5
                    )
                }
            }

            macroColumns
                .padding(.top, Space.blockGap)

            if !plateChemistry.isEmpty {
                plateChemistryRow
                    .padding(.top, Space.md)
            }
        }
    }

    /// "of 1,473 kcal · 613 left" — the lead's second clause carries
    /// what to do with the number (R3's move).
    private var kcalMetaLine: String {
        guard let kcal = snapshot.targets.kcal else { return "kcal today" }
        let target = kcal.formatted()
        let left = kcal - snapshot.kcalEaten
        if left > 0 { return "of \(target) kcal · \(left.formatted()) left" }
        return "of \(target) kcal · window met"
    }

    private var macroColumns: some View {
        HStack(alignment: .top, spacing: Space.blockGap) {
            if let target = snapshot.targets.proteinG, target > 0 {
                JeniMetricBar(
                    label: "protein",
                    value: "\(snapshot.proteinEatenG) / \(target) g",
                    fraction: Double(snapshot.proteinEatenG) / Double(target),
                    index: 0
                )
            } else {
                JeniMetricBar(label: "protein",
                              value: "\(snapshot.proteinEatenG) g", index: 0)
            }
            JeniMetricBar(label: "carbs",
                          value: "\(snapshot.carbsEatenG) g", index: 1)
            JeniMetricBar(label: "fat",
                          value: "\(snapshot.fatEatenG) g", index: 2)
        }
    }

    /// The rest of the plate, whispered. Only what the day actually
    /// collected renders — a zero that was never measured is not a
    /// zero (law §1.6).
    private var plateChemistry: [(String, String)] {
        var pairs: [(String, String)] = []
        if snapshot.fiberEatenG > 0 {
            pairs.append(("fiber", "\(snapshot.fiberEatenG) g"))
        }
        if snapshot.sugarEatenG > 0 {
            pairs.append(("sugar", "\(snapshot.sugarEatenG) g"))
        }
        let sodium = Int(snapshot.plates.reduce(0) { $0 + $1.sodiumMg }.rounded())
        if sodium > 0 {
            pairs.append(("sodium", "\(sodium.formatted()) mg"))
        }
        return pairs
    }

    private var plateChemistryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            ForEach(plateChemistry, id: \.0) { pair in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pair.0)
                        .font(Typo.statLabel)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Text(pair.1)
                        .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary.opacity(0.85))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var platesLine: (text: String, italic: [String]) {
        let n = snapshot.plates.count
        if n == 0 { return ("no plates yet today.", []) }
        if n == 1 { return ("one plate, counted.", ["counted."]) }
        return ("\(n) plates, counted.", ["counted."])
    }

    private var a11ySummary: String {
        if snapshot.targets.numericsSuppressed {
            return "\(platesLine.text) gentle plates, protein first"
        }
        var parts = ["\(snapshot.kcalEaten) calories today"]
        if let kcal = snapshot.targets.kcal {
            let left = kcal - snapshot.kcalEaten
            parts.append(left > 0 ? "\(left) left" : "window met")
        }
        if let target = snapshot.targets.proteinG {
            parts.append("protein \(snapshot.proteinEatenG) of \(target) grams")
        } else {
            parts.append("protein \(snapshot.proteinEatenG) grams")
        }
        for pair in plateChemistry {
            parts.append("\(pair.0) \(pair.1)")
        }
        return parts.joined(separator: ", ")
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
