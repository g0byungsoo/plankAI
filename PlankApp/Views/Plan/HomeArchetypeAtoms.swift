import SwiftUI
import PlankFood

// MARK: - Home archetype atoms (Phase 1, 2026-06-19)
//
// Synthesized from the 4-expert panel (her75 typographer / Gen-Z
// aesthetic iOS / WL iOS / GLP-1 RD). The Home screen gains:
//
//   • HomeArchetypeHeader — JeniHeroSerif sentence above the checklist
//     ("today is a *protein* day."). Lowercase, italic-Fraunces punch
//     on the keyword. Carries the day's voice without color-coding the
//     rows.
//
//   • HomeProteinTracker — the founder's explicit ask: on protein
//     days, surface a clean inline protein progress strip just under
//     the header so the day's anchor is felt, not just named. Today's
//     protein gram numeral + soft gradient bar + adequacy stamp.
//     Cohort-routed copy (GLP-1 users get muscle-stays framing).
//
// Both compose against the locked palette (cream/cocoa/rose/sage)
// and the her75 typographic ladder. No new tokens. No badges.

// MARK: - HomeArchetypeHeader

struct HomeArchetypeHeader: View {

    let archetype: ProgramDayArchetype
    /// Optional dim flag for past-day viewing — drops the header to
    /// a muted register without breaking the sentence pattern.
    var pastDay: Bool = false
    /// Phase 3 — when the user has marked today as kind, the header
    /// swaps to a soft "today is a *kind* day." sentence regardless
    /// of the underlying archetype. The day's plan stays underneath
    /// but the rows go optional.
    var kindToday: Bool = false
    /// Phase 3 — long-press to mark today kind. Optional; when nil
    /// the header is non-interactive (harness/peek use cases).
    var onLongPressKind: (() -> Void)? = nil
    /// Harness-only initial "why" reveal for screenshot capture.
    var debugInitialWhy: Bool = false

    /// Phase 4 (2026-06-19) — double-tap reveals a one-line italic
    /// "*why* this is your day" explainer below the header. 4s auto-
    /// dismiss. Surfaces the archetype's meaning without a sheet.
    @State private var showWhy: Bool = false

    private var sentence: (prefix: String, italic: String, suffix: String) {
        if kindToday {
            return ("today is a ", "kind", " day \u{2661}")
        }
        return archetype.headerSentence
    }

    /// Phase 4 — one-line "why" copy per archetype. Lowercase casual,
    /// italic-Fraunces on the punch word. Anti-fitness-bro language.
    private var whyLine: (prefix: String, italic: String, suffix: String) {
        switch archetype {
        case .protein:
            return ("lean into ", "satiety", " today \u{2661}")
        case .movement:
            return ("muscle is the ", "metabolic", " win.")
        case .balanced:
            return ("a little of ", "everything", ", that's the brief.")
        case .rest:
            return ("rest is ", "part", " of the plan \u{2661}")
        }
    }

    var body: some View {
        let s = sentence
        VStack(alignment: .leading, spacing: 6) {
            (Text(s.prefix)
                .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3))
            + Text(s.italic)
                .font(.custom("JeniHeroSerif-Italic", size: 26, relativeTo: .title3))
            + Text(s.suffix)
                .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3)))
                .foregroundStyle(pastDay
                    ? Palette.cocoaPrimary.opacity(0.55)
                    : Palette.cocoaPrimary)
                .kerning(-0.3)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !pastDay, !kindToday, (showWhy || debugInitialWhy) {
                let w = whyLine
                (Text(w.prefix)
                    .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                + Text(w.italic)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
                + Text(w.suffix)
                    .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote)))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard !pastDay, !kindToday else { return }
            Haptics.tick()
            withAnimation(Motion.crossFade) { showWhy.toggle() }
            if showWhy {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(Motion.crossFade) { showWhy = false }
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            guard !pastDay, !kindToday else { return }
            onLongPressKind?()
        }
        .onAppear {
            if debugInitialWhy, !pastDay, !kindToday, !showWhy {
                showWhy = true
            }
        }
        .accessibilityLabel("\(s.prefix)\(s.italic)\(s.suffix)")
        .accessibilityAddTraits(onLongPressKind != nil && !pastDay && !kindToday
            ? .isButton
            : [])
        .accessibilityHint(onLongPressKind != nil && !pastDay && !kindToday
            ? "double tap to see why · long press to mark today kind"
            : "")
    }
}

