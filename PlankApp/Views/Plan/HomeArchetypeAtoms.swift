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

    var body: some View {
        let sentence = archetype.headerSentence
        (Text(sentence.prefix)
            .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3))
        + Text(sentence.italic)
            .font(.custom("JeniHeroSerif-Italic", size: 26, relativeTo: .title3))
        + Text(sentence.suffix)
            .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title3)))
            .foregroundStyle(pastDay
                ? Palette.cocoaPrimary.opacity(0.55)
                : Palette.cocoaPrimary)
            .kerning(-0.3)
            .lineSpacing(-4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(sentence.prefix)\(sentence.italic)\(sentence.suffix)")
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
