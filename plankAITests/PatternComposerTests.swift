import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - PatternComposerTests (p72)
//
// The pattern engine's inputs used to be hand-built at three sites
// (the Becoming tile, jeni's read_patterns, and — as of p72 — the
// regimen page, where the observation finally renders beside the
// ledgers it reads). One composer now; this pins that it composes the
// REAL stores into the engine's proof case: a dose change followed by
// a symptom cluster fires "picked up after the dose changed" from
// nothing but the record.

@MainActor
final class PatternComposerTests: XCTestCase {

    private var seededUserIds: [String] = []

    override func tearDown() {
        let context = TestModelContainer.shared.mainContext
        for uid in seededUserIds {
            for r in (try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
                predicate: #Predicate { $0.userId == uid }
            ))) ?? [] { context.delete(r) }
            for o in (try? context.fetch(FetchDescriptor<ObservationRecord>(
                predicate: #Predicate { $0.userId == uid }
            ))) ?? [] { context.delete(o) }
        }
        try? context.save()
        super.tearDown()
    }

    private func user(_ tag: String) -> String {
        let u = "p72-\(tag)-\(UUID().uuidString)"
        seededUserIds.append(u)
        return u
    }

    private func dayKey(daysAgo: Int) -> String {
        TodayStateService.dayKey(
            for: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        )
    }

    func testTheComposedRecordFiresTheDoseChangeObservation() throws {
        let context = ModelContext(TestModelContainer.shared)
        let uid = user("change")

        // Version 1: 0.25 mg, twenty days ago.
        var spec = RegimenService.SelfRegimenSpec()
        spec.displayName = "ozempic"
        spec.productId = "ozempic"
        spec.doseValue = 0.25
        spec.doseUnit = "mg"
        spec.anchorWeekday = 3
        _ = RegimenService.applySelfRegimen(
            spec, userId: uid,
            now: .now.addingTimeInterval(-86_400 * 20), in: context
        )
        // Version 2: the dose bump, five days ago.
        var bump = spec
        bump.doseValue = 0.5
        let plan = try XCTUnwrap(RegimenService.applySelfRegimen(
            bump, userId: uid,
            now: .now.addingTimeInterval(-86_400 * 5), in: context
        ))

        // Two queasy days AFTER the bump, none in the window before —
        // the engine's own floor (≥2 after, after > before).
        _ = SideEffectLog.record(.nausea, severity: .noticeable,
                                 dayKey: dayKey(daysAgo: 4),
                                 userId: uid, in: context)
        _ = SideEffectLog.record(.nausea, severity: .noticeable,
                                 dayKey: dayKey(daysAgo: 2),
                                 userId: uid, in: context)

        let observations = MedicationPatternEngine.observations(
            MedicationPatternEngine.composedInputs(
                plan: plan, userId: uid, in: context
            )
        )
        XCTAssertTrue(
            observations.contains { $0.id.hasPrefix("after-change") },
            "the record's own shape must reach the engine through the composer; got \(observations.map(\.id))"
        )
    }

    func testAQuietRecordComposesToSilence() throws {
        let context = ModelContext(TestModelContainer.shared)
        let uid = user("quiet")
        var spec = RegimenService.SelfRegimenSpec()
        spec.displayName = "ozempic"
        spec.productId = "ozempic"
        spec.doseValue = 0.5
        spec.doseUnit = "mg"
        spec.anchorWeekday = 3
        let plan = try XCTUnwrap(RegimenService.applySelfRegimen(
            spec, userId: uid, in: context
        ))
        let observations = MedicationPatternEngine.observations(
            MedicationPatternEngine.composedInputs(
                plan: plan, userId: uid, in: context
            )
        )
        XCTAssertTrue(observations.isEmpty,
                      "no floors cleared → the page stays silent")
    }
}
