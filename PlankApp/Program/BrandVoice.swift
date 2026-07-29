import Foundation

// MARK: - BrandVoice
//
// App v8 (docs/app_v8/03_ARCHITECTURE.md §3e) — the rules/voice
// split the v7 thesis named (§4): clinical logic emits typed
// outcomes; a voice layer renders the prose. jeni's exact shipped
// strings are the default implementation (snapshot-tested
// byte-identical), so changing the words for a future tenant —
// or a founder register pass — never touches a clinical rule.
//
// S1 scope: CarePlanEngine's spoken reasons only. DailyBriefEngine
// / WeeklyReview / Signals migrate opportunistically (named debt,
// 04_DECISIONS). A line's italics ride beside its text (the
// ItalicAccentText composition law — never markdown markers).

struct VoiceLine: Equatable, Sendable {
    var text: String
    var italics: [String] = []
}

protocol BrandVoice: Sendable {
    // Gentle-day reasons (one move, spoken softly).
    func gentleTender() -> VoiceLine
    func gentleShortNight(hours: Int, minutes: Int) -> VoiceLine
    func gentleReturn(daysAway: Int) -> VoiceLine
    // Supporting-move reasons.
    func weighInStale() -> VoiceLine
    /// Why a CADENCE weigh-in is here today (founder refinement:
    /// every ringed row answers "why is this here today").
    func weighInCadence(keeping: Bool) -> VoiceLine
    /// Why the demoted dose-day keystone (the food anchor) still
    /// rides the plan under the medication lead.
    func keystoneProteinAnchor() -> VoiceLine
    // Clinical lead promotions.
    func rapidLossProteinFirst() -> VoiceLine
    func proteinDeficit(gapG: Int) -> VoiceLine
    // Regimen rows (v8).
    func doseDay() -> VoiceLine
    func hydrationTitration() -> VoiceLine
}

/// jeni — the org-null tenant's voice. These strings are the
/// shipped literals, moved, not rewritten.
struct JeniVoice: BrandVoice {
    func gentleTender() -> VoiceLine {
        VoiceLine(text: "yesterday read tender. just this, nothing else")
    }
    func gentleShortNight(hours: Int, minutes: Int) -> VoiceLine {
        VoiceLine(text: "short night (\(hours)h \(String(format: "%02d", minutes))m). one thing is the whole plan")
    }
    func gentleReturn(daysAway: Int) -> VoiceLine {
        VoiceLine(text: "back after \(daysAway) days. one small thing restarts it")
    }
    func weighInStale() -> VoiceLine {
        VoiceLine(text: "first one in a while")
    }
    func weighInCadence(keeping: Bool) -> VoiceLine {
        keeping
            ? VoiceLine(text: "the weekly band check. 30 seconds")
            : VoiceLine(text: "the trend reads the week, not the day")
    }
    func keystoneProteinAnchor() -> VoiceLine {
        VoiceLine(text: "protein still anchors the day")
    }
    func rapidLossProteinFirst() -> VoiceLine {
        VoiceLine(
            text: "losing fast. protein first protects muscle",
            italics: ["protein first"]
        )
    }
    func proteinDeficit(gapG: Int) -> VoiceLine {
        VoiceLine(text: "yesterday landed \(gapG)g under your protein floor")
    }
    func doseDay() -> VoiceLine {
        // Founder refinement 2026-07-28: the medication register is
        // clinical — a statement of fact, zero reward vocabulary
        // (NN/g seriousness-congruence: playful reads less
        // trustworthy on clinical tasks). The timestamp after the
        // mark is the only reward.
        VoiceLine(text: "your dose day")
    }
    func hydrationTitration() -> VoiceLine {
        VoiceLine(text: "water sits easier than food these weeks. small sips count")
    }
}
