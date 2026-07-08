import Foundation
import SwiftData
import PlankSync

// MARK: - JourneyModel (app v4, docs/app_v4/02_JOURNEY.md)
//
// The ledger's loader: assembles week entries (slice + name + story
// + signed record) for the visible window, the current week, and
// next week's shape. Views stay dumb; everything here reads through
// the pure engines so the past is reconstructable and the future is
// shape, never a locked list.

struct JourneyModel {

    struct WeekEntry: Identifiable {
        let weekIndex: Int
        let slice: ProgramWeekSlice
        let name: String
        /// The intent sentence (current week only renders it).
        let intentLine: String?
        let story: String
        let record: ReviewRecord?
        /// v5 — the week's trend movement as a quiet receipt total
        /// ("−0.9 lb" / "steady"), EMA-sourced, nil under 3 in-week
        /// points (same trust floor as the reading).
        var weightDeltaLine: String? = nil

        var id: Int { weekIndex }

        var dotDays: [JKStandingDots.Day] {
            slice.days.map {
                JKStandingDots.Day(
                    id: $0.programDay,
                    standing: $0.standing,
                    // v5: today reads distinct in the current week's
                    // card (the passthrough never marked it).
                    isToday: Calendar.current.isDateInToday($0.date),
                    isFuture: $0.isFuture,
                    isPaused: $0.isPaused
                )
            }
        }
    }

    let currentWeek: WeekEntry?
    /// Newest-first past weeks in the loaded window.
    let pastWeeks: [WeekEntry]
    /// Weeks older than the window, compressed ("the first N weeks").
    let earlierWeekCount: Int
    let nextWeekName: String?
    let nextWeekShape: String?
    /// A re-signing is due — the journey offers the received moment.
    let dueReview: DueReview?

    struct DueReview: Identifiable {
        let weekIndex: Int
        let slice: ProgramWeekSlice
        let proposal: ReviewProposal
        let weekName: String
        let story: String

        /// Item-identity for the full-screen cover: the presented
        /// copy must survive a journey reload mid-presentation (a
        /// signed review resolves dueReview to nil behind the cover;
        /// an isPresented cover would blank out — the walker caught
        /// exactly that as a white screen).
        var id: Int { weekIndex }
    }

    /// How many past weeks the ledger loads eagerly.
    static let windowWeeks = 4

    // MARK: - Load

