import SwiftUI
import PlankFood
import PlankSync

// MARK: - Becoming v1.2 premium atoms (2026-06-18)
//
// Synthesized from the cohort-research + competitive-scan briefs. The
// dashboard register shifts from "magazine reportage" to "quiet diary
// entry" — written by her future self to her present self, in her own
// voice, with the kindness she can't quite give herself yet.
//
// Three signature design moves are reused across atoms:
//
//   • The 80ms perceptual lag (Whoop): number-rolls start `Motion.
//     perceptualLag` after the visual primary lands. Cause precedes
//     effect.
//   • The eased-final-20% number-roll (Apple Fitness+ Wrapped):
//     `Motion.easedFinal` cubic-bezier-(0.22, 1.0, 0.36, 1.0) over
//     1.6s — last 20% of the count is ~6× slower than the first 20%.
//   • The breathing text shadow (Calm): 3s ease-in-out indefinite
//     pulse on hero italics. Connects masthead + insight line via
//     shared ambient motion → reads as one breath.
//
// Voice: lowercase casual, italic-Fraunces on numerals + identity
// punch words only, hearts as terminal punctuation on the warmest
// beats. No "AI," no "crush," no "deficit," no calendar heatmap, no
// red bars, no fire emoji.

// MARK: - BecomingDiaryHero
//
// Page-opening: spelled-out day number with the breathing serif glow,
// supporting meta line, and a one-sentence diary entry from her own
// data. Replaces the previous folio masthead — same data, warmer
// register, signature breathing pulse on the serif numeral.
//
// Per cohort brief: "she opens the app when her boyfriend is sleeping,
// when she's spiraling in the bathroom mirror. The dashboard's job is
// to interrupt the rumination loop with evidence of self."

struct BecomingDiaryHero: View {
    let dayNumber: Int
    let totalDays: Int?
    let dateRange: String?
    let showedUpCount: Int   // engagedDates across the entire program/year
    let identityLine: String
    let identityItalic: [String]

