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

    private var sentence: (prefix: String, italic: String, suffix: String) {
        if kindToday {
            return ("today is a ", "kind", " day \u{2661}")
        }
        return archetype.headerSentence
    }

    var body: some View {
        let s = sentence
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
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.6) {
                guard !pastDay, !kindToday else { return }
                onLongPressKind?()
            }
            .accessibilityLabel("\(s.prefix)\(s.italic)\(s.suffix)")
            .accessibilityAddTraits(onLongPressKind != nil && !pastDay && !kindToday
                ? .isButton
                : [])
            .accessibilityHint(onLongPressKind != nil && !pastDay && !kindToday
                ? "long press to mark today kind"
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

    var body: some View {
        let n = max(0, count)
        let dayWord = n == 1 ? "day" : "days"
        (Text("you've shown up ")
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
        + Text("\(n)")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14, relativeTo: .footnote))
        + Text(" \(dayWord) \u{2661}")
            .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote)))
            .foregroundStyle(Palette.cocoaTertiary)
            .accessibilityLabel("you've shown up \(n) \(dayWord)")
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
                bar
                statusLine
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(proteinG) of \(targetG) grams of protein today, \(statusWord.prefix)\(statusWord.italic)")
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