// MARK: - HomeShowsUpLine
//
// Home Phase 3 retention atom (2026-06-19). Replaces the missing
// "streak" surface on Home with a gain-only "shows up" count that
// never decrements + has no denominator (Panel 4 anti-shame lock:
// no ratio that could read as < 50%). Sits just below the archetype
// header — a quiet identity beat the cohort can carry forward.
//
// Surfaces only when count >= 2 (avoids the weak "you've shown up
// 1 day" early-day signal) and only on the today view (past-view
// shows the day's settled state, not running totals).

struct HomeShowsUpLine: View {

    let count: Int
    /// Phase 4 (2026-06-19) — last 7 days as a dot pattern. nil →
    /// tap is a no-op (legacy callers). Each entry: true = engaged,
    /// false = open. Ordering oldest → today.
    var week: [Bool]? = nil
    /// Harness-only initial expanded state for screenshot capture.
    var debugInitialExpanded: Bool = false

    @State private var expanded: Bool = false

    var body: some View {
        let n = max(0, count)
        let dayWord = n == 1 ? "day" : "days"
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                (Text("you've shown up ")
                    .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                + Text("\(n)")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
                + Text(" \(dayWord) \u{2661}")
                    .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote)))
                    .foregroundStyle(Palette.cocoaTertiary)
            }

            if let week, (expanded || debugInitialExpanded) {
                weekDots(week)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard week != nil else { return }
            Haptics.tick()
            withAnimation(Motion.crossFade) { expanded.toggle() }
        }
        .accessibilityLabel("you've shown up \(n) \(dayWord)")
        .accessibilityHint(week != nil ? "tap to see this week's pattern" : "")
    }

    /// 7 small dots, today rightmost. Engaged = solid cocoa; open
    /// = hairline ring. Today gets an accent ring overlay regardless
    /// of state (matches Becoming's week-row dot convention).
    @ViewBuilder
    private func weekDots(_ week: [Bool]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(week.enumerated()), id: \.offset) { idx, done in
                let isToday = idx == week.count - 1
                ZStack {
                    if done {
                        Circle().fill(Palette.cocoaPrimary).frame(width: 8, height: 8)
                    } else {
                        Circle().stroke(Palette.divider, lineWidth: 1.2)
                            .frame(width: 8, height: 8)
                    }
                    if isToday {
                        Circle().stroke(Palette.accent, lineWidth: 1.2).frame(width: 14, height: 14)
                    }
                }
                .frame(width: 14, height: 14)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - HomeWelcomeBackLine
//
// Home Phase 3 retention atom (2026-06-19). Re-engagement line
// that surfaces when the user returns after a multi-day absence.
// Sits in the same vertical slot as the yesterday recap (only
// one of the two ever renders), and takes priority — recap is
// for the morning continuity beat; welcome-back is for the
// "she's back" moment, which is bigger.
//
// Tone: warm + non-judgmental. No "we missed you," no "where
// have you been," no shame about the gap. Panel 4 lock.

struct HomeWelcomeBackLine: View {

    /// Days since the last PlanView appearance. Drives the sentence
    /// variant — short gap (3-6) gets a soft "welcome back"; medium
    /// (7-13) gets warmer language; long (14+) leans into the
    /// permission frame.
    let daysAway: Int

    private var sentence: (prefix: String, italic: String, suffix: String) {
        switch daysAway {
        case ..<7:
            return ("", "welcome back", " \u{2661}")
        case 7..<14:
            return ("happy you're ", "here", " \u{2661}")
        default:
            return ("ready when ", "you are", " \u{2661}")
        }
    }

    var body: some View {
        let s = sentence
        (Text(s.prefix)
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
        + Text(s.italic)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
        + Text(s.suffix)
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote)))
            .foregroundStyle(Palette.cocoaTertiary)
            .accessibilityLabel("\(s.prefix)\(s.italic)\(s.suffix)")
    }
}