    private var dayWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: dayNumber)) ?? "\(dayNumber)"
    }

    private var showedUpWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: showedUpCount)) ?? "\(showedUpCount)"
    }

    /// v1.6.2 — brand-canonical heartGlossy sticker accent on the
    /// hero, sized + rotated per the StickerName.signature locked
    /// placement. Replaces the dropped pressed-flower experiment;
    /// the heart is one of the curated 5 the brand carries forward.
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                (Text("day ").font(Typo.heroHeadline)
                 + Text(dayWord).font(Typo.heroHeadlineItalic))
                    .foregroundStyle(Palette.textPrimary)
                    .kerning(-0.4)
                    .lineSpacing(Typo.heroHeadlineLineGap)
                    .fixedSize(horizontal: false, vertical: true)
                    .breathingShadow()

            // Sidecar meta — single dense DM Sans line, kerning +0.1.
            // her75 IMG_6276 convention: tucked-under stat pair in a
            // single justified-right typographic row.
            (
                Text(totalDays.map { "of \($0) days" } ?? "of showing up")
                    .font(.custom("DMSans-Medium", size: 13))
                + (dateRange.map {
                    Text(" · \($0)").font(.custom("DMSans-Medium", size: 13))
                } ?? Text(""))
                + (showedUpCount > 0
                    ? (
                        Text(" · ")
                            .font(.custom("DMSans-Medium", size: 13))
                        + Text(showedUpWord)
                            .font(.custom("JeniHeroSerif-Italic", size: 14))
                        + Text(" times \u{2661}")
                            .font(.custom("DMSans-Medium", size: 13))
                    )
                    : Text(""))
            )
            .foregroundStyle(Palette.textSecondary)
            .kerning(0.1)
            .padding(.top, 2)

                // Identity line — italic-Fraunces punch word, restraint
                // register. Kept since it's the brand voice signature.
                ItalicAccentText(
                    identityLine,
                    italic: identityItalic,
                    baseFont: .custom("DMSans-Regular", size: 14),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 15),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Brand-canonical heartGlossy. 28pt locked size + 0° rotation
            // per StickerName.signature spec; +6° tilt softens the perch.
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(6))
                .opacity(0.92)
                .offset(x: -2, y: 4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - BecomingTodayEnergyTile
//
// Bento card — one half of the today bento pair (the other half is
// BecomingProteinTile). Soft cream-elevated chrome, 1.5pt cocoa
// hairline border, 14pt corners. NO shadow (Chanel/Tiffany restraint
// per founder lock). The pair sits side-by-side; together they own
// ~75pt of vertical real estate.
//
// Per the WL iOS expert: 'in' / 'moved' / 'pace' replaces 'eaten' /
// 'burned' / 'deficit'. Per the GLP-1 expert: the 'moved' number is
// wordless on the dashboard — only the minutes carry it. NO ring,
// NO red.

struct BecomingTodayEnergyTile: View {
    let eatenKcal: Int
    let movedMinutes: Int
    let paceKcalTarget: Int?

    private var paceProgress: Double {
        guard let target = paceKcalTarget, target > 0 else { return 0 }
        return min(1.0, Double(eatenKcal) / Double(target))
    }

    private var paceWord: String {
        guard let target = paceKcalTarget, target > 0 else { return "logging" }
        let delta = eatenKcal - target
        if abs(delta) < 80 { return "right at pace \u{2661}" }
        if delta < 0 { return "\(abs(delta)) under pace" }
        return "\(delta) above pace"
    }

    private var paceColor: Color {
        guard let target = paceKcalTarget, target > 0 else { return Palette.cocoaSecondary }
        let delta = eatenKcal - target
        if abs(delta) < 80 { return Palette.stateGood }
        return Palette.cocoaSecondary
    }

    /// v1.6 luxury polish — diary-register lowercase eyebrow, single
    /// accent rose on the protein tile only ("in" reverts to cocoa
    /// for restraint), warm gradient card chrome via luxuryCard().
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("energy")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(eatenKcal.formatted())
                    .font(.custom("JeniHeroSerif-Regular", size: 34))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("in")
                    .font(.custom("JeniHeroSerif-Italic", size: 20))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            Text("\(movedMinutes) min moved today")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.cocoaTertiary)

            paceBar.padding(.top, 6)

            Text(paceWord)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(paceColor)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .luxuryCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eatenKcal) calories in, \(movedMinutes) minutes moved")
    }

    @ViewBuilder private var paceBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.hairlineCocoa)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Palette.cocoaPrimary, Palette.cocoaPrimary.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * paceProgress))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - BecomingProteinGauge
//
// The cohort wedge. Protein leads, target derived from body mass (1.2
// g/kg, floor 80 g). NO ring (Apple Activity = guilt). Thin bar +
// status word in italic-Fraunces. Status word rotates by % hit per
// the GLP-1 expert's spec:
//   - <60%: "still time today"
//   - 60-95%: "muscle stays"
//   - 95-120%: "protein, done ♡"
//   - 120%+: "well-fed today"

/// Phase 4 interactivity (2026-06-19) — single plate source for the
/// protein tile peek. Caller composes from FoodLogPersister; tile
/// renders up to 3 highest-protein-contribution photos as proof.
struct BecomingProteinSource: Equatable {
    let entryId: String
    let proteinG: Int
}

struct BecomingProteinTile: View {
    let proteinG: Int
    let targetG: Int
    /// Phase 4 — plate sources for the long-press peek. nil → tile is
    /// non-interactive (legacy). Empty → long-press is a no-op (we
    /// don't want a "you have no plates" empty state nag).
    var sources: [BecomingProteinSource]? = nil

    /// Phase 4 — long-press flips the bottom row from statusWord to
    /// a horizontal thumbnail strip. Release-to-dismiss is automatic
    /// via DragGesture's onEnded; auto-dismiss after 2.4s as a fail-
    /// safe if the user keeps holding while reading.
    @State private var peeking: Bool = false

    /// Phase 4 — harness-only initial peek (debug screenshots).
    var debugInitialPeeking: Bool = false

    private var progress: Double {
        guard targetG > 0 else { return 0 }
        return min(1.0, Double(proteinG) / Double(targetG))
    }

    private var statusWord: String {
        let pct = targetG > 0 ? Double(proteinG) / Double(targetG) * 100 : 0
        switch pct {
        case ..<60:    return "still time today"
        case ..<95:    return "muscle stays"
        case ..<120:   return "protein, done \u{2661}"
        default:       return "well-fed today"
        }
    }

