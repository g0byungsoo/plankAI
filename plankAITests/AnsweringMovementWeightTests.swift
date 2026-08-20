import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - AnsweringMovementWeightTests (app v25 pass 53)
//
// MOVEMENT: a session she recorded by hand must count everywhere a
// session counts — the Method's note 11 scolded a strength-recorder
// ("nothing is asking your muscles to stay") while the Home tile
// beside it said "strength met this week", which violates the
// builder's own first law (a note can never quote a number the
// screen behind it disagrees with).
//
// WEIGHT: pass 51 built the canonical fold and named "everything a
// customer reads as a trend" as its jurisdiction — this pass closes
// the three readers still speaking the fast trigger fold (the
// morning brief's trend clauses, the Home/Becoming change line, the
// packet's fourth direction engine) and the two onboarding-row
// leaks. The trigger folds themselves (band pushes, rapid-loss
// tripwire, flat-week counter) are calibrated instruments and stay,
// documented.
//
// RED before GREEN against honest-BEFORE stubs.

@MainActor
final class AnsweringMovementWeightTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MoveManualStore.wipe()
    }

    override func tearDown() {
        MoveManualStore.wipe()
        super.tearDown()
    }

    // MARK: movement — recorded by hand counts everywhere

    func testHandRecordedStrengthReachesTheMethod() {
        MoveManualStore.record(kind: .strength, minutes: 30, weightKg: 70)
        MoveManualStore.record(kind: .strength, minutes: 20, weightKg: 70)
        MoveManualStore.record(kind: .walk, minutes: 30, weightKg: 70)
        XCTAssertEqual(
            MethodInputBuilder.strengthLast7(healthKitCount: nil), 2,
            "two hand-recorded strength sessions are two strength sessions"
        )
        XCTAssertEqual(
            MethodInputBuilder.strengthLast7(healthKitCount: 1), 3,
            "health's count and her own add — the Home tile's own sum"
        )
    }

    func testPreservationSeesHandSessionsWithoutHealth() {
        // everRequested=false used to force nil — a user who records
        // every session by hand read as "not connected" to the
        // preservation review.
        XCTAssertEqual(
            MethodInputBuilder.preservationStrength(
                everRequested: false, healthKit: 0, entered: 2
            ), 2
        )
        XCTAssertNil(
            MethodInputBuilder.preservationStrength(
                everRequested: false, healthKit: 0, entered: 0
            ),
            "no grant and no entries is honest absence, never zero"
        )
        XCTAssertEqual(
            MethodInputBuilder.preservationStrength(
                everRequested: true, healthKit: 1, entered: 1
            ), 2
        )
        XCTAssertEqual(
            MethodInputBuilder.preservationStrength(
                everRequested: true, healthKit: 0, entered: 0
            ), 0,
            "a granted stream with nothing in it is a real zero"
        )
    }

    func testADeletedManualSessionLeavesTheWeek() {
        // Pin: the store's delete works and the week count follows —
        // the list UI this pass adds depends on it. (A pin, not a
        // RED: the function existed with zero callers.)
        let entry = MoveManualStore.record(kind: .strength, minutes: 30, weightKg: nil)
        XCTAssertEqual(MoveManualStore.strengthLastWeek(), 1)
        MoveManualStore.delete(id: entry.id)
        XCTAssertEqual(MoveManualStore.strengthLastWeek(), 0)
        XCTAssertTrue(MoveManualStore.all().isEmpty)
    }

    // MARK: weight — one customer-legible fold

    private func log(
        _ kg: Double, daysAgo: Int, source: String = "manual",
        now: Date
    ) -> WeightLogRecord {
        let record = WeightLogRecord(
            userId: "p53-w", weightKg: kg, source: source
        )
        record.loggedAt = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: now
        ) ?? now
        return record
    }

    func testTheBriefsTrendDeltaIsTheCanonicalFold() {
        // A sharp recent drop: the fast α=2/8 fold reacts harder than
        // the τ=9.5d canonical fold, so the two disagree — and the
        // number the morning brief speaks must be the one the chat
        // card, Becoming's tile and jeni's tool already speak.
        let now = Date()
        var logs: [WeightLogRecord] = []
        for day in 0..<16 {
            let kg = day < 3 ? 78.0 - Double(3 - day) : 78.0
            logs.append(log(kg, daysAgo: 15 - day == 0 ? 0 : 15 - day, now: now))
        }
        logs.sort { $0.loggedAt > $1.loggedAt }
        let read = BodyStateService.weightRead(logs: logs, today: now)
        let samples = WeightSeries.samples(from: logs)
        let canonical = WeightWeekReadEngine.read(samples: samples, now: now)
        XCTAssertNotNil(read?.emaDelta7dKg)
        XCTAssertEqual(
            read?.emaDelta7dKg ?? .nan,
            canonical.weeklyDeltaKg ?? .nan,
            accuracy: 0.001,
            "the brief's delta and the canonical weekly delta are one number"
        )
    }

    func testTrendEstablishmentFollowsTheCanonicalGate() {
        // Three rows spanning six days: the old ad-hoc rule said
        // "established" and the brief spoke a direction while jeni's
        // tool said not_established for the same person. The
        // canonical band (≥4 obs over ≥14 days before any direction)
        // is the one gate now.
        let now = Date()
        let logs = [
            log(78.0, daysAgo: 0, now: now),
            log(78.4, daysAgo: 3, now: now),
            log(78.8, daysAgo: 6, now: now),
        ]
        let read = BodyStateService.weightRead(logs: logs, today: now)
        XCTAssertEqual(read?.trendEstablished, false)
    }

    func testThePacketDirectionWordIsTheCanonicalBand() {
        // Raw first-vs-last says +0.35 kg → the old hand-rolled rule
        // called it "climbing"; the canonical τ-fold's weekly delta
        // sits inside the honesty band → "steady". The clinician and
        // Becoming must read the same story.
        let now = Date()
        var samples: [WeightWeekReadEngine.Sample] = []
        for day in stride(from: 27, through: 0, by: -1) {
            let kg = 78.0 + (Double(27 - day) / 27.0) * 0.35
            samples.append(.init(
                day: Calendar.current.date(byAdding: .day, value: -day, to: now) ?? now,
                kg: kg
            ))
        }
        XCTAssertEqual(
            VisitPacketBuilder.weightDirectionWord(samples: samples, now: now),
            "steady"
        )
    }

    func testThePreviousWeighInIgnoresTheSignUpRow() throws {
        // The scale-jump note compared her real weigh-in against the
        // sign-up self-report — "two real readings" it was not.
        let context = ModelContext(TestModelContainer.shared)
        let now = Date()
        let manual = WeightLogRecord(
            userId: "p53-prev", weightKg: 80, source: "manual"
        )
        manual.loggedAt = now
        let onboarding = WeightLogRecord(
            userId: "p53-prev", weightKg: 90, source: "onboarding"
        )
        onboarding.loggedAt = Calendar.current.date(
            byAdding: .day, value: -1, to: now
        ) ?? now
        context.insert(manual)
        context.insert(onboarding)
        try context.save()
        XCTAssertNil(
            MethodInputBuilder.previousWeighInKg(userId: "p53-prev", in: context),
            "one real reading has no previous reading; the sign-up answer is not one"
        )
        // Shared-container law: leave no rows behind
        // (ReattributionTests counts WeightLogRecord globally — the
        // pass-36 lesson, honored in MY file).
        context.delete(manual)
        context.delete(onboarding)
        try context.save()
    }

    // MARK: cycle — context earned from HER logged starts (p53)

    private func daysAgo(_ n: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: now) ?? now
    }

    func testAnIrregularHistoryStandsDown() {
        // Gaps of 21 and 38 days — a spread this wide (likelier in
        // this population: cycles shift on-therapy) makes any phase
        // claim a guess, and silence is the return value.
        let now = Date()
        let starts = [daysAgo(63, from: now), daysAgo(42, from: now), daysAgo(4, from: now)]
        XCTAssertNil(CycleSignal.read(periodStarts: starts, now: now))
    }

    func testALutealClaimNeedsHerOwnHistory() {
        // One logged start, day 22 of a DEFAULT 28: "the days before
        // your period" would be a prediction with no history under
        // it. Not luteal.
        let now = Date()
        let one = [daysAgo(21, from: now)]
        XCTAssertNotEqual(
            CycleSignal.read(periodStarts: one, now: now)?.phase, .luteal
        )
        // With a real start-to-start gap on file, the claim stands.
        let two = [daysAgo(49, from: now), daysAgo(21, from: now)]
        XCTAssertEqual(
            CycleSignal.read(periodStarts: two, now: now)?.phase, .luteal
        )
    }

    func testAFreshLoggedStartIsAlwaysReadable() {
        // Day 2 of flow from HER OWN logged start — observed, not
        // predicted; one cycle is enough for this one claim.
        let now = Date()
        let starts = [daysAgo(1, from: now)]
        XCTAssertEqual(
            CycleSignal.read(periodStarts: starts, now: now)?.phase, .menstrual
        )
    }
}
