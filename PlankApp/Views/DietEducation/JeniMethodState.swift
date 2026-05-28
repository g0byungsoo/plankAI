import Foundation

// UserDefaults-backed state for "The JeniFit Method" post-purchase
// education flow. No SwiftData model, no Supabase column — keeping state
// in UserDefaults per the no-schema-change contract in
// docs/diet_education_plan.md. All keys are prefixed `jenimethod.` so
// they're easy to enumerate and easy to clear in the account-delete flow
// (see allKeys below).
enum JeniMethodState {
    // MARK: - Keys
    private enum Key {
        static let enrolledAt        = "jenimethod.enrolled_at"
        static let lesson1StartedAt  = "jenimethod.lesson_1_started_at"
        static let lastCompletedId   = "jenimethod.last_lesson_completed_id"
        static let skipCount         = "jenimethod.skip_count"
        /// Phase 9.21 — stamped whenever a ritual is opened. Drives the
        /// once-per-calendar-day auto-present gate in HomeView.
        static let ritualLastShownAt = "jenimethod.ritual_last_shown_at"
    }

    /// All keys this module writes. The account-delete flow (and the debug
    /// reset) iterates this list — adding a new key here keeps cleanup
    /// honest without scattering string literals.
    static let allKeys: [String] = [
        Key.enrolledAt, Key.lesson1StartedAt, Key.lastCompletedId,
        Key.skipCount, Key.ritualLastShownAt,
    ]

    // MARK: - Goal-gate (locked decision #1)

    /// Only fat-loss-oriented goals enroll in v1. `growGlutes` is excluded
    /// because the program is built around a gentle deficit; a glute-focus
    /// user is hypertrophy-first and the messaging doesn't fit.
    /// Single editable constant — change here if product re-scopes.
    private static let enrolledGoals: Set<String> = [
        "loseWeight",
        "slimLegs",
        "toneCore",
        "fullBody",
    ]

    static func shouldEnroll(for goal: String?) -> Bool {
        guard let goal else { return false }
        return enrolledGoals.contains(goal)
    }

    // MARK: - Post-purchase idempotency (locked decision #4)

    /// True iff Lesson 1 has not yet been opened. The post-purchase
    /// fullScreenCover trigger consults this to avoid re-firing on cold
    /// relaunches or restore-purchase events. Lessons 2-5 surface via the
    /// HomeView card instead, so this gate only protects the first cover.
    static func shouldShowOnPurchase() -> Bool {
        UserDefaults.standard.object(forKey: Key.lesson1StartedAt) == nil
    }