    private var statusColor: Color {
        let pct = targetG > 0 ? Double(proteinG) / Double(targetG) * 100 : 0
        return pct >= 95 ? Palette.stateGood : Palette.cocoaSecondary
    }

    /// Top-3 plate sources sorted by protein contribution. Caller
    /// can pass them already sorted; we sort defensively in case
    /// not. Empty when there's nothing to peek at.
    private var topSources: [BecomingProteinSource] {
        (sources ?? []).sorted { $0.proteinG > $1.proteinG }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("protein")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(proteinG)")
                    .font(.custom("JeniHeroSerif-Regular", size: 34))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                Text("g")
                    .font(.custom("JeniHeroSerif-Italic", size: 20))
                    .foregroundStyle(Palette.accent)
            }
            Text("of ~\(targetG)g")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.cocoaTertiary)

            proteinBar.padding(.top, 6)

            // Phase 4 — bottom row cross-fades between status word
            // and the plate-peek strip. Long-press on the tile body
            // toggles peeking; release auto-dismisses after 2.4s.
            Group {
                if peeking, !topSources.isEmpty {
                    plateStrip
                        .transition(.opacity)
                        .id("peek")
                } else {
                    Text(statusWord)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                        .foregroundStyle(statusColor)
                        .transition(.opacity)
                        .id("status")
                }
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .luxuryCard()
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !topSources.isEmpty else { return }
            Haptics.soft()
            withAnimation(Motion.crossFade) { peeking = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(Motion.crossFade) { peeking = false }
            }
        }
        .onAppear {
            if debugInitialPeeking, !topSources.isEmpty, !peeking {
                peeking = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(proteinG) of \(targetG) grams of protein today, \(statusWord)")
        .accessibilityHint(topSources.isEmpty ? "" : "long press to see the plates that built it")
    }

    /// Phase 4 — horizontal mini-row of up to 3 plate thumbnails.
    /// Falls back to a pink rounded rect if the photo isn't on disk
    /// (a user can log a plate without a snap; the row still reads).
    @ViewBuilder
    private var plateStrip: some View {
        HStack(spacing: 4) {
            ForEach(topSources, id: \.entryId) { src in
                ZStack(alignment: .bottomTrailing) {
                    if let img = FoodPhotoStore.photo(entryId: src.entryId) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Palette.accent.opacity(0.18))
                            .frame(width: 38, height: 38)
                    }
                    Text("\(src.proteinG)g")
                        .font(.custom("DMSans-Medium", size: 9))
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Palette.cocoaPrimary.opacity(0.85))
                        )
                        .padding(2)
                }
            }
        }
    }

    @ViewBuilder private var proteinBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.hairlineCocoa)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Palette.accent, Palette.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * progress))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - BecomingMacroRow
//
// Tight 3-column macro row: carbs · fat · fiber (protein lives in the
// dedicated gauge above). Numeral-led tabular DM Sans; statLabel-class
// eyebrow above. Density done premium per her75 typographer's spec.

/// Phase 4 interactivity (2026-06-19) — discriminant for the macro
/// segment tap reveal. Identifies which segment is selected so the
/// eyebrow can swap to a macro-specific insight line.
enum BecomingMacroSegment: Equatable {
    case protein, carbs, fat, fiber
}

struct BecomingMacroRow: View {
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int

    private var total: Double {
        Double(max(1, protein + carbs + fat + fiber))
    }

    /// Phase 4 — which segment the user has tapped. Tapping the bar
    /// outside any segment, or the same segment again, releases the
    /// selection. Eyebrow swaps from "macros" to the per-macro
    /// insight when non-nil.
    @State private var selected: BecomingMacroSegment? = nil

    /// Phase 4 — harness-only initial selection (debug screenshots).
    var debugInitialSelected: BecomingMacroSegment? = nil

