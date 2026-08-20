import Foundation
import SwiftData
import PlankSync

// MARK: - ChatToolRouter
//
// App v2 (docs/app_v2/05_CHAT.md §Tools), rebuilt in v25 E3 ONE JENI
// (docs/app_v25/12_E3_ONE_JENI.md §2). Jeni proposes; this executes —
// through the same writers and router the rest of the app uses.
//
// THE THREE KINDS, and why the difference is the era:
//
//   READ          — answers a question from the stored record and
//                   CONTINUES the turn, so jeni writes her reply from
//                   real data. No card, no confirmation, no mutation.
//   actImmediate  — opens or renders something. Fires at once.
//   actConfirmed  — changes stored state. Renders a card first; runs
//                   only on the user's tap, then continues so jeni
//                   can acknowledge what actually happened.
//
// The kind comes from `JeniToolCatalog`, which is also what goes on
// the wire — so the list the model sees and the behaviour the app
// gives it cannot drift apart.

@MainActor
enum ChatToolRouter {

    static func kind(of name: String) -> JeniToolKind {
        JeniToolCatalog.kind(of: name)
    }

    static func isRead(_ name: String) -> Bool {
        JeniToolCatalog.isRead(name)
    }

    static func needsConfirmation(_ name: String) -> Bool {
        JeniToolCatalog.needsConfirmation(name)
    }

    /// The line shown while a read is in flight. Honest theater: it
    /// names what she is doing, in her register, and it is gone in a
    /// second. (v23's law — real work may be narrated; fake work may
    /// not.)
    static func readingLine(for call: ChatToolCall) -> String {
        switch call.name {
        case "read_food_day", "read_food_week": return "reading your plates"
        case "read_weight_trend":               return "reading your trend"
        case "read_dose_history":               return "reading your doses"
        case "read_symptoms":                   return "reading what you've logged"
        case "read_patterns":                   return "looking for a pattern"
        case "read_activity":                   return "reading your movement"
        case "read_program":                    return "checking your plan"
        default:                                return "reading your record"
        }
    }

    /// The card's line. Voice contract: lowercase, concrete, and it
    /// states what will be TRUE, not what the model asked for.
    static func cardLabel(for call: ChatToolCall) -> String {
        switch call.name {
        case "open_snap_camera":
            return "opening the camera"
        case "log_weight":
            if let kg = call.arguments["kg"] as? Double {
                let unit = WeightUnit.current
                return "weigh in at \(unit.display(fromKg: kg).formatted()) \(unit.label)?"
            }
            return "weigh in?"
        case "log_food_text":
            if let text = call.arguments["description"] as? String, !text.isEmpty {
                return "log \"\(text.lowercased())\"?"
            }
            return "log that meal?"
        case "propose_program_fact":
            return JeniActTools.proposalLabel(call.arguments) ?? "change your plan?"
        case "remember":
            return JeniActTools.rememberLabel(call.arguments) ?? "remember that?"
        case "show_today_plan":
            return "today's plan"
        case "open_lesson":
            return "opening today's lesson"
        case "start_breathwork":
            return "starting a breath session"
        case "show_weight_trend":
            return "your trend line"
        case "open_dose_sheet":
            return "opening your dose sheet"
        case "open_weekly_read":
            return "opening your weekly read"
        case "set_reminder_hour":
            if let hour = call.arguments["hour"] as? Int {
                return "move your daily nudge to \(hourLabel(hour))?"
            }
            return "move your daily nudge?"
        default:
            return call.name.replacingOccurrences(of: "_", with: " ")
        }
    }

    static func glyph(for name: String) -> String {
        switch name {
        case "open_snap_camera": return "camera"
        case "log_food_text": return "fork.knife"
        case "log_weight": return "scalemass"
        case "show_today_plan": return "list.bullet"
        case "open_lesson": return "book.closed"
        case "start_breathwork": return "leaf"
        case "show_weight_trend": return "chart.line.uptrend.xyaxis"
        case "set_reminder_hour": return "bell"
        case "open_dose_sheet": return "cross.vial"
        case "open_weekly_read": return "calendar"
        case "propose_program_fact": return "slider.horizontal.3"
        case "remember": return "bookmark"
        default: return "sparkle"
        }
    }

