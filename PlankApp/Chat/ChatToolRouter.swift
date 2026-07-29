import Foundation
import SwiftData
import PlankSync

// MARK: - ChatToolRouter
//
// App v2 (docs/app_v2/05_CHAT.md §Tools). Jeni proposes; this
// executes — through the same writers and router the rest of the
// app uses. Mutating tools require her confirmation (the card's
// pills); navigation tools act immediately.

@MainActor
enum ChatToolRouter {

    static func needsConfirmation(_ name: String) -> Bool {
        switch name {
        case "log_weight", "set_reminder_hour": return true
        default: return false
        }
    }

    /// The card's line. Voice contract: lowercase, concrete.
    static func cardLabel(for call: ChatToolCall) -> String {
        switch call.name {
        case "open_snap_camera":
            return "opening the camera"
        case "log_weight":
            if let kg = call.arguments["kg"] as? Double {
                return "weigh in at \(String(format: "%.1f", kg)) kg?"
            }
            return "weigh in?"
        case "show_today_plan":
            return "today's plan"
        case "open_lesson":
            return "opening today's lesson"
        case "start_breathwork":
            return "starting a breath session"
        case "show_weight_trend":
            return "your trend line"
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
        case "log_weight": return "scalemass"
        case "show_today_plan": return "list.bullet"
        case "open_lesson": return "book.closed"
        case "start_breathwork": return "leaf"
        case "show_weight_trend": return "chart.line.uptrend.xyaxis"
        case "set_reminder_hour": return "bell"
        default: return "sparkle"
        }
    }

    /// Executes; returns the compact result JSON the continuation
    /// sends back so jeni can acknowledge with truth.
    @discardableResult
    static func execute(
        _ call: ChatToolCall,
        userId: String,
        modelContext: ModelContext?
    ) -> [String: Any] {
        switch call.name {
        case "open_snap_camera":
            AppRouter.shared.open(.snap)
            return ["opened": true]

        case "open_lesson":
            AppRouter.shared.open(.lesson)
            return ["opened": true]

        case "start_breathwork":
            AppRouter.shared.open(.breath)
            return ["opened": true]

        case "show_weight_trend":
            // 1.1.6: the trend renders INLINE (JKChatTrendCard) — the
            // conversation keeps her; the card's tap opens becoming.
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
}
