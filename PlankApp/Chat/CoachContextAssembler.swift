import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - CoachContextAssembler
//
// App v2 (docs/app_v2/05_CHAT.md). Builds the provenance-only
// grounding envelope jeni reads. Rules: every field traces to a
// stored record; fields the user never provided are OMITTED, not
// defaulted; numeric-suppressed cohorts get no kcal/weight numerics
// at all. Derived aggregates only — no photos, no raw journal rows.

enum CoachContextAssembler {

    @MainActor
    static func assemble(userId: String, in context: ModelContext) -> [String: Any] {
        let snapshot = TodayStateService.snapshot(userId: userId, in: context)
        let d = UserDefaults.standard
        var out: [String: Any] = [:]

        if let name = d.string(forKey: "userName"), !name.isEmpty {
            out["name"] = name.lowercased()
        }
        out["cohort"] = cohortWord
        if CohortStore.isMaintenanceMode { out["program_mode"] = "maintenance" }
        // v3 — the chapter spine grounds jeni's register (losing /
        // on_medication / keeping), the band zone grounds keeping
        // conversations, kept-days grounds identity evidence, and the
        // break state tells her to hold plan-talk entirely.
        out["chapter"] = CohortStore.chapter.rawValue
        if snapshot.isOnBreak { out["on_break"] = true }
        if let zone = snapshot.bandZone { out["band_zone"] = zone }
        let kept = PresenceLedger.keptDays
        if kept > 0 { out["kept_days"] = kept }

        // — plan
        if let day = snapshot.day, snapshot.isEnrolled {
            var plan: [String: Any] = [
                "day": snapshot.programDay,
                "total": snapshot.totalDays,
                "archetype": day.archetype.rawValue,
                "beats": day.beats.map(\.itemKey),
                "done": day.beats.map(\.itemKey).filter {
                    let s = snapshot.checkStates[$0] ?? "empty"
                    return s == "complete" || s == "autoCompleted"
                },
            ]
            if let tier = snapshot.plan?.intensityTier { plan["tier"] = tier }
            // v4 — the arc: jeni can answer "why is this week like
            // this?" from the same spine the app renders.
            if let phase = snapshot.arcPhase {
                plan["phase"] = phase.name
                plan["week"] = snapshot.programWeek
                plan["week_of"] = snapshot.totalWeeks
            }
            if let intent = snapshot.weekIntent {
                plan["week_intent"] = intent.name
                plan["week_line"] = intent.line
            }
            if let signed = WeeklyReview.records(userId: userId).last {
                plan["last_resigning"] = [
                    "week": signed.weekIndex,
                    "decision": signed.decision,
                    "stamp": signed.stampLine,
                ]
            }
            out["plan"] = plan
        }

        let suppressed = snapshot.targets.numericsSuppressed
        out["flags"] = [
            "numeric_suppression": suppressed,
            "restrictive_risk": CohortStore.isRestrictiveRisk,
            "maintenance": CohortStore.isMaintenanceMode,
        ]

        // — weight (omitted entirely under suppression)
        if !suppressed {
            var weight: [String: Any] = [:]
            if let kg = snapshot.latestWeightKg { weight["current_kg"] = round1(kg) }
            if let goal = snapshot.plan?.goalWeightKg { weight["goal_kg"] = round1(goal) }
            if let start = snapshot.plan?.currentWeightKg { weight["start_kg"] = round1(start) }
            if let delta = snapshot.emaDelta7dKg { weight["ema_delta_7d_kg"] = round1(delta) }
            if let ago = snapshot.lastWeighInDaysAgo { weight["last_logged_days_ago"] = ago }
            if !weight.isEmpty { out["weight"] = weight }

            var targets: [String: Any] = ["steps": snapshot.targets.steps]
            if let kcal = snapshot.targets.kcal { targets["kcal"] = kcal }
            if let p = snapshot.targets.proteinG { targets["protein_g"] = p }
            out["targets"] = targets

            var today: [String: Any] = [
                "steps": snapshot.steps,
                "kcal": snapshot.kcalEaten,
                "protein_g": snapshot.proteinEatenG,
            ]
            today["plates"] = snapshot.plates.suffix(6).map { entry in
                var plate: [String: Any] = [
                    "t": entry.loggedAt.formatted(date: .omitted, time: .shortened).lowercased(),
                    "title": entry.title,
                    "kcal": Int(entry.kcal.rounded()),
                ]
                plate["protein_g"] = Int(entry.protein.rounded())
                return plate
            }
            out["today"] = today
        } else {
            // Suppressed: rhythm-only view of the day.
            out["today"] = [
                "steps": snapshot.steps,
                "plates_count": snapshot.plates.count,
            ]
            out["targets"] = ["steps": snapshot.targets.steps]
        }

        // — her file (v2.6): the evening note is jeni's memory.
        // Yesterday's note first (this morning's most useful echo),
        // today's if present. Truncated; the persona is instructed
        // to reference gently, at most once, never quote at length.
        let noteStore = UserDefaults.standard
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
            let yKey = TodayStateService.dayKey(for: yesterday)
            if let note = noteStore.string(forKey: "day.note.\(yKey)"), !note.isEmpty {
                out["her_note_yesterday"] = String(note.prefix(140))
            }
        }
        if let today = noteStore.string(forKey: "day.note.\(TodayStateService.dayKey())"),
           !today.isEmpty {
            out["her_note_today"] = String(today.prefix(140))
        }

