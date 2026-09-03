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
            // p54 — the EF prompt never governed this field, so the
            // app's most carefully gated signal reached an ungoverned
            // narrator. The rules travel in-band until the prompt gains
            // its cycle block (a founder-gated deploy): hedged, never
            // predictive, never a fertility word — the same register
            // the surfaces already hold.
            signals["season_note"] = season.phase == .luteal
                ? "from her own recorded starts. speak it hedged ('for many'), never as her certainty, never a prediction or fertility words."
                : "first days of flow, from her own recorded starts. the scale often runs high on water here; the trend decides. never a prediction or fertility words."
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
            // ONE GOAL, WHEREVER SHE ASKS.
            //
            // This read `snapshot.plan?.goalWeightKg` unconditionally —
            // the plan's goal, the very source the 2026-08-13 pass taught
            // every SCREEN to stop trusting when it disagrees with her own
            // answer. So the coach was the last surface in the app able to
            // tell her her goal was 143.3 lb while the plan screen said
            // 110. `PlanSummary` is the resolution the screens use, so it
            // is the resolution the envelope uses.
            let summary = PlanSummary.build(
                plan: snapshot.plan,
                latestWeightKg: snapshot.latestWeightKg,
                proteinG: snapshot.targets.proteinG,
                stepsGoal: snapshot.targets.steps,
                numericsSuppressed: false,
                careProtocol: CareProtocolStore.current
            )
            var weight: [String: Any] = [:]
            // ONE WEIGHT LADDER, AND THE COACH IS ON IT.
            //
            // v25 §37. This read `snapshot.latestWeightKg` — the RAW
            // weigh-in row — so a woman who told the consult what she
            // weighs and has not opened the scale yet had NO
            // `current_kg` in the envelope at all, while `your numbers`
            // rendered `weight today · 124 lb` and Home priced her day
            // from it. `35` fixed exactly this ladder two fields down
            // (`missingEnergyInput`) and left the published weight
            // behind.
            //
            // It was worse than an omission: `to_go_kg` below is
            // `current − goal` and DOES resolve through the ladder, so
            // the payload answered "how far am I" from a number it
            // refused to state. `summary.currentKg` is the resolution
            // every screen uses, so it is the resolution the envelope
            // uses. Every existing envelope test seeds a weigh-in
            // first, which is why this survived four passes.
            if let kg = summary.currentKg { weight["current_kg"] = round1(kg) }
            if let goal = summary.goalKg { weight["goal_kg"] = round1(goal) }
            if let start = snapshot.plan?.currentWeightKg { weight["start_kg"] = round1(start) }
            // p54 — the delta travels ONLY when the band licenses a
            // direction. A raw −0.4 beside `trend_established: false`
            // let the model narrate "you're losing" over a record the
            // read tool answers with "don't imply one" — the same fold,
            // two gates, two stories in one conversation. The house
            // pattern for a withheld fact is an in-band note, so the
            // model hears WHY the number is missing instead of
            // improvising around the hole.
            if snapshot.trendIsEstablished, let delta = snapshot.emaDelta7dKg {
                weight["ema_delta_7d_kg"] = round1(delta)
            }
            if let ago = snapshot.lastWeighInDaysAgo { weight["last_logged_days_ago"] = ago }
            weight["trend_established"] = snapshot.trendIsEstablished
            if !snapshot.trendIsEstablished {
                weight["no_trend_note"] =
                    "not enough weigh-ins to state a direction. don't imply one; a few more mornings start the line."
            }
            // The three things she asks and the coach could not answer:
            // how much is left, roughly how long, and — when there is no
            // goal — that there ISN'T one, so jeni asks instead of
            // improvising a number.
            if let remaining = summary.distanceKg { weight["to_go_kg"] = round1(remaining) }
            if let weeks = summary.horizonWeeks { weight["weeks_at_her_pace"] = weeks }
            weight["goal_on_file"] = summary.goalKg != nil
            if summary.needsGoal {
                weight["no_goal_note"] =
                    "she has no goal weight on file. don't invent one and don't read her current weight as a goal — the editor is settings › goal weight."
            }
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
            if let kcal = snapshot.targets.kcal {
                targets["kcal"] = kcal
                // WHAT KIND OF NUMBER IT IS. A maintenance estimate and a
                // loss target are the same glyph and opposite
                // instructions; the whole 2026-08-13 report lives in that
                // gap. "why is that my target" and "am i in maintenance"
                // were unanswerable without this word.
                targets["kcal_basis"] = summary.energyKind == .maintenance
                    ? "maintenance" : "deficit"
                targets["kcal_note"] =
                    "an estimate of her needs (mifflin-st jeor x her activity, minus her plan's pace), not a measurement. never promise a weight change from it."
            } else if let missing = TargetsService.missingEnergyInput(
                plan: snapshot.plan,
                // THE ONE LADDER. `snapshot.latestWeightKg` is the raw
                // weigh-in row, not `TargetsService.resolvedWeightKg`, so
                // a woman who has never opened the scale — her weight is
                // on file from the consult — was told by jeni that her
                // WEIGHT was the missing fact, while Home named the real
                // one. `TodayStateService` resolves this correctly two
                // lines apart (its own `missingEnergyInput`); the coach
                // was the copy that drifted. Same defect class as
                // `30` §3, one surface further out.
                latestWeightKg: TargetsService.resolvedWeightKg(
                    userId: userId, plan: snapshot.plan, in: context),
                careProtocol: CareProtocolStore.current
            ) {
                // `direction` was arriving here as "goal", which would
                // have had jeni tell a woman to set a goal weight she
                // already has. The enum's own name is the honest word.
                targets["kcal_missing"] = missing.rawValue
                if missing == .direction {
                    targets["kcal_missing_note"] =
                        "her plan is set to hold steady and this device cannot tell whether that was her choice or a health reason checked at sign-up. do not tell her to set a goal weight and do not encourage a deficit. the answer is in settings › your numbers › this plan."
                }
            }
            if let p = snapshot.targets.proteinG { targets["protein_g"] = p }

            // WHY THE NUMBER IS THE NUMBER — and where she changes it.
            //
            // v25 §34. The envelope carried the target and its BASIS
            // (deficit vs maintenance, `30` §7) but never its INPUTS, so
            // "why is my target 1,282?" could only ever be answered with
            // the name of an equation, and "how do I change it?" not at
            // all. `31` §7 built the screen that answers both —
            // `JKPlanNumbersSheet`, seven rows, every one editable — and
            // the coach could not see it or point at it. A product whose
            // support answer is a screen the coach cannot name is a
            // product with two front desks.
            //
            // Categorical + her own numbers, nothing derived: the model
            // already holds the target and can do the arithmetic itself,
            // and shipping a second copy of the subtraction is how two
            // numbers start to disagree (`33`, the remainder).
            //
            // ZERO EDGE FUNCTION DEPLOY — the allowlist gates tool
            // NAMES, not payloads (`27`).
            let bodyInputs = TargetsService.profileInputs()
            var inputs: [String: Any] = [:]
            if bodyInputs.heightCm > 100 { inputs["height_cm"] = Int(bodyInputs.heightCm.rounded()) }
            if let years = TargetsService.knownAge() {
                inputs["age"] = years
                // A restored account's age comes back as a BAND. Saying
                // "34" when we hold "25-34" would be the coach inventing
                // a fact the screen already refuses to invent.
                if TargetsService.ageIsApproximate() { inputs["age_is_approximate"] = true }
            }
            if let sexWords = BodyFactsStore.sexWords() { inputs["sex_term"] = sexWords }
            if let move = BodyFactsStore.activityWords() { inputs["activity"] = move }
            if BodyFactsStore.activityIsAmbiguous() { inputs["activity_is_ambiguous"] = true }
            // HER WORD, NOT THE COLUMN'S. This published the raw stored
            // value, so every screen said `steady` and jeni said
            // `medium` — about the fact that decides her deficit and her
            // horizon. `soft`/`medium`/`hard` has never been shown to a
            // customer; `IntensityTier.paceWord` is the one place the
            // word is decided (v25 §37).
            if let raw = snapshot.plan?.intensityTier,
               let tier = IntensityTier(rawValue: raw) {
                inputs["pace"] = tier.paceWord
            }
            if !inputs.isEmpty { targets["inputs"] = inputs }
            targets["repair_note"] =
                "every input above is hers to see and change in one screen. if she says a number looks wrong, send her to it rather than explaining it away, and never edit anything yourself."
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
                // p70 — a protein nobody measured is OMITTED, never 0
                // (a model reads protein_g: 0 as "no protein" — a
                // statement nobody made).
                if let p = entry.measuredProtein {
                    plate["protein_g"] = Int(p.rounded())
                }
                // p53 — TODAY's plates finally carry the footing the
                // read_food_day tool goes to such trouble to state: a
                // photo estimate, a package label and her own fixed
                // numbers must not arrive as identical integers in
                // the one context every conversation reads.
                // p70 — and a stated plate's footing is her authorship.
                if entry.isUserStated {
                    plate["how"] = "your numbers, as you gave them"
                } else if let method = EntryMethod(rawValue: entry.source ?? "") {
                    plate["how"] = method.provenanceLine
                }
                if entry.wasVerified { plate["her_numbers"] = true }
                return plate
            }
            // p53 — movement beyond steps: the strength story, with
            // hand-recorded sessions attributed (note 11's subject
            // was unanswerable in chat).
            let hkStrength = MovementService.shared.everRequested
                ? MovementService.shared.strengthSessionsLast7 : 0
            let enteredStrength = MoveManualStore.strengthLastWeek()
            if hkStrength + enteredStrength > 0 {
                var movement: [String: Any] = [
                    "strength_sessions_7d": hkStrength + enteredStrength
                ]
                if enteredStrength > 0 {
                    movement["recorded_by_hand_7d"] = enteredStrength
                }
                out["movement"] = movement
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
        // WHY SHE IS HERE — `onb_v5_outcome`, the consult's first
        // substantive question ("what do you want to change most?":
        // feel like myself again · quiet around food · steady energy ·
        // clothes that fit right · keep off what i lost).
        //
        // It had exactly ONE reader in the product and it was
        // `OnboardingRevealView` — the PRE-PURCHASE screen. The moment
        // she paid, the most personal answer in the consult stopped
        // existing. That is the brief's class G: we ask her something
        // personal and the app does nothing with it.
        //
        // The narrowest honest fix is this envelope, and it is a real
        // one: "what should I focus on this week?" is a question the
        // coach could only ever answer from metrics, with no idea what
        // she came for. Zero Edge Function deploy — the allowlist gates
        // tool NAMES, not payloads (established in `27`).
        if let reason = d.string(forKey: "onb_v5_outcome"), !reason.isEmpty {
            profile["came_for"] = reason
        }
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
            // p53: the cadence word from the ONE authority.
            medication["cadence"] = MedicationScheduleEngine.cadenceWord(facts)
            if let dose = plan.strengthValue {
                medication["dose_mg"] = dose
            }
            // p53: treatment tenure, when stated — the coach must
            // not speak to month eighteen as if it were day one.
            // p54: the qualifier travels WITH the number. The packet
            // says "by her account"; the envelope shipped a bare
            // integer the model could speak as verified fact.
            if let months = MedicationScheduleEngine.treatmentMonths(
                startedOn: plan.treatmentStartedOn
            ) {
                medication["treatment_months"] = months
                medication["treatment_months_basis"] =
                    "her own account, month resolution. say 'by your account' if you lean on it."
            }
            let slotEventsForDays = DoseEventStore.slotEvents(
                userId: userId, limit: 30, in: context
            )
            let todayKey = TodayStateService.dayKey()
            medication["dose_day_today"] = MedicationScheduleEngine.isDoseDay(
                .now, facts: facts, events: slotEventsForDays
            )
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                medication["day_after_dose"] =
                    MedicationScheduleEngine.isDoseDay(
                        yesterday, facts: facts, events: slotEventsForDays
                    )
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
            // p53: interval rhythms included; the engine gates
            // internally (splits refuse a cycle, daily/as-needed
            // have no late window).
            if facts.scheduleRule != "daily", facts.scheduleRule != "asNeeded" {
                if let cycle = MedicationScheduleEngine.cyclePosition(
                    now: .now, facts: facts, events: slotEventsForDays
                ) {
                    medication["cycle_day"] = cycle.day
                    medication["cycle_len"] = cycle.length
                    medication["cycle_basis"] = cycle.basis.rawValue
                }
                if let open = MedicationScheduleEngine.openLateSlot(
                    now: .now, facts: facts, events: slotEventsForDays
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
            MethodInputBuilder.input(
                userId: userId, snapshot: snapshot,
                // p53 — the same clinic resolution the surfaces use,
                // so a clinic suppression cannot fork jeni's answer.
                clinic: MethodClinicSource.current(), in: context
            )
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

        // — WHERE THINGS LIVE (v25 §34).
        //
        // Jeni can OPEN five things (`JeniToolCatalog.acts`: the camera,
        // the dose sheet, the weekly read, a lesson, breathwork) and
        // cannot open the rest, because a new tool NAME has to be added
        // to the jeni-chat server allowlist and that is a founder-gated
        // deploy. Three of the questions this product must answer —
        // "show me my food log", "how do I change my goal", "where are
        // my weigh-ins" — sit behind doors she has no tool for, and
        // until now the envelope did not even tell her they existed.
        //
        // So: the payload names them, in her own words, and she can
        // DIRECT instead of navigate. That is the honest half of the
        // capability and it costs nothing — the allowlist gates tool
        // names, not payloads (`27`). The navigation acts stay named,
        // unbuilt, and behind the standing deploy gate.
        out["doors"] = [
            "your_numbers": "settings \u{203A} your numbers — weight, height, goal weight, how she moves, the calorie equation, age, pace. every input to her daily target, each one editable.",
            "goal_weight": "settings \u{203A} goal weight, or the goal row inside your numbers.",
            "food_record": "becoming \u{203A} your plates — every meal with its photo, its numbers and the day it landed on. a plate opens to fix, repeat, re-date or remove it.",
            "weigh_ins": "becoming \u{203A} your weigh-ins — every weight with its date. tapping one corrects or removes it.",
            "medication": "the medication line at the top of home, or settings \u{203A} your medication.",
        ]

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
