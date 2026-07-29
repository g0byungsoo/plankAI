import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// ObservationStore (app v8, docs/app_v8/03_ARCHITECTURE.md §3b) —
// the chart. Pins: singular-kind upsert semantics, append kinds,
// userId scoping, the "queasy N of last 7" aggregation, the legacy
// backfill (incl. the orphaned day.dose. family), delete-account
// scoping. Shares the ONE process-wide container.

@MainActor
final class ObservationStoreTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userA = "OBS-TEST-USER-A"
    private let userB = "OBS-TEST-USER-B"

    private func dayKey(_ daysAgo: Int, from base: Date = .now) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: base)!
        return f.string(from: d)
    }

    override func setUp() {
        super.setUp()
        ObservationStore.deleteAll(userId: userA, in: context)
        ObservationStore.deleteAll(userId: userB, in: context)
    }

    // MARK: - Write semantics

    func testSingularKindUpsertsInPlace() {
        let key = dayKey(0)
        ObservationStore.record(
            .sitCheck, valueText: "fine", dayKey: key, userId: userA,
            in: context, sync: false
        )
        ObservationStore.record(
            .sitCheck, valueText: "queasy", dayKey: key, userId: userA,
            in: context, sync: false
        )
        let rows = ObservationStore.series(.sitCheck, userId: userA, in: context)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.valueText, "queasy")
    }

    func testDifferentDaysAppend() {
        ObservationStore.record(
            .feeling, valueText: "proud", dayKey: dayKey(1), userId: userA,
            in: context, sync: false
        )
        ObservationStore.record(
            .feeling, valueText: "tender", dayKey: dayKey(0), userId: userA,
            in: context, sync: false
        )
        XCTAssertEqual(
            ObservationStore.series(.feeling, userId: userA, in: context).count, 2
        )
    }

    func testCareEventsAppendWithinOneDay() {
        let key = dayKey(0)
        ObservationStore.record(
            .careEvent, valueText: "underfuel_streak", dayKey: key, userId: userA,
            source: "derived", in: context, sync: false
        )
        ObservationStore.record(
            .careEvent, valueText: "rapid_loss", dayKey: key, userId: userA,
            source: "derived", in: context, sync: false
        )
        XCTAssertEqual(
            ObservationStore.series(.careEvent, userId: userA, in: context).count, 2
        )
    }

    // MARK: - Read semantics

    func testValueTextReadsTheDay() {
        let key = dayKey(0)
        ObservationStore.record(
            .doseTaken, valueText: "yes", dayKey: key, userId: userA,
            in: context, sync: false
        )
        XCTAssertEqual(
            ObservationStore.valueText(.doseTaken, dayKey: key, userId: userA, in: context),
            "yes"
        )
        XCTAssertNil(
            ObservationStore.valueText(.doseTaken, dayKey: dayKey(1), userId: userA, in: context)
        )
    }

    func testSeriesIsUserScoped() {
        ObservationStore.record(
            .feeling, valueText: "proud", dayKey: dayKey(0), userId: userA,
            in: context, sync: false
        )
        ObservationStore.record(
            .feeling, valueText: "tender", dayKey: dayKey(0), userId: userB,
            in: context, sync: false
        )
        let a = ObservationStore.series(.feeling, userId: userA, in: context)
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a.first?.valueText, "proud")
    }

    func testCountMatchingWindowsAndValues() {
        // queasy on 3 of the last 7 evenings; heavy on 1; older
        // queasy outside the window must not count.
        for daysAgo in [0, 2, 5] {
            ObservationStore.record(
                .sitCheck, valueText: "queasy", dayKey: dayKey(daysAgo),
                userId: userA, in: context, sync: false
            )
        }
        ObservationStore.record(
            .sitCheck, valueText: "heavy", dayKey: dayKey(3), userId: userA,
            in: context, sync: false
        )
        ObservationStore.record(
            .sitCheck, valueText: "queasy", dayKey: dayKey(10), userId: userA,
            in: context, sync: false
        )
        XCTAssertEqual(
            ObservationStore.countMatching(
                .sitCheck, values: ["queasy"], lastDays: 7, userId: userA, in: context
            ), 3
        )
        XCTAssertEqual(
            ObservationStore.countMatching(
                .sitCheck, values: ["queasy", "heavy"], lastDays: 7, userId: userA, in: context
            ), 4
        )
    }

    // MARK: - Backfill (legacy day-keyed strings become records)

    func testBackfillConvertsLegacyFamiliesOnce() {
        let suite = UserDefaults(suiteName: "obs-backfill-test")!
        suite.removePersistentDomain(forName: "obs-backfill-test")
        let key = dayKey(2)
        suite.set("tender", forKey: "day.reflection.\(key)")
        suite.set("queasy", forKey: "day.sit.\(key)")
        suite.set("yes", forKey: "day.dose.\(key)")   // the orphaned family
        suite.set("her line", forKey: "day.note.\(key)")
        suite.set("walk after dinner", forKey: "plan.tonight.\(key)")
        suite.set("not-a-day-key", forKey: "day.sit.garbage")

        ObservationStore.backfillLegacyIfNeeded(
            userId: userA, in: context, defaults: suite
        )

        XCTAssertEqual(
            ObservationStore.valueText(.feeling, dayKey: key, userId: userA, in: context),
            "tender"
        )
        XCTAssertEqual(
            ObservationStore.valueText(.sitCheck, dayKey: key, userId: userA, in: context),
            "queasy"
        )
        XCTAssertEqual(
            ObservationStore.valueText(.doseTaken, dayKey: key, userId: userA, in: context),
            "yes"
        )
        XCTAssertEqual(
            ObservationStore.valueText(.journalNote, dayKey: key, userId: userA, in: context),
            "her line"
        )
        XCTAssertEqual(
            ObservationStore.valueText(.tonightPlan, dayKey: key, userId: userA, in: context),
            "walk after dinner"
        )
        // The malformed key was skipped.
        XCTAssertEqual(ObservationStore.series(.sitCheck, userId: userA, in: context).count, 1)

        // Second run is a no-op (flag) — a changed legacy key never
        // re-imports over the record.
        suite.set("proud", forKey: "day.reflection.\(key)")
        ObservationStore.backfillLegacyIfNeeded(
            userId: userA, in: context, defaults: suite
        )
        XCTAssertEqual(
            ObservationStore.valueText(.feeling, dayKey: key, userId: userA, in: context),
            "tender"
        )
        suite.removePersistentDomain(forName: "obs-backfill-test")
    }

    // MARK: - Delete-account scoping

    func testDeleteAllScopesToUser() {
        ObservationStore.record(
            .feeling, valueText: "proud", dayKey: dayKey(0), userId: userA,
            in: context, sync: false
        )
        ObservationStore.record(
            .feeling, valueText: "okay", dayKey: dayKey(0), userId: userB,
            in: context, sync: false
        )
        let plan = RegimenPlanRecord(
            userId: userA, kind: "medication", displayName: "her words",
            scheduleRule: "weeklyAnchor", anchorWeekday: 7
        )
        context.insert(plan)
        try? context.save()

        ObservationStore.deleteAll(userId: userA, in: context)

        XCTAssertTrue(ObservationStore.series(.feeling, userId: userA, in: context).isEmpty)
        XCTAssertEqual(ObservationStore.series(.feeling, userId: userB, in: context).count, 1)
        let plans = try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == "OBS-TEST-USER-A" }
        ))
        XCTAssertEqual(plans?.count, 0)
    }
}