    /// Executes; returns the compact result JSON the continuation
    /// sends back so jeni can answer, or acknowledge, with truth.
    @discardableResult
    static func execute(
        _ call: ChatToolCall,
        userId: String,
        modelContext: ModelContext?
    ) -> [String: Any] {

        // — READS. Pure lookups over the same engines the surfaces
        //   render from; they never write and never navigate.
        if isRead(call.name) {
            guard let modelContext else {
                return ["have": false, "why": "the record isn't loaded"]
            }
            let result = JeniReadTools.execute(
                call, userId: userId, in: modelContext
            )
            Analytics.track(.jeniReadToolCalled, properties: [
                "tool": call.name,
                "had_data": (result["have"] as? Bool) ?? false,
            ])
            return result
        }

        switch call.name {
        case "open_snap_camera":
            AppRouter.shared.open(.snap)
            return ["opened": true]

        case "log_food_text":
            return JeniActTools.logFoodText(call.arguments)

        case "open_lesson":
            AppRouter.shared.open(.lesson)
            return ["opened": true]

        case "start_breathwork":
            AppRouter.shared.open(.breath)
            return ["opened": true]

        case "open_dose_sheet":
            guard let modelContext,
                  RegimenService.activeMedicationPlan(
                      userId: userId, in: modelContext
                  ) != nil
            else {
                return [
                    "opened": false,
                    "why": "there's no medication on their record, so there's no sheet to open.",
                ]
            }
            AppRouter.shared.open(.doseSheet)
            return [
                "opened": true,
                "note": "the sheet carries their medication's own label facts. don't restate the rules yourself.",
            ]

        case "open_weekly_read":
            AppRouter.shared.open(.weeklyRead)
            return [
                "opened": true,
                "note": "if no read is due yet, the page shows their record instead. the read arrives on its own anchor. don't promise them one today.",
            ]

        case "show_weight_trend":
            // 1.1.6: the trend renders INLINE (JKChatTrendCard) — the
            // conversation keeps them; the card's tap opens becoming.
            return ["shown": true]

        case "show_today_plan":
            // Inline card (JKChatPlanCard) renders from the snapshot.
            return ["shown": true]

        case "log_weight":
            guard
                let kg = call.arguments["kg"] as? Double,
                kg > 25, kg < 350,
                let modelContext, !userId.isEmpty
            else { return ["logged": false, "reason": "invalid"] }
            WeightLogWriter.persist(kg: kg, userId: userId, in: modelContext)
            _ = ProgramService.shared.markChecklistItem(
                prescription: .weighIn,
                state: .autoCompleted,
                userId: userId,
                in: modelContext
            )
            return ["logged": true, "kg": kg]

        case "propose_program_fact":
            guard let modelContext else {
                return ["applied": false, "reason": "no store"]
            }
            return JeniActTools.proposeProgramFact(
                call.arguments, userId: userId, in: modelContext
            ).payload

        case "remember":
            guard let modelContext else {
                return ["remembered": false, "reason": "no store"]
            }
            return JeniActTools.remember(
                call.arguments, userId: userId, in: modelContext
            )

        case "set_reminder_hour":
            guard let hour = call.arguments["hour"] as? Int, (0...23).contains(hour)
            else { return ["set": false] }
            UserDefaults.standard.set(reminderBucket(for: hour), forKey: "plankTime")
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = 0
            if let time = Calendar.current.date(from: comps) {
                NotificationPermission.scheduleDailyReminder(at: time)
            }
            return ["set": true, "hour": hour]

        default:
            return ["unknown_tool": call.name]
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12)\(hour < 12 ? "am" : "pm")"
    }

    /// Map an exact hour onto the existing plankTime bucket space
    /// (the daily-reminder scheduler reads buckets, not hours).
    private static func reminderBucket(for hour: Int) -> String {
        switch hour {
        case 0...10: return "morning"
        case 11...14: return "lunch"
        case 15...18: return "evening"
        default: return "night"
        }
    }
}

// MARK: - WeightLogWriter
//
// The one weight-write path chat + Today share (mirrors PlanView's
// persistWeight semantics: one row per day, updated in place).

@MainActor
enum WeightLogWriter {
    static func persist(kg: Double, userId: String, in context: ModelContext) {
        let uid = userId
        var descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let latest = try? context.fetch(descriptor).first
        if let latest, Calendar.current.isDateInToday(latest.loggedAt) {
            latest.weightKg = kg
            // v25 pass 51 — USER INTENT WINS. A number she typed is
            // HERS, even when today's row arrived from Apple Health:
            // without this relabel the row kept `healthkit`, and
            // `BodyMassImportService`'s own per-day rule ("a healthkit
            // row is the one the scale may correct in place") silently
            // overwrote her typed number on the next launch or observer
            // fire. Same one-line law as `update` below.
            latest.source = WeightLedger.sourceAfterCorrection(latest.source)
            latest.pendingUpsert = true
            try? context.save()
            Task { await AppSync.shared.upsertWeightLog(latest) }
        } else {
            let record = WeightLogRecord(
                userId: uid, weightKg: kg, loggedAt: .now, source: "manual"
            )
            context.insert(record)
            try? context.save()
            Task { await AppSync.shared.upsertWeightLog(record) }
        }
        NotificationCenter.default.post(name: .weightLogDidChange, object: nil)

        // v3 phase-7: the weigh chokepoint feeds the keeping
        // chapter's JITAI pings (zone crossing + pattern watcher).
        // No-ops outside the keeping chapter.
        Task { @MainActor in
            NotificationOrchestrator.onWeighSaved(userId: uid, in: context)
        }
    }

