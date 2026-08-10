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
    }

    struct Question: Equatable, Identifiable {
        let id: String
        let text: String
        /// "generated" | "her"
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
        // F1: self-reported stays generic; care-team renders the
        // assigned facts only when actually present.
        let displayLine: String = {
            if managed {
                var line = plan.displayName.isEmpty ? "your medication" : plan.displayName
                if let v = plan.strengthValue, let u = plan.strengthUnit {
                    line += " \(v.formatted()) \(u)"
                }
                return line
            }
            return "your weekly medication"
        }()

        let calendar = Calendar.current
        let activeStart = max(window.start, calendar.startOfDay(for: plan.startedAt))
        let activeEnd = plan.endedAt.map { min(window.end, calendar.startOfDay(for: $0)) } ?? window.end
        var scheduled: [String] = []
        if activeStart <= activeEnd, let anchor = plan.anchorWeekday {
            var day = activeStart
            while day <= activeEnd {
                if RegimenService.isoWeekday(day) == anchor {
                    scheduled.append(dayFormatter.string(from: day))
                }
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? activeEnd.addingTimeInterval(1)
            }
        }

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
            anchorWeekdayWord: plan.anchorWeekday.flatMap { iso in
                ["monday", "tuesday", "wednesday", "thursday",
                 "friday", "saturday", "sunday"][safe: iso - 1]
            },
            scheduledCount: scheduled.count,
            takenCount: taken,
            skippedCount: skipped
        )
    }

    // MARK: Weight

    private static func weightSection(
        userId: String, window: VisitPacket.Window, in context: ModelContext
    ) -> VisitPacket.Weight? {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.loggedAt, order: .forward)]
        )
        let calendar = Calendar.current
        let logs = ((try? context.fetch(descriptor)) ?? []).filter {
            $0.loggedAt >= window.start
                && $0.loggedAt < (calendar.date(byAdding: .day, value: 1, to: window.end) ?? window.end)
        }
        guard !logs.isEmpty else { return nil }

        // One entry per day (the latest that day) — duplicates and
        // corrections collapse honestly.
        var byDay: [String: WeightLogRecord] = [:]
        for log in logs { byDay[dayFormatter.string(from: log.loggedAt)] = log }
        let daily = byDay.values.sorted { $0.loggedAt < $1.loggedAt }

        let spanDays = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: daily.first!.loggedAt),
            to: calendar.startOfDay(for: daily.last!.loggedAt)
        ).day ?? 0
        let trendEstablished = daily.count >= 3 && spanDays >= 5

        let direction: String? = {
            guard trendEstablished else { return nil }
            let delta = daily.last!.weightKg - daily.first!.weightKg
            if delta <= -0.3 { return "easing" }
            if delta >= 0.3 { return "climbing" }
            return "steady"
        }()

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
        guard moved > 0 || stepsAvg != nil else { return nil }
        return .init(movedDays: moved, stepsWeekAvg: stepsAvg)
    }

    // MARK: Questions (records; generated ones insert once per rule)

    static func questionRecords(
        userId: String, in context: ModelContext
    ) -> [VisitPacket.Question] {
        ObservationStore.series(.visitQuestion, userId: userId, limit: 20, in: context)
            .compactMap { record in
                guard let text = record.valueText, !text.isEmpty else { return nil }
                let origin = (record.payload
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["origin"] as? String) ?? "her"
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
            propose(
                rule: "rhythm",
                text: "you may want to mention how the weekly rhythm is fitting."
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
