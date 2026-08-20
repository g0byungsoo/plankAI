import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - JeniReadTools
//
// v25 E3 ONE JENI (docs/app_v25/12_E3_ONE_JENI.md §3).
//
// THE COACH CAN LOOK THINGS UP.
//
// Until this era every one of jeni's seven tools ACTED. She could open
// the camera and propose a weight, and she knew exactly one thing: a
// flat snapshot of today, assembled once at the start of the turn. Ask
// her what you ate on friday, how last week compared, or what changed
// when your dose went up, and she had to either say nothing or invent
// it. Five eras of record — dose chains, cycle positions, weight EMAs,
// symptom timelines, food weeks, program facts with authority — were
// unreachable from the one surface people actually talk to.
//
// These reads close that. THE LAWS, in order of how much they matter:
//
//  1. EVERY READ RENDERS FROM THE SAME ENGINE THE SURFACES RENDER
//     FROM. The weight read is `WeightWeekReadEngine` (E2), the cycle
//     is `MedicationScheduleEngine.cyclePosition` (E2), the patterns
//     are the floor-gated engines (v24), the facts are
//     `ProgramFactStore` (E1). Chat and UI cannot disagree because
//     there is only one answer.
//  2. HONEST EMPTINESS. Every read can return `have: false` with a
//     `why`. A day with no plates is "not logged", never "0 kcal";
//     one weigh-in has no direction; a pattern under its floor does
//     not exist. Silence is a real answer and the prompt is told so.
//  3. PROVENANCE TRAVELS. Sufficiency, sample counts, basis words and
//     authority ride with the numbers, so jeni can hedge correctly
//     instead of hedging decoratively.
//  4. THE STANDING PRIVACY FLOORS HOLD. Numeric suppression removes
//     every kcal and weight number here exactly as it does on screen.
//     Body-scan imagery and derived body numbers never appear (L4).
//     Nothing returns free text the user wrote in a note.
//
// Reads are pure with respect to the record: they never write.

@MainActor
enum JeniReadTools {

    /// Execute a read tool. Returns the compact JSON the continuation
    /// turn hands back to the model.
    static func execute(
        _ call: ChatToolCall,
        userId: String,
        in context: ModelContext,
        now: Date = .now
    ) -> [String: Any] {
        guard !userId.isEmpty else { return unavailable("no account yet") }
        let targets = TargetsService.current(userId: userId, in: context)
        let suppressed = targets.numericsSuppressed

        switch call.name {
        case "read_food_day":
            return foodDay(
                call.arguments, userId: userId, targets: targets,
                suppressed: suppressed, now: now
            )
        case "read_food_week":
            return foodWeek(
                call.arguments, userId: userId, targets: targets,
                suppressed: suppressed, now: now
            )
        case "read_weight_trend":
            return weightTrend(userId: userId, suppressed: suppressed, in: context, now: now)
        case "read_dose_history":
            return doseHistory(userId: userId, in: context, now: now)
        case "read_symptoms":
            return symptoms(call.arguments, userId: userId, in: context, now: now)
        case "read_patterns":
            return patterns(userId: userId, suppressed: suppressed, in: context, now: now)
        case "read_activity":
            return activity(userId: userId, in: context, now: now)
        case "read_program":
            return program(userId: userId, in: context, now: now)
        default:
            return unavailable("unknown read")
        }
    }

    // MARK: - Food

