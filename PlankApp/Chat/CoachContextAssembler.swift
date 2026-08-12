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

        // — v6.2 the passive signals (the same facts the tabs show,
        // so jeni's desk and the surfaces never disagree). Window
        // facts ride QuietHours' own hard gate; the season never
        // includes dates or predictions.
        var signals: [String: Any] = [:]
        switch KitchenSignal.livePhase(userId: userId) {
        case let .settled(hours, _, _):
            signals["overnight_window_h"] = round1(hours)
        case let .overnight(hours, _):
            signals["overnight_open_h"] = round1(hours)
        case .evening, nil:
            break
        }
        if let night = SleepService.shared.lastNight {
            signals["slept_h"] = round1(night.asleepDuration / 3600)
        }
        if !CohortStore.isPerimenopausal,
           let season = CycleSignal.read(periodStarts: CycleService.shared.periodStarts),
           season.phase != .follicular {
            signals["season"] = season.phase == .luteal ? "luteal" : "menstrual"
        }
        // v6.4 — the full signal week, so jeni can coach from the
        // same analysis the becoming pages show (founder: the chat
        // needs all this data).
        if let weekStory = KitchenSignal.liveWeekStory(userId: userId) {
            if let avg = weekStory.averageHours {
                signals["fast_week_avg_h"] = round1(avg)
            }
            signals["fast_nights_7d"] = weekStory.narratedCount
        }
        if let pacing = ProteinPacing.liveStory(userId: userId) {
            signals["protein_morning_share"] = round1(pacing.morningShare)
            signals["protein_evening_share"] = round1(pacing.eveningShare)
        }
        if !suppressed, let sweet = Sweetness.liveStory(userId: userId),
           let direction = sweet.direction {
            signals["sugar_direction"] = switch direction {
            case .easing: "down"
            case .steady: "steady"
            case .rising: "up"
            }
        }
        if !signals.isEmpty { out["signals"] = signals }

        // — weight (omitted entirely under suppression)
        if !suppressed {
            var weight: [String: Any] = [:]
            if let kg = snapshot.latestWeightKg { weight["current_kg"] = round1(kg) }
            if let goal = snapshot.plan?.goalWeightKg { weight["goal_kg"] = round1(goal) }
            if let start = snapshot.plan?.currentWeightKg { weight["start_kg"] = round1(start) }
            if let delta = snapshot.emaDelta7dKg { weight["ema_delta_7d_kg"] = round1(delta) }
            if let ago = snapshot.lastWeighInDaysAgo { weight["last_logged_days_ago"] = ago }
            weight["trend_established"] = snapshot.trendIsEstablished
            if !weight.isEmpty { out["weight"] = weight }

            // v9 P3 — the body record reaches jeni's letters (facts
            // only; no image, no photo-derived number — L3/L4).
            let scans = BodyScanStore.all(userId: userId, in: context)
            if !scans.isEmpty {
                var body: [String: Any] = ["scan_count": scans.count]
                if let newest = scans.first, let oldest = scans.last {
                    let days = Calendar.current.dateComponents(
                        [.day], from: oldest.capturedAt, to: newest.capturedAt
                    ).day ?? 0
                    body["scan_span_weeks"] = max(0, days / 7)
                }
                out["body"] = body
            }

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

        // — v24 THE REGIMEN: medication facts (docs/app_v24 §5.8).
        //   Compound + route, NEVER the brand (the EF's never-name-
        //   brands redline holds even in context); dose-day flags
        //   for timing empathy; recent symptoms as timing facts.
        //   The EF prompt already routes dosing questions to her
        //   clinician — this block adds awareness, never authority.
        if let plan = RegimenService.activeMedicationPlan(userId: userId, in: context) {
            var medication: [String: Any] = [:]
            let facts = RegimenService.facts(for: plan)
            if let productId = plan.productId,
               let product = MedicationCatalog.product(id: productId) {
                medication["compound"] = product.compound.rawValue
            }
            medication["route"] = facts.isOral ? "oral" : "injection"
            medication["cadence"] = facts.scheduleRule == "daily" ? "daily" : "weekly"
            if let dose = plan.strengthValue {
                medication["dose_mg"] = dose
            }
            let todayKey = TodayStateService.dayKey()
            medication["dose_day_today"] = MedicationScheduleEngine.isDoseDay(
                .now, facts: facts
            )
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                medication["day_after_dose"] =
                    MedicationScheduleEngine.isDoseDay(yesterday, facts: facts)
            }
            if let todayEvent = DoseEventStore.event(
                dayKey: todayKey, userId: userId, in: context
            ) {
                medication["today_marked"] = todayEvent.status
            }
            let events = DoseEventStore.events(userId: userId, limit: 10, in: context)
            let resolved = events.filter {
                ["taken", "skipped", "missed"].contains($0.status)
            }
            if resolved.count >= 3 {
                medication["doses_marked_recent"] =
                    "\(resolved.filter { $0.status == "taken" }.count)/\(resolved.count)"
            }
            // Dose-change recency (the titration-empathy flag).
            let latest = RegimenService.medicationHistory(userId: userId, in: context)
                .first { $0.previousPlanId != nil && $0.endedAt == nil }
            if let changed = latest?.startedAt {
                let days = Calendar.current.dateComponents(
                    [.day], from: changed, to: .now
                ).day ?? 999
                if days <= 21 { medication["dose_changed_days_ago"] = days }
            }
            // v25 E2 — the cycle position, so "why am i so hungry
            // today" is answered from HER record ("you're day 6 of
            // 7") rather than general knowledge. Honest positions
            // only (nil when an unresolved slot outranks the
            // rhythm); the open late slot rides as a fact.
            if facts.scheduleRule == "weeklyAnchor" {
                let slotEvents = DoseEventStore.slotEvents(
                    userId: userId, limit: 30, in: context
                )
                if let cycle = MedicationScheduleEngine.cyclePosition(
                    now: .now, facts: facts, events: slotEvents
                ) {
                    medication["cycle_day"] = cycle.day
                    medication["cycle_len"] = cycle.length
                    medication["cycle_basis"] = cycle.basis.rawValue
                }
                if let open = MedicationScheduleEngine.openLateSlot(
                    now: .now, facts: facts, events: slotEvents
                ) {
                    medication["open_dose_slot"] =
                        MedicationScheduleEngine.dayKey(for: open)
                }
            }
            let symptoms = SideEffectLog.entries(userId: userId, limit: 40, in: context)
                .filter { entry in
                    guard let day = dayKeyDate(entry.dayKey) else { return false }
                    return Calendar.current.dateComponents(
                        [.day], from: day, to: .now
                    ).day ?? 99 <= 7
                }
                .prefix(5)
                .map { ["symptom": $0.symptom.rawValue, "severity": $0.severity.rawValue] }
            if !symptoms.isEmpty { medication["recent_symptoms"] = Array(symptoms) }
            out["medication"] = medication
        }

        // — v25 E2: the weekly read's compact — the coach reflects
        //   the SAME ritual Today and Becoming compose from (one
        //   jeni, never three). Categorical only: anchor, offer key,
        //   decision, recency.
        if let read = WeeklyReadStore.latest(userId: userId, in: context) {
            var week: [String: Any] = [
                "anchor": read.anchor,
                "offer": read.offerKey,
                "decision": read.decision,
            ]
            if let days = Calendar.current.dateComponents(
                [.day], from: read.decidedAt, to: .now
            ).day, days >= 0 {
                week["days_ago"] = days
            }
            out["week"] = week
        }

        // — v25 E3 ONE JENI: WHAT SHE WAS TOLD.
        //   The compounding half of the era. Everything else in this
        //   envelope is what HAPPENED; this is what the person SAID
        //   about themselves, and it is the only part that makes next
        //   week's conversation better than this one. Verbatim, never
        //   paraphrased, and only ever written through a card they
        //   tapped (JeniMemory §laws).
        let memory = JeniMemoryStore.envelope(userId: userId, in: context)
        if !memory.isEmpty {
            out["remembered"] = memory
        }

        // — v25 E3: THE PROGRAM'S FACTS AND WHO SET THEM.
        //   E1 built the authority ladder and chat could not see it,
        //   so jeni could recommend against a clinician's prescription
        //   without knowing one existed. Categorical only: kind,
        //   value, authority.
        var facts: [[String: Any]] = []
        for kind in ProgramFactKind.allCases {
            guard let head = ProgramFactStore.head(kind, userId: userId, in: context)
            else { continue }
            var fact: [String: Any] = [
                "kind": kind.rawValue,
                "authority": head.authority.rawValue,
            ]
            switch head.value {
            case .int(let v): fact["value"] = v
            case .word(let w): fact["value"] = w
            }
            facts.append(fact)
        }
        if !facts.isEmpty { out["program_facts"] = facts }

        // — v25 E8.1: WHAT THE METHOD HAS ALREADY TOLD HER.
        //
        //   The Method cannot be a separate app. If Jeni does not know
        //   what was surfaced she will re-teach the thing the person read
        //   yesterday, or contradict it, and the two halves of one coach
        //   will read as two products.
        //
        //   Deliberately the ENVELOPE and not a read tool: a new tool
        //   name has to be added to the `jeni-chat` server allowlist,
        //   which is a founder-gated deploy, and five eras have queued
        //   behind those gates before. The envelope costs nothing and
        //   ships today.
        //
        //   CATEGORICAL ONLY. The trigger name, when, and whether the
        //   action followed. Never the rendered sentence and never the
        //   numbers inside it: the model already has her record and can
        //   restate the facts itself, so shipping the prose would be
        //   duplicating medical logic into a prompt — the exact thing
        //   this product refuses to do.
        //
        //   `authored_by` is load-bearing. A clinician's instruction and
        //   Jeni's own education must stay distinguishable INSIDE the
        //   conversation too, or the coach will paraphrase a prescriber.
        let told = MethodLedger.entries().prefix(6).map { entry -> [String: Any] in
            var row: [String: Any] = [
                "trigger": entry.trigger,
                "days_ago": max(0, Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: entry.shownAt),
                    to: Calendar.current.startOfDay(for: .now)
                ).day ?? 0),
                "acted": entry.actionTaken,
                "authored_by": entry.fromCareTeam ? "care_team" : "jeni",
            ]
            if let met = entry.followUpMet { row["followed_through"] = met }
            return row
        }
        if !told.isEmpty { out["method_told"] = Array(told) }

        // — v25 E8.1: WHAT THE METHOD WOULD SAY RIGHT NOW.
        //
        //   The active triggers, so a question like "why does my weight
        //   keep jumping" is answered from the SAME observation the note
        //   surface would have made, rather than from a general fact
        //   about water weight. Same engine, same thresholds, one voice.
        let active = MethodEngine.activeTriggers(
            MethodInputBuilder.input(userId: userId, snapshot: snapshot, in: context)
        )
        if !active.isEmpty {
            out["method_now"] = active.prefix(3).map(\.rawValue)
        }

        // — v25 E3: THE WEEK BEHIND HER, in one line each.
        //   Cheap, always-present longitudinal shape, so even a
        //   deployment that predates the read tools answers "how has
        //   my week been" from the record instead of from today.
        if !suppressed {
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: .now)
            if let from = cal.date(byAdding: .day, value: -6, to: todayStart) {
                var loggedDays = Set<Date>()
                var proteinByDay: [Date: Double] = [:]
                for entry in FoodLogPersister.allEntries(userId: userId)
                where entry.loggedAt >= from {
                    let day = cal.startOfDay(for: entry.loggedAt)
                    loggedDays.insert(day)
                    proteinByDay[day, default: 0] += entry.protein
                }
                if !loggedDays.isEmpty {
                    var week: [String: Any] = ["days_logged": loggedDays.count]
                    if let floor = snapshot.targets.proteinG {
                        week["days_met_protein"] = proteinByDay.values
                            .filter { $0 >= Double(floor) }.count
                    }
                    out["food_week"] = week
                }
            }
        }

        out["device"] = [
            "local_time": Date.now.formatted(date: .omitted, time: .shortened).lowercased(),
            "weekday": Date.now.formatted(.dateTime.weekday(.abbreviated)).lowercased(),
        ]

        return out
    }

    private static func dayKeyDate(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
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
                careResponse: "i'm really glad you told me. this is bigger than what i can hold, and you deserve real support right now.\n\nif you're in the US, you can call or text 988 anytime. if you're elsewhere, findahelpline.com lists someone near you.\n\ni'm not going anywhere. your plan will be right here when you're ready."
            )
        }
        if edMarkers.contains(where: { lowered.contains($0) }) {
            return Screen(
                blocked: true,
                careResponse: "thank you for trusting me with that. what you're describing deserves more care than an app can give, and none of it means you've failed.\n\ntalking to someone qualified helps. the NEDA helpline (nationaleatingdisorders.org) is a gentle place to start.\n\nhere, we'll keep things soft. no numbers today. just the next kind plate."
            )
        }
        return Screen(blocked: false, careResponse: nil)
    }
}
