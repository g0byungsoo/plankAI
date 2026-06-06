import SwiftUI
import PlankSync
import PlankFood

// MARK: - SundayCard
//
// v1.0.7 Phase C.2 — Spotify-Wrapped-miniaturized weekly composition
// per the retention expert brief
// (docs/home_becoming_research_retention_2026_06_06.md):
//
// > "Ship the Sunday Card on Becoming. A screenshot-shareable,
// >  weekly-varying 'your week ♥' composition layered over the
// >  existing 5 chapters. This is the Spotify-Wrapped pattern
// >  miniaturized — Spotify pulled 200M users in 24h and 500M
// >  shares in 2025, and Strava moved Year-in-Sport behind a
// >  paywall."
//
// What it shows (week-by-week varies; week-1 users get a softer
// composition):
//   - Italic-Fraunces hero: "your week, [name] ♥" (or "your week ♥"
//     when name unknown)
//   - 4 quiet stat reads pulled from collected data only:
//       · weight delta (logged) — "down 0.4 lb" / "even" / "up 0.2 lb"
//       · days you breathed
//       · sessions logged
//       · plates snapped (food rail users only)
//   - ShareLink so the user can post to TikTok / IG — the retention
//     loop the brief flagged as the highest organic acquisition lever
//     for our cohort.
//
// Timing per retention brief:
//   - Fri evening → Mon end-of-day: prominent at top of Becoming
//   - Tue–Thu: hidden (Becoming reads as chapters only)
//
// Anti-shame guardrails (per brand voice lock):
//   - Empty stats render as "—" not "0"; the hero still ships ♥
//   - No streak language ("3 weeks running") — pure this-week read
//   - No comparison vs previous week — the cohort-specific brief was
//     explicit on this. Comparison breeds anxiety.

struct SundayCard: View {

    let userName: String
    let weeklyWeightDelta: String?   // pre-formatted "down 0.4 lb" / "even" / "up 0.2 lb" / nil
    let breathDaysThisWeek: Int
    let sessionsThisWeek: Int
    let platesThisWeek: Int
    let voicePreference: String      // for the coach quote
    let isFoodRailEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroLine

            VStack(alignment: .leading, spacing: 10) {
                if let delta = weeklyWeightDelta {
                    statRow(label: "weight", value: delta, italicPunch: "weight")
                }
                if breathDaysThisWeek > 0 {
                    let dayWord = breathDaysThisWeek == 1 ? "day" : "days"
                    statRow(label: "breathed", value: "\(breathDaysThisWeek) \(dayWord)", italicPunch: "breathed")
                }
                if sessionsThisWeek > 0 {
                    let s = sessionsThisWeek == 1 ? "session" : "sessions"
                    statRow(label: "sessions", value: "\(sessionsThisWeek) \(s)", italicPunch: "sessions")
                }
                if isFoodRailEnabled, platesThisWeek > 0 {
                    let p = platesThisWeek == 1 ? "plate" : "plates"
                    statRow(label: "plates", value: "\(platesThisWeek) \(p)", italicPunch: "plates")
                }
                if !hasAnyStocked {
                    Text("the page is open ♥")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            HStack {
                ShareLink(item: shareText) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("share")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("share your week")
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.accent.opacity(0.12))
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.accentSubtle)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
        .overlay(alignment: .topTrailing) {
            Image(StickerName.sparkleGlossy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(12))
                .offset(x: 10, y: -14)
                .accessibilityHidden(true)
        }
    }

    private var heroLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SUNDAY ♥")
                .font(.custom("Fraunces72pt-SemiBold", size: 11))
                .tracking(2)
                .foregroundStyle(Palette.accent)
            // Italic-Fraunces on "week" punch word — voice signal lock.
            (Text("your ")
                .font(.custom("Fraunces72pt-SemiBold", size: 26))
                .foregroundStyle(Palette.textPrimary)
             + Text("week")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
                .foregroundStyle(Palette.textPrimary)
             + Text(userName.isEmpty ? " ♥" : ", \(userName.lowercased()) ♥")
                .font(.custom("Fraunces72pt-SemiBold", size: 26))
                .foregroundStyle(Palette.textPrimary))
        }
    }

    private func statRow(label: String, value: String, italicPunch: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .foregroundStyle(Palette.accent)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var hasAnyStocked: Bool {
        weeklyWeightDelta != nil
            || breathDaysThisWeek > 0
            || sessionsThisWeek > 0
            || (isFoodRailEnabled && platesThisWeek > 0)
    }

    /// Composed share text for the ShareLink. Anti-shame + brand-voice
    /// locked. The user shares an editorial-feel one-paragraph weekly
    /// recap, not a screenshot of metrics. Keeps the post lightweight
    /// for TikTok / IG without forcing the user to assemble copy.
    private var shareText: String {
        let openerName = userName.isEmpty ? "" : "\(userName.lowercased()), "
        var lines: [String] = ["\(openerName)my week with jenifit ♥"]
        if let delta = weeklyWeightDelta {
            lines.append("· \(delta) this week")
        }
        if breathDaysThisWeek > 0 {
            lines.append("· breathed \(breathDaysThisWeek) day\(breathDaysThisWeek == 1 ? "" : "s")")
        }
        if sessionsThisWeek > 0 {
            lines.append("· \(sessionsThisWeek) session\(sessionsThisWeek == 1 ? "" : "s")")
        }
        if isFoodRailEnabled, platesThisWeek > 0 {
            lines.append("· \(platesThisWeek) plate\(platesThisWeek == 1 ? "" : "s") logged")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Public visibility helper

    /// Per retention brief: visible Fri evening → Mon end-of-day; hidden
    /// the rest of the week. Returns true when the Sunday Card should
    /// render at the top of Becoming. Keeps `weekDay > 4` Mon-Fri off
    /// to satisfy the "1-3 day visibility window" requirement.
    static func shouldShowNow(_ now: Date = Date()) -> Bool {
        // Weekday numbering: Sunday = 1, Saturday = 7. Fri evening (6)
        // → Mon end-of-day (2) is the visibility window; Tue (3) - Thu
        // (5) hidden.
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        switch weekday {
        case 1, 2, 7: return true   // Sun, Mon, Sat
        case 6:                     // Fri — only after 18:00 local
            let hour = cal.component(.hour, from: now)
            return hour >= 18
        default: return false       // Tue, Wed, Thu
        }
    }
}