    private static func foodDay(
        _ args: [String: Any], userId: String,
        targets: TargetsService.Targets, suppressed: Bool, now: Date
    ) -> [String: Any] {
        let cal = Calendar.current
        guard let target = resolveDay(args, calendar: cal, now: now) else {
            return unavailable("that day isn't in the record")
        }
        let dayStart = cal.startOfDay(for: target)
        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { cal.isDate($0.loggedAt, inSameDayAs: dayStart) }
            .sorted { $0.loggedAt < $1.loggedAt }

        var out: [String: Any] = [
            "day": dayLabel(dayStart, calendar: cal, now: now),
            "days_ago": cal.dateComponents(
                [.day], from: dayStart, to: cal.startOfDay(for: now)
            ).day ?? 0,
        ]
        guard !entries.isEmpty else {
            out["have"] = false
            // S3's law, stated where the model will read it.
            out["why"] = "nothing was logged that day. unrecorded is not the same as not eaten."
            return out
        }
        out["have"] = true
        out["plate_count"] = entries.count
        out["plates"] = entries.map { entry -> [String: Any] in
            var plate: [String: Any] = [
                "title": entry.title,
                "at": entry.loggedAt.formatted(date: .omitted, time: .shortened).lowercased(),
                // WHICH DOOR. She can now answer "was that the one I
                // photographed?" and, more usefully, hedge correctly: a
                // barcode read is the package's own numbers and a
                // restaurant estimate is a range, and until now the tool
                // handed both to the model as identical integers.
                "how": EntryMethod.provenanceLine(for: entry.source),
            ]
            if !suppressed {
                plate["kcal"] = Int(entry.kcal.rounded())
                plate["protein_g"] = Int(entry.protein.rounded())
                plate["carbs_g"] = Int(entry.carbs.rounded())
                plate["fat_g"] = Int(entry.fat.rounded())
                // Only when the plate actually carries them. 0 means "not
                // collected" everywhere else in this product (the
                // provenance rule), and handing a model a 0 it will read
                // as "no sodium" is the estimate-dressed-as-measurement
                // defect in a JSON payload.
                if entry.sodiumMg > 0 { plate["sodium_mg"] = Int(entry.sodiumMg.rounded()) }
                if entry.sugar > 0 { plate["sugar_g"] = Int(entry.sugar.rounded()) }
                if entry.fiber > 0 { plate["fiber_g"] = Int(entry.fiber.rounded()) }
                // WHAT WAS IN IT. "what was that chicken bowl?" was
                // unanswerable from a record that has held the ledger
                // since v1.2.
                let names = entry.itemsDetail?.map(\.name) ?? entry.items
                if let names, !names.isEmpty { plate["items"] = names }
                // HER OWN WORDS. E4 persisted these; the record kept them
                // in the DTO as of the last pass; the coach still could
                // not see them. "what did i correct yesterday?" is a
                // question about the one thing in the record that came
                // from the user rather than a model.
                if let fixes = entry.corrections, !fixes.isEmpty {
                    plate["your_corrections"] = fixes
                }
                // p53 — her hand edits are user truth too (stepper,
                // editor, portion); same never-contradict rule.
                if let edits = entry.edits, !edits.isEmpty {
                    plate["your_edits"] = edits
                }
            }
            return plate
        }
        if !suppressed {
            out["kcal_total"] = Int(entries.reduce(0) { $0 + $1.kcal }.rounded())
            out["protein_total_g"] = Int(entries.reduce(0) { $0 + $1.protein }.rounded())
            out["fiber_total_g"] = Int(entries.reduce(0) { $0 + $1.fiber }.rounded())
            let sodium = entries.reduce(0) { $0 + $1.sodiumMg }
            if sodium > 0 { out["sodium_total_mg"] = Int(sodium.rounded()) }
            let sugar = entries.reduce(0) { $0 + $1.sugar }
            if sugar > 0 { out["sugar_total_g"] = Int(sugar.rounded()) }
            if let kcal = targets.kcal { out["kcal_target"] = kcal }
            if let p = targets.proteinG { out["protein_target_g"] = p }
        }
        return out
    }

    private static func foodWeek(
        _ args: [String: Any], userId: String,
        targets: TargetsService.Targets, suppressed: Bool, now: Date
    ) -> [String: Any] {
        let cal = Calendar.current
        let window = (args["days"] as? Int) == 14 ? 14 : 7
        let todayStart = cal.startOfDay(for: now)
        guard let from = cal.date(byAdding: .day, value: -(window - 1), to: todayStart) else {
            return unavailable("couldn't read that window")
        }
        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= from }

        var out: [String: Any] = ["window_days": window]
        guard !entries.isEmpty else {
            out["have"] = false
            out["why"] = "no meals logged in this window."
            return out
        }

        var byDay: [Date: (kcal: Double, protein: Double, fiber: Double, count: Int)] = [:]
        for entry in entries {
            let day = cal.startOfDay(for: entry.loggedAt)
            var acc = byDay[day] ?? (0, 0, 0, 0)
            acc.kcal += entry.kcal
            acc.protein += entry.protein
            acc.fiber += entry.fiber
            acc.count += 1
            byDay[day] = acc
        }
        let loggedDays = byDay.count
        out["have"] = true
        out["days_logged"] = loggedDays
        out["plate_count"] = entries.count
        // The honesty gate the food read itself uses: under 4 days a
        // week has no verdict in it.
        out["sparse"] = loggedDays < FoodWeekRead.loggedDaysFloor
        if loggedDays < FoodWeekRead.loggedDaysFloor {
            out["sparse_note"] =
                "\(loggedDays) of \(window) days have a record. averages here describe those days only."
        }

