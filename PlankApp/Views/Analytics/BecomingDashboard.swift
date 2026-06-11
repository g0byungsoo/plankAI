import SwiftUI
import PlankFood

// MARK: - Becoming dashboard atoms (v1.1 restructure)
//
// Per docs/becoming_dashboard_v1_1_plan_2026_06_10.md + the round-2
// dashboard brief's 11-atom vocabulary. The surface is a dense-but-
// premium one-snapshot dashboard: folio masthead → week dot-row →
// ONE chromed artifact → hairline stat pair → her plate filmstrip →
// one insight sentence. Registers:
//   - serif numerals ONLY ≥20pt, max 3 per viewport
//   - DM Sans tabular for dense rows
//   - 0 rings; dots (binary days) + micro-bars (composition) +
//     sparkline (trend) cover every data shape
//   - direction in language, never arrows or ±%
//   - color budget: accent (bars/today ring) + cocoa (lines/dots) +
//     sage (goal-hit language only)

// MARK: - Folio masthead (atom 1)

/// The page-opening masthead: day count in words, program horizon,
/// identity line. Type directly on cream — no card, no border.
/// Reads `totalDays` from the active plan when one exists; falls back
/// to engagement-day framing for pre-program users. NEVER hardcodes
/// a program length per [[project-program-duration-custom]].
struct BecomingFolio: View {
    let dayNumber: Int
    /// nil when the user has no active program plan.
    let totalDays: Int?
    /// "apr 2 → jun 25" when a plan exists, else nil.
    let dateRange: String?
    /// Data-derived identity line ("becoming steady." etc., from the
    /// existing becomingStateWord derivation — provenance rule).
    let identityLine: String
    let identityItalic: [String]

    private var dayWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: dayNumber)) ?? "\(dayNumber)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            (Text("day ").font(Typo.heroHeadline)
             + Text(dayWord).font(Typo.heroHeadlineItalic))
                .foregroundStyle(Palette.textPrimary)
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if let totalDays {
                    Text("of her \(totalDays)")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("of showing up")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
                if let dateRange {
                    Text("·").foregroundStyle(Palette.divider)
                    Text(dateRange)
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            ItalicAccentText(
                identityLine,
                italic: identityItalic,
                baseFont: Typo.body,
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Week dot-row (atom 6)

enum WeekDayState: Equatable {
    case done      // filled cocoa
    case open      // divider-stroke circle
    case today     // accent-ringed (not yet done today)
    case todayDone // filled + accent ring
}

/// "this week  5 of 7  ●●●●●○◐" — gain-framed; an un-done day is an
/// open circle, never red, never an X.
struct BecomingWeekRow: View {
    let states: [WeekDayState]   // 7 entries, oldest → today
    let doneCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("this week")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text("\(doneCount) of 7")
                .font(.custom("JeniHeroSerif-Regular", size: 20))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 5) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    dot(state)
                }
            }
            .padding(.leading, 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("this week: \(doneCount) of 7 days")
    }

    @ViewBuilder private func dot(_ state: WeekDayState) -> some View {
        switch state {
        case .done:
            Circle().fill(Palette.cocoaPrimary).frame(width: 7, height: 7)
        case .open:
            Circle().stroke(Palette.divider, lineWidth: 1.2).frame(width: 7, height: 7)
        case .today:
            Circle().stroke(Palette.divider, lineWidth: 1.2).frame(width: 7, height: 7)
                .overlay(Circle().stroke(Palette.accent, lineWidth: 1.2).frame(width: 11, height: 11))
        case .todayDone:
            Circle().fill(Palette.cocoaPrimary).frame(width: 7, height: 7)
                .overlay(Circle().stroke(Palette.accent, lineWidth: 1.2).frame(width: 11, height: 11))
        }
    }
}

// MARK: - Stat pair (atom 7)

/// The ONLY 2-up on the surface, chromed by a single hairline COLUMN
/// rule (magazine columns) — no tile backgrounds, no borders.
struct BecomingStatPair<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leading.frame(maxWidth: .infinity, alignment: .leading)
            Rectangle()
                .fill(Palette.divider)
                .frame(width: 1)
                .padding(.vertical, 2)
            trailing
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Space.md)
        }
    }
}

/// One cell of the stat pair: eyebrow label → numeral line(s) →
/// language chip. DM Sans tabular numerals (dense-row contract).
struct BecomingStatCell: View {
    let label: String
    let lines: [(value: String, caption: String)]
    var languageChip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(line.value)
                        .font(.custom("DMSans-SemiBold", size: 17))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                    Text(line.caption)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            if let languageChip {
                Text(languageChip)
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Protein/carb/fat composition micro-bars — the shipped HomeFoodCard
/// 3-bar idiom (3pt capsules), no numeric % labels on the surface.
struct MacroMicroBars: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double { max(protein + carbs + fat, 1) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                Capsule().fill(Palette.accent)
                    .frame(width: max(6, geo.size.width * protein / total))
                Capsule().fill(Palette.accent.opacity(0.45))
                    .frame(width: max(6, geo.size.width * carbs / total))
                Capsule().fill(Palette.accent.opacity(0.25))
                    .frame(width: max(6, geo.size.width * fat / total))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

// MARK: - Plate filmstrip (atom 8)

/// 4-up strip of HER OWN plate photos (FoodPhotoStore thumbnails).
/// Renders nothing at all when she has no photos this week — an empty
/// module disappears, it never apologizes with a placeholder.
struct PlateFilmstrip: View {
    let entryIds: [String]   // newest first, already photo-filtered
    var onTap: (() -> Void)? = nil

    var body: some View {
        if !entryIds.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("her week in plates")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 8) {
                    ForEach(entryIds.prefix(4), id: \.self) { id in
                        if let img = FoodPhotoStore.photo(entryId: id) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .accessibilityLabel("her week in plates — opens the food log")
        }
    }
}

// MARK: - Insight line (atom 9)

/// One sentence about her own data, italic punch word, optional ♥.
/// Never a card. Provenance-gated at the call site — if no insight
/// clears its gate, the line doesn't render.
struct BecomingInsightLine: View {
    let text: String
    let italic: [String]

    var body: some View {
        ItalicAccentText(
            text,
            italic: italic,
            baseFont: .custom("DMSans-Regular", size: 14),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
            color: Palette.textPrimary,
            alignment: .leading
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}
