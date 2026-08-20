import XCTest
@testable import plankAI

// E1 THE SPINE — the notification brain (docs/app_v25/05_E1_SPINE
// §4). One attention policy over every scheduler: a HARD weekly
// budget, priority lanes, the medication exemption (medical rhythm ≠
// engagement), per-category auto-silence, stable holdouts. The brain
// VETOES; it never schedules — the working infrastructure stays.

final class NotificationBrainTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_754_000_000)
    private func scratch(_ tag: String) -> UserDefaults {
        let name = "e1-brain-\(tag)-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // MARK: - The budget (hard, weekly)

    func testBudgetAdmitsUnderCapAndVetoesOver() {
        let d = scratch("budget")
        for i in 0..<5 {
            XCTAssertTrue(NotificationBrain.admit(
                .init(category: .support, id: "s\(i)"), now: t0, defaults: d
            ), "send \(i) should admit")
        }
        XCTAssertFalse(NotificationBrain.admit(
            .init(category: .support, id: "s5"), now: t0, defaults: d
        ), "the sixth support send busts the ≤5/week budget")
    }

    func testBudgetWindowRolls() {
        let d = scratch("roll")
        for i in 0..<5 {
            _ = NotificationBrain.admit(
                .init(category: .support, id: "s\(i)"), now: t0, defaults: d
            )
        }
        let nextWeek = t0.addingTimeInterval(8 * 86_400)
        XCTAssertTrue(NotificationBrain.admit(
            .init(category: .support, id: "fresh"), now: nextWeek, defaults: d
        ))
    }

    func testSameIdReplaceIsFree() {
        // Planners replace-never-stack daily; re-admitting the same
        // id within the window is a REPLACE, not a new interruption.
        let d = scratch("replace")
        for _ in 0..<8 {
            XCTAssertTrue(NotificationBrain.admit(
                .init(category: .support, id: "anchor_d1"), now: t0, defaults: d
            ))
        }
        // Only ONE budget slot consumed by all eight replaces.
        for i in 0..<4 {
            XCTAssertTrue(NotificationBrain.admit(
                .init(category: .support, id: "other\(i)"), now: t0, defaults: d
            ))
        }
        XCTAssertFalse(NotificationBrain.admit(
            .init(category: .support, id: "other4"), now: t0, defaults: d
        ))
    }

    // MARK: - The medication exemption

    func testMedicationLaneIsExemptFromTheBudget() {
        let d = scratch("med")
        for i in 0..<5 {
            _ = NotificationBrain.admit(
                .init(category: .support, id: "s\(i)"), now: t0, defaults: d
            )
        }
        // Budget exhausted — the dose reminder still passes (medical
        // rhythm, never engagement).
        XCTAssertTrue(NotificationBrain.admit(
            .init(category: .medication, id: "med_dose_reminder"),
            now: t0, defaults: d
        ))
    }

    func testMedicationLaneDoesNotConsumeTheBudget() {
        let d = scratch("med2")
        for i in 0..<10 {
            _ = NotificationBrain.admit(
                .init(category: .medication, id: "m\(i)"), now: t0, defaults: d
            )
        }
        XCTAssertTrue(NotificationBrain.admit(
            .init(category: .support, id: "s0"), now: t0, defaults: d
        ))
    }

    // MARK: - Priority lanes (the read outranks support)

    func testReadAdmitsEvenAtFullBudget() {
        let d = scratch("lane")
        for i in 0..<5 {
            _ = NotificationBrain.admit(
                .init(category: .support, id: "s\(i)"), now: t0, defaults: d
            )
        }
        // Budget full: support is done for the week — the week's ONE
        // ritual still passes (priority-exempt, but logged).
        XCTAssertFalse(NotificationBrain.admit(
            .init(category: .support, id: "s5"), now: t0, defaults: d
        ))
        XCTAssertTrue(NotificationBrain.admit(
            .init(category: .weeklyRead, id: "read"), now: t0, defaults: d
        ))
    }

    // MARK: - Auto-silence (ignores put a category to sleep)

    func testCategoryAutoSilencesAfterIgnoreStreak() {
        let d = scratch("silence")
        for _ in 0..<6 {
            NotificationBrain.recordIgnored(.support, defaults: d)
        }
        XCTAssertFalse(NotificationBrain.admit(
            .init(category: .support, id: "s"), now: t0, defaults: d
        ))
        XCTAssertTrue(NotificationBrain.isSilenced(.support, defaults: d))
    }

    func testEngagementResetsTheIgnoreStreak() {
        let d = scratch("reset")
        for _ in 0..<5 {
            NotificationBrain.recordIgnored(.support, defaults: d)
        }
        NotificationBrain.recordEngaged(.support, defaults: d)
        for _ in 0..<5 {
            NotificationBrain.recordIgnored(.support, defaults: d)
        }
        // 5 after a reset is under the 6-threshold — still awake.
        XCTAssertTrue(NotificationBrain.admit(
            .init(category: .support, id: "s"), now: t0, defaults: d
        ))
    }

    func testMedicationNeverAutoSilences() {
        let d = scratch("medsilence")
        for _ in 0..<20 {
            NotificationBrain.recordIgnored(.medication, defaults: d)
        }
        XCTAssertTrue(NotificationBrain.admit(
            .init(category: .medication, id: "m"), now: t0, defaults: d
        ))
    }

    // MARK: - Posture (the quieter fact halves the budget)

    func testQuieterPostureHalvesTheSupportBudget() {
        let d = scratch("posture")
        for i in 0..<2 {
            XCTAssertTrue(NotificationBrain.admit(
                .init(category: .support, id: "s\(i)"),
                now: t0, posture: "quieter", defaults: d
            ))
        }
        XCTAssertFalse(NotificationBrain.admit(
            .init(category: .support, id: "s2"),
            now: t0, posture: "quieter", defaults: d
        ))
    }

    // MARK: - Holdouts (stable, per user+category)

    func testHoldoutIsStablePerUserAndCategory() {
        let a = NotificationBrain.isHoldout(userId: "user-a", category: .support)
        for _ in 0..<20 {
            XCTAssertEqual(
                NotificationBrain.isHoldout(userId: "user-a", category: .support), a
            )
        }
    }

    func testMedicationHasNoHoldout() {
        for user in ["a", "b", "c", "d", "e", "f", "g", "h"] {
            XCTAssertFalse(
                NotificationBrain.isHoldout(userId: user, category: .medication)
            )
        }
    }

    // MARK: - p54 · consented cadence vs the interruption budget

    /// THE SATURATION DEFECT, as a test. An ordinary enrolled week
    /// re-stamps the three morning-read rungs daily, the weekly read
    /// stamps despite being exempt, and the winback re-arm stamps on
    /// every launch — `stamps.count` sits at 5 permanently, and the
    /// only thing the ≤5/week law can still do is veto whichever
    /// fresh send arrives. In production that was the milestone
    /// family: the budget's one working act was silencing the
    /// kindest push, forever, for every active user.
    func testAStandingCadenceLeavesTheBudgetOpen() {
        let d = scratch("cadence")
        for day in 0..<7 {
            let now = t0.addingTimeInterval(Double(day) * 86_400)
            for rung in 1...3 {
                _ = NotificationBrain.admit(
                    .init(category: .morningRead, id: "anchor_d\(rung)"),
                    now: now, defaults: d
                )
            }
            _ = NotificationBrain.admit(
                .init(category: .weeklyRead, id: "resigning_knock"),
                now: now, defaults: d
            )
            _ = NotificationBrain.admit(
                .init(category: .reengagement, id: "winback_lapse"),
                now: now, defaults: d
            )
        }
        XCTAssertTrue(
            NotificationBrain.admit(
                .init(category: .support, id: "keeping_zone"),
                now: t0.addingTimeInterval(6 * 86_400), defaults: d
            ),
            "a week of standing rhythms must not spend the interruption budget"
        )
    }

    /// The cadence class passes without touching the ledger at all:
    /// the budget counts interruptions, and only interruptions.
    func testConsentedCadenceNeverStamps() {
        let d = scratch("nostamp")
        _ = NotificationBrain.admit(
            .init(category: .morningRead, id: "anchor_d1"), now: t0, defaults: d
        )
        _ = NotificationBrain.admit(
            .init(category: .weeklyRead, id: "resigning_knock"), now: t0, defaults: d
        )
        _ = NotificationBrain.admit(
            .init(category: .medication, id: "med_dose_reminder"), now: t0, defaults: d
        )
        let ledger = d.dictionary(forKey: "brain.ledger.v1") as? [String: Double]
        XCTAssertTrue(
            ledger == nil || ledger!.isEmpty,
            "a consented rhythm stamped the interruption ledger: \(ledger ?? [:])"
        )
    }

    // MARK: - p54 · every send passes through the gate

    /// The census found seventeen schedule paths and four admit calls
    /// — both daily repeats and the whole retention family bypassed
    /// the arbiter. This sweep reads the app sources: every
    /// `UNUserNotificationCenter` `.add(` outside the gate itself and
    /// the medication lane (exempt BY DESIGN, its own file) is a
    /// bypass, and a bypass is a failing test now instead of a
    /// census finding two eras later.
    func testEverySendPassesThroughTheGate() throws {
        let appDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // plankAITests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("PlankApp")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: appDir.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw XCTSkip("app sources not visible from this runner — the sweep cannot run here")
        }
        let allowlisted: Set<String> = [
            "NotificationBrain.swift",     // the gate itself
            "MedicationReminders.swift",   // the medication lane, exempt by design
        ]
        var bypasses: [String] = []
        let enumerator = FileManager.default.enumerator(
            at: appDir, includingPropertiesForKeys: nil
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  !allowlisted.contains(url.lastPathComponent),
                  let source = try? String(contentsOf: url, encoding: .utf8),
                  source.contains("UNUserNotificationCenter") else { continue }
            for (index, line) in source.components(separatedBy: "\n").enumerated()
            where line.contains("center.add(")
                || line.contains("UNUserNotificationCenter.current().add(") {
                bypasses.append("\(url.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertTrue(
            bypasses.isEmpty,
            "sends bypassing the gate: \(bypasses.joined(separator: " · "))"
        )
    }
}
