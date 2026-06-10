import Foundation

// MARK: - ProgramDayPrescription
//
// v1.1 program pivot. The per-day value type emitted by
// ProgramScheduler that PlanView's DailyChecklistCard renders as
// 5 rows + any optional add-ons (evening recap on Hard tier).
//
// Each case represents one rail of the program. The associated
// values are the PARAMETERS the rail's existing module needs to
// configure today's instance — no rail module is rewritten, they
// just get a (tier, minutes, ...) tuple from this enum.
//
// Codable + Sendable so it can serialize into program_day_checks.payload
// jsonb when ProgramService caches the resolved prescription per day
// (kills WorkoutGenerator non-determinism per Phase 2 plan).

public enum ProgramDayPrescription: Codable, Sendable, Equatable {
    /// JeniMethod lesson scheduled for today. Lesson id resolved
    /// by LessonScheduler — barrier-aware when content has
    /// barrier_tags (Phase 3); falls back to day-N lookup until
    /// then.
    case lesson(lessonId: String?)

    /// "Snap a meal" row. Self-check; turns autoCompleted when
    /// the first FoodScanRecord for the day inserts.
    case snapMeal

    /// Today's workout session. `minutes` drives PreSessionView's
    /// duration cap; `tier` is the intensity (maps to existing
    /// WorkoutGenerator pace param soft/medium/hard); `bodyFocus`
    /// is the optional muscle-group emphasis from onboarding.
    case workout(tier: IntensityTier, minutes: Int, bodyFocus: String?)

    /// Plank-focus session. `targetSeconds` is the time-under-tension
    /// target — Phase 1 uses 60s default; Phase 2 ramps +5s/wk capped
    /// at user 1RM + 60s (Soft) / +120s (Medium/Hard).
    case plank(targetSeconds: Int)

    /// Breathwork session. `minutes` is the duration; `style`
    /// determines cycle pattern.
    case breath(minutes: Int, style: BreathStyle)

    /// Steps row — auto-completes via HealthKit. `goal` is the
    /// daily step target from IntensityProfile.stepsDailyGoal.
    case steps(goal: Int)

    /// Water row — Phase 3 ships with HydrationService. Phase 1
    /// renders the row as locked/coming-soon with cup count.
    case water(ml: Int)

    /// Weekly weigh-in (cycled on Sundays + 7-day-stale fallback).
    case weighIn

    /// Body measurements row — Phase 2 ships with body_measurements
    /// table + LogMeasurementsSheet.
    case measurements

    public enum BreathStyle: String, Codable, Sendable {
        case calming    // 4-7-8 / box breathing
        case energizing // wim-hof-lite
    }
}

// MARK: - Row metadata
//
// The view layer reads these accessors to render PlanRow chrome
// (title, subtitle, icon name, default state). Keeps the enum
// the single source of truth for what each rail says on the
// daily checklist.

public extension ProgramDayPrescription {
    /// Stable key for persistence in program_day_checks.item_key.
    /// MUST match the SQL CHECK constraint.
    var itemKey: String {
        switch self {
        case .lesson: return "lesson"
        case .snapMeal: return "snap_meal"
        case .workout: return "move"
        case .plank: return "plank"
        case .breath: return "breath"
        case .steps: return "steps"
        case .water: return "water"
        case .weighIn: return "weigh_in"
        case .measurements: return "measurements"
        }
    }

    /// SF Symbol name rendered inside the 40pt sticky-note. Per
    /// [[feedback-no-checkbox-circle]] v4 sticky redesign: integer
    /// numeral → type-glyph for per-row identity.
    var stickyGlyph: String {
        switch self {
        case .lesson:       return "book.closed"
        case .snapMeal:     return "camera"
        case .workout:      return "figure.run"
        case .plank:        return "figure.core.training"
        case .breath:       return "leaf"
        case .steps:        return "figure.walk"
        case .water:        return "drop"
        case .weighIn:      return "scalemass"
        case .measurements: return "ruler"
        }
    }

    /// Sticky-note palette token name. Type-keyed (founder pick):
    /// same type = same color across days for cohort recognition.
    /// 4 pastels cycle across the 8 types in calm→data→action→growth pairs.
    var stickyColorKind: StickyColor {
        switch self {
        case .lesson, .breath:           return .mint    // calm / mindful
        case .snapMeal, .weighIn:        return .butter  // data / check-in
        case .workout, .water, .plank:   return .rose    // active / hydrate
        case .steps, .measurements:      return .olive   // ambient / growth
        }
    }

    enum StickyColor {
        case mint
        case butter
        case rose
        case olive
    }

    /// True when this row is a numeric-progress row (steps, water).
    /// PlanRow renders these with the 64pt × 3pt bar trailing pattern
    /// instead of the binary state indicator.
    var isProgressRow: Bool {
        switch self {
        case .steps, .water: return true
        default:             return false
        }
    }

    /// True when this row is the snap-meal row. PlanView reads this
    /// to inject live calorie data into the subtitle.
    var isSnapMeal: Bool {
        if case .snapMeal = self { return true }
        return false
    }

    /// True when this row uses the v5 fat-row pattern (an embedded
    /// mini-component below the header line). Snap/move/steps load-
    /// bear daily decisions; the other rows stay compact at 76pt.
    /// Per UX spec §v5.2.
    var isFatRow: Bool {
        switch self {
        case .snapMeal, .workout, .steps: return true
        default:                          return false
        }
    }

    /// Row title — lowercase casual register per voice rules.
    /// Shortened to her75-style single-noun where possible per
    /// founder QA 2026-06-09 (long titles wrap and crowd the
    /// trailing region).
    var rowTitle: String {
        switch self {
        case .lesson: return "today's lesson"
        case .snapMeal: return "snap a meal"
        case .workout: return "move"
        case .plank: return "plank"
        case .breath: return "breathe"
        case .steps: return "steps"
        case .water: return "water"
        case .weighIn: return "weigh in"
        case .measurements: return "measurements"
        }
    }

    /// Row subtitle — concrete prescription bound to associated values.
    var rowSubtitle: String {
        switch self {
        case .lesson:
            return "3 min · read it before lunch"
        case .snapMeal:
            return "one photo · we read the plate"
        case .workout(_, let minutes, _):
            return "\(minutes) min · you've got this"
        case .plank(let seconds):
            return "\(seconds)s target"
        case .breath(let minutes, _):
            return "\(minutes) min · calm the noise"
        case .steps(let goal):
            return "\(goal.formatted(.number.grouping(.automatic))) steps · auto-tracked"
        case .water(let ml):
            return "\(ml) ml today"
        case .weighIn:
            return "weekly check-in"
        case .measurements:
            return "monthly snapshot"
        }
    }

    /// Whether this row auto-completes from telemetry (no tap
    /// required) vs requires user action. PlanView paints the
    /// checkbox differently for auto rows.
    var isAutoCompleting: Bool {
        switch self {
        case .steps, .workout, .plank, .breath, .lesson, .snapMeal, .weighIn:
            // Workout/plank/breath/lesson auto-complete via SessionLogRecord
            // / JeniMethodState insert. Snap auto-completes via FoodScanRecord.
            // Weigh-in auto-completes via WeightLogRecord. Lesson auto-completes
            // via JeniMethodState.markComplete.
            return true
        case .water, .measurements:
            // Tap-to-check rows — user toggles after the action.
            return false
        }
    }
}