// MARK: - HomeYesterdayRecapLine
//
// Home Phase 3 retention atom (2026-06-19). First-of-day morning
// beat: a single italic-Fraunces line at the very top of the
// checklist card that acknowledges what she did yesterday before
// today's plan appears. Surfaces once per day, then auto-dismisses
// for the rest of the day (Panel 4: no nagging persistence).
//
// Gain-only: only renders when yesterday had ≥1 engagement bar
// (plate, session, or completed ritual). Zero-engagement days
// don't get a recap line — that would feel like surveillance. The
// line celebrates what counted, never what was missed.
//
// Sentence variants composed at the call site via YesterdayRecap.

enum YesterdayRecapKind: Equatable {
    case plates(Int)
    case rituals(Int)
    case mixed(plates: Int, rituals: Int)
    case engaged
}

/// Cohort routing for the recap verb. Each cohort gets a slightly
/// different italic punch — softer for GLP-1, nourishing for the
/// restrictive flag, neutral default. Avoids feature-promise copy
/// per [[feedback-no-feature-promises-until-shipped]]; only the
/// identity verb shifts, never the underlying action.
enum YesterdayRecapCohort {
    case `default`
    case glp1Current
    case restrictiveRisk

    /// Returns (plates_verb, rituals_verb, mixed_verb, engaged_verb)
    /// for this cohort.
    fileprivate var verbs: (plates: String, rituals: String, mixed: String, engaged: String) {
        switch self {
        case .glp1Current:
            return (plates: "softened", rituals: "held space", mixed: "showed up", engaged: "counted")
        case .restrictiveRisk:
            return (plates: "nourished", rituals: "moved", mixed: "took care", engaged: "counted")
        case .default:
            return (plates: "snapped", rituals: "finished", mixed: "showed up", engaged: "counted")
        }
    }
}

struct HomeYesterdayRecapLine: View {

    let kind: YesterdayRecapKind
    var cohort: YesterdayRecapCohort = .default

    private var sentence: (prefix: String, italic: String, suffix: String) {
        let v = cohort.verbs
        switch kind {
        case .plates(let n):
            let word = n == 1 ? "plate" : "plates"
            return ("yesterday you ", v.plates, " \(n) \(word) \u{2661}")
        case .rituals(let n):
            let word = n == 1 ? "ritual" : "rituals"
            return ("yesterday you ", v.rituals, " \(n) \(word) \u{2661}")
        case .mixed(let p, let r):
            let pw = p == 1 ? "plate" : "plates"
            let rw = r == 1 ? "ritual" : "rituals"
            return (
                "yesterday you ",
                v.mixed,
                " · \(p) \(pw) + \(r) \(rw) \u{2661}"
            )
        case .engaged:
            return ("yesterday ", v.engaged, " \u{2661}")
        }
    }

    var body: some View {
        let s = sentence
        (Text(s.prefix)
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
        + Text(s.italic)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
        + Text(s.suffix)
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote)))
            .foregroundStyle(Palette.cocoaTertiary)
            .accessibilityLabel("\(s.prefix)\(s.italic)\(s.suffix)")
    }
}

// MARK: - HomeTomorrowResetsLine
//
// Home Phase 3 retention atom (2026-06-19). After 9pm local, the
// day winds down and any still-open rows get a single warm closing
// line below the checklist instead of an implicit shame ("you didn't
// finish"). Panel 4 GLP-1 RD's anti-shame lock: tomorrow always
// resets ♡. JeniFit's anti-streak pattern in one phrase.
//
// Triggers when current hour >= 21 AND the day has any incomplete
// rows AND we're on the today view. Hidden on past view, hidden
// when everything is checked.

struct HomeTomorrowResetsLine: View {

    var body: some View {
        (Text("tomorrow ")
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
        + Text("resets")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
        + Text(" \u{2661}")
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote)))
            .foregroundStyle(Palette.cocoaTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .accessibilityLabel("tomorrow resets")
    }
}

// MARK: - HomeProteinTracker
//
// The founder's added ask: emphasize the protein tracker on Home on
// protein days. The cohort wedge no competitor surfaces — protein
// adequacy as the day's anchor signal. Mirrors the BecomingProteinTile
// design language (italic-Fraunces eyebrow, JeniHeroSerif numeral,
// gradient bar, status word stamp) but compressed for inline Home use.