    /// v1.5 — horizontal stack-bar with 4 proportional segments per
    /// macro. Compact (one row of bar + one row of legend), visual,
    /// dense. The bar IS the data; the legend reads as a label index.
    /// Card chrome stays for unity with the bento pair above.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow
                .onAppear {
                    if let s = debugInitialSelected, selected == nil {
                        selected = s
                    }
                }

            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 0) {
                    segment(.protein, color: Palette.accent.opacity(0.92),
                            width: w * CGFloat(Double(protein) / total))
                    segment(.carbs, color: Palette.cocoaPrimary.opacity(0.58),
                            width: w * CGFloat(Double(carbs) / total))
                    segment(.fat, color: Palette.cocoaPrimary.opacity(0.32),
                            width: w * CGFloat(Double(fat) / total))
                    segment(.fiber, color: Palette.stateGood.opacity(0.85),
                            width: w * CGFloat(Double(fiber) / total))
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)

            HStack(spacing: 14) {
                legend(.protein, color: Palette.accent.opacity(0.92), value: protein, label: "protein")
                legend(.carbs, color: Palette.cocoaPrimary.opacity(0.58), value: carbs, label: "carbs")
                legend(.fat, color: Palette.cocoaPrimary.opacity(0.32), value: fat, label: "fat")
                legend(.fiber, color: Palette.stateGood.opacity(0.85), value: fiber, label: "fiber")
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .luxuryCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today: \(protein)g protein, \(carbs)g carbs, \(fat)g fat, \(fiber)g fiber")
    }

    /// Phase 4 — eyebrow swaps from "macros" to the per-macro insight
    /// when a segment is selected. Single line, no chrome change.
    @ViewBuilder
    private var eyebrow: some View {
        if let s = selected {
            let copy = insight(for: s)
            (Text(copy.prefix)
                .font(.custom("DMSans-Regular", size: 13))
            + Text(copy.italic)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
            + Text(copy.suffix)
                .font(.custom("DMSans-Regular", size: 13)))
                .foregroundStyle(Palette.cocoaSecondary)
                .transition(.opacity)
                .id(s)
        } else {
            Text("macros")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(Palette.cocoaTertiary)
                .transition(.opacity)
        }
    }

    /// Per-macro insight sentences. Each is grounded in the value she
    /// already has on screen + universally-true nutrition framing
    /// (no claims about "climbing" without weekly trend data we don't
    /// pass to this atom yet). Italic-Fraunces punch per voice lock.
    private func insight(for s: BecomingMacroSegment) -> (prefix: String, italic: String, suffix: String) {
        switch s {
        case .protein:
            return ("\(protein)g · ", "muscle", " stays \u{2661}")
        case .carbs:
            return ("\(carbs)g · ", "primary", " fuel today")
        case .fat:
            return ("\(fat)g · ", "steady", ", roughly a third")
        case .fiber:
            return ("\(fiber)g · ", "fiber", " keeps satiety strong \u{2661}")
        }
    }

    @ViewBuilder
    private func segment(_ id: BecomingMacroSegment, color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tick()
                withAnimation(Motion.crossFade) {
                    selected = selected == id ? nil : id
                }
            }
    }

    @ViewBuilder
    private func legend(_ id: BecomingMacroSegment, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)g")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                Text(" \(label)")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tick()
            withAnimation(Motion.crossFade) {
                selected = selected == id ? nil : id
            }
        }
    }
}

// MARK: - BecomingMovedStrip
//
// Soft activity stripe — steps, workout, plank. NO kcal numeric (GLP-1
// safety: exchange-economy framing is the #1 driver of disordered
// tracking patterns per Levinson 2017 + Plateau 2018). The italic
// closing line carries the meaning ("body used some of what you fed
// it ♡") without the bargaining math.

struct BecomingMovedStrip: View {
    let steps: Int
    let workoutMinutes: Int
    let breathMinutes: Int

    private var hasAnything: Bool {
        steps > 0 || workoutMinutes > 0 || breathMinutes > 0
    }

