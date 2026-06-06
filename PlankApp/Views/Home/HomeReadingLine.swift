import SwiftUI
import PlankSync

/// Top-of-Home typographic "reading" line. Per the 3 luxury fitness
/// designer briefs (docs/home_aesthetic_redesign_briefs_2026_06_06.md)
/// — Lasta + Flo + Apple Fitness all independently called for the
/// same move: a designed Fraunces line at the top of Home pulled
/// from HER data, not the app's. Makes Home feel **authored**
/// before she touches a tile.
///
/// > "Lasta's home leads with a Fraunces italic line that reflects
/// >  *her* state, not the app's — pulled from her most recent
/// >  logged signal ... the single highest-retention pattern in
/// >  luxury-WL because it makes the app feel like it noticed her
/// >  before she has to do anything."
///
/// Copy cascade (most-retention-load-bearing first):
///   1. Yesterday had a session → "yesterday was *gentle*. today, your call ♥"
///   2. Returning after ≥7 days → "no catching up needed ♥"
///   3. Shown up ≥3 times this week → "you showed up *N* days this week ♥"
///   4. Shown up 1-2 times this week → "you *showed up*. that's the whole thing ♥"
///   5. Fresh user (no sessions) → "today is the page ♥"
///
/// Italic-Fraunces SemiBoldItalic on ONE punch word per line (voice
/// signal as rare jewel). DM Sans 22pt body. Cocoa-secondary so the
/// reading register reads as quiet observation, not announcement.
/// No card chrome — generous 32pt top + 24pt bottom padding.
///
/// Render with the parent view supplying the data — keeps this view
/// stateless and unit-testable.
struct HomeReadingLine: View {
    let mostRecentSessionAt: Date?
    let sessionsThisWeek: Int
    let totalSessionCount: Int

    var body: some View {
        ItalicAccentText(
            reading.text,
            italic: reading.italic,
            baseFont: .custom("DMSans-Regular", size: 22),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
            color: Palette.cocoaSecondary,
            alignment: .leading
        )
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .accessibilityLabel(reading.text)
    }

    private struct Reading {
        let text: String
        let italic: [String]
    }

    /// Compute the reading from her data. Cascade prioritizes the
    /// most retention-critical state at each open.
    private var reading: Reading {
        let cal = Calendar.current
        let now = Date()
        let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: now)!)
        let dayAfterYesterday = cal.startOfDay(for: now)

        // Yesterday had a session → soft acknowledgment
        if let last = mostRecentSessionAt,
           last >= yesterday, last < dayAfterYesterday {
            return Reading(text: "yesterday was gentle. today, your call ♥", italic: ["gentle"])
        }

        // Returning after ≥7 days off
        if let last = mostRecentSessionAt {
            let daysSince = cal.dateComponents([.day], from: last, to: now).day ?? 0
            if daysSince >= 7 {
                return Reading(text: "no catching up needed ♥", italic: [])
            }
        }

        // Shown up multiple times this week
        if sessionsThisWeek >= 3 {
            return Reading(text: "you showed up \(numberWord(sessionsThisWeek)) days this week ♥", italic: [numberWord(sessionsThisWeek)])
        }
        if sessionsThisWeek >= 1 {
            return Reading(text: "you showed up. that's the whole thing ♥", italic: ["showed up"])
        }

        // Fresh user
        if totalSessionCount == 0 {
            return Reading(text: "today is the page ♥", italic: ["today"])
        }

        // Default: kind, low-pressure
        return Reading(text: "soft start. one move opens the rest ♥", italic: ["soft"])
    }

    /// "3" → "three", "4" → "four", etc. Italic-Fraunces reads better
    /// on a spelled-out number than a digit (matches the "italic ONLY
    /// on copy" voice lock — words italicize gracefully, digits don't).
    private func numberWord(_ n: Int) -> String {
        switch n {
        case 1: return "one"
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        case 7: return "seven"
        default: return "\(n)"
        }
    }
}

#if DEBUG
#Preview("Yesterday session") {
    HomeReadingLine(
        mostRecentSessionAt: Calendar.current.date(byAdding: .day, value: -1, to: .now),
        sessionsThisWeek: 2,
        totalSessionCount: 14
    )
    .padding(.horizontal, 20)
    .background(Palette.bgPrimary)
}

#Preview("3+ this week") {
    HomeReadingLine(
        mostRecentSessionAt: .now,
        sessionsThisWeek: 4,
        totalSessionCount: 28
    )
    .padding(.horizontal, 20)
    .background(Palette.bgPrimary)
}

#Preview("Fresh user") {
    HomeReadingLine(
        mostRecentSessionAt: nil,
        sessionsThisWeek: 0,
        totalSessionCount: 0
    )
    .padding(.horizontal, 20)
    .background(Palette.bgPrimary)
}
#endif
