import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - VisitPacket (app v8 S3 — docs/app_v8/09_S3_PACKET.md)
//
// The visit-prep packet: a deterministic PROJECTION over the
// records the app already holds — regimen + dose marks, sit-checks,
// weight logs, plates, movement checks, her questions. Laws:
//   - Every statement traces to a record; counts speak plainly
//     ("marked on 3 of 4 scheduled days"); sparse data is labeled,
//     never inflated; causality is never inferred (timing only).
//   - F1: a self-reported regimen renders as "your weekly
//     medication" + self-reported provenance; a care-team regimen
//     renders its assigned name/strength only when present.
//   - No AI, no network: valid offline, sparse-safe, pure of
//     clinical advice. The packet is a personal record.

struct VisitPacket: Equatable {

    struct Window: Equatable {
        let start: Date
        let end: Date
        let label: String
        let dayKeys: [String]
    }

    struct Regimen: Equatable {
        /// F1 rule: "your weekly medication" for self-reported;
        /// the assigned name (+ strength) for care-team plans.
        let displayLine: String
        /// "self-reported" | "assigned by your care team"
        let authorityLabel: String
        let anchorWeekdayWord: String?
        /// p53 — "month 4 of treatment", from her own stated start.
        /// nil when never stated; a follow-up's first question.
        let tenureLine: String?
        let scheduledCount: Int
        let takenCount: Int
        let skippedCount: Int
        var unrecordedCount: Int { max(0, scheduledCount - takenCount - skippedCount) }
    }

    struct Weight: Equatable {
        let entryCount: Int
        let firstKg: Double?
        let latestKg: Double?
        /// "easing" | "steady" | "climbing" — only when the trend
        /// floor holds (≥3 entries spanning ≥5 days); nil = sparse.
        let directionWord: String?
    }

    struct Symptom: Equatable {
        let word: String
        let count: Int
        /// Timing note ("often within two days of a marked dose")
        /// — rendered ONLY when ≥2 qualifying records; never causal.
        let timingNote: String?
    }

    struct Nutrition: Equatable {
        let loggedDays: Int
        let proteinDaysMet: Int
        let targetG: Int
    }

    struct Movement: Equatable {
        let movedDays: Int
        let stepsWeekAvg: Int?
        /// p53 — strength sessions this week (health + her own
        /// entries), against the 2-3/week floor the guidance names.
        /// The one movement figure a follow-up actually uses.
        var strengthSessions7: Int? = nil
        /// p55 — how many of those are HER OWN entries. A clinical
        /// surface is the one place a self-report read as a
        /// measurement changes a decision; every other line in this
        /// packet wears its provenance and this one did not.
        var strengthRecordedByHand7: Int = 0
    }

    struct Question: Equatable, Identifiable {
        let id: String
        let text: String
        /// "generated" | "patient"
        let origin: String
    }

    let window: Window
    let regimen: Regimen?
    let weight: Weight?
    let symptoms: [Symptom]
    let nutrition: Nutrition?
    let movement: Movement?
    let questions: [Question]
    let gaps: [String]

    static let disclaimerLine =
        "a personal record, not a diagnosis or medical advice."

    var isEmpty: Bool {
        regimen == nil && weight == nil && symptoms.isEmpty
            && nutrition == nil && movement == nil
    }
}

// MARK: - Builder

@MainActor
enum VisitPacketBuilder {

    static let windowDays = 28

    /// The two words a resolved-but-not-taken dose can carry.
    ///
    /// The evening ask writes "no" (HomeEvening); v24's MedicationLog
    /// — the chokepoint every dose sheet, quick-mark and notification
    /// action lands on — writes "skipped". The packet only knew "no",
    /// so a dose she deliberately skipped reached her clinician as
    /// UNRECORDED, under a gap line that says in as many words
    /// "unrecorded is not skipped". That is the one sentence in the
    /// packet a clinician acts on, and it was inverted.
    static let skippedAnswers: Set<String> = ["no", "skipped"]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func build(
        userId: String, in context: ModelContext, now: Date = .now
    ) -> VisitPacket {
        let window = window(now: now)
        let regimen = regimenSection(userId: userId, window: window, in: context)
        let weight = weightSection(userId: userId, window: window, in: context)
        let symptoms = symptomSection(userId: userId, window: window, in: context)
        let nutrition = nutritionSection(userId: userId, window: window, in: context)
        let movement = movementSection(userId: userId, window: window, in: context)
        let questions = questionRecords(userId: userId, in: context)
            + generatedQuestions(
                userId: userId, regimen: regimen, weight: weight,
                symptoms: symptoms, existing: questionRecords(userId: userId, in: context),
                in: context
            )
        let gaps = gapLines(
            regimen: regimen, weight: weight, nutrition: nutrition,
            movement: movement, symptoms: symptoms
        )
        return VisitPacket(
            window: window, regimen: regimen, weight: weight,
            symptoms: symptoms, nutrition: nutrition, movement: movement,
            questions: questions, gaps: gaps
        )
    }

