#if DEBUG
import Foundation
import PlankSync

// MARK: - WeightSelfCheck
//
// Covers two modules with non-trivial math:
//   - WeightUnit (kg ↔ lb conversion + grid snapping)
//   - WeightAnalytics (goal progress capping, stall detection)
//
// Same DEBUG-only detached-task pattern as WorkoutGeneratorSelfCheck +
// StreakCalculatorSelfCheck. Migrates cleanly to XCTest later.

enum WeightSelfCheck {

    @discardableResult
    static func runAll() -> [String] {
        var failures: [String] = []
        failures.append(contentsOf: weightUnitChecks())
        failures.append(contentsOf: weightAnalyticsChecks())

        if failures.isEmpty {
            print("[SelfCheck] ✅ Weight (Unit + Analytics): all scenarios pass")
        } else {
            print("[SelfCheck] ⚠️ Weight: \(failures.count) failure(s):")
            for f in failures { print("  - \(f)") }
        }
        return failures
    }

    // MARK: - WeightUnit

    private static func weightUnitChecks() -> [String] {
        var failures: [String] = []

        // Kg display = identity (rounded to 1 decimal).
        assertClose(
            WeightUnit.kg.display(fromKg: 70.0), 70.0,
            label: "kg.display 70.0",
            failures: &failures
        )
        assertClose(
            WeightUnit.kg.display(fromKg: 70.456), 70.5,
            label: "kg.display rounds to 1 decimal",
            failures: &failures
        )

        // Lb display = kg * 2.20462, 1-decimal.
        assertClose(
            WeightUnit.lb.display(fromKg: 70.0), 154.3,
            label: "lb.display 70 kg → 154.3 lb",
            failures: &failures
        )

        // Round-trip: display → toKg → display = display (within 0.1).
        for kg in [50.0, 70.0, 90.0, 120.0] {
            for unit in [WeightUnit.kg, WeightUnit.lb] {
                let displayed = unit.display(fromKg: kg)
                let backToKg = unit.toKg(displayed: displayed)
                let displayedAgain = unit.display(fromKg: backToKg)
                if abs(displayed - displayedAgain) > 0.1 {
                    failures.append(
                        "round-trip \(unit.label) kg=\(kg): \(displayed) → \(backToKg) kg → \(displayedAgain)"
                    )
                }
            }
        }

        // Step deltas + display range — kg uses 0.1/1.0; lb uses 0.2/2.0.
        if WeightUnit.kg.smallStep != 0.1 {
            failures.append("kg.smallStep should be 0.1, got \(WeightUnit.kg.smallStep)")
        }
        if WeightUnit.lb.smallStep != 0.2 {
            failures.append("lb.smallStep should be 0.2, got \(WeightUnit.lb.smallStep)")
        }
        if WeightUnit.kg.largeStep != 1.0 {
            failures.append("kg.largeStep should be 1.0, got \(WeightUnit.kg.largeStep)")
        }
        if WeightUnit.lb.largeStep != 2.0 {
            failures.append("lb.largeStep should be 2.0, got \(WeightUnit.lb.largeStep)")
        }
        // Display range bounds must envelope the canonical kg 20–250 range.
        if !WeightUnit.kg.displayRange.contains(50) ||
           !WeightUnit.kg.displayRange.contains(150) {
            failures.append("kg.displayRange should contain typical adult weights")
        }
        if !WeightUnit.lb.displayRange.contains(110) ||
           !WeightUnit.lb.displayRange.contains(330) {
            failures.append("lb.displayRange should contain typical adult weights")
        }

        // Formatted helper: "70.0 kg" / "154.3 lb"
        if WeightUnit.kg.formatted(fromKg: 70.0) != "70.0 kg" {
            failures.append("kg.formatted 70.0 expected '70.0 kg', got '\(WeightUnit.kg.formatted(fromKg: 70.0))'")
        }
        if WeightUnit.lb.formatted(fromKg: 70.0) != "154.3 lb" {
            failures.append("lb.formatted 70.0 expected '154.3 lb', got '\(WeightUnit.lb.formatted(fromKg: 70.0))'")
        }

        return failures
    }

    // MARK: - WeightAnalytics

    private static func weightAnalyticsChecks() -> [String] {
        var failures: [String] = []

        // displayGoalKg caps at 10% loss. Wing & Phelan 2005 framing.
        // 70 kg starting, declared goal 60 → cap at 70*0.9 = 63. Goal floors at cap.
        assertClose(
            WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 60),
            63.0, label: "displayGoalKg caps 60 to 63 (10% of 70)",
            failures: &failures
        )
        // Declared goal already inside cap — pass through.
        assertClose(
            WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 65),
            65.0, label: "displayGoalKg 65 within cap, passes through",
            failures: &failures
        )
        // Declared goal above starting (gain target — still respects cap math).
        assertClose(
            WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 75),
            75.0, label: "displayGoalKg gain-target passes through",
            failures: &failures
        )

        // goalProgress: 70 starting, 65 current, declared 60 → cap goal at 63.
        // Total needed: 70 - 63 = 7. Progressed: 70 - 65 = 5. Fraction: 5/7 ≈ 0.714.
        if let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 65, declaredGoalKg: 60) {
            assertClose(p, 5.0/7.0, tolerance: 0.001,
                       label: "goalProgress 70→65 vs goal 60 (capped 63)",
                       failures: &failures)
        } else {
            failures.append("goalProgress should not be nil for valid input")
        }

        // goalProgress nil when no real gap (already at goal).
        if WeightAnalytics.goalProgress(startingKg: 70, currentKg: 70, declaredGoalKg: 70) != nil {
            failures.append("goalProgress should be nil when starting == declared goal")
        }

        // goalProgress clamped to [0, 1].
        if let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 60, declaredGoalKg: 65) {
            // Started 70, now 60, goal 65 → exceeded. Should clamp to 1.0.
            if p < 0.99 || p > 1.01 {
                failures.append("goalProgress should clamp to 1.0 when current passes goal, got \(p)")
            }
        }
        // Negative progress (gain when goal is loss) clamped to 0.
        if let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 75, declaredGoalKg: 65) {
            if p < -0.01 || p > 0.01 {
                failures.append("goalProgress should clamp to 0 on weight gain, got \(p)")
            }
        }

        // isStalled needs ≥3 logs in last 14 days. Empty = false.
        if WeightAnalytics.isStalled(logs: []) {
            failures.append("isStalled([]) should be false")
        }

        return failures
    }

    // MARK: - Helpers

    private static func assertClose(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 0.05,
        label: String,
        failures: inout [String]
    ) {
        if abs(actual - expected) > tolerance {
            failures.append("\(label): expected \(expected), got \(actual)")
        }
    }
}
#endif