    var body: some View {
        if hasAnything {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 0) {
                    iconStat(
                        glyph: "figure.walk",
                        value: steps.formatted(),
                        unit: "steps",
                        show: steps > 0
                    )
                    if steps > 0 && (workoutMinutes > 0 || breathMinutes > 0) {
                        divider
                    }
                    iconStat(
                        glyph: "figure.core.training",
                        value: "\(workoutMinutes)",
                        unit: "min plank",
                        show: workoutMinutes > 0
                    )
                    if workoutMinutes > 0 && breathMinutes > 0 {
                        divider
                    }
                    iconStat(
                        glyph: "lungs.fill",
                        value: "\(breathMinutes)",
                        unit: "min breath",
                        show: breathMinutes > 0
                    )
                }
                (
                    Text("body used some of what you ")
                        .font(.custom("DMSans-Regular", size: 12))
                    + Text("fed")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    + Text(" it \u{2661}")
                        .font(.custom("DMSans-Regular", size: 12))
                )
                .foregroundStyle(Palette.cocoaTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .luxuryCard()
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func iconStat(glyph: String, value: String, unit: String, show: Bool) -> some View {
        if show {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: glyph)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.accent.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Palette.accentSubtle.opacity(0.6)))
                VStack(alignment: .leading, spacing: -2) {
                    Text(value)
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(Palette.cocoaPrimary)
                        .monospacedDigit()
                    Text(unit)
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var divider: some View {
        Rectangle()
            .fill(Palette.hairlineCocoa)
            .frame(width: 1, height: 24)
    }
}

// MARK: - BecomingPlateTimelineToday
//
// Horizontal row of today's plate photos with time + kcal underneath.
// Replaces the PlateFanTeaser's purely-shareable register with a
// utility-first today-timeline. The trailing "+ log" tile closes the
// input-loop in 1 tap. Per WL iOS expert: this is the input-loop fire
// the Becoming surface has been missing; PlateFanTeaser was 4 taps
// from quick-add.

struct BecomingPlateTimelineToday: View {
    /// (entryId, loggedAt, kcal) for today only, oldest → newest.
    let plates: [(id: String, loggedAt: Date, kcal: Int)]
    let onTapPlate: (String) -> Void
    let onLogTapped: () -> Void

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("on her plate")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(Palette.cocoaTertiary)
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(plates.prefix(4).enumerated()), id: \.element.id) { _, p in
                    plateTile(p)
                }
                if plates.count < 4 {
                    logTile
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .luxuryCard()
    }

    @ViewBuilder
    private func plateTile(_ p: (id: String, loggedAt: Date, kcal: Int)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                if let img = FoodPhotoStore.photo(entryId: p.id) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Palette.bgElevated)
                }
            }
            .frame(width: 64, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Palette.divider, lineWidth: 0.5)
            )
            Text(Self.timeFmt.string(from: p.loggedAt).lowercased())
                .font(.custom("BradleyHandITCTT-Bold", size: 11))
                .foregroundStyle(Palette.cocoaSecondary)
            Text("\(p.kcal) cal")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundStyle(Palette.cocoaPrimary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture { Haptics.light(); onTapPlate(p.id) }
    }

    @ViewBuilder private var logTile: some View {
        VStack(alignment: .center, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Palette.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.accent)
            }
            .frame(width: 64, height: 80)
            Text("log")
                .font(.custom("BradleyHandITCTT-Bold", size: 11))
                .foregroundStyle(Palette.accent)
            Text(" ")
                .font(.custom("DMSans-Medium", size: 11))
        }
        .contentShape(Rectangle())
        .onTapGesture { Haptics.light(); onLogTapped() }
        .accessibilityLabel("log a plate")
    }
}

// MARK: - BecomingDeedsCounter
//
// The signature cumulative-deeds module — "X plates kept · Y lessons
// read · Z hours of food noise quieted." Net-positive register, not
// daily pressure. Robinhood number-roll: counts up from 0 every time
// the screen mounts → ritualizes return. Each open re-earns the
// number.
//
// Per cohort brief: "Strava's 'lifetime miles' is the most-screenshot-
// shared Strava UI element. Cumulative-positive = identity scaffold."

struct BecomingDeedsCounter: View {
    let plates: Int
    let lessons: Int
    let breathMinutes: Int

    private var foodNoiseHours: Int {
        let minutes = lessons * 10 + (breathMinutes / 12)
        return minutes / 60
    }