    /// Stamp both enrolled_at and lesson_1_started_at on Lesson 1 first
    /// open. Idempotent — re-calls preserve the original timestamps so the
    /// day-index math stays anchored to the original purchase moment, not
    /// later returns.
    static func markEnrolled(now: Date = .now) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.lesson1StartedAt) == nil {
            defaults.set(now, forKey: Key.lesson1StartedAt)
        }
        if defaults.object(forKey: Key.enrolledAt) == nil {
            defaults.set(now, forKey: Key.enrolledAt)
        }
    }

    // MARK: - Lesson completion

    static var lastCompletedLessonId: Int {
        get { UserDefaults.standard.integer(forKey: Key.lastCompletedId) }
        set { UserDefaults.standard.set(newValue, forKey: Key.lastCompletedId) }
    }

    /// Bump to a new completed ID, never down. Defensive against
    /// out-of-order completion (e.g. tester opens Lesson 3 from a future
    /// debug menu before Lesson 1) so the next-lesson math doesn't regress.
    static func markLessonCompleted(_ id: Int) {
        if id > lastCompletedLessonId {
            lastCompletedLessonId = id
        }
    }

    // MARK: - Skip count (Phase 6 — for diet_education_completed cohort props)

    /// Total number of times the user has tapped X to dismiss a lesson
    /// across the whole journey. Reported as `lessons_skipped` on the
    /// terminal `diet_education_completed` event. Monotonic-increment;
    /// resets only on account-delete.
    static var skipCount: Int {
        get { UserDefaults.standard.integer(forKey: Key.skipCount) }
        set { UserDefaults.standard.set(newValue, forKey: Key.skipCount) }
    }

    static func incrementSkipCount() {
        skipCount = skipCount + 1
    }

    // MARK: - Day-index math (Phase 3 HomeView card)

    static func enrolledAt() -> Date? {
        UserDefaults.standard.object(forKey: Key.enrolledAt) as? Date
    }

    /// Calendar days since enrollment (0 = same day). Timezone-aware via
    /// Calendar.current — same pattern HomeView uses for dailyRefreshDate.
    static func daysSinceEnrolled(now: Date = .now,
                                  calendar: Calendar = .current) -> Int? {
        guard let start = enrolledAt() else { return nil }
        let startDay = calendar.startOfDay(for: start)
        let today    = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: startDay, to: today).day
    }

    /// Highest lesson ID currently available, capped at 5. nil if not
    /// enrolled. Day 1 = available on enrollment; one new lesson unlocks
    /// per calendar-day boundary.
    static func highestUnlockedLessonId(now: Date = .now,
                                        calendar: Calendar = .current) -> Int? {
        guard let days = daysSinceEnrolled(now: now, calendar: calendar) else { return nil }
        return min(5, days + 1)
    }

    /// The next lesson the HomeView card should surface (Phase 3 will read
    /// this). nil when the user is up-to-date for today, or fully done.
    /// Card does NOT auto-open on Day 2 (locked decision #5) — this just
    /// tells the card which lesson to point to, not whether to open it.
    static func todaysLessonForCard(now: Date = .now,
                                    calendar: Calendar = .current) -> Int? {
        guard let unlocked = highestUnlockedLessonId(now: now, calendar: calendar) else { return nil }
        let next = lastCompletedLessonId + 1
        guard next <= 5 else { return nil }       // fully done
        guard next <= unlocked else { return nil } // tomorrow's not unlocked yet
        return next
    }

    // MARK: - Daily ritual scheduling (Phase 9.21)

    /// The ritual that should appear today, given completion state +
    /// once-per-day gate. Phase 9.23 — sequential progression based on
    /// completion, NOT calendar day. Module 1 fires post-paywall. The
    /// next-uncompleted module fires the next time the user opens the
    /// app after the previous one is marked complete. Module 6 (the
    /// short pre-workout warmup) fires every day after Module 5 is
    /// done. `hasShownRitualToday` keeps the same module from firing
    /// twice in one session.
    ///
    /// Completion mapping (lastCompletedLessonId → next ritual):
    ///   0 (never completed)  → .day1
    ///   1 (Module 1 done)    → .day2
    ///   2 (Module 2 done)    → .day3
    ///   3 (Module 3 done)    → .day4
    ///   4 (Module 4 done)    → .day5
    ///   5+ (Module 5 done)   → .generic
    static func ritualForToday(now: Date = .now,
                               calendar: Calendar = .current) -> LessonID? {
        guard enrolledAt() != nil else { return nil }
        guard !hasShownRitualToday(now: now, calendar: calendar) else { return nil }
        let nextId = lastCompletedLessonId + 1
        if let lesson = LessonID(rawValue: nextId), lesson != .generic {
            return lesson
        }
        return .generic
    }

    /// True iff a ritual was opened earlier today (calendar-day
    /// boundary). Used by HomeView to gate auto-presentation.
    static func hasShownRitualToday(now: Date = .now,
                                    calendar: Calendar = .current) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: Key.ritualLastShownAt) as? Date else {
            return false
        }
        return calendar.isDate(last, inSameDayAs: now)
    }

    /// Stamp the current time so HomeView won't re-present another
    /// ritual today. Called from JeniMethodRitualView.onAppear (or
    /// equivalent) so post-paywall + auto-present + debug paths all
    /// converge on the same gate.
    static func markRitualShownToday(now: Date = .now) {
        UserDefaults.standard.set(now, forKey: Key.ritualLastShownAt)
    }

    #if DEBUG
    /// DEBUG-only: clear all jenimethod.* state. Wired into a future
    /// DebugAuthView reset button so QA can replay the flow without
    /// reinstalling.
    static func _debugReset() {
        let defaults = UserDefaults.standard
        for key in allKeys { defaults.removeObject(forKey: key) }
    }
    #endif
}