struct HomeProteinTracker: View {

    let proteinG: Int
    /// 1.0 g/kg from onboarding weight, clamped 70…150. PlanView
    /// derives + passes; the atom doesn't compute.
    let targetG: Int
    /// True when glp1Status == "current" — drives the cohort copy
    /// (`muscle stays` vs `solid`).
    var isGLP1Current: Bool = false
    /// Phase 4 (2026-06-19) — plate sources for the long-press peek.
    /// Mirrors BecomingProteinTile.sources: top-3 plates by protein
    /// contribution today. nil → tile is non-interactive (legacy).
    var sources: [(entryId: String, proteinG: Int)]? = nil
    /// Harness-only initial peeking state for screenshot capture.
    var debugInitialPeeking: Bool = false

    @State private var peeking: Bool = false

    private var topSources: [(entryId: String, proteinG: Int)] {
        (sources ?? []).sorted { $0.proteinG > $1.proteinG }.prefix(3).map { $0 }
    }

    private var progress: Double {
        guard targetG > 0 else { return 0 }
        return min(1.0, Double(proteinG) / Double(targetG))
    }

    private var statusWord: (prefix: String, italic: String) {
        let pct = targetG > 0
            ? Double(proteinG) / Double(targetG) * 100
            : 0
        switch pct {
        case ..<60:
            return ("still ", "time")
        case ..<95:
            return isGLP1Current
                ? ("muscle ", "stays")
                : ("", "solid")
        case ..<120:
            return ("", "hits enough \u{2661}")
        default:
            return ("", "well-fed")
        }
    }

    private var statusColor: Color {
        let pct = targetG > 0
            ? Double(proteinG) / Double(targetG) * 100
            : 0
        return pct >= 95 ? Palette.stateGood : Palette.cocoaSecondary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Numeral block — left third
            VStack(alignment: .leading, spacing: 0) {
                Text("protein")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.4)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(proteinG)")
                        .font(.custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title2))
                        .foregroundStyle(Palette.cocoaPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("g")
                        .font(.custom("JeniHeroSerif-Italic", size: 18, relativeTo: .title3))
                        .foregroundStyle(Palette.accent)
                    Text("of ~\(targetG)g")
                        .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .baselineOffset(4)
                        .padding(.leading, 2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if (peeking || debugInitialPeeking), !topSources.isEmpty {
                        platePeekStrip
                            .transition(.opacity)
                            .id("peek")
                    } else {
                        bar
                        statusLine
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FFFAF8"),
                            Color(hex: "#FBF2EE"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.textPrimary.opacity(0.07), lineWidth: 0.75)
        )
        .shadow(
            color: Color(red: 0.36, green: 0.20, blue: 0.18).opacity(0.06),
            radius: 14,
            x: 0,
            y: 4
        )
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
        .accessibilityLabel("\(proteinG) of \(targetG) grams of protein today, \(statusWord.prefix)\(statusWord.italic)")
        .accessibilityHint(topSources.isEmpty ? "" : "long press to see the plates that built it")
    }

    /// Phase 4 — horizontal mini-row of up to 3 plate thumbnails
    /// behind the protein numeral. Falls back to a rose rect when
    /// no photo (mock data + plates logged without snaps).
    @ViewBuilder
    private var platePeekStrip: some View {
        HStack(spacing: 4) {
            ForEach(topSources, id: \.entryId) { src in
                ZStack(alignment: .bottomTrailing) {
                    if let img = FoodPhotoStore.photo(entryId: src.entryId) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Palette.accent.opacity(0.18))
                            .frame(width: 36, height: 36)
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
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.textPrimary.opacity(0.10))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Palette.accent.opacity(0.95),
                                Palette.accent.opacity(0.62),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * progress))
                    .animation(.easeOut(duration: 0.6), value: progress)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder private var statusLine: some View {
        let s = statusWord
        (Text(s.prefix)
            .font(.custom("DMSans-Regular", size: 13))
        + Text(s.italic)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14)))
            .foregroundStyle(statusColor)
            .lineLimit(1)
    }
}
