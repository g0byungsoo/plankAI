import Foundation
import SwiftData
import PlankFood
import PlankSync

// MARK: - WeeklyReview (app v4 spine)
//
// docs/app_v4/01_PROGRAM.md §0. THE RE-SIGNING: at each program-week
// boundary jeni reads the week back from her real data, proposes at
// most ONE adjustment with the reason attached, and she consents,
// adjusts, or declines — never punished. The plan visibly learns or
// visibly holds; both are signal.
//
// Evidence license: automated weekly tailored feedback matched human
// coaching at 3 months (Tate 2006); adaptation builds trust only as
// a named, reasoned, consented moment (MacroFactor anatomy; Runna;
// Garmin's "why" retrofit) — docs/app_v4/research/PROGRAM_STRUCTURE.
//
// Weeks are ENROLLMENT-relative (day 1 = week 1 day 1), matching
// PrescriptionEngineV2's slot math — the review lands on HER week's
// closing evening (program day 7, 14, ...) or the first open in the
// 3 days after. Never on a break.
//
// Proposals draw from a CLOSED set and apply through knobs the
// engines already read (or gain a seam for in this pass):
//   plan.proteinAdjustG   Int, clamped ±10, read by TargetsService
//   plan.sessionsAdjust   Int, −1...+1, read by PrescriptionEngineV2
//   plan.weighSoftened    Bool, read by weighInSlots
//   plan.intentPick.weekN String, read by the intent resolver
// All identity-scoped ("plan." + "review." prefixes join the
// sign-out sweep). Records persist to a device-local JSONL
// (FoodLogPersister pattern) — no schema, no server.

// MARK: - ProgramWeekSlice (one week's facts)

struct ProgramWeekSlice: Equatable {
    struct DayFact: Equatable {
        let programDay: Int
        let dayKey: String
        let date: Date
        let isFuture: Bool
        let isPaused: Bool
        let completedCount: Int
        let oneThingDone: Bool
        let plateCount: Int
        let proteinG: Double
        let weighKg: Double?
        let repKept: Bool

        /// Standing over EVERYTHING that happened — beats checked OR
        /// raw actions recorded (a weigh-in without its check still
        /// counts; "any meaningful action" is the spine's law). max()
        /// avoids double-counting a checked snap against its plates.
        var standing: DayStanding {
            let actions = (plateCount > 0 ? 1 : 0)
                + (weighKg != nil ? 1 : 0)
                + (repKept ? 1 : 0)
            return DayStanding.from(
                completedCount: max(completedCount, actions),
                oneThingDone: oneThingDone
            )
        }
    }

    let weekIndex: Int
    let days: [DayFact]

    var elapsedDays: [DayFact] { days.filter { !$0.isFuture && !$0.isPaused } }
    var keptCount: Int { elapsedDays.filter { $0.standing == .kept }.count }
    var plateCount: Int { elapsedDays.reduce(0) { $0 + $1.plateCount } }
    var weighCount: Int { elapsedDays.compactMap(\.weighKg).count }
    var repsKept: Int { elapsedDays.filter(\.repKept).count }
    var pausedCount: Int { days.filter(\.isPaused).count }

    func proteinDaysMet(targetG: Int?) -> Int {
        guard let targetG, targetG > 0 else { return 0 }
        return elapsedDays.filter { $0.proteinG >= Double(targetG) }.count
    }
}

// MARK: - ReviewProposal (the closed set)

enum ReviewProposal: Equatable {
    case holdSteady(reason: String)
    case proteinEase(newG: Int, reason: String)
    case proteinFirm(newG: Int, reason: String)
    case movesEase(newCount: Int, reason: String)
    case weighSoften(reason: String)
    case intentPick(options: [WeekIntentSpec], reason: String)

    /// Stable key for records + analytics.
    var key: String {
        switch self {
        case .holdSteady: return "hold_steady"
        case .proteinEase: return "protein_ease"
        case .proteinFirm: return "protein_firm"
        case .movesEase: return "moves_ease"
        case .weighSoften: return "weigh_soften"
        case .intentPick: return "intent_pick"
        }
    }

    /// The proposal sentence — jeni's voice, provenance-backed.
    var title: String {
        switch self {
        case .holdSteady:
            return "the plan holds steady"
        case .proteinEase(let g, _):
            return "ease your protein floor to \(g)g"
        case .proteinFirm(let g, _):
            return "raise your protein floor to \(g)g"
        case .movesEase(let n, _):
            return n == 1 ? "one move this week" : "\(n) moves this week"
        case .weighSoften:
            return "one gentle weigh-in a week"
        case .intentPick:
            return "you pick next week's focus"
        }
    }