        // — profile texture (only answered fields)
        var profile: [String: Any] = [:]
        if !CohortStore.sleepHoursKey.isEmpty { profile["sleep"] = CohortStore.sleepHoursKey }
        if !CohortStore.stressKey.isEmpty { profile["stress"] = CohortStore.stressKey }
        if !CohortStore.foodRelationshipKey.isEmpty {
            profile["food_relationship"] = CohortStore.foodRelationshipKey
        }
        if !CohortStore.appetiteRhythmKey.isEmpty {
            profile["appetite_rhythm"] = CohortStore.appetiteRhythmKey
        }
        if !CohortStore.priorAttemptsKey.isEmpty {
            profile["prior_attempts"] = CohortStore.priorAttemptsKey
        }
        var fears: [String] = []
        if d.string(forKey: "onb_fear_quickResults") == "yes" { fears.append("wants_fast_results") }
        if d.string(forKey: "onb_fear_anotherDiet") == "yes" { fears.append("afraid_another_failed_diet") }
        if d.string(forKey: "onb_fear_regain") == "yes" { fears.append("afraid_of_regain") }
        if !fears.isEmpty { profile["fears"] = fears }
        if !profile.isEmpty { out["profile"] = profile }

        out["device"] = [
            "local_time": Date.now.formatted(date: .omitted, time: .shortened).lowercased(),
            "weekday": Date.now.formatted(.dateTime.weekday(.abbreviated)).lowercased(),
        ]

        return out
    }

    private static var cohortWord: String {
        switch CohortStore.glp1Cohort {
        case .onGlp1: return "on_glp1"
        case .postGlp1: return "post_glp1"
        case .considering: return "considering_glp1"
        case .generalWL: return "general"
        }
    }

    private static func round1(_ v: Double) -> Double {
        (v * 10).rounded() / 10
    }
}

// MARK: - ChatSafety
//
// The client pre-filter (05_CHAT §Safety). Crisis language never
// reaches the model; the turn gets the fixed care response locally.
// This is routing, not diagnosis — broad on purpose, warm always.

enum ChatSafety {
    struct Screen {
        let blocked: Bool
        let careResponse: String?
    }

    private static let crisisMarkers = [
        "kill myself", "hurt myself", "end my life", "self harm",
        "self-harm", "suicid", "don't want to be alive",
        "dont want to be alive", "want to disappear forever",
    ]

    private static let edMarkers = [
        "purge", "throw up after", "laxative", "punish myself for eating",
        "deserve to starve", "hate myself for eating", "make myself sick",
    ]

    static func screen(_ text: String) -> Screen {
        let lowered = text.lowercased()
        if crisisMarkers.contains(where: { lowered.contains($0) }) {
            return Screen(
                blocked: true,
                careResponse: "i'm really glad you told me. this is bigger than what i can hold, and you deserve real support right now.\n\nif you're in the US, you can call or text 988 anytime. if you're elsewhere, findahelpline.com lists someone near you.\n\ni'm not going anywhere. your plan will be right here when you're ready \u{2665}\u{FE0E}"
            )
        }
        if edMarkers.contains(where: { lowered.contains($0) }) {
            return Screen(
                blocked: true,
                careResponse: "thank you for trusting me with that. what you're describing deserves more care than an app can give, and none of it means you've failed.\n\ntalking to someone qualified helps. the NEDA helpline (nationaleatingdisorders.org) is a gentle place to start.\n\nhere, we'll keep things soft. no numbers today. just the next kind plate \u{2665}\u{FE0E}"
            )
        }
        return Screen(blocked: false, careResponse: nil)
    }
}
