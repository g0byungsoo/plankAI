import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// E1 THE SPINE — the ONE writer over program-fact chains
// (docs/app_v25/05_E1_SPINE.md §1). Adversarial per the brief:
// competing authorities, chain integrity, rejected writes,
// idempotent bootstrap, legacy write-through.

@MainActor
final class ProgramFactStoreTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private func freshUser(_ tag: String) -> String { "e1-\(tag)-\(UUID().uuidString)" }
    private let t0 = Date(timeIntervalSince1970: 1_754_000_000)
    private func at(_ days: Double) -> Date { t0.addingTimeInterval(days * 86_400) }
    private func scratchDefaults(_ tag: String) -> UserDefaults {
        let name = "e1-tests-\(tag)-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // MARK: - Chain writes

    func testApplyCreatesVersionOne() throws {
        let user = freshUser("v1")
        let rec = ProgramFactStore.apply(
            .stepGoal, value: .int(6_000), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0, in: context
        )
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec?.value, "i:6000")
        XCTAssertNil(rec?.endedAt)
        XCTAssertNil(rec?.previousFactId)
        XCTAssertEqual(
            ProgramFactStore.headValue(.stepGoal, userId: user, in: context),
            .int(6_000)
        )
    }

    func testSameDayCoalesceMutatesInPlace() throws {
        let user = freshUser("coalesce")
        let first = ProgramFactStore.apply(
            .stepGoal, value: .int(6_000), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0, in: context
        )
        let second = ProgramFactStore.apply(
            .stepGoal, value: .int(6_500), authority: .preferred,
            basis: .stated, source: "user",
            userId: user, now: t0.addingTimeInterval(3_600), in: context
        )
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(second?.value, "i:6500")
        XCTAssertEqual(
            ProgramFactStore.history(.stepGoal, userId: user, in: context).count, 1
        )
    }

    func testSettledChangeSupersedes() throws {
        let user = freshUser("chain")
        let first = ProgramFactStore.apply(
            .stepGoal, value: .int(6_000), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0, in: context
        )
        let second = ProgramFactStore.apply(
            .stepGoal, value: .int(7_000), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: at(2), in: context
        )
        XCTAssertNotEqual(first?.id, second?.id)
        XCTAssertEqual(second?.previousFactId, first?.id)
        XCTAssertNotNil(first?.endedAt)
        XCTAssertEqual(first?.endReason, "superseded")
        XCTAssertEqual(
            ProgramFactStore.headValue(.stepGoal, userId: user, in: context),
            .int(7_000)
        )
        XCTAssertEqual(
            ProgramFactStore.history(.stepGoal, userId: user, in: context).count, 2
        )
    }

    func testPreferredAndAcceptedRecommendationChainsCoexist() throws {
        let user = freshUser("coexist")
        ProgramFactStore.apply(
            .stepGoal, value: .int(9_000), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0, in: context
        )
        ProgramFactStore.apply(
            .stepGoal, value: .int(7_000), authority: .recommended,
            basis: .inferred, source: "weekly_read", acceptedAt: at(1),
            userId: user, now: at(1), in: context
        )
        // Both chains active; preferred out-renders.
        XCTAssertEqual(
            ProgramFactStore.headValue(.stepGoal, userId: user, in: context),
            .int(9_000)
        )
        XCTAssertEqual(
            ProgramFactStore.history(.stepGoal, userId: user, in: context).count, 2
        )
    }

    func testRecommendedWithoutAcceptanceRejected() throws {
        let user = freshUser("noconsent")
        let rec = ProgramFactStore.apply(
            .stepGoal, value: .int(7_000), authority: .recommended,
            basis: .inferred, source: "weekly_read",
            userId: user, now: t0, in: context
        )
        XCTAssertNil(rec)
        XCTAssertNil(ProgramFactStore.headValue(.stepGoal, userId: user, in: context))
    }

    func testPrescribedWriteRejectedAtTheChokepoint() throws {
        // iOS never authors prescriptions (S4 law) — prescribed rows
        // arrive only via sync hydrate.
        let user = freshUser("rx")
        let rec = ProgramFactStore.apply(
            .stepGoal, value: .int(10_000), authority: .prescribed,
            basis: .assigned, source: "clinic", userId: user, now: t0, in: context
        )
        XCTAssertNil(rec)
    }

    func testClampAppliedOnWrite() throws {
        let user = freshUser("clamp")
        let rec = ProgramFactStore.apply(
            .stepGoal, value: .int(12_000), authority: .recommended,
            basis: .inferred, source: "weekly_read", acceptedAt: t0,
            userId: user, now: t0, in: context
        )
        XCTAssertEqual(rec?.value, "i:8000")
    }

    func testInvalidWordRejected() throws {
        let user = freshUser("word")
        let rec = ProgramFactStore.apply(
            .weighCadence, value: .word("sometimes"), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0, in: context
        )
        XCTAssertNil(rec)
        XCTAssertNil(ProgramFactStore.headValue(.weighCadence, userId: user, in: context))
    }

    // MARK: - Authority interplay

    func testPrescriptionOutRendersThenEndResumesPreferred() throws {
        let user = freshUser("resume")
        ProgramFactStore.apply(
            .stepGoal, value: .int(9_000), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0, in: context
        )
        // A prescription arrives the way sync delivers it: as a row,
        // not through the chokepoint.
        let rx = ProgramFactRecord(
            userId: user, kind: "stepGoal", value: "i:10000",
            authority: "prescribed", basis: "assigned", source: "sync"
        )
        rx.createdAt = at(1)
        context.insert(rx)
        try context.save()

        XCTAssertEqual(
            ProgramFactStore.headValue(.stepGoal, userId: user, in: context),
            .int(10_000)
        )

        ProgramFactStore.endFact(
            .stepGoal, authority: .prescribed, reason: "revoked",
            userId: user, now: at(2), in: context
        )
        // The preference RESUMES — it was never destroyed.
        XCTAssertEqual(
            ProgramFactStore.headValue(.stepGoal, userId: user, in: context),
            .int(9_000)
        )
    }

    func testUserScopingNeverCrosses() throws {
        let a = freshUser("scope-a")
        let b = freshUser("scope-b")
        ProgramFactStore.apply(
            .proteinAdjust, value: .int(5), authority: .preferred,
            basis: .stated, source: "user", userId: a, now: t0, in: context
        )
        XCTAssertNil(ProgramFactStore.headValue(.proteinAdjust, userId: b, in: context))
    }

    // MARK: - Legacy write-through (transition law)

    func testWriteThroughKeepsLegacyKnobsInSync() throws {
        let user = freshUser("knob")
        let d = scratchDefaults("knob")
        ProgramFactStore.apply(
            .proteinAdjust, value: .int(-5), authority: .recommended,
            basis: .inferred, source: "weekly_read", acceptedAt: t0,
            userId: user, now: t0, in: context, legacyDefaults: d
        )
        XCTAssertEqual(d.integer(forKey: WeeklyReview.proteinAdjustKey), -5)

        ProgramFactStore.apply(
            .weighCadence, value: .word("softened"), authority: .preferred,
            basis: .stated, source: "user", userId: user, now: t0,
            in: context, legacyDefaults: d
        )
        XCTAssertTrue(d.bool(forKey: WeeklyReview.weighSoftenedKey))
    }

    // MARK: - Bootstrap (migration moment)

    func testBootstrapMigratesConsentedKnobsOnce() throws {
        let user = freshUser("boot")
        let d = scratchDefaults("boot")
        d.set(-5, forKey: WeeklyReview.proteinAdjustKey)
        d.set(-1, forKey: WeeklyReview.sessionsAdjustKey)
        d.set(true, forKey: WeeklyReview.weighSoftenedKey)

        ProgramFactStore.bootstrapIfNeeded(
            userId: user, defaults: d, now: t0, in: context
        )

        XCTAssertEqual(
            ProgramFactStore.headValue(.proteinAdjust, userId: user, in: context),
            .int(-5)
        )
        XCTAssertEqual(
            ProgramFactStore.headValue(.movesAdjust, userId: user, in: context),
            .int(-1)
        )
        XCTAssertEqual(
            ProgramFactStore.headValue(.weighCadence, userId: user, in: context),
            .word("softened")
        )
        // Migrated rows carry their provenance.
        let row = ProgramFactStore.history(.proteinAdjust, userId: user, in: context).first
        XCTAssertEqual(row?.source, "migration")
        XCTAssertEqual(row?.authority, "preferred")

        // Idempotent: a second run adds nothing.
        ProgramFactStore.bootstrapIfNeeded(
            userId: user, defaults: d, now: at(1), in: context
        )
        XCTAssertEqual(
            ProgramFactStore.history(.proteinAdjust, userId: user, in: context).count, 1
        )
    }

    func testBootstrapWritesNothingForDefaultKnobs() throws {
        let user = freshUser("boot-empty")
        let d = scratchDefaults("boot-empty")
        ProgramFactStore.bootstrapIfNeeded(
            userId: user, defaults: d, now: t0, in: context
        )
        XCTAssertNil(ProgramFactStore.headValue(.proteinAdjust, userId: user, in: context))
        XCTAssertNil(ProgramFactStore.headValue(.movesAdjust, userId: user, in: context))
        XCTAssertNil(ProgramFactStore.headValue(.weighCadence, userId: user, in: context))
    }
}