    var reason: String {
        switch self {
        case .holdSteady(let r), .proteinEase(_, let r), .proteinFirm(_, let r),
             .movesEase(_, let r), .weighSoften(let r), .intentPick(_, let r):
            return r
        }
    }
}

// MARK: - ReviewRecord (the signed moment)

struct ReviewRecord: Codable, Equatable, Identifiable {
    let id: String
    let userId: String
    let weekIndex: Int
    let decidedAtISO: String
    let proposalKey: String
    /// "kept" | "adjusted" | "declined"
    let decision: String
    /// The stamp the journey renders ("protein floor → 95g").
    let stampLine: String
    /// The because-you clause, kept verbatim for the journey.
    let reasonLine: String
    /// The week's name, frozen at signing — a steadying week stays
    /// "the steadying week" in memory even after the zone recovers.
    let weekName: String
}

// MARK: - WeeklyReview

enum WeeklyReview {

    static let proteinAdjustKey = "plan.proteinAdjustG"
    static let sessionsAdjustKey = "plan.sessionsAdjust"
    static let weighSoftenedKey = "plan.weighSoftened"
    static func intentPickKey(week: Int) -> String { "plan.intentPick.week\(week)" }

    // MARK: - Due logic (pure)

    /// The week index whose re-signing is due, or nil. Due on the
    /// week's closing evening (day-in-week 7 from 17:00) and through
    /// the first 3 days of the next week. Never while on a break;
    /// never for a week already signed; needs ≥3 elapsed days so a
    /// mid-week enrollment's stub week doesn't review itself.
    static func dueWeekIndex(
        programDay: Int,
        hour: Int,
        signedWeeks: Set<Int>,
        breakActive: Bool,
        elapsedDaysInWeek: (Int) -> Int
    ) -> Int? {
        guard !breakActive, programDay >= 7 else { return nil }
        let slot = PrescriptionEngineV2.dayInWeek(programDay)   // 0-6
        let week = PrescriptionEngineV2.programWeek(programDay)

        var candidate: Int?
        if slot == 6, hour >= 17 {
            candidate = week
        } else if slot <= 2, week >= 2 {
            candidate = week - 1
        }
        guard let candidate, candidate >= 1,
              !signedWeeks.contains(candidate),
              elapsedDaysInWeek(candidate) >= 3
        else { return nil }
        return candidate
    }

    // MARK: - Proposal rules (pure, conservative, closed set)

    struct ProposalInputs: Equatable {
        var chapter: Chapter
        var phaseKey: ArcPhase.Key
        var zone: BandZone?
        var numericsSuppressed: Bool
        var restrictiveRisk: Bool
        var proteinTargetG: Int?
        var proteinAdjustG: Int
        var sessionsPlanned: Int
        var sessionsAdjust: Int
        var movedDays: Int
        var weighCount: Int
        var priorWeekWeighCount: Int?
        var proteinDaysMet: Int
        /// Days with at least one plate logged — the protein rules'
        /// provenance floor: an unreached floor means nothing when
        /// the plates simply weren't logged.
        var plateLoggedDays: Int
        var keptCount: Int
        var elapsedDays: Int
    }

    static func propose(_ p: ProposalInputs) -> ReviewProposal {
        // Zone weeks own themselves — the re-signing acknowledges.
        if p.chapter == .keeping, p.zone == .drifting || p.zone == .reset {
            return .holdSteady(reason: p.zone == .drifting
                ? "steadying week active. everything else holds."
                : "reset arc active. everything else holds.")
        }

        // Protein floor reachability — on-med this is the hero rule.
        // Easing meets her where the week actually was; the formula's
        // advisory band still clamps the floor downstream. Provenance
        // floor: the rules only speak when ≥4 days actually logged
        // plates (an unreached floor means nothing on absent data).
        if !p.numericsSuppressed, let target = p.proteinTargetG,
           p.plateLoggedDays >= 4 {
            if p.proteinDaysMet <= 1, p.elapsedDays >= 5, p.proteinAdjustG > -10 {
                return .proteinEase(
                    newG: target - 5,
                    reason: "\(target)g landed \(p.proteinDaysMet) of \(p.elapsedDays) days. a 5g lower floor fits this week."
                )
            }
            if p.proteinDaysMet >= 5, p.proteinAdjustG < 10, !p.restrictiveRisk {
                return .proteinFirm(
                    newG: target + 5,
                    reason: "you cleared \(target)g on \(p.proteinDaysMet) of \(p.elapsedDays) days. the floor can rise 5g."
                )
            }
        }

        // Movement honesty — the plan bends toward her real week.
        if p.movedDays == 0, p.sessionsPlanned >= 3, p.sessionsAdjust > -1 {
            return .movesEase(
                newCount: p.sessionsPlanned - 1,
                reason: "0 of \(p.sessionsPlanned) sessions happened. a smaller plan fits this stretch."
            )
        }

        // The scale can wait — two quiet weigh weeks in a row.
        if p.chapter != .keeping, p.weighCount == 0,
           (p.priorWeekWeighCount ?? 1) == 0 {
            return .weighSoften(
                reason: "two weeks without a weigh-in. one weekly check keeps the trend alive."
            )
        }

        // The bend responds to a change of angle — she picks.
        if p.phaseKey == .bend {
            let options = ["steady_week", "fresh_angle", "protein_week"]
                .compactMap { WeekIntent.spec(for: $0) }
            return .intentPick(
                options: options,
                reason: "the plateau stretch. pick next week's focus."
            )
        }

        let kept = p.keptCount
        return .holdSteady(reason: kept >= 3
            ? "\(kept) kept \(kept == 1 ? "day" : "days") this week. the plan holds."
            : "a quiet week. the plan holds; monday restarts.")
    }