    /// v1.4 (2026-06-18) — visual bento 2x2 + closing italic.
    /// Each cell is a tiny card so the cumulative-deeds register
    /// reads as a scrapbook page, not a stat row. Soft elevation
    /// chrome (bgElevated + hairline cocoa border, no shadow).
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("kept")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .foregroundStyle(Palette.cocoaSecondary)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    cellCard(value: "\(plates)", label: "plates kept")
                    cellCard(value: "\(lessons)", label: "lessons read")
                }
                HStack(spacing: 10) {
                    cellCard(value: "\(breathMinutes)", label: "min of breath")
                    cellCard(
                        value: "\(foodNoiseHours)h",
                        label: "food noise quieted",
                        accent: foodNoiseHours > 0
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    @ViewBuilder
    private func cellCard(value: String, label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.custom("JeniHeroSerif-Regular", size: 28))
                .foregroundStyle(accent ? Palette.accent : Palette.cocoaPrimary)
                .monospacedDigit()
            Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(Palette.cocoaTertiary)
                .kerning(0.6)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .luxuryCard(cornerRadius: 12, horizontalPadding: 14, verticalPadding: 12)
    }

    private var a11yLabel: String {
        var parts: [String] = ["\(plates) plates kept"]
        if lessons > 0 { parts.append("\(lessons) lessons read") }
        if breathMinutes > 0 { parts.append("\(breathMinutes) minutes of breath") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - BecomingTrendCanvas
//
// The hero chart, rebuilt from stock SwiftUI `Chart` to custom Canvas
// so the trend line can be a flowing gradient stroke (cocoa → accent
// → cocoa) that draws in left-to-right over 1.2s on appearance, then
// shimmers gently while idle.
//
// The y-axis numbers stay hidden by default — per cohort brief, hidden
// y-axis lets the trend SHAPE land first, defusing scale-anxiety. The
// headline weight floats above the chart on the left, italic-Fraunces.
//
// Tap-and-drag along the canvas reveals a vertical scrub line + the
// data point under the finger; the headline number rolls to match,
// monospacedDigit, with a soft haptic per data-point traversal.

struct BecomingTrendCanvas: View {
    let logs: [WeightLogRecord]
    let goalWeightKg: Double?
    var unit: WeightUnit = .lb
    // v1.3 (2026-06-18) — compressed per her75 typographer panel:
    // Apple Health charts ride at ~120pt on the Summary surface; her75
    // photo modules at ~100-120pt. 110pt lands the chart on register
    // and frees ~60pt below for an insight line or stat row.
    var height: CGFloat = 110

    @State private var drawProgress: Double = 0     // 0...1 — line trace-in
    @State private var shimmerPhase: Double = 0     // 0...1 — idle gradient flow
    @State private var scrubFraction: Double? = nil // 0...1 — drag position
    @State private var lastHapticIndex: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var points: [WeightTrendChart.EMAPoint] {
        WeightTrendChart.computeEMA(logs: logs)
    }

    private func toDisplay(_ kg: Double) -> Double { unit.display(fromKg: kg) }

    /// The currently-visible weight number — either the scrubbed
    /// point or the most-recent EMA.
    private var headlineWeightLb: Double {
        if let frac = scrubFraction, !points.isEmpty {
            let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
            return toDisplay(points[idx].emaKg)
        }
        return toDisplay(points.last?.emaKg ?? 0)
    }

    private var headlineDateLabel: String? {
        guard let frac = scrubFraction, !points.isEmpty else { return nil }
        let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: points[idx].date).lowercased()
    }

    var body: some View {
        if points.count < 2 {
            placeholder
        } else {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow
                headline
                trendCanvas
                xAxisLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .luxuryCard()
        }
    }

    @ViewBuilder private var eyebrow: some View {
        Text("trend")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
            .foregroundStyle(Palette.cocoaTertiary)
    }

    // MARK: - Headline

    @ViewBuilder private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", headlineWeightLb))
                    .font(.custom("JeniHeroSerif-Regular", size: 40))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: headlineWeightLb)
                Text(unit.label)
                    .font(.custom("JeniHeroSerif-Italic", size: 18))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(4)
            }
            Spacer()
            if let scrubDate = headlineDateLabel {
                Text(scrubDate)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(Palette.accent)
                    .transition(.opacity)
            } else if let delta = weeklyDeltaDisplay {
                (Text(delta.amount)
                    .font(.custom("DMSans-Medium", size: 13))
                + Text(" this week")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13)))
                    .foregroundStyle(delta.tint)
            }
        }
    }

    /// 7-day delta (current EMA vs EMA from 7 days ago) — soft sage
    /// when trending down, soft cocoa otherwise. Hidden when the
    /// window is too short.
    private var weeklyDeltaDisplay: (amount: String, tint: Color)? {
        guard points.count >= 7 else { return nil }
        let latest = points[points.count - 1].emaKg
        let weekAgo = points[points.count - 7].emaKg
        let deltaKg = latest - weekAgo
        let display = unit.display(fromKg: latest) - unit.display(fromKg: weekAgo)
        let amount: String = {
            if abs(display) < 0.05 { return "steady" }
            if display < 0 { return "−\(String(format: "%.1f", abs(display))) \(unit.label)" }
            return "+\(String(format: "%.1f", display)) \(unit.label)"
        }()
        let tint: Color = deltaKg <= 0 ? Palette.stateGood : Palette.cocoaSecondary
        return (amount, tint)
    }

    // MARK: - Canvas chart

    @ViewBuilder private var trendCanvas: some View {
        // Canvas's closure receives the actual drawing-region size, so
        // we sidestep GeometryReader's layout-race entirely. TimelineView
        // pumps a fresh phase value at 30fps for the idle shimmer; the
        // Canvas re-renders against the latest drawProgress @State.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            Canvas { ctx, canvasSize in
                let yDom = yDomain
                let mapped = points.enumerated().map { (i, p) -> CGPoint in
                    let x = CGFloat(i) / CGFloat(max(1, points.count - 1)) * canvasSize.width
                    let yVal = toDisplay(p.emaKg)
                    let y = canvasSize.height
                        - CGFloat((yVal - yDom.lowerBound) / max(0.0001, yDom.upperBound - yDom.lowerBound))
                        * canvasSize.height
                    return CGPoint(x: x, y: y)
                }
                let phase = reduceMotion
                    ? 0.5
                    : (context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.0) / 6.0)
                drawLine(ctx: ctx, points: mapped, size: canvasSize, phase: phase, progress: drawProgress)
                drawScrubMarker(ctx: ctx, points: mapped, size: canvasSize)
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .contentShape(Rectangle())
        .gesture(scrubGesture)
        .task {
            // Use task instead of onAppear so the animation block runs
            // on the MainActor after the view actually mounts. onAppear
            // was firing before SwiftUI's animation transaction was
            // ready in the TimelineView wrapper, leaving drawProgress
            // stuck at 0.
            try? await Task.sleep(nanoseconds: UInt64(Motion.perceptualLag * 1_000_000_000))
            if reduceMotion {
                drawProgress = 1
            } else {
                withAnimation(Motion.trendDrawIn) {
                    drawProgress = 1
                }
            }
        }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Map x to fraction.
                let width = max(1.0, UIScreen.main.bounds.width - 48) // outer padding aware fallback
                let frac = min(1.0, max(0.0, value.location.x / width))
                scrubFraction = frac
                let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
                if idx != lastHapticIndex {
                    lastHapticIndex = idx
                    let gen = UIImpactFeedbackGenerator(style: .soft)
                    gen.impactOccurred(intensity: 0.4)
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.32)) {
                    scrubFraction = nil
                }
                lastHapticIndex = -1
            }
    }

    @ViewBuilder private var xAxisLabel: some View {
        if !points.isEmpty,
           let first = points.first?.date,
           let last = points.last?.date {
            HStack {
                Text(monthDayLabel(first))
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(monthDayLabel(last))
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func monthDayLabel(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: d).lowercased()
    }

    // MARK: - Placeholder

    @ViewBuilder private var placeholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("your trend")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            (Text("a line takes ")
                .font(.custom("JeniHeroSerif-Regular", size: 24))
            + Text("two")
                .font(.custom("JeniHeroSerif-Italic", size: 24))
            + Text(" points.")
                .font(.custom("JeniHeroSerif-Regular", size: 24)))
                .foregroundStyle(Palette.textPrimary)
                .lineSpacing(Typo.heroHeadlineLineGap)
            Text("log a few more days. your trend draws itself.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Drawing

    private func drawLine(
        ctx: GraphicsContext,
        points: [CGPoint],
        size: CGSize,
        phase: Double,
        progress: Double
    ) {
        guard points.count >= 2 else { return }

        let visibleCount = max(2, Int(Double(points.count) * progress))
        let visible = Array(points.prefix(visibleCount))

        // Soft fill underneath — fades to nothing at the baseline.
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: visible.first?.x ?? 0, y: size.height))
        for p in visible { fillPath.addLine(to: p) }
        fillPath.addLine(to: CGPoint(x: visible.last?.x ?? 0, y: size.height))
        fillPath.closeSubpath()
        let fillGradient = Gradient(stops: [
            .init(color: Palette.accent.opacity(0.18), location: 0.0),
            .init(color: Palette.accent.opacity(0.02), location: 0.85),
            .init(color: Palette.accent.opacity(0.00), location: 1.0),
        ])
        ctx.fill(
            fillPath,
            with: .linearGradient(
                fillGradient,
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Trend line — moving gradient stroke. Hue migrates with phase
        // so the line "breathes" while idle. Catmull-rom style curve.
        var path = Path()
        path.move(to: visible[0])
        for i in 1..<visible.count {
            let p0 = visible[max(0, i - 1)]
            let p1 = visible[i]
            let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            if i == 1 {
                path.addLine(to: mid)
            } else {
                path.addQuadCurve(to: mid, control: p0)
            }
        }
        if let last = visible.last { path.addLine(to: last) }

        // Phase-driven gradient stops give the line a flowing highlight
        // that drifts cocoa → accent → cocoa over a 6-second loop.
        let gradient = Gradient(stops: [
            .init(color: Palette.cocoaPrimary.opacity(0.85), location: 0.0),
            .init(
                color: Palette.accent,
                location: CGFloat(max(0.05, min(0.95, phase)))
            ),
            .init(color: Palette.cocoaPrimary.opacity(0.85), location: 1.0),
        ])
        ctx.stroke(
            path,
            with: .linearGradient(
                gradient,
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            ),
            style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
        )

        // Accent rose tip dot — Robinhood-coded "latest point" marker.
        // Soft halo at 0.4 opacity, solid core at 100%; appears only
        // when the trace-in has fully landed.
        if progress > 0.95, let last = visible.last {
            let halo = Path(ellipseIn: CGRect(x: last.x - 8, y: last.y - 8, width: 16, height: 16))
            ctx.fill(halo, with: .color(Palette.accent.opacity(0.18)))
            let core = Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7))
            ctx.fill(core, with: .color(Palette.accent))
        }

        // Goal reference (subtle dashed) — only when set + only after
        // the line has finished tracing in.
        if let goal = goalWeightKg, goal > 0, progress > 0.9 {
            let yDom = yDomain
            let goalY = size.height
                - CGFloat((toDisplay(goal) - yDom.lowerBound) / max(0.0001, yDom.upperBound - yDom.lowerBound))
                * size.height
            var goalPath = Path()
            goalPath.move(to: CGPoint(x: 0, y: goalY))
            goalPath.addLine(to: CGPoint(x: size.width, y: goalY))
            ctx.stroke(
                goalPath,
                with: .color(Palette.stateGood.opacity(0.40)),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
            )
        }
    }

    private func drawScrubMarker(
        ctx: GraphicsContext,
        points: [CGPoint],
        size: CGSize
    ) {
        guard let frac = scrubFraction, !points.isEmpty else { return }
        let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
        let pt = points[idx]
        var line = Path()
        line.move(to: CGPoint(x: pt.x, y: 0))
        line.addLine(to: CGPoint(x: pt.x, y: size.height))
        ctx.stroke(line, with: .color(Palette.cocoaPrimary.opacity(0.22)), lineWidth: 0.75)

        let dot = Path(ellipseIn: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
        ctx.fill(dot, with: .color(Palette.accent))
        let halo = Path(ellipseIn: CGRect(x: pt.x - 10, y: pt.y - 10, width: 20, height: 20))
        ctx.stroke(halo, with: .color(Palette.accent.opacity(0.45)), lineWidth: 1.0)
    }

    /// Y domain padded by ~12% above + below, includes goal when set.
    private var yDomain: ClosedRange<Double> {
        let weightsKg = points.map(\.emaKg) + points.compactMap(\.rawKg)
        var lo = weightsKg.min() ?? 0
        var hi = weightsKg.max() ?? 0
        if let goal = goalWeightKg, goal > 0 {
            lo = min(lo, goal)
            hi = max(hi, goal)
        }
        let dLo = toDisplay(lo)
        let dHi = toDisplay(hi)
        let pad = max(0.6, (dHi - dLo) * 0.12)
        return (dLo - pad)...(dHi + pad)
    }
}