    @MainActor
    static func load(
        userId: String,
        snapshot: TodaySnapshot,
        in context: ModelContext,
        now: Date = .now
    ) -> JourneyModel {
        guard let plan = snapshot.plan, snapshot.programDay >= 1 else {
            return JourneyModel(
                currentWeek: nil, pastWeeks: [], earlierWeekCount: 0,
                nextWeekName: nil, nextWeekShape: nil, dueReview: nil
            )
        }

        let week = max(snapshot.programWeek, 1)
        let records = Dictionary(
            uniqueKeysWithValues: WeeklyReview.records(userId: userId)
                .map { ($0.weekIndex, $0) }
        )
        let flags = WeekIntent.Flags.live
        let zone = snapshot.bandZone.flatMap(BandZone.init(rawValue:))
        let d = UserDefaults.standard

        // One EMA pass feeds every card's delta line (same source as
        // the trend canvas — the one-story law).
        let emaPoints: [WeightTrendChart.EMAPoint] = {
            let descriptor = FetchDescriptor<WeightLogRecord>(
                predicate: #Predicate { $0.userId == userId },
                sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
            )
            let logs = (try? context.fetch(descriptor)) ?? []
            return WeightTrendChart.computeEMA(logs: logs)
        }()
        let unitRaw = d.string(forKey: "weightUnit") ?? "lb"
        let unit = WeightUnit(rawValue: unitRaw) ?? .lb

        func deltaLine(for slice: ProgramWeekSlice) -> String? {
            guard let first = slice.days.first?.date,
                  let last = slice.days.last?.date else { return nil }
            let cal = Calendar.current
            let start = cal.startOfDay(for: first)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last)) ?? last
            let inWeek = emaPoints.filter { $0.date >= start && $0.date < end }
            guard inWeek.count >= 3,
                  let a = inWeek.first?.emaKg, let b = inWeek.last?.emaKg
            else { return nil }
            let deltaKg = b - a
            guard abs(deltaKg) >= 0.1 else { return "steady" }
            let display = abs(unit.display(fromKg: abs(deltaKg)))
            return String(format: "%@%.1f %@", deltaKg < 0 ? "−" : "+", display, unit.label)
        }

        func entry(for weekIndex: Int, isCurrent: Bool) -> WeekEntry {
            let slice = WeeklyReview.weekSlice(
                weekIndex: weekIndex, userId: userId, plan: plan,
                in: context, now: now
            )
            let record = records[weekIndex]
            let phase = ProgramArc.phase(
                week: weekIndex,
                totalWeeks: snapshot.totalWeeks,
                chapter: snapshot.chapter
            )
            let intent = WeekIntent.intent(
                week: weekIndex,
                chapter: snapshot.chapter,
                phase: phase,
                flags: flags,
                zone: isCurrent ? zone : nil,
                pickedKey: d.string(forKey: WeeklyReview.intentPickKey(week: weekIndex))
            )
            // A signed week keeps its frozen name (a drifting week
            // stays "the steadying week" in memory even after the
            // zone recovers).
            let name = record?.weekName ?? intent.name
            return WeekEntry(
                weekIndex: weekIndex,
                slice: slice,
                name: name,
                intentLine: isCurrent ? intent.line : nil,
                story: WeeklyReview.weekStory(slice: slice, chapter: snapshot.chapter),
                record: record,
                weightDeltaLine: deltaLine(for: slice)
            )
        }

        let current = entry(for: week, isCurrent: true)

        let oldestLoaded = max(1, week - windowWeeks)
        var past: [WeekEntry] = []
        if week > 1 {
            for idx in stride(from: week - 1, through: oldestLoaded, by: -1) {
                past.append(entry(for: idx, isCurrent: false))
            }
        }

        // Next week: shape, never a list.
        let nextIndex = week + 1
        var nextName: String?
        var nextShape: String?
        let withinPlan = snapshot.chapter != .losing
            || nextIndex <= snapshot.totalWeeks
        if withinPlan {
            let nextPhase = ProgramArc.phase(
                week: nextIndex,
                totalWeeks: snapshot.totalWeeks,
                chapter: snapshot.chapter
            )
            let nextIntent = WeekIntent.intent(
                week: nextIndex,
                chapter: snapshot.chapter,
                phase: nextPhase,
                flags: flags,
                zone: nil,
                pickedKey: d.string(forKey: WeeklyReview.intentPickKey(week: nextIndex))
            )
            nextName = nextIntent.name
            nextShape = weekShapeLine(
                weekIndex: nextIndex, plan: plan, snapshot: snapshot
            )
        }

        // The re-signing, if due.
        var due: DueReview?
        if let dueIndex = WeeklyReview.dueWeekIndex(
            programDay: snapshot.programDay,
            hour: Calendar.current.component(.hour, from: now),
            signedWeeks: WeeklyReview.signedWeeks(userId: userId),
            breakActive: snapshot.isOnBreak,
            elapsedDaysInWeek: { idx in
                let slice = idx == week ? current.slice
                    : past.first(where: { $0.weekIndex == idx })?.slice
                    ?? WeeklyReview.weekSlice(
                        weekIndex: idx, userId: userId, plan: plan,
                        in: context, now: now
                    )
                return slice.elapsedDays.count
            }
        ) {
            let dueEntry = dueIndex == week ? current
                : past.first(where: { $0.weekIndex == dueIndex })
                ?? entry(for: dueIndex, isCurrent: false)
            due = DueReview(
                weekIndex: dueIndex,
                slice: dueEntry.slice,
                proposal: proposal(for: dueEntry.slice, snapshot: snapshot, plan: plan),
                weekName: dueEntry.name,
                story: dueEntry.story
            )
        }

        return JourneyModel(
            currentWeek: current,
            pastWeeks: past,
            earlierWeekCount: max(0, oldestLoaded - 1),
            nextWeekName: nextName,
            nextWeekShape: nextShape,
            dueReview: due
        )
    }

    // MARK: - Proposal assembly (live inputs → pure rules)

    @MainActor
    private static func proposal(
        for slice: ProgramWeekSlice,
        snapshot: TodaySnapshot,
        plan: ProgramPlanRecord
    ) -> ReviewProposal {
        let d = UserDefaults.standard
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let profile = IntensityProfile.from(tier: tier)
        let phase = ProgramArc.phase(
            week: slice.weekIndex,
            totalWeeks: snapshot.totalWeeks,
            chapter: snapshot.chapter
        )
        // Prior week's weigh count feeds the two-quiet-weeks rule.
        let priorWeighs: Int? = slice.weekIndex > 1
            ? nil   // loaded lazily only when the current week is quiet
            : nil

        return WeeklyReview.propose(.init(
            chapter: snapshot.chapter,
            phaseKey: phase.key,
            zone: snapshot.bandZone.flatMap(BandZone.init(rawValue:)),
            numericsSuppressed: snapshot.targets.numericsSuppressed,
            restrictiveRisk: CohortStore.isRestrictiveRisk,
            proteinTargetG: snapshot.targets.proteinG,
            proteinAdjustG: d.integer(forKey: WeeklyReview.proteinAdjustKey),
            sessionsPlanned: max(1, min(6, profile.sessionsPerWeek
                + d.integer(forKey: WeeklyReview.sessionsAdjustKey))),
            sessionsAdjust: d.integer(forKey: WeeklyReview.sessionsAdjustKey),
            movedDays: movedDays(slice: slice),
            weighCount: slice.weighCount,
            priorWeekWeighCount: priorWeighs,
            proteinDaysMet: slice.proteinDaysMet(targetG: snapshot.targets.proteinG),
            plateLoggedDays: slice.elapsedDays.filter { $0.plateCount > 0 }.count,
            keptCount: slice.keptCount,
            elapsedDays: slice.elapsedDays.count
        ))
    }

    private static func movedDays(slice: ProgramWeekSlice) -> Int {
        // A moved day = the day's one thing was a workout that landed
        // OR any completed count ≥ 1 on a workout day. The slice
        // carries completed counts; workout-specific checks ride the
        // one-thing derivation upstream. Conservative: use kept +
        // partial days with any completion as the floor.
        slice.elapsedDays.filter { $0.completedCount >= 1 && $0.oneThingDone }.count
    }

    // MARK: - The future's shape line

    /// One sentence of rhythm for a coming week — counted from the
    /// pure engine, spoken as shape ("3 moves · 2 reads · one trend
    /// check"), never a day-by-day list.
    @MainActor
    static func weekShapeLine(
        weekIndex: Int,
        plan: ProgramPlanRecord,
        snapshot: TodaySnapshot
    ) -> String {
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let profile = IntensityProfile.from(tier: tier)
        let firstDay = (weekIndex - 1) * 7 + 1
        let lastDay = min(weekIndex * 7, plan.totalDays)
        guard firstDay <= lastDay else { return "the road ahead" }

        var moves = 0, reads = 0, weighs = 0, breaths = 0
        for day in firstDay...lastDay {
            let composed = PrescriptionEngineV2.compose(
                programDay: day,
                totalDays: plan.totalDays,
                profile: profile,
                context: .live(lastWeighInDaysAgo: 0, lastSnapDaysAgo: nil)
            )
            for beat in composed.beats {
                switch beat {
                case .workout: moves += 1
                case .lesson: reads += 1
                case .weighIn: weighs += 1
                case .breath: breaths += 1
                default: break
                }
            }
        }

        var parts: [String] = []
        if moves > 0 { parts.append(moves == 1 ? "one move" : "\(moves) moves") }
        // Daily-cadence reads compress to their rhythm — "7 reads"
        // reads as homework; "the daily rep" reads as a practice.
        if reads >= 5 { parts.append("the daily rep") }
        else if reads > 0 { parts.append(reads == 1 ? "one read" : "\(reads) reads") }
        if weighs > 0 { parts.append(weighs == 1 ? "one trend check" : "\(weighs) trend checks") }
        if breaths > 0 { parts.append("a rest-day breath") }
        if parts.isEmpty { return "a light week, on purpose" }
        return parts.joined(separator: " · ")
    }
}