    // MARK: - Consent application

    /// Applies a consented proposal through the engine knobs. Returns
    /// the stamp line the journey renders. `decision` is "kept" for
    /// the proposal as offered; intent picks pass the chosen spec.
    @discardableResult
    static func apply(
        _ proposal: ReviewProposal,
        forWeek weekIndex: Int,
        chosenIntentKey: String? = nil,
        _ d: UserDefaults = .standard
    ) -> String {
        switch proposal {
        case .holdSteady:
            return "the plan held steady"
        case .proteinEase(let g, _):
            let adj = max(-10, d.integer(forKey: proteinAdjustKey) - 5)
            d.set(adj, forKey: proteinAdjustKey)
            return "protein floor → \(g)g"
        case .proteinFirm(let g, _):
            let adj = min(10, d.integer(forKey: proteinAdjustKey) + 5)
            d.set(adj, forKey: proteinAdjustKey)
            return "protein floor → \(g)g"
        case .movesEase(let n, _):
            d.set(max(-1, d.integer(forKey: sessionsAdjustKey) - 1),
                  forKey: sessionsAdjustKey)
            return n == 1 ? "one move a week" : "\(n) moves a week"
        case .weighSoften:
            d.set(true, forKey: weighSoftenedKey)
            return "one weigh-in a week"
        case .intentPick:
            if let chosenIntentKey, let picked = WeekIntent.spec(for: chosenIntentKey) {
                d.set(chosenIntentKey, forKey: intentPickKey(week: weekIndex + 1))
                return "next week: \(picked.name)"
            }
            return "next week: your pick"
        }
    }

    // MARK: - Week story (the receipt's authored line)

    /// One sentence over the week's facts — the week card's voice.
    /// Provenance-only: every clause traces to a counted fact.
    static func weekStory(slice: ProgramWeekSlice, chapter: Chapter) -> String {
        let kept = slice.keptCount
        let plates = slice.plateCount
        let weighs = slice.weighCount

        if slice.pausedCount >= 5 {
            return "a break week. plan paused."
        }
        if kept == 0 && plates == 0 && weighs == 0 {
            return "a quiet week. nothing logged."
        }
        var clauses: [String] = []
        if kept > 0 {
            clauses.append(kept == 1 ? "one day kept" : "\(kept) days kept")
        }
        if plates > 0 {
            clauses.append(plates == 1 ? "one plate logged" : "\(plates) plates logged")
        }
        if weighs > 0, chapter != .onMedication {
            clauses.append(weighs == 1 ? "weighed in once" : "weighed in \(weighs) times")
        }
        if slice.repsKept > 0, clauses.count < 3 {
            clauses.append(slice.repsKept == 1 ? "one rep done" : "\(slice.repsKept) reps done")
        }
        return clauses.prefix(3).joined(separator: " · ") + "."
    }

    // MARK: - Records (device-local JSONL)

    private static var storeURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("WeeklyReviews", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reviews.jsonl")
    }

    private static var cache: [ReviewRecord]?

    static func records(userId: String) -> [ReviewRecord] {
        if cache == nil { cache = loadAll() }
        return (cache ?? []).filter { $0.userId == userId }
    }

    static func signedWeeks(userId: String) -> Set<Int> {
        Set(records(userId: userId).map(\.weekIndex))
    }

