import SwiftUI
import PlankSync

// MARK: - v1.0.7 Becoming snapshot tiles
//
// Per docs/becoming_snapshot_redesign_briefs_2026_06_06.md — 3
// luxury fitness designers (Equinox+, Apple Fitness+, Whoop/Oura)
// converged on: 5 chapter spreads kill ~400pt of pacing chrome.
// Replace with a one-viewport snapshot dashboard. This file ships
// the small reusable tiles for that snapshot (status strip, stat
// tile, movement tile, coach line).
//
// Voice + type locks (sacred, this session):
//   - Italic-Fraunces ONLY on COPY punch words (not numbers)
//   - Hero numerals Fraunces Light 64pt tabular cocoa-100
//   - Stat numerals DM Sans Medium 22pt tabular
//   - 3-tier cocoa scale (100 / 72 / 48)
//   - 0.5pt cocoa-12 hairlines NEVER 1pt
//   - Lowercase casual, hearts ♥ as terminal punctuation only

// MARK: - BecomingStatusStrip
//
// Top-of-screen 44pt strip. Replaces the page hero ("you're /
// becoming steady.") with the Equinox+ concierge tell — date on
// the left, italic-Fraunces state word on the right computed from
// the 28-day EMA slope. She glances top-right and knows her state
// in 0.5s before reading a single number.
//
// State vocabulary (3 words, anti-shame-locked):
//   ↘ losing  — trend EMA moving toward weight-loss goal
//   → steady  — flat or near-flat (no meaningful slope)
//   ↗ rising  — trend EMA moving away from goal direction
//
// "rising" replaces the more clinical "regaining" per voice lock —
// the cohort tested poorly against direct goal-direction words
// for the off-goal state; "rising" reads physical (a number goes
// up) without scoring her behavior.

struct BecomingStatusStrip: View {
    let weightLogs: [WeightLogRecord]

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dateText)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.cocoaSecondary)
            Text("♥")
                .font(.system(size: 11))
                .foregroundStyle(Palette.cocoaTertiary)
            Spacer()
            if let state = trendState {
                HStack(spacing: 4) {
                    Text(state.arrow)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.jeweledRose.opacity(0.85))
                    Text(state.word)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                        .foregroundStyle(Palette.jeweledRose)
                }
                .accessibilityLabel("Trend \(state.word)")
            }
        }
        .frame(height: 28)
        .padding(.top, 4)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE 'week' w"
        return f.string(from: .now).lowercased()
    }

    private struct TrendState { let arrow: String; let word: String }

    /// Compute the 28-day EMA slope and map to a 3-word state.
    /// Returns nil with <2 logs (no signal to label).
    private var trendState: TrendState? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
        let recent = weightLogs.filter { $0.loggedAt >= cutoff }.sorted { $0.loggedAt < $1.loggedAt }
        guard recent.count >= 2 else { return nil }

        let alpha: Double = 2.0 / (7.0 + 1.0)
        var ema: [Double] = []
        for (i, log) in recent.enumerated() {
            if i == 0 { ema.append(log.weightKg) }
            else { ema.append(alpha * log.weightKg + (1 - alpha) * ema[i - 1]) }
        }
        guard let first = ema.first, let last = ema.last else { return nil }
        let deltaKg = last - first
        if abs(deltaKg) < 0.3 {
            return .init(arrow: "→", word: "steady")
        } else if deltaKg < 0 {
            return .init(arrow: "↘", word: "losing")
        } else {
            return .init(arrow: "↗", word: "rising")
        }
    }
}

// MARK: - BecomingStatTile
//
// Reusable secondary tile for the 2-up row below the weight hero.
// Used for: streak count, plank PR. Per the Equinox+ / Apple
// hybrid: label (DM Sans 11pt uppercase tracking +0.06em cocoa-48)
// + big numeral (Fraunces Light 36pt tabular cocoa-100) + tiny
// supporting hint underneath.
//
// No card chrome — sits flush on the cream backdrop. 0.5pt cocoa-12
// hairline TOP only (visual separator between tile pair and the
// weight hero above; bottom hairline is owned by the next module).

struct BecomingStatTile: View {
    let label: String          // e.g. "STREAK"
    let value: String          // e.g. "12" or "1:42"
    let hint: String?          // e.g. "days ♥" or "personal best"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("Fraunces72pt-Light", size: 36))
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaPrimary)
                .contentTransition(.numericText())
            if let hint {
                Text(hint)
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(hint ?? "")")
    }
}

// MARK: - BecomingMovementTile
//
// Composite movement signal — collapses what was Chapter III (3
// separate bento tiles for steps / breath / sessions) into ONE
// full-width row. Per founder pick: "Composite tile — steps +
// breath + workout sessions in 1 row." Lowest-cost movement
// summary (no ring math needed).
//
// Layout: 3 micro-stat columns left + italic caption right
// ("today's *moved*"). Each column = label tracked +0.06em + DM
// Sans Medium 22pt tabular number (same register as
// BecomingDashboardHero's stat row, so the tile reads as one
// system with the rest of the snapshot).

struct BecomingMovementTile: View {
    let stepsToday: Int
    let breathSessionsToday: Int
    let workoutSessionsThisWeek: Int

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            statColumn(label: "STEPS", value: "\(stepsToday)")
            statColumn(label: "BREATH", value: "\(breathSessionsToday)")
            statColumn(label: "SESSIONS", value: "\(workoutSessionsThisWeek)")
            Spacer(minLength: 8)
            (Text("today's ").font(.custom("DMSans-Regular", size: 13))
             + Text("moved").font(.custom("Fraunces72pt-SemiBoldItalic", size: 13)))
                .foregroundStyle(Palette.cocoaSecondary)
        }
        .padding(.vertical, Space.md)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today: \(stepsToday) steps, \(breathSessionsToday) breath sessions, \(workoutSessionsThisWeek) workouts this week")
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(Typo.numeralStat)
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - BecomingCoachLine
//
// One-sentence coach voice surface — the only editorial moment in
// the snapshot above the fold. Replaces the Chapter I coachTile
// + the page-hero subhero (both killed). DM Sans 15pt cocoa-72
// with italic-Fraunces on the punch verb. No card chrome, no
// avatar, no sticker — Aesop's "italic only when it earns it"
// register.

struct BecomingCoachLine: View {
    /// Caller passes a pre-composed line. Italic punch word is
    /// inline via the [italic:] token sequence — same `ItalicAccentText`
    /// pattern used in chapter headers.
    let line: String
    let italicWords: [String]

    var body: some View {
        ItalicAccentText(
            line,
            italic: italicWords,
            baseFont: .custom("DMSans-Regular", size: 15),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 15),
            color: Palette.cocoaSecondary,
            alignment: .leading
        )
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, Space.md)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }
}
