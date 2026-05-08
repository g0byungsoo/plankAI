#if DEBUG
import Foundation

// MARK: - StreakCalculatorSelfCheck
//
// Runs a battery of streak scenarios against the calculator and
// reports any mismatches. Same pattern as WorkoutGeneratorSelfCheck —
// detached background task at launch, silent on success, prints on
// failure. Migrate to XCTest when a test target lands.
//
// Each case fixes `today` to a known reference date so the math
// doesn't drift by clock; activeDates are constructed by offsetting
// from that anchor.

enum StreakCalculatorSelfCheck {

    @discardableResult
    static func runAll() -> [String] {
        var failures: [String] = []

        // Anchor "today" so the test isn't time-of-day-sensitive.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func dayOffset(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: n, to: today)!
        }

        // 1. Empty input → 0
        check(
            label: "empty",
            actual: StreakCalculator.calculate(activeDates: [], today: today),
            expectedCount: 0,
            expectedActive: 0,
            expectedFrozen: 0,
            failures: &failures
        )

        // 2. Just today → 1
        check(
            label: "today-only",
            actual: StreakCalculator.calculate(activeDates: [dayOffset(0)], today: today),
            expectedCount: 1, expectedActive: 1, expectedFrozen: 0,
            failures: &failures
        )

        // 3. Just yesterday (today not active yet) → 1
        check(
            label: "yesterday-only",
            actual: StreakCalculator.calculate(activeDates: [dayOffset(-1)], today: today),
            expectedCount: 1, expectedActive: 1, expectedFrozen: 0,
            failures: &failures
        )

        // 4. Today + yesterday → 2
        check(
            label: "today-yesterday",
            actual: StreakCalculator.calculate(
                activeDates: Set([dayOffset(0), dayOffset(-1)]),
                today: today
            ),
            expectedCount: 2, expectedActive: 2, expectedFrozen: 0,
            failures: &failures
        )

        // 5. Today + missed yesterday + active day-before — auto-freeze
        // kicks in. Streak = 3 (today + frozen yesterday + active -2).
        check(
            label: "auto-freeze-yesterday",
            actual: StreakCalculator.calculate(
                activeDates: Set([dayOffset(0), dayOffset(-2)]),
                today: today
            ),
            expectedCount: 3, expectedActive: 2, expectedFrozen: 1,
            failures: &failures
        )

        // 6. Today + missed -1 + missed -2 → 1 (can't freeze two in a row)
        check(
            label: "two-misses-no-freeze",
            actual: StreakCalculator.calculate(
                activeDates: Set([dayOffset(0)]),
                today: today
            ),
            expectedCount: 1, expectedActive: 1, expectedFrozen: 0,
            failures: &failures
        )

        // 7. 10-day streak with one freeze in the middle (8 days apart
        // from start) — allowed.
        // Days: 0..-9 except -3 missed.
        // activeDates: 0,-1,-2,-4,-5,-6,-7,-8,-9
        // Walking back: 0,1,2 active (dslf 8,9,10), -3 missed → freeze
        // (-4 active before, dslf=10 ≥ 7), then -4..-9 active (6 more
        // days). Total = 3 + 1 + 6 = 10 days. 9 active, 1 frozen.
        var dates10 = Set<Date>()
        for off in [0, -1, -2, -4, -5, -6, -7, -8, -9] {
            dates10.insert(dayOffset(off))
        }
        check(
            label: "10-day-with-1-freeze",
            actual: StreakCalculator.calculate(activeDates: dates10, today: today),
            expectedCount: 10, expectedActive: 9, expectedFrozen: 1,
            failures: &failures
        )

        // 8. Two freezes far enough apart (8 active days separating) —
        // both allowed.
        // Days: 0,-1,-3,-5,-6,-7,-8,-9,-10,-12,-13
        // miss -2 (freeze, 2 active days before since today) — no, walk
        // back: 0 active dslf=8, -1 active dslf=9, -2 miss → freeze
        // (dslf=9 ≥ 7, dslf=0). -3 active dslf=1. -4 miss → dayBefore -5
        // active, dslf=1 < 7 → break. So this set breaks early.
        //
        // Let's construct it differently: 0,-1,-2,-3,-4,-5,-6,-7,-9,-10,-11,-12,-13
        // miss only -8. Walk: 0,-1,-2,-3,-4,-5,-6,-7 = 8 active (dslf=15).
        // -8 miss → freeze (dslf=15 ≥ 7), dslf=0. -9 active dslf=1.
        // -10 active dslf=2 ... -13 active dslf=5. -14 miss → break.
        // Total = 8 + 1 freeze + 5 = 14, 13 active, 1 frozen.
        var dates14 = Set<Date>()
        for off in [0, -1, -2, -3, -4, -5, -6, -7, -9, -10, -11, -12, -13] {
            dates14.insert(dayOffset(off))
        }
        check(
            label: "14-day-with-1-freeze",
            actual: StreakCalculator.calculate(activeDates: dates14, today: today),
            expectedCount: 14, expectedActive: 13, expectedFrozen: 1,
            failures: &failures
        )

        // 9. Two misses too close (5 active days between freezes) →
        // second miss breaks streak. Days: 0,-1,-2,-3,-4,-5 then miss
        // -6, then active -7. Walk: 0..-5 = 6 active dslf=13. -6 miss
        // (dayBefore -7 active, dslf=13 ≥ 7) → freeze, dslf=0. -7 active
        // dslf=1. Now if -8 was also a miss (with -9 active), we'd see:
        // -8 miss, dayBefore -9 active, dslf=1 < 7 → BREAK.
        // Result: streak = 6 active + 1 freeze + 1 active (-7) = 8.
        var dates8 = Set<Date>()
        for off in [0, -1, -2, -3, -4, -5, -7, -9] {
            dates8.insert(dayOffset(off))
        }
        check(
            label: "second-freeze-too-close-breaks",
            actual: StreakCalculator.calculate(activeDates: dates8, today: today),
            expectedCount: 8, expectedActive: 7, expectedFrozen: 1,
            failures: &failures
        )

        if failures.isEmpty {
            print("[SelfCheck] ✅ StreakCalculator: all scenarios pass")
        } else {
            print("[SelfCheck] ⚠️ StreakCalculator: \(failures.count) failure(s):")
            for f in failures { print("  - \(f)") }
        }
        return failures
    }

    private static func check(
        label: String,
        actual: StreakCalculator.Result,
        expectedCount: Int,
        expectedActive: Int,
        expectedFrozen: Int,
        failures: inout [String]
    ) {
        if actual.count != expectedCount {
            failures.append("\(label) — count: expected \(expectedCount), got \(actual.count)")
        }
        if actual.activeDays != expectedActive {
            failures.append("\(label) — activeDays: expected \(expectedActive), got \(actual.activeDays)")
        }
        if actual.frozenDates.count != expectedFrozen {
            failures.append("\(label) — frozenDates: expected \(expectedFrozen), got \(actual.frozenDates.count)")
        }
    }
}
#endif