    // MARK: Window

    static func window(now: Date) -> VisitPacket.Window {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: end) ?? end
        let keys: [String] = (0..<windowDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
                .map { dayFormatter.string(from: $0) }
        }
        return .init(
            start: start, end: end,
            label: "\(labelFormatter.string(from: start).lowercased()) – \(labelFormatter.string(from: end).lowercased())",
            dayKeys: keys
        )
    }

    // MARK: Medication (F1 + adherence counts)

    private static func regimenSection(
        userId: String, window: VisitPacket.Window, in context: ModelContext
    ) -> VisitPacket.Regimen? {
        guard let plan = RegimenService.activeMedicationPlan(userId: userId, in: context)
        else { return nil }

        let managed = RegimenService.isManagedByCareTeam(plan)
        let facts = RegimenService.facts(for: plan)
        let displayLine = regimenDisplayLine(
            managed: managed,
            displayName: plan.displayName,
            strengthValue: plan.strengthValue,
            strengthUnit: plan.strengthUnit,
            facts: facts
        )

        let events = DoseEventStore.slotEvents(userId: userId, in: context)
        let scheduled = scheduledSlotKeys(
            window: window, plan: plan, facts: facts, events: events
        )

        var taken = 0, skipped = 0
        for key in scheduled {
            let answer = ObservationStore.valueText(
                .doseTaken, dayKey: key, userId: userId, in: context
            )
            if answer == "yes" {
                taken += 1
            } else if VisitPacketBuilder.skippedAnswers.contains(answer ?? "") {
                skipped += 1
            }
        }

        return .init(
            displayLine: displayLine,
            authorityLabel: managed ? "assigned by your care team" : "self-reported",
            // p54 — the anchor word renders as "weekly · thursdays",
            // so it may only travel for a plan that IS weekly: a split
            // (mon+thu) plan carries anchorWeekday too, and the packet
            // printed "weekly · mondays" directly under "your
            // medication, twice a week".
            anchorWeekdayWord: {
                guard case .weekly = MedicationScheduleEngine.cadence(facts)
                else { return nil }
                return plan.anchorWeekday.flatMap { iso in
                    ["monday", "tuesday", "wednesday", "thursday",
                     "friday", "saturday", "sunday"][safe: iso - 1]
                }
            }(),
            tenureLine: MedicationScheduleEngine.treatmentMonths(
                startedOn: plan.treatmentStartedOn
            ).map { months in
                months == 0
                    ? "first month of treatment, by their account"
                    : "month \(months + 1) of treatment, by their account"
            },
            scheduledCount: scheduled.count,
            takenCount: taken,
            skippedCount: skipped
        )
    }

    /// F1's sentence, one authority (pass 53). Self-reported stays
    /// generic — but generic must not LIE about the rhythm: a daily
    /// pill is not "your weekly medication". Care-team renders the
    /// assigned facts only when actually present.
    static func regimenDisplayLine(
        managed: Bool,
        displayName: String,
        strengthValue: Double?,
        strengthUnit: String?,
        facts: MedicationScheduleEngine.RegimenFacts
    ) -> String {
        if managed {
            var line = displayName.isEmpty ? "your medication" : displayName
            if let v = strengthValue, let u = strengthUnit {
                line += " \(v.formatted()) \(u)"
            }
            return line
        }
        switch MedicationScheduleEngine.cadence(facts) {
        case .weekly: return "your weekly medication"
        case .daily: return "your daily medication"
        case .twiceWeekly: return "your medication, twice a week"
        case .everyNDays(let n): return "your medication, every \(n) days"
        case .asNeeded: return "your medication, as needed"
        case .unknown: return "your medication"
        }
    }

    /// The scheduled slot keys inside the packet window (pass 53).
    /// The adherence denominator every clinician line divides by.
    static func scheduledSlotKeys(
        window: VisitPacket.Window,
        plan: RegimenPlanRecord,
        facts: MedicationScheduleEngine.RegimenFacts,
        events: [MedicationScheduleEngine.SlotEvent],
        calendar: Calendar = .current
    ) -> [String] {
        // The engine derives the slots (every rhythm — G2's zero-
        // denominator for daily plans died here); the packet only
        // windows them to the plan's active span. Interval chains
        // ignore the version's startedAt on purpose (a version
        // change never moves her dose days), so the active clamp
        // applies to calendar rules only.
        let activeStart = plan.scheduleRule == "intervalDays"
            ? window.start
            : max(window.start, calendar.startOfDay(for: plan.startedAt))
        let activeEnd = plan.endedAt.map { min(window.end, calendar.startOfDay(for: $0)) } ?? window.end
        guard activeStart <= activeEnd else { return [] }
        let span = (calendar.dateComponents(
            [.day], from: window.start, to: activeEnd
        ).day ?? 0) + 1
        return MedicationScheduleEngine.slotDays(
            through: activeEnd, lookbackDays: span, facts: facts,
            events: events, calendar: calendar
        )
        .filter { $0 >= activeStart }
        .map { MedicationScheduleEngine.dayKey(for: $0, calendar: calendar) }
    }

    // MARK: Weight

    /// p53 — the packet's direction word, from the canonical fold's
    /// own band (it was a fourth hand-rolled engine: raw first-vs-
    /// last over ±0.3 kg, able to call "climbing" what Becoming
    /// called "holding steady" for the same window). The clinician
    /// reads the story every other surface tells.
    static func weightDirectionWord(
        samples: [WeightWeekReadEngine.Sample], now: Date = .now
    ) -> String? {
        switch WeightWeekReadEngine.read(samples: samples, now: now).band {
        case .trendingDown: return "easing"
        case .holdingSteady: return "steady"
        case .driftingUp: return "climbing"
        case nil: return nil
        }
    }

    private static func weightSection(
        userId: String, window: VisitPacket.Window, in context: ModelContext
    ) -> VisitPacket.Weight? {
        // Pass 51 — the packet reads THE SAME resolved series every
        // consumer surface reads: sign-up self-report excluded (it is
        // an intake answer, not a weigh-in — and every consumer trend
        // already excluded it, so the clinician was seeing a row the
        // customer's own screens never counted), one entry per day
        // reduced to the EARLIEST of the day (the fasted-morning rule
        // the engine has carried since E2; this section used to keep
        // the LATEST, so the packet could quote a different number
        // than Becoming for the same day).
        let calendar = Calendar.current
        let logs = WeightSeries.records(userId: userId, in: context).filter {
            $0.loggedAt >= window.start
                && $0.loggedAt < (calendar.date(byAdding: .day, value: 1, to: window.end) ?? window.end)
        }
        guard !logs.isEmpty else { return nil }

        var byDay: [String: WeightLogRecord] = [:]
        for log in logs {
            let key = dayFormatter.string(from: log.loggedAt)
            if let held = byDay[key], held.loggedAt <= log.loggedAt { continue }
            byDay[key] = log
        }
        let daily = byDay.values.sorted { $0.loggedAt < $1.loggedAt }

        // p53 — the direction word comes from the canonical fold's
        // own band (the same gate Becoming and jeni speak through);
        // the window's raw first/last stay as the honest endpoints.
        let direction = weightDirectionWord(
            samples: daily.map { .init(day: $0.loggedAt, kg: $0.weightKg) },
            now: window.end
        )

        return .init(
            entryCount: daily.count,
            firstKg: daily.first?.weightKg,
            latestKg: daily.last?.weightKg,
            directionWord: direction
        )
    }

    // MARK: Symptoms (sit-check aggregates; timing, never causality)

    private static func symptomSection(
        userId: String, window: VisitPacket.Window, in context: ModelContext
    ) -> [VisitPacket.Symptom] {
        let records = ObservationStore
            .series(.sitCheck, userId: userId, limit: 120, in: context)
            .filter { window.dayKeys.contains($0.dayKey) }
        let symptomWords = ["heavy", "queasy", "backed up"]
        let doseDays: Set<String> = Set(
            ObservationStore.series(.doseTaken, userId: userId, limit: 120, in: context)
                .filter { $0.valueText == "yes" && window.dayKeys.contains($0.dayKey) }
                .map(\.dayKey)
        )

        // v25 E2 — the v24 symptom vocabulary finally reaches the
        // packet (it read only the three v8 sit-check words; the
        // side-effect timeline — including the underreported set
        // and food noise — was invisible to the visit). Same
        // grammar: her word, a count, timing-never-causality.
        let sideEffects = SideEffectLog
            .entries(userId: userId, limit: 240, in: context)
            .filter { window.dayKeys.contains($0.dayKey) }
        var symptomRows: [VisitPacket.Symptom] = Dictionary(
            grouping: sideEffects, by: \.symptom
        ).compactMap { symptom, entries in
            guard !entries.isEmpty else { return nil }
            let nearDose = entries.filter { entry in
                guard let day = dayFormatter.date(from: entry.dayKey)
                else { return false }
                return (0...2).contains(where: { offset in
                    guard let prior = Calendar.current.date(
                        byAdding: .day, value: -offset, to: day
                    ) else { return false }
                    return doseDays.contains(dayFormatter.string(from: prior))
                })
            }
            return .init(
                word: symptom.word,
                count: entries.count,
                timingNote: nearDose.count >= 2
                    ? "often within two days of a marked dose" : nil
            )
        }.sorted { $0.count > $1.count }

        symptomRows += symptomWords.compactMap { word in
            let matches = records.filter { $0.valueText == word }
            guard !matches.isEmpty else { return nil }
            // Timing note: ≥2 records landing 0-2 days AFTER a
            // marked dose. Worded as timing — never causation.
            let nearDose = matches.filter { record in
                guard let day = dayFormatter.date(from: record.dayKey) else { return false }
                return (0...2).contains(where: { offset in
                    guard let prior = Calendar.current.date(
                        byAdding: .day, value: -offset, to: day
                    ) else { return false }
                    return doseDays.contains(dayFormatter.string(from: prior))
                })
            }
            return .init(
                word: word,
                count: matches.count,
                timingNote: nearDose.count >= 2
                    ? "often within two days of a marked dose" : nil
            )
        }
        return symptomRows
    }

    // MARK: Nutrition (protein consistency only)

    private static func nutritionSection(
        userId: String, window: VisitPacket.Window, in context: ModelContext
    ) -> VisitPacket.Nutrition? {
        guard let target = TargetsService.proteinTargetLight(userId: userId, in: context)
        else { return nil }
        var proteinByDay: [String: Double] = [:]
        for entry in FoodLogPersister.allEntries(userId: userId)
        where entry.loggedAt >= window.start {
            proteinByDay[dayFormatter.string(from: entry.loggedAt), default: 0] += entry.protein
        }
        let logged = proteinByDay.filter { window.dayKeys.contains($0.key) }
        guard logged.count >= 5 else { return nil }
        let met = logged.values.filter { $0 >= Double(target) }.count
        return .init(loggedDays: logged.count, proteinDaysMet: met, targetG: target)
    }

    // MARK: Movement (window move-checks + last-week steps, labeled)

    private static func movementSection(
        userId: String, window: VisitPacket.Window, in context: ModelContext
    ) -> VisitPacket.Movement? {
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.itemKey == "move"
                    && ($0.state == "complete" || $0.state == "autoCompleted")
            }
        )
        let moved = ((try? context.fetch(descriptor)) ?? []).filter { record in
            guard let done = record.completedAt else { return false }
            return done >= window.start
        }.count
        let weekly = StepsService.shared.weeklyCounts.filter { $0 > 0 }
        let stepsAvg = weekly.count >= 4 ? weekly.reduce(0, +) / weekly.count : nil
        // p53 — the strength count reaches the packet (rank 7 of the
        // clinically useful list): health's sessions plus her own.
        let strength = MethodInputBuilder.preservationStrength(
            everRequested: MovementService.shared.everRequested,
            healthKit: MovementService.shared.strengthSessionsLast7,
            entered: MoveManualStore.strengthLastWeek()
        )
        guard moved > 0 || stepsAvg != nil || (strength ?? 0) > 0 else { return nil }
        return .init(
            movedDays: moved, stepsWeekAvg: stepsAvg,
            strengthSessions7: strength,
            strengthRecordedByHand7: MoveManualStore.strengthLastWeek()
        )
    }

    // MARK: Questions (records; generated ones insert once per rule)

    static func questionRecords(
        userId: String, in context: ModelContext
    ) -> [VisitPacket.Question] {
        ObservationStore.series(.visitQuestion, userId: userId, limit: 20, in: context)
            .compactMap { record in
                guard let text = record.valueText, !text.isEmpty else { return nil }
                // "her" is the legacy value for a question the patient
                // wrote; unisex Jeni writes "patient". Old rows keep
                // their value and are normalised on read.
                let raw = (record.payload
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["origin"] as? String) ?? "patient"
                let origin = raw == "her" ? "patient" : raw
                return .init(id: record.id, text: text, origin: origin)
            }
            .sorted { $0.text < $1.text }
    }

    /// Bounded deterministic rules (09_S3_PACKET §4). Each rule
    /// inserts its question ONCE (deterministic id per rule);
    /// removal is permanent for the rule's id — her edit/delete
    /// wins forever after.
    @discardableResult
    static func generatedQuestions(
        userId: String,
        regimen: VisitPacket.Regimen?,
        weight: VisitPacket.Weight?,
        symptoms: [VisitPacket.Symptom],
        existing: [VisitPacket.Question],
        in context: ModelContext
    ) -> [VisitPacket.Question] {
        var out: [VisitPacket.Question] = []
        func propose(rule: String, text: String) {
            let id = "\(userId.lowercased())-visitq-\(rule)"
            let tombstone = "visitq.removed.\(rule).\(userId.lowercased())"
            guard !UserDefaults.standard.bool(forKey: tombstone) else { return }
            if existing.contains(where: { $0.id == id }) { return }
            let payload = try? JSONSerialization.data(
                withJSONObject: ["origin": "generated", "rule": rule]
            )
            let record = ObservationStore.record(
                .visitQuestion, valueText: text, payload: payload,
                dayKey: dayFormatter.string(from: .now), userId: userId,
                source: "derived", in: context, sync: false, id: id
            )
            out.append(.init(id: record.id, text: text, origin: "generated"))
        }

        if let regimen, regimen.scheduledCount > 0,
           regimen.skippedCount + regimen.unrecordedCount >= 2 {
            // p55 — no cadence word: the packet's own header already
            // states her rhythm ("every 10 days"), and this question
            // said "weekly" to every cadence.
            propose(
                rule: "rhythm",
                text: "you may want to mention how the rhythm is fitting."
            )
        }
        if symptoms.contains(where: { $0.count >= 3 }) {
            propose(
                rule: "tolerability",
                text: "worth discussing how meals have been sitting."
            )
        }
        if let weight, weight.entryCount < 3 {
            propose(
                rule: "weighrhythm",
                text: "ask what weigh-in rhythm would help between visits."
            )
        }
        if symptoms.contains(where: { $0.timingNote != nil }) {
            propose(
                rule: "timing",
                text: "your records show symptoms tend to land near dose days. worth mentioning the timing."
            )
        }
        return out
    }

    // MARK: Gaps (honest missing-information lines)

    private static func gapLines(
        regimen: VisitPacket.Regimen?,
        weight: VisitPacket.Weight?,
        nutrition: VisitPacket.Nutrition?,
        movement: VisitPacket.Movement?,
        symptoms: [VisitPacket.Symptom]
    ) -> [String] {
        var gaps: [String] = []
        if let regimen, regimen.unrecordedCount > 0 {
            gaps.append("\(regimen.unrecordedCount) scheduled dose day\(regimen.unrecordedCount == 1 ? "" : "s") went unrecorded. unrecorded is not skipped.")
        }
        if weight == nil {
            gaps.append("no weigh-ins this period.")
        } else if let weight, weight.directionWord == nil {
            gaps.append("not enough weigh-ins to describe a trend (logged \(weight.entryCount) time\(weight.entryCount == 1 ? "" : "s")).")
        }
        if nutrition == nil {
            gaps.append("fewer than 5 logged food days. no eating pattern is claimed.")
        }
        if movement == nil {
            gaps.append("not enough movement data to describe consistency.")
        }
        if symptoms.isEmpty {
            gaps.append("no sit-check answers this period.")
        }
        return gaps
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