    // MARK: - Repair (v25 §34)
    //
    // `persist` above can only ever write TODAY: it updates the latest
    // row in place when that row is today's, and otherwise inserts a
    // `.now` one. So a weigh-in that was wrong — shoes on, a fat
    // finger, someone else's scale — was permanent the moment the
    // calendar rolled over, and it kept feeding
    // `TargetsService.resolvedWeightKg` (the calorie target AND the
    // protein floor) and the trend for as long as it stayed the
    // freshest row.
    //
    // These two are the repair, and they are deliberately the SAME
    // chokepoint rather than a second writer: the drift this whole line
    // of work exists to stop starts with a second writer.

    /// Correct one weigh-in in place. The id, the day and the user are
    /// untouched — it is the same weigh-in, with the number she meant.
    ///
    /// A corrected row becomes HERS (`source = "manual"`), which is not
    /// a relabel: `BodyMassImportService` re-imports the last thirty
    /// days on launch and overwrites any row still marked `healthkit`,
    /// so a typed correction that kept the old source would be silently
    /// reverted by the next sync. Its own rule — "manual rows always
    /// win their day" — is the fix.
    @discardableResult
    static func update(
        id: String, toKg kg: Double, userId: String, in context: ModelContext
    ) -> Bool {
        guard !userId.isEmpty, kg > 20, kg < 400 else { return false }
        let target = id
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.id == target }
        )
        guard let record = try? context.fetch(descriptor).first,
              record.userId.caseInsensitiveCompare(userId) == .orderedSame
        else { return false }
        record.weightKg = kg
        record.source = WeightLedger.sourceAfterCorrection(record.source)
        record.pendingUpsert = true
        try? context.save()
        Task { await AppSync.shared.upsertWeightLog(record) }
        NotificationCenter.default.post(name: .weightLogDidChange, object: nil)
        // Deliberately NOT `NotificationOrchestrator.onWeighSaved`: that
        // is the keeping chapter's reaction to a NEW weigh-in. Fixing a
        // typo from last Tuesday is not a weigh-in.
        return true
    }

    /// Take one weigh-in out of the record.
    ///
    /// The server delete is not optional. `applyHydratedWeightLogs` is
    /// insert-only by id, so a row removed only on the device is
    /// re-inserted by the next pull — a delete that undoes itself is
    /// worse than no delete at all.
    @discardableResult
    static func remove(
        id: String, userId: String, in context: ModelContext
    ) -> Bool {
        guard !userId.isEmpty else { return false }
        let target = id
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.id == target }
        )
        guard let record = try? context.fetch(descriptor).first,
              record.userId.caseInsensitiveCompare(userId) == .orderedSame
        else { return false }
        // v25 §38 — the deletion is a FACT this device records, not an
        // absence it infers. `applyHydratedWeightLogs` is insert-only,
        // so without the ledger a row a stale device pushed back (or
        // edited, which sets `pendingUpsert` and re-uploads it) lands
        // here again on the next hydrate. Recorded before the network
        // call so an offline delete is still remembered.
        DeletionLedger.record(id: target, userId: userId)
        // v25 §44 — AND THE DAY, because a weigh-in has a second author.
        // `BodyMassImportService` re-reads ninety days of Apple Health
        // at every launch and on every observer fire, decides by
        // CALENDAR DAY, and mints a fresh uuid — which the id above can
        // never name. Without this line `remove it` silently undid
        // itself for every customer whose weight comes from a scale.
        DeletionLedger.record(
            id: DeletionLedger.clearedWeightDayId(
                userId: userId, dayKey: TodayStateService.dayKey(for: record.loggedAt)
            ),
            userId: userId
        )
        // v25 pass 51 — AND THE INSTANT, because the day key above is
        // a time-zone reading: a zone change between delete and the
        // next import re-buckets the same Health sample onto a
        // neighboring civil day and the day tombstone stops matching.
        // The sample's epoch second is zone-proof.
        DeletionLedger.record(
            id: DeletionLedger.clearedWeightInstantId(
                userId: userId, at: record.loggedAt
            ),
            userId: userId
        )
        context.delete(record)
        try? context.save()
        Task { await AppSync.shared.deleteWeightLog(id: target) }
        NotificationCenter.default.post(name: .weightLogDidChange, object: nil)
        return true
    }

    /// Every weigh-in on file, newest first — the ledger's feed.
    static func entries(
        userId: String, in context: ModelContext
    ) -> [WeightLedger.Entry] {
        guard !userId.isEmpty else { return [] }
        let uid = userId
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map {
            WeightLedger.Entry(
                id: $0.id, at: $0.loggedAt, kg: $0.weightKg, source: $0.source
            )
        }
    }
}
