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
    func doseDay(cadence: MedicationScheduleEngine.Cadence?) -> VoiceLine
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
        VoiceLine(text: "appetite often comes back about now. protein first helps",
                  italics: ["often"])
    }
    func lateSlotOpen(weekdayWord: String) -> VoiceLine {
        VoiceLine(text: "\(weekdayWord)'s dose is still open")
    }
}

/// jeni — the org-null tenant's voice. These strings are the
/// shipped literals, moved, not rewritten.
struct JeniVoice: BrandVoice {
    func gentleTender() -> VoiceLine {
        VoiceLine(text: "yesterday sounded rough. just this one thing today")
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
            : VoiceLine(text: "30 seconds. it keeps your trend honest")
    }
    func keystoneProteinAnchor() -> VoiceLine {
        VoiceLine(text: "protein first is still the plan")
    }
    func rapidLossProteinFirst() -> VoiceLine {
        VoiceLine(
            text: "losing fast. protein first protects muscle",
            italics: ["protein first"]
        )
    }
    func proteinDeficit(gapG: Int) -> VoiceLine {
        VoiceLine(text: "yesterday was \(gapG) g short of your protein goal")
    }
    func doseDay(
        cadence: MedicationScheduleEngine.Cadence?
    ) -> VoiceLine {
        // Founder refinement 2026-07-28: the medication register is
        // clinical — a statement of fact, zero reward vocabulary
        // (NN/g seriousness-congruence: playful reads less
        // trustworthy on clinical tasks). The timestamp after the
        // mark is the only reward.
        // v25 E2 — the week gets its name from the first dose
        // (08_E2 outcome 1): still a fact, now an anchor.
        // p55 — an anchor SHE has: "the week starts here" was said
        // to every-N and split users, asserting a weekly rhythm
        // they do not keep. The interval user's dose starts her
        // rhythm; a split user's Thursday starts nothing — the
        // plain fact is the whole sentence there.
        switch cadence {
        case .weekly:
            return VoiceLine(text: "your dose day. the week starts here")
        case .everyNDays:
            return VoiceLine(text: "your dose day. the rhythm starts here")
        default:
            return VoiceLine(text: "your dose day.")
        }
    }
    func lateCycleAppetite() -> VoiceLine {
        // The return of appetite NAMED before she blames herself
        // (the era's core normalization) — tendency register only.
        VoiceLine(text: "appetite often comes back about now. protein first helps",
                  italics: ["often"])
    }
    func lateSlotOpen(weekdayWord: String) -> VoiceLine {
        // The row states the fact (it must survive one line — a
        // frame-caught truncation); the sheet carries "log it
        // late, or let it go" + the label facts.
        VoiceLine(text: "\(weekdayWord)'s dose is still open")
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
        VoiceLine(text: "water goes down easier than food these weeks. small sips count")
    }
    func bodyScanInvitation(first: Bool) -> VoiceLine {
        // Clinical register (L6): a fact and an instruction, zero
        // cheer. The repeat line teaches consistency — same light,
        // same spot is what makes week 6 comparable to week 1.
        first
            ? VoiceLine(text: "one scan is all it takes to start")
            : VoiceLine(text: "scan day. same spot, same light")
    }
    func preservationAtRisk() -> VoiceLine {
        VoiceLine(
            text: "the weight moved fast this week and protein ran low. protein first protects muscle",
            italics: ["protein first"]
        )
    }
    func plateauHold() -> VoiceLine {
        // Linde 2004 — the plateau named early, as support, never a
        // push. Maintainers see these too; the plan simply holds.
        // p54 — "your body's adjusting" left the sentence: metabolic-
        // ward measurements put adaptation at a stall near 40-90
        // kcal/day, too small to be the cause and not predictive of
        // regain (Martins 2020; Hall's validated model reproduces the
        // plateau from intake drift alone). The line now says what the
        // record supports — the trend is the measure — instead of a
        // physiological story the evidence contradicts.
        VoiceLine(
            text: "a plateau week. normal, and the plan holds. watch the trend, not one morning",
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