        if !suppressed {
            let kcals = byDay.values.map(\.kcal)
            let proteins = byDay.values.map(\.protein)
            out["avg_kcal_on_logged_days"] =
                Int((kcals.reduce(0, +) / Double(loggedDays)).rounded())
            out["avg_protein_g_on_logged_days"] =
                Int((proteins.reduce(0, +) / Double(loggedDays)).rounded())
            out["avg_fiber_g_on_logged_days"] =
                Int((byDay.values.map(\.fiber).reduce(0, +) / Double(loggedDays)).rounded())
            if let floor = targets.proteinG {
                out["protein_target_g"] = floor
                out["days_met_protein"] = proteins.filter { $0 >= Double(floor) }.count
            }
        }

        // Repeats — the cheapest thing that gets cheaper with use.
        var titleCounts: [String: Int] = [:]
        for entry in entries where !entry.title.isEmpty {
            titleCounts[entry.title.lowercased(), default: 0] += 1
        }
        let repeats = titleCounts.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { ["dish": $0.key, "times": $0.value] as [String: Any] }
        if !repeats.isEmpty { out["repeated_dishes"] = Array(repeats) }

        // The engine's own qualitative band, when it earns one.
        if let read = FoodWeekRead.compose(
            plates: entries.map {
                .init(loggedAt: $0.loggedAt, kcal: $0.kcal, protein: $0.protein)
            },
            proteinTargetG: suppressed ? nil : targets.proteinG,
            calendar: cal,
            now: now
        ) {
            out["week_band"] = read.band.rawValue
        }
        return out
    }

    // MARK: - Weight

    private static func weightTrend(
        userId: String, suppressed: Bool, in context: ModelContext, now: Date
    ) -> [String: Any] {
        guard !suppressed else {
            return [
                "have": false,
                "why": "weight numbers are turned off for this account. talk about rhythm, not the scale.",
            ]
        }
        let cal = Calendar.current
        // Pass 51 — the canonical series (one fetch rule, earliest-of-
        // day) instead of a hand-rolled sibling; jeni's spoken trend
        // now provably reads the same resolved rows Becoming draws.
        let cutoff = cal.date(byAdding: .day, value: -90, to: now) ?? now
        let samples = WeightSeries
            .samples(userId: userId, in: context, calendar: cal)
            .filter { $0.day >= cutoff }
        guard !samples.isEmpty else {
            return ["have": false, "why": "no weigh-ins on record yet."]
        }

        let read = WeightWeekReadEngine.read(
            samples: samples, now: now, calendar: cal
        )
        let unit = WeightUnit.current
        var out: [String: Any] = [
            "have": true,
            "unit": unit.label,
            "weigh_in_count_90d": samples.count,
            "sufficiency": read.sufficiency.rawValue,
        ]
        if let daysAgo = read.lastSampleDaysAgo { out["last_weigh_in_days_ago"] = daysAgo }
        if let trend = read.trendKg {
            out["trend"] = round1(unit.display(fromKg: trend))
        }
        if let latest = samples.last {
            out["latest"] = round1(unit.display(fromKg: latest.kg))
            // p55 — a day can hold two rows (a morning weigh-in and a
            // later correction or import). The trend reads the day's
            // EARLIEST (the fasted-morning law); every "current
            // weight" surface reads the NEWEST. When they differ,
            // jeni explains the difference instead of embodying it.
            if let newestRow = WeightSeries.records(
                userId: userId, in: context
            ).first,
               cal.isDate(newestRow.loggedAt, inSameDayAs: latest.day),
               abs(newestRow.weightKg - latest.kg) > 0.05 {
                out["latest_note"] =
                    "a later weigh-in exists today (\(round1(unit.display(fromKg: newestRow.weightKg))) \(unit.label)). the trend reads the day's first; the app's current weight reads the newest."
            }
        }
        // The band is the ONLY thing licensed to state a direction,
        // and the engine withholds it when the record can't carry one.
        if let band = read.band, let delta = read.weeklyDeltaKg {
            out["direction"] = band.rawValue
            out["weekly_change"] = round1(unit.display(fromKg: delta))
        } else {
            out["direction"] = "not_established"
            out["direction_note"] = read.sufficiency == .stale
                ? "the last weigh-in is too old to read a direction from."
                : "not enough weigh-ins yet to state a direction. don't imply one."
        }
        // p53 — the recent ROWS, so "what did i weigh on tuesday" is
        // finally answerable from the record that holds the answer
        // (pass 37 named the gap; the payload extension needs no
        // deploy — the allowlist gates tool NAMES). Rows only, day
        // + value; the trend above stays the only spoken direction.
        out["recent"] = samples.suffix(10).map { sample in
            [
                "day": MedicationScheduleEngine.dayKey(for: sample.day),
                "value": round1(unit.display(fromKg: sample.kg)),
            ] as [String: Any]
        }
        return out
    }

    // MARK: - Medication

    private static func doseHistory(
        userId: String, in context: ModelContext, now: Date
    ) -> [String: Any] {
        guard let plan = RegimenService.activeMedicationPlan(userId: userId, in: context) else {
            return ["have": false, "why": "no medication on record."]
        }
        let facts = RegimenService.facts(for: plan)
        let cal = Calendar.current
        var out: [String: Any] = ["have": true]

        if let productId = plan.productId,
           let product = MedicationCatalog.product(id: productId) {
            // The compound, never the brand — the standing redline
            // holds inside a tool result exactly as it does in copy.
            out["compound"] = product.compound.rawValue
        }
        out["route"] = facts.isOral ? "oral" : "injection"
        // p53: the cadence word from the ONE authority — an as-needed
        // or every-N plan no longer reads "weekly".
        out["cadence"] = MedicationScheduleEngine.cadenceWord(facts)
        out["authority"] = plan.authority
        if let days = cal.dateComponents([.day], from: plan.startedAt, to: now).day {
            out["current_era_days"] = max(0, days)
        }
        // p53: treatment tenure is its own truth (jeni day ≠
        // treatment day); only when she stated it.
        if let months = MedicationScheduleEngine.treatmentMonths(
            startedOn: plan.treatmentStartedOn, now: now
        ) {
            out["treatment_months"] = months
        }

        let history = RegimenService.medicationHistory(userId: userId, in: context)
        out["era_count"] = history.count
        if history.count >= 2 {
            out["eras"] = history.prefix(4).map { record -> [String: Any] in
                var era: [String: Any] = [
                    "started": dayKeyString(record.startedAt),
                ]
                if let strength = record.strengthValue { era["dose_mg"] = strength }
                if let ended = record.endedAt { era["ended"] = dayKeyString(ended) }
                return era
            }
        }

        let slots = DoseEventStore.slotEvents(userId: userId, limit: 30, in: context)
        if !slots.isEmpty {
            var tally: [String: Int] = [:]
            for slot in slots.prefix(12) { tally[slot.status, default: 0] += 1 }
            out["recent_slots"] = tally
        }

        // WHERE SHE PUT IT LAST TIME (v25 §37).
        //
        // `DoseEventRecord` has stored a site on every taken dose since
        // v24, `SiteRotationAdvisor` states it on the dose sheet, and
        // `the doses` lists it on every row — and no payload the model
        // ever receives carried it, so *"where did I inject last time?"*
        // could only be answered by sending her to a screen. Two
        // previous records list that question as answered by this tool.
        //
        // Taken doses only (a skipped day has no site), her own words
        // rather than the stored key, and ABSENT when there is none —
        // an oral regimen must not acquire an injection site by
        // omission.
        if let last = DoseEventStore.events(userId: userId, limit: 40, in: context)
            .first(where: { $0.status == "taken" && ($0.site?.isEmpty == false) }),
           let site = last.site {
            out["last_site"] = DoseLedger.siteWord(site)
            out["last_site_day"] = last.dayKey
        }
        // p53: interval rhythms have a cycle and a late door too —
        // the engine gates internally (splits refuse a cycle, daily
        // has no late window).
        if let cycle = MedicationScheduleEngine.cyclePosition(
            now: now, facts: facts, events: slots
        ) {
            out["cycle_day"] = cycle.day
            out["cycle_len"] = cycle.length
            out["cycle_basis"] = cycle.basis.rawValue
        }
        if facts.scheduleRule != "daily", facts.scheduleRule != "asNeeded",
           let open = MedicationScheduleEngine.openLateSlot(
            now: now, facts: facts, events: slots
        ) {
            out["open_dose_slot"] = MedicationScheduleEngine.dayKey(for: open)
        }
        out["note"] =
            "facts from their own record. never turn these into dosing advice; their prescriber decides."
        return out
    }

    private static func symptoms(
        _ args: [String: Any], userId: String, in context: ModelContext, now: Date
    ) -> [String: Any] {
        let window = min(120, max(7, (args["days"] as? Int) ?? 30))
        let cal = Calendar.current
        guard let from = cal.date(byAdding: .day, value: -window, to: now) else {
            return unavailable("couldn't read that window")
        }
        let entries = SideEffectLog.entries(userId: userId, limit: 200, in: context)
            .filter { entry in
                guard let day = dayKeyDate(entry.dayKey) else { return false }
                return day >= from
            }
        guard !entries.isEmpty else {
            return [
                "have": false,
                "window_days": window,
                "why": "nothing recorded in this window. that isn't proof nothing happened.",
            ]
        }
        var grouped: [String: [(day: String, severity: Int)]] = [:]
        for entry in entries {
            grouped[entry.symptom.rawValue, default: []]
                .append((entry.dayKey, entry.severity.rawValue))
        }
        return [
            "have": true,
            "window_days": window,
            "symptoms": grouped
                .sorted { $0.value.count > $1.value.count }
                .prefix(8)
                .map { key, days -> [String: Any] in
                    [
                        "symptom": key,
                        "times": days.count,
                        "most_recent": days.map(\.day).max() ?? "",
                        "worst_severity": days.map(\.severity).max() ?? 1,
                    ]
                },
        ]
    }

    private static func patterns(
        userId: String, suppressed: Bool, in context: ModelContext, now: Date
    ) -> [String: Any] {
        var observations: [[String: Any]] = []

        // The medication engine, assembled exactly as the becoming
        // tile assembles it (BecomingTiles §medication) — one input
        // shape, one set of floors, one answer.
        if let medPlan = RegimenService.activeMedicationPlan(userId: userId, in: context) {
            let events = DoseEventStore.events(userId: userId, limit: 60, in: context)
            let history = RegimenService.medicationHistory(userId: userId, in: context)
            let changeDays: [String] = history
                .filter { $0.previousPlanId != nil && $0.strengthValue != nil }
                .map { MedicationScheduleEngine.dayKey(for: $0.startedAt) }
            let symptomEntries = SideEffectLog.entries(userId: userId, in: context)
            var proteinByDay: [String: Int] = [:]
            for entry in FoodLogPersister.allEntries(userId: userId) {
                let key = TodayStateService.dayKey(for: entry.loggedAt)
                proteinByDay[key, default: 0] += Int(entry.protein.rounded())
            }
            let medObservations = MedicationPatternEngine.observations(.init(
                takenDoseDays: events.filter { $0.status == "taken" }.map(\.dayKey),
                doseChangeDays: changeDays,
                symptoms: symptomEntries.map { .init($0.dayKey, $0.symptom.rawValue) },
                proteinByDay: proteinByDay,
                today: TodayStateService.dayKey(for: now),
                cycleLengthDays: MedicationScheduleEngine.cycleLengthDays(
                    RegimenService.facts(for: medPlan)
                )
            ))
            for observation in medObservations {
                observations.append([
                    "about": "medication",
                    "says": observation.sentence,
                ])
            }
        }

        guard !observations.isEmpty else {
            return [
                "have": false,
                "why": "no pattern has cleared its floor yet. patterns need repeats. say there isn't enough yet.",
            ]
        }
        return [
            "have": true,
            "observations": observations,
            "note": "these are about TIMING, never cause. keep them that way.",
        ]
    }

    // MARK: - Activity

    private static func activity(
        userId: String, in context: ModelContext, now: Date
    ) -> [String: Any] {
        let counts = StepsService.shared.dailyCounts28
        let recorded = counts.filter { $0 > 0 }
        // p53 — strength finally reaches the tool (its own catalog
        // description promised workouts and it returned steps only):
        // health's sessions plus the ones she recorded by hand, said
        // separately so jeni can attribute.
        let hkStrength = MovementService.shared.everRequested
            ? MovementService.shared.strengthSessionsLast7 : 0
        let entered = MoveManualStore.strengthLastWeek()
        var out: [String: Any] = ["have": !recorded.isEmpty || hkStrength + entered > 0]
        if hkStrength + entered > 0 {
            out["strength_sessions_7d"] = hkStrength + entered
            if entered > 0 { out["strength_recorded_by_hand_7d"] = entered }
        }
        guard !recorded.isEmpty else {
            out["why"] = "no step history. apple health may not be connected."
            return out
        }
        out["steps_today"] = StepsService.shared.todayCount
        out["days_with_steps_28d"] = recorded.count
        let sorted = recorded.sorted()
        out["typical_day"] = sorted[sorted.count / 2]
        out["best_day_28d"] = sorted.last ?? 0
        let lastSeven = counts.suffix(7).filter { $0 > 0 }
        if !lastSeven.isEmpty {
            out["avg_last_7d"] = lastSeven.reduce(0, +) / lastSeven.count
        }
        if let goal = ProgramFactStore.headValue(.stepGoal, userId: userId, in: context)?.intValue {
            out["step_goal"] = goal
            out["goal_source"] = "a fact in their program"
        } else {
            out["step_goal_note"] = "no step goal has been agreed yet."
        }
        out["note"] = "compare them to themselves, never to a population."
        return out
    }

    // MARK: - Program

    private static func program(
        userId: String, in context: ModelContext, now: Date
    ) -> [String: Any] {
        let cal = Calendar.current
        var facts: [[String: Any]] = []
        for kind in ProgramFactKind.allCases {
            guard let head = ProgramFactStore.head(kind, userId: userId, in: context) else {
                continue
            }
            var fact: [String: Any] = [
                "kind": kind.rawValue,
                "authority": head.authority.rawValue,
            ]
            switch head.value {
            case .int(let v): fact["value"] = v
            case .word(let w): fact["value"] = w
            }
            if let days = cal.dateComponents([.day], from: head.createdAt, to: now).day {
                fact["set_days_ago"] = max(0, days)
            }
            // The one thing the model must get right before proposing.
            fact["changeable_here"] = head.authority != .prescribed
            facts.append(fact)
        }
        var out: [String: Any] = [
            "have": !facts.isEmpty,
            "facts": facts,
        ]
        if facts.isEmpty {
            out["why"] = "no program facts are in force. the app is running on defaults."
        }
        out["authority_note"] =
            "prescribed beats preferred beats recommended beats default. never propose over a prescribed fact; route them to the correction door in their medication settings."
        return out
    }

    // MARK: - Helpers

    private static func unavailable(_ why: String) -> [String: Any] {
        ["have": false, "why": why]
    }

    /// `days_ago` wins when both are given; `weekday` resolves to the
    /// most recent PAST day with that name (never today, never the
    /// future — "what did i eat on friday" on a friday means last
    /// friday).
    static func resolveDay(
        _ args: [String: Any], calendar: Calendar, now: Date
    ) -> Date? {
        if let ago = args["days_ago"] as? Int, (1...60).contains(ago) {
            return calendar.date(byAdding: .day, value: -ago, to: now)
        }
        if let ago = args["days_ago"] as? Double, (1...60).contains(Int(ago)) {
            return calendar.date(byAdding: .day, value: -Int(ago), to: now)
        }
        if let weekday = args["weekday"] as? String {
            let names = ["sunday", "monday", "tuesday", "wednesday",
                         "thursday", "friday", "saturday"]
            guard let index = names.firstIndex(of: weekday.lowercased()) else { return nil }
            let wanted = index + 1
            for back in 1...7 {
                guard let candidate = calendar.date(byAdding: .day, value: -back, to: now)
                else { continue }
                if calendar.component(.weekday, from: candidate) == wanted {
                    return candidate
                }
            }
            return nil
        }
        return nil
    }

    private static func dayLabel(_ day: Date, calendar: Calendar, now: Date) -> String {
        let days = calendar.dateComponents(
            [.day], from: day, to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days == 1 { return "yesterday" }
        if days < 7 {
            return day.formatted(.dateTime.weekday(.wide)).lowercased()
        }
        return day.formatted(.dateTime.month(.abbreviated).day()).lowercased()
    }

    private static func dayKeyString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func dayKeyDate(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    private static func round1(_ v: Double) -> Double {
        (v * 10).rounded() / 10
    }
}
