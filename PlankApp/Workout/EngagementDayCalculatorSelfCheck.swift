#if DEBUG
import Foundation
import PlankSync

// MARK: - EngagementDayCalculatorSelfCheck
//
// Runs a battery of engagement-day scenarios against the calculator and
// reports any mismatches. Same pattern as StreakCalculatorSelfCheck —
// detached background task at launch, silent on success, prints on
// failure. Migrates to XCTest when a test target lands.
//
// Each scenario fixes `asOf` to a known reference date so the math
// doesn't drift by clock; session timestamps are constructed by
// offsetting from that anchor. The key invariants tested:
//   - empty input → 0
//   - single session today → 1
//   - multiple sessions on the same day → still that day's count
//   - sessions across N distinct days → N
//   - inactive days don't count
//   - non-qualifying sessionTypes are excluded
//   - future-dated sessions (clock skew) are clamped at asOf
//   - programDayForNewSession returns N when today already counted,
//     N+1 when today was previously empty

enum EngagementDayCalculatorSelfCheck {

    @discardableResult
    static func runAll() -> [String] {
        var failures: [String] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func dayOffset(_ n: Int, hour: Int = 12) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0,
                     of: cal.date(byAdding: .day, value: n, to: today)!)!
        }

        // 1. Empty → 0
        checkCount(
            label: "empty",
            sessions: [],
            asOf: today,
            expected: 0,
            into: &failures
        )

        // 2. Single session today → 1
        checkCount(
            label: "today-only",
            sessions: [routine(at: dayOffset(0))],
            asOf: dayOffset(0, hour: 18),
            expected: 1,
            into: &failures
        )

        // 3. THREE sessions today (the bug case) → still 1
        checkCount(
            label: "three-today",
            sessions: [
                routine(at: dayOffset(0, hour: 8)),
                plank(at: dayOffset(0, hour: 12)),
                routine(at: dayOffset(0, hour: 18)),
            ],
            asOf: dayOffset(0, hour: 20),
            expected: 1,
            into: &failures
        )

        // 4. Sessions across 3 distinct days → 3
        checkCount(
            label: "three-distinct-days",
            sessions: [
                routine(at: dayOffset(-2)),
                routine(at: dayOffset(-1)),
                plank(at: dayOffset(0)),
            ],
            asOf: dayOffset(0, hour: 23),
            expected: 3,
            into: &failures
        )

        // 5. Inactive days in between don't inflate count
        checkCount(
            label: "skip-days",
            sessions: [
                routine(at: dayOffset(-10)),
                routine(at: dayOffset(-3)),
                routine(at: dayOffset(0)),
            ],
            asOf: dayOffset(0, hour: 23),
            expected: 3,
            into: &failures
        )

        // 6. Non-qualifying sessionType (e.g. legacy type) excluded
        checkCount(
            label: "unknown-type-excluded",
            sessions: [
                SessionLogRecord(userId: "u", exerciseType: "ghost",
                                 completedAt: dayOffset(0),
                                 holdTime: 0, targetTime: 0, qualityScore: 0,
                                 sessionType: "ghost"),
                routine(at: dayOffset(-1)),
            ],
            asOf: dayOffset(0, hour: 18),
            expected: 1,
            into: &failures
        )

        // 7. Future-dated session (clock skew) ignored
        checkCount(
            label: "future-clamped",
            sessions: [
                routine(at: dayOffset(0)),
                routine(at: dayOffset(2)),   // 2 days in the future
            ],
            asOf: dayOffset(0, hour: 18),
            expected: 1,
            into: &failures
        )

        // 8. programDayForNewSession — today already counted → no bump
        let actual8 = EngagementDayCalculator.programDayForNewSession(
            existingLogs: [
                routine(at: dayOffset(-2)),
                routine(at: dayOffset(-1)),
                routine(at: dayOffset(0, hour: 8)),
            ],
            newSessionCompletedAt: dayOffset(0, hour: 18),
            calendar: cal
        )
        if actual8 != 3 {
            failures.append("FAIL: programDay-same-day-no-bump expected 3 got \(actual8)")
        }

        // 9. programDayForNewSession — today is fresh → +1
        let actual9 = EngagementDayCalculator.programDayForNewSession(
            existingLogs: [
                routine(at: dayOffset(-2)),
                routine(at: dayOffset(-1)),
            ],
            newSessionCompletedAt: dayOffset(0, hour: 12),
            calendar: cal
        )
        if actual9 != 3 {
            failures.append("FAIL: programDay-fresh-day-bump expected 3 got \(actual9)")
        }

        // 10. hasCompletedToday true/false
        let yesToday = EngagementDayCalculator.hasCompletedToday(
            sessionLogs: [routine(at: dayOffset(0, hour: 6))],
            asOf: dayOffset(0, hour: 18),
            calendar: cal
        )
        if !yesToday {
            failures.append("FAIL: hasCompletedToday true case returned false")
        }
        let noToday = EngagementDayCalculator.hasCompletedToday(
            sessionLogs: [routine(at: dayOffset(-1))],
            asOf: dayOffset(0, hour: 18),
            calendar: cal
        )
        if noToday {
            failures.append("FAIL: hasCompletedToday false case returned true")
        }

        if !failures.isEmpty {
            print("[EngagementDayCalculatorSelfCheck] \(failures.count) FAILURES")
            for f in failures { print("  - \(f)") }
        }
        return failures
    }

    // MARK: - Helpers

    private static func routine(at date: Date) -> SessionLogRecord {
        SessionLogRecord(
            userId: "u", exerciseType: "routine",
            completedAt: date,
            holdTime: 0, targetTime: 0, qualityScore: 0,
            sessionType: "routine"
        )
    }

    private static func plank(at date: Date) -> SessionLogRecord {
        SessionLogRecord(
            userId: "u", exerciseType: "plank",
            completedAt: date,
            holdTime: 30, targetTime: 60, qualityScore: 0.7,
            sessionType: "plank_benchmark"
        )
    }

    private static func checkCount(
        label: String,
        sessions: [SessionLogRecord],
        asOf: Date,
        expected: Int,
        into failures: inout [String]
    ) {
        let actual = EngagementDayCalculator.daysCompleted(
            sessionLogs: sessions,
            asOf: asOf
        )
        if actual != expected {
            failures.append("FAIL: \(label) expected \(expected) got \(actual)")
        }
    }
}
#endif
