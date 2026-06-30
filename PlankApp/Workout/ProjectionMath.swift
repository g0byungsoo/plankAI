import Foundation

// MARK: - ProjectionMath
//
// Single source of truth for the projected goal-weight date shown across
// onboarding (pace selector 167, rough sketch 161, recap 206, day-one card,
// goal-date reveal) AND on `BecomingProjectionCard` (paywall hero + reveal
// sequence). Before the 2026-06-11 pace unification, five separate
// calculations lived in four files and produced different dates for the
// same inputs (gentle pace said oct 8, the reveal said sep 24, the paywall
// said aug 29 labeled "gentle" at steady-rate math).
//
// The user's picked pace (`onboardingPaceChoice`: gentle / steady / focused)
// is the ONE knob. Every surface passes it through `paceKey:`; the ACSM
// 0.5–1%/wk band maps gentle→0.5%, steady→0.75%, focused→1.0%. The reveal
// PacePicker tiers map soft→gentle, medium→steady, hard→focused and write
// back to the same key, so a tier change re-dates every downstream surface.
//
// Never re-implement this math in a screen-specific helper. If a screen
// needs to "sharpen" the projection visually, do it via chart styling, not
// by tweaking the number.

enum ProjectionMath {

    /// Canonical UserDefaults key for the picked pace. Shared by
    /// OnboardingView (case 167) and the reveal PacePicker write-back.
    static let paceDefaultsKey = "onboardingPaceChoice"

    /// Cohort-aware soft-tier floor rate, written once at reveal time from
    /// `ProgramGoalCalculator.Window.lossRateFloor`. The gentle (soft) pace
    /// is the ONLY tier whose rate is cohort-dependent: a GLP-1 /
    /// perimenopausal / short-sleep / regain-risk user gets a gentler floor
    /// (0.003 / 0.004) than the 0.005 default. Pre-fix this side-channel was
    /// missing, so the projected DATE drew gentle at a hard-coded 0.005
    /// while the calorie target used the cohort floor — the date she saw
    /// wasn't actually gentler, yet the provenance line said it was. Storing
    /// the floor here makes every surface that reads `weeklyFraction` (the
    /// reveal date, the pace-row week counts, the paywall hero, the becoming
    /// card) derive the soft date from the same cohort-aware rate the
    /// calorie deficit uses. Mirrors the existing `paceDefaultsKey`
    /// side-channel pattern. 0 / unset = no reveal yet -> 0.005 default.
    static let softFloorDefaultsKey = "onboardingSoftFloorRate"

    /// Soft (gentle) pace rate. Reads the cohort floor stored at reveal
    /// time; falls back to the 0.005 default when unset, and clamps to the
    /// calculator's cohort band [0.003, 0.005] defensively.
    static func softFloorRate() -> Double {
        let stored = UserDefaults.standard.double(forKey: softFloorDefaultsKey)
        guard stored > 0 else { return 0.005 }
        return min(max(stored, 0.003), 0.005)
    }

    /// ACSM 0.5–1%/wk sustainable-loss band, keyed by pace choice.
    /// Unknown / empty keys anchor at steady (0.75%) — the band middle.
    /// gentle is cohort-aware (see `softFloorRate`).
    static func weeklyFraction(paceKey: String?) -> Double {
        switch paceKey {
        case "gentle":  return softFloorRate()
        case "focused": return 0.01
        default:        return 0.0075
        }
    }

    /// IntensityTier raw value ↔ pace key mapping (reveal PacePicker).
    static func paceKey(forTier tierRaw: String) -> String {
        switch tierRaw {
        case "soft": return "gentle"
        case "hard": return "focused"
        default:     return "steady"
        }
    }

    static func tierRaw(forPaceKey paceKey: String?) -> String {
        switch paceKey {
        case "gentle":  return "soft"
        case "focused": return "hard"
        default:        return "medium"
        }
    }

    /// "gentle pace" / "steady pace" / "focused pace" — chart rate label.
    static func paceLabel(paceKey: String?) -> String {
        switch paceKey {
        case "gentle":  return "gentle pace"
        case "focused": return "focused pace"
        default:        return "steady pace"
        }
    }

    /// Weeks floor. 4 weeks: a tiny loss goal (2 lbs) must not render as
    /// "next Tuesday" — reads aspirational-but-fake.
    static let minWeeks: Double = 4

    /// Weeks cap. 26 weeks (6 months): a 50+ lb goal at gentle pace must
    /// not render as "next March" — reads daunting. The Wing & Phelan
    /// reframe (case 286) pulls most goals inside this window anyway.
    static let maxWeeks: Double = 26

    /// Whole weeks to the goal at the picked pace, clamped 4...26.
    /// Returns nil when inputs don't describe a loss goal.
    static func projectedWeeks(
        currentKg: Double,
        goalKg: Double,
        paceKey: String? = nil
    ) -> Int? {
        guard currentKg > goalKg else { return nil }
        let kgPerWeek = currentKg * weeklyFraction(paceKey: paceKey)
        guard kgPerWeek > 0 else { return nil }
        let weeksRaw = (currentKg - goalKg) / kgPerWeek
        return Int(min(max(weeksRaw, minWeeks), maxWeeks).rounded())
    }

    /// Projected goal-weight date. Returns `nil` when the inputs don't
    /// describe a weight-loss goal (currentKg <= goalKg).
    ///
    /// This is the canonical projection across the app. DO NOT re-implement.
    static func projectedGoalDate(
        currentKg: Double,
        goalKg: Double,
        paceKey: String? = nil
    ) -> Date? {
        guard let weeks = projectedWeeks(currentKg: currentKg, goalKg: goalKg, paceKey: paceKey) else {
            return nil
        }
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: Date())
    }

    /// "MMM d" lowercase ("jul 5") for inline copy. Returns nil when no
    /// projection is possible (no loss goal).
    static func formattedShortDate(
        currentKg: Double,
        goalKg: Double,
        paceKey: String? = nil
    ) -> String? {
        guard let date = projectedGoalDate(currentKg: currentKg, goalKg: goalKg, paceKey: paceKey) else {
            return nil
        }
        return Self.shortFormatter.string(from: date).lowercased()
    }

    /// "MMMM d" lowercase ("september 24") for hero beats.
    static func formattedLongDate(
        currentKg: Double,
        goalKg: Double,
        paceKey: String? = nil
    ) -> String? {
        guard let date = projectedGoalDate(currentKg: currentKg, goalKg: goalKg, paceKey: paceKey) else {
            return nil
        }
        return Self.longFormatter.string(from: date).lowercased()
    }

    /// Days-from-today integer when callers need the raw count (chart
    /// width calculations, week-1 callout positioning). Returns the
    /// default 12-week window when no loss goal is set so screens that
    /// drive layout off this number don't collapse.
    static func projectedDays(
        currentKg: Double,
        goalKg: Double,
        paceKey: String? = nil
    ) -> Int {
        guard let weeks = projectedWeeks(currentKg: currentKg, goalKg: goalKg, paceKey: paceKey) else {
            return 84
        }
        return weeks * 7
    }

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f
    }()
}
