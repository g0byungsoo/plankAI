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
    // Regimen rows (v8; v24 adds the daily cadence).
    func doseDay() -> VoiceLine
    func dailyDose(oral: Bool) -> VoiceLine
    func hydrationTitration() -> VoiceLine
    // v9 P1 — the weekly Body Vision invitation (offered, never debt).
    func bodyScanInvitation(first: Bool) -> VoiceLine
    // v9 P4 — the body-outcome axis.
    func preservationAtRisk() -> VoiceLine
    func plateauHold() -> VoiceLine
    // v25 E1 — the walking action (the gap against her own goal).
    func walkGap(remainingSteps: Int) -> VoiceLine
    func walkAfterMeal() -> VoiceLine
    // v25 E2 — the cycle reaches the day's reasons (position and
    // tendency words, never predictions; "often" is the register).
    func lateCycleAppetite() -> VoiceLine
    func lateSlotOpen(weekdayWord: String) -> VoiceLine
}

// v25 E2 — defaults so existing conformers (test doubles) keep
// compiling; jeni overrides with her own words below.
extension BrandVoice {
    func lateCycleAppetite() -> VoiceLine {
        VoiceLine(text: "appetite often stirs about now. protein holds the line",
                  italics: ["often"])
    }
    func lateSlotOpen(weekdayWord: String) -> VoiceLine {
        VoiceLine(text: "\(weekdayWord)'s dose is still open. log it late, or let it go")
    }
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
        // v25 E2 — the week gets its name from the first dose
        // (08_E2 outcome 1): still a fact, now an anchor.
        VoiceLine(text: "your dose day. the week starts here")
    }
    func lateCycleAppetite() -> VoiceLine {
        // The return of appetite NAMED before she blames herself
        // (the era's core normalization) — tendency register only.
        VoiceLine(text: "appetite often stirs about now. protein holds the line",
                  italics: ["often"])
    }
    func lateSlotOpen(weekdayWord: String) -> VoiceLine {
        // v24's exact late language, now with an in-app door.
        VoiceLine(text: "\(weekdayWord)'s dose is still open. log it late, or let it go")
    }
    func dailyDose(oral: Bool) -> VoiceLine {
        // v24 — the daily cadence (pills, daily injectables). Same
        // clinical register: a fact, not a cheer. The empty-stomach
        // guidance lives in the sheet + reminder, never the row.
        oral
            ? VoiceLine(text: "your daily pill")
            : VoiceLine(text: "your daily dose")
    }
    func hydrationTitration() -> VoiceLine {
        VoiceLine(text: "water sits easier than food these weeks. small sips count")
    }
    func bodyScanInvitation(first: Bool) -> VoiceLine {
        // Clinical register (L6): a fact and an instruction, zero
        // cheer. The repeat line teaches consistency — same light,
        // same spot is what makes week 6 comparable to week 1.
        first
            ? VoiceLine(text: "your record starts with one scan")
            : VoiceLine(text: "scan day. same spot, same light")
    }
    func preservationAtRisk() -> VoiceLine {
        VoiceLine(
            text: "the week ran fast with protein under. protein first protects muscle",
            italics: ["protein first"]
        )
    }
    func plateauHold() -> VoiceLine {
        // Linde 2004 — the plateau named early, as support, never a
        // push. Maintainers see these too; the plan simply holds.
        VoiceLine(
            text: "plateau week. your body's adjusting. the plan holds",
            italics: ["plateau"]
        )
    }
    func walkGap(remainingSteps: Int) -> VoiceLine {
        // Gain-frame law: the gap is room left, never a debt. The
        // minutes translate the number into a decision (~105
        // steps/min easy pace, rounded to a friendly 5).
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let steps = formatter.string(from: NSNumber(value: remainingSteps))
            ?? "\(remainingSteps)"
        let minutes = max(5, Int((Double(remainingSteps) / 105.0 / 5.0).rounded()) * 5)
        return VoiceLine(text: "\(steps) steps left · about \(minutes) minutes")
    }
    func walkAfterMeal() -> VoiceLine {
        // Glucose framing only (r4 PROVEN); digestion comfort said
        // softly; never calories, never earn/burn.
        VoiceLine(
            text: "after a full plate, ten gentle minutes help it settle",
            italics: ["ten gentle minutes"]
        )
    }
}
