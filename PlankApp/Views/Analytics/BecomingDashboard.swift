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
                    // Founder QA 2026-06-11: "of her 84" read ambiguous;
                    // "of 84 days" is the clear version.
                    Text("of \(totalDays) days")
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
///
/// v1.0.10 Phase 4 — when `archetypes` is non-nil, a quiet single-letter
/// row renders above the dots showing each day's archetype (p / m / b /
/// r). Each letter sits in a 7pt-wide frame matching the dot HStack so
/// the letters align over their corresponding dots. Pre-program days
/// (program day < 1, e.g. user just enrolled and `archetypes[i] == nil`)
/// render a blank space; the dot row stays unchanged.
struct BecomingWeekRow: View {
    let states: [WeekDayState]   // 7 entries, oldest → today
    let doneCount: Int
    /// Optional archetype per day, matching `states` count + ordering.
    /// nil per-entry = no archetype to surface for that day (pre-
    /// program or no active plan). Whole array nil = no plan info,
    /// row renders exactly as it did pre-Phase-4.
    var archetypes: [ProgramDayArchetype?]? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("this week")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            // Never headline a zero (Koo & Fishbach 2012 small-area
            // framing) — the count appears once there's something
            // to count; until then the dots carry the row alone.
            if doneCount > 0 {
                Text("\(doneCount) of 7")
                    .font(.custom("JeniHeroSerif-Regular", size: 20))
                    .foregroundStyle(Palette.textPrimary)
            }
            VStack(alignment: .trailing, spacing: 4) {
                if let archetypes, archetypes.count == states.count {
                    archetypeLetterRow(archetypes)
                }
                HStack(spacing: 5) {
                    ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                        dot(state)
                    }
                }
            }
            .padding(.leading, 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("this week: \(doneCount) of 7 days")
    }

    @ViewBuilder
    private func archetypeLetterRow(_ archetypes: [ProgramDayArchetype?]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(archetypes.enumerated()), id: \.offset) { _, arch in
                Group {
                    if let arch {
                        Text(letterFor(arch))
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 10))
                            .foregroundStyle(Palette.cocoaSecondary.opacity(0.7))
                    } else {
                        // Blank slot for pre-program / unknown days.
                        // Matches the dot's 7pt width so the column
                        // alignment is preserved.
                        Color.clear
                    }
                }
                .frame(width: 11, height: 12)
            }
        }
        .accessibilityHidden(true)  // the dot-row a11y label already
                                    // conveys the engagement story
    }

    private func letterFor(_ arch: ProgramDayArchetype) -> String {
        switch arch {
        case .protein:  return "p"
        case .balanced: return "b"
        case .movement: return "m"
        case .rest:     return "r"
        }
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

// (PlateFilmstrip deleted 2026-06-11 — reborn as PlateFanTeaser,
// the journal doorway below.)

// (ProgramWeekMap + BecomingLedgerRow deleted 2026-06-11 — founder
// QA: "i don't think information there is quite useful." Replaced
// by the lighter-days module + plates journal teaser below, per
// docs/becoming_food_layer_design_2026_06_11.md.)

// MARK: - Lighter days (the deficit insight, gain-framed)

/// Weekly "lighter day" dots — filled when the day cleared every
/// honesty gate in EnergyLedger (conservative under, ≥2 meals,
/// restriction floor). EVERYTHING else (over days, thin-logging
/// days, today, future) renders as the same faint open dot: a
/// filled dot is the only statement this surface ever makes. The
/// count has NO denominator (founder-locked 2026-06-11) — "two so
/// far" only ever grows; an off week reads quiet, not failed. The
/// word "deficit" never appears in user-facing copy.
struct LighterDaysRow: View {
    /// Last 7 days oldest → today; true = earned the mark.
    let states: [Bool]

    private var count: Int { states.filter { $0 }.count }

    private var countWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("lighter days")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            if count > 0 {
                Text("\(countWord) so far this week")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.textPrimary)
            }
            HStack(spacing: 5) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, lighter in
                    if lighter {
                        Circle().fill(Palette.cocoaPrimary).frame(width: 7, height: 7)
                    } else {
                        Circle().stroke(Palette.divider, lineWidth: 1.2).frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.leading, 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count > 0
            ? "lighter days: \(countWord) so far this week"
            : "lighter days")
    }
}

// MARK: - Plates journal teaser

/// The latest plates as a fanned polaroid trio — the doorway into
/// the full journal. Photos wear the white matte (the her75
/// polaroid cue); collapses entirely when she has no logs.
struct PlateFanTeaser: View {
    /// Supabase user id — needed by the weekly share renderer to scope
    /// FoodLogPersister reads + photo lookups when the user taps share.
    let userId: String
    let photoEntryIds: [String]   // newest first, photo-backed only
    let entryCount: Int           // total logs (drives the empty / populated split)
    let onOpen: () -> Void

    var body: some View {
        Group {
            if entryCount == 0 {
                emptyStateRow
            } else {
                populatedRow
            }
        }
    }

    // MARK: - Empty state (Task #8 — session-1 entry into the food rail)
    //
    // Trial users who haven't logged a plate yet land on Becoming and
    // see a soft polaroid placeholder instead of an empty row. The +
    // glyph + "your first plate" italic + "tap to log + share" caption
    // doubles as a clear next-action AND a brand-aligned promise.

    @ViewBuilder private var emptyStateRow: some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Palette.divider, lineWidth: 0.5)
                    )
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(width: 70, height: 70)
            .rotationEffect(.degrees(-4))
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("your first plate")
                    .font(.custom("JeniHeroSerif-Italic", size: 19))
                    .foregroundStyle(Palette.textPrimary)
                Text("tap to log + share")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            onOpen()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("your first plate — tap to log and share")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Populated row
    //
    // Existing polaroid-fan doorway into the journal, plus a small
    // share icon that renders the weekly 9:16 collage when the user
    // has at least one photo-backed log this week. The whole row
    // remains tappable for "open journal"; the share Button takes
    // precedence over the row-level onTapGesture for its 36×36 area
    // (SwiftUI Button-vs-tap precedence) so the wires don't cross.

    @ViewBuilder private var populatedRow: some View {
        HStack(spacing: Space.md) {
            if !photoEntryIds.isEmpty {
                polaroidFan
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("her plates")
                    .font(.custom("JeniHeroSerif-Italic", size: 19))
                    .foregroundStyle(Palette.textPrimary)
                Text(entryCount == 1 ? "1 plate kept" : "\(entryCount) plates kept")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            onOpen()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("her plates — opens the food journal, \(entryCount) plates kept")
    }

    @ViewBuilder private var polaroidFan: some View {
        ZStack {
            ForEach(Array(photoEntryIds.prefix(3).enumerated()), id: \.element) { index, id in
                if let img = FoodPhotoStore.photo(entryId: id) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Palette.divider, lineWidth: 0.5)
                        )
                        .rotationEffect(.degrees(Double(index - 1) * 6))
                        .offset(x: CGFloat(index - 1) * 22)
                }
            }
        }
        .frame(width: 116, height: 76)
    }

}

// MARK: - Plate share infrastructure

/// Identifiable wrapper so `.sheet(item:)` can drive the rendered
/// share PNG through its lifecycle without re-rendering on every
/// state change.
private struct PlateShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// SwiftUI host for UIActivityViewController. Inlined here (rather
/// than imported from PlankFood) so PlateFanTeaser's share flow stays
/// self-contained in the main app target. Mirrors the helper used by
/// FoodLogTimelineView for the daily share — kept private to avoid
/// duplicating the public surface of PlankFood.
private struct PlateShareActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onComplete() }
        }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
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