    static func record(_ record: ReviewRecord) {
        if cache == nil { cache = loadAll() }
        cache?.append(record)
        guard let url = storeURL,
              let data = try? JSONEncoder().encode(record),
              let line = String(data: data, encoding: .utf8)
        else { return }
        let payload = line + "\n"
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(payload.utf8))
            }
        } else {
            try? payload.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func loadAll() -> [ReviewRecord] {
        guard let url = storeURL,
              let raw = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return raw.split(separator: "\n").compactMap {
            try? JSONDecoder().decode(ReviewRecord.self, from: Data($0.utf8))
        }
    }

    /// Test seam — drops the in-memory cache so a fresh read hits disk.
    static func _resetCacheForTesting() { cache = nil }

    #if DEBUG
    /// QA seam — wipes records + consent knobs so seeded walker runs
    /// are deterministic (a prior run's signature must not silence
    /// the next run's re-signing).
    static func _wipeForQA(_ d: UserDefaults = .standard) {
        cache = []
        if let url = storeURL {
            try? FileManager.default.removeItem(at: url)
        }
        for key in d.dictionaryRepresentation().keys
        where key.hasPrefix("plan.") || key.hasPrefix("review.") {
            d.removeObject(forKey: key)
        }
    }
    #endif

    // MARK: - Week slice loader (the live assembler)

    /// Facts for one program week. Deterministic engines make the
    /// past reconstructable: the day's one-thing is re-derived from
    /// the same pure compose the day rendered with.
    @MainActor
    static func weekSlice(
        weekIndex: Int,
        userId: String,
        plan: ProgramPlanRecord,
        in context: ModelContext,
        now: Date = .now
    ) -> ProgramWeekSlice {
        let cal = Calendar.current
        let startOfPlan = cal.startOfDay(for: plan.startDate)
        let today = cal.startOfDay(for: now)
        let planId = plan.id

        let firstDay = (weekIndex - 1) * 7 + 1
        let lastDay = min(weekIndex * 7, max(plan.totalDays, firstDay))

        // One fetch per source for the whole window.
        let checks = (try? context.fetch(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.programPlanId == planId
                && $0.programDay >= firstDay && $0.programDay <= lastDay
            }
        ))) ?? []

        guard let windowStart = cal.date(byAdding: .day, value: firstDay - 1, to: startOfPlan),
              let windowEnd = cal.date(byAdding: .day, value: lastDay, to: startOfPlan)
        else { return ProgramWeekSlice(weekIndex: weekIndex, days: []) }

        let weights = (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate {
                $0.userId == userId
                && $0.loggedAt >= windowStart && $0.loggedAt < windowEnd
                && $0.source != "onboarding"
            }
        ))) ?? []

        let plates = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= windowStart && $0.loggedAt < windowEnd }

        let d = UserDefaults.standard
        var days: [ProgramWeekSlice.DayFact] = []
        for programDay in firstDay...lastDay {
            guard let date = cal.date(byAdding: .day, value: programDay - 1, to: startOfPlan)
            else { continue }
            let dayKey = TodayStateService.dayKey(for: date)
            let dayChecks = checks.filter { $0.programDay == programDay }
            let done = dayChecks.filter {
                $0.state == "complete" || $0.state == "autoCompleted"
            }
            let dayPlates = plates.filter { cal.isDate($0.loggedAt, inSameDayAs: date) }
            let dayWeigh = weights
                .filter { cal.isDate($0.loggedAt, inSameDayAs: date) }
                .sorted { $0.loggedAt > $1.loggedAt }
                .first?.weightKg

            // Re-derive the day's one thing from the pure engine.
            let composed = PrescriptionEngineV2.compose(
                programDay: programDay,
                totalDays: plan.totalDays,
                profile: IntensityProfile.from(
                    tier: IntensityTier(rawValue: plan.intensityTier) ?? .medium
                ),
                context: .live(lastWeighInDaysAgo: nil, lastSnapDaysAgo: nil)
            )
            let oneThingDone = composed.oneThing.map { one in
                done.contains { $0.itemKey == one.itemKey }
            } ?? false

            days.append(ProgramWeekSlice.DayFact(
                programDay: programDay,
                dayKey: dayKey,
                date: date,
                isFuture: date > today,
                isPaused: BreakState.covers(dayKey: dayKey, now: now),
                completedCount: done.count,
                oneThingDone: oneThingDone,
                plateCount: dayPlates.count,
                proteinG: dayPlates.reduce(0) { $0 + $1.protein },
                weighKg: dayWeigh,
                repKept: d.object(forKey: "lesson.rep.kept.\(dayKey)") != nil
            ))
        }
        return ProgramWeekSlice(weekIndex: weekIndex, days: days)
    }
}
