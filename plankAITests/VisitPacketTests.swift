import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// VisitPacket (app v8 S3, docs/app_v8/09_S3_PACKET.md) — the
// packet's laws pinned: traceable counts, sparse honesty, F1
// provenance naming (self-reported never looks verified), bounded
// deterministic questions with permanent removal, consent inactive
// by default + revocable, account isolation. Shares the ONE
// process-wide container; every constructed record is user-scoped.

@MainActor
final class VisitPacketTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    private func dayKey(_ daysAgo: Int) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return f.string(from: d)
    }

    private func date(_ daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
    }

    private func wipe(_ userId: String) {
        ObservationStore.deleteAll(userId: userId, in: context)
        for record in (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        ))) ?? [] { context.delete(record) }
        for record in (try? context.fetch(FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.userId == userId }
        ))) ?? [] { context.delete(record) }
        try? context.save()
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix("visitq.removed.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Empty + sparse honesty

    func testEmptyPacketRendersWindowAndGapsOnly() {
        let user = "PKT-EMPTY"
        wipe(user)
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertTrue(packet.isEmpty)
        XCTAssertNil(packet.regimen)
        XCTAssertNil(packet.weight)
        XCTAssertFalse(packet.gaps.isEmpty)
        XCTAssertEqual(packet.window.dayKeys.count, 28)
        wipe(user)
    }

    func testSparseWeightSpeaksCountsNeverTrend() {
        let user = "PKT-SPARSE-W"
        wipe(user)
        for daysAgo in [2, 9] {
            context.insert(WeightLogRecord(
                userId: user, weightKg: 74 - Double(daysAgo) * 0.05,
                loggedAt: date(daysAgo), source: "manual"
            ))
        }
        try? context.save()
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(packet.weight?.entryCount, 2)
        XCTAssertNil(packet.weight?.directionWord)   // no false trend
        XCTAssertTrue(packet.gaps.contains { $0.contains("not enough weigh-ins") })
        wipe(user)
    }

    func testEstablishedTrendSpeaksDirection() {
        let user = "PKT-TREND"
        wipe(user)
        for (daysAgo, kg) in [(20, 75.0), (14, 74.4), (7, 73.9), (1, 73.2)] {
            context.insert(WeightLogRecord(
                userId: user, weightKg: kg, loggedAt: date(daysAgo), source: "manual"
            ))
        }
        try? context.save()
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(packet.weight?.entryCount, 4)
        XCTAssertEqual(packet.weight?.directionWord, "easing")
        wipe(user)
    }

    // MARK: - F1 provenance naming

    func testSelfReportedRegimenNeverLeaksHerName() {
        let user = "PKT-F1-SELF"
        wipe(user)
        let plan = RegimenPlanRecord(
            userId: user, kind: "medication",
            displayName: "wegovy",   // her words — must NOT render
            scheduleRule: "weeklyAnchor",
            anchorWeekday: RegimenService.isoWeekday(.now),
            startedAt: date(27)
        )
        context.insert(plan)
        try? context.save()
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(packet.regimen?.displayLine, "your weekly medication")
        XCTAssertEqual(packet.regimen?.authorityLabel, "self-reported")
        RegimenService.endMedicationPlan(userId: user, in: context)
        wipe(user)
    }

    func testCareTeamRegimenRendersAssignedFacts() {
        let user = "PKT-F1-TEAM"
        wipe(user)
        let plan = RegimenPlanRecord(
            userId: user, kind: "medication",
            displayName: "semaglutide",
            scheduleRule: "weeklyAnchor",
            anchorWeekday: RegimenService.isoWeekday(.now),
            startedAt: date(27)
        )
        plan.authority = "care_team"
        plan.strengthValue = 1.0
        plan.strengthUnit = "mg"
        context.insert(plan)
        try? context.save()
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(packet.regimen?.displayLine, "semaglutide 1 mg")
        XCTAssertEqual(packet.regimen?.authorityLabel, "assigned by your care team")
        plan.endedAt = .now   // direct: the service refuses managed edits
        try? context.save()
        wipe(user)
    }

    // MARK: - Adherence arithmetic

    func testAdherenceCountsTakenSkippedUnrecorded() {
        let user = "PKT-ADHERE"
        wipe(user)
        let anchor = RegimenService.isoWeekday(.now)
        let plan = RegimenPlanRecord(
            userId: user, kind: "medication", displayName: "",
            scheduleRule: "weeklyAnchor", anchorWeekday: anchor,
            startedAt: date(27)
        )
        context.insert(plan)
        try? context.save()
        // 4 scheduled anchor days in a 28-day window (today, -7,
        // -14, -21). Mark: taken today, skipped -7, unrecorded rest.
        ObservationStore.record(
            .doseTaken, valueText: "yes", dayKey: dayKey(0),
            userId: user, in: context, sync: false
        )
        ObservationStore.record(
            .doseTaken, valueText: "no", dayKey: dayKey(7),
            userId: user, in: context, sync: false
        )
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(packet.regimen?.scheduledCount, 4)
        XCTAssertEqual(packet.regimen?.takenCount, 1)
        XCTAssertEqual(packet.regimen?.skippedCount, 1)
        XCTAssertEqual(packet.regimen?.unrecordedCount, 2)
        XCTAssertTrue(packet.gaps.contains { $0.contains("unrecorded is not skipped") })
        RegimenService.endMedicationPlan(userId: user, in: context)
        wipe(user)
    }

    // MARK: - Symptoms: timing, never causality

    func testSymptomTimingNoteRequiresTwoQualifyingRecords() {
        let user = "PKT-SYMPTOM"
        wipe(user)
        ObservationStore.record(
            .doseTaken, valueText: "yes", dayKey: dayKey(10),
            userId: user, in: context, sync: false
        )
        ObservationStore.record(
            .doseTaken, valueText: "yes", dayKey: dayKey(3),
            userId: user, in: context, sync: false
        )
        // queasy the day after each dose (2 qualifying) + one far
        // from any dose.
        for daysAgo in [9, 2, 20] {
            ObservationStore.record(
                .sitCheck, valueText: "queasy", dayKey: dayKey(daysAgo),
                userId: user, in: context, sync: false
            )
        }
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        let queasy = packet.symptoms.first { $0.word == "queasy" }
        XCTAssertEqual(queasy?.count, 3)
        XCTAssertNotNil(queasy?.timingNote)
        XCTAssertFalse(queasy?.timingNote?.contains("caus") ?? true)
        wipe(user)
    }

    func testIsolatedSymptomGetsNoTimingNote() {
        let user = "PKT-SYMPTOM-1"
        wipe(user)
        ObservationStore.record(
            .sitCheck, valueText: "heavy", dayKey: dayKey(4),
            userId: user, in: context, sync: false
        )
        let packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(packet.symptoms.first?.count, 1)
        XCTAssertNil(packet.symptoms.first?.timingNote)
        wipe(user)
    }

    // MARK: - Questions: generated once, removable forever, hers editable

    func testGeneratedQuestionInsertsOnceAndTombstoneRemoves() {
        let user = "PKT-Q"
        wipe(user)
        for daysAgo in [1, 8] {
            context.insert(WeightLogRecord(
                userId: user, weightKg: 74, loggedAt: date(daysAgo), source: "manual"
            ))
        }
        try? context.save()
        var packet = VisitPacketBuilder.build(userId: user, in: context)
        let generated = packet.questions.filter { $0.origin == "generated" }
        XCTAssertTrue(generated.contains { $0.text.contains("weigh-in rhythm") })

        // Rebuild: no duplicate.
        packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertEqual(
            packet.questions.filter { $0.text.contains("weigh-in rhythm") }.count, 1
        )

        // Removal is permanent (tombstone survives rebuilds).
        if let q = packet.questions.first(where: { $0.text.contains("weigh-in rhythm") }) {
            ObservationStore.delete(id: q.id, in: context)
            UserDefaults.standard.set(
                true, forKey: "visitq.removed.weighrhythm.\(user.lowercased())"
            )
        }
        packet = VisitPacketBuilder.build(userId: user, in: context)
        XCTAssertFalse(packet.questions.contains { $0.text.contains("weigh-in rhythm") })
        wipe(user)
    }

    // MARK: - Consent: inactive default, grant, revoke

    func testConsentLifecycle() {
        let user = "PKT-CONSENT"
        wipe(user)
        XCTAssertFalse(ConsentService.isActive(
            scope: ConsentService.visitPacketScope, userId: user, in: context
        ))
        ConsentService.grant(
            scope: ConsentService.visitPacketScope,
            purpose: "share the visit packet with a future care team",
            userId: user, in: context
        )
        XCTAssertTrue(ConsentService.isActive(
            scope: ConsentService.visitPacketScope, userId: user, in: context
        ))
        ConsentService.revoke(
            scope: ConsentService.visitPacketScope, userId: user, in: context
        )
        XCTAssertFalse(ConsentService.isActive(
            scope: ConsentService.visitPacketScope, userId: user, in: context
        ))
        // The audit pair survives revocation.
        let rows = (try? context.fetch(FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.userId == "PKT-CONSENT" }
        ))) ?? []
        XCTAssertEqual(rows.count, 1)
        XCTAssertNotNil(rows.first?.revokedAt)
        wipe(user)
    }

    // MARK: - Account isolation

    func testPacketNeverCrossesAccounts() {
        let a = "PKT-ISO-A", b = "PKT-ISO-B"
        wipe(a); wipe(b)
        context.insert(WeightLogRecord(
            userId: a, weightKg: 70, loggedAt: date(1), source: "manual"
        ))
        try? context.save()
        ObservationStore.record(
            .sitCheck, valueText: "queasy", dayKey: dayKey(1),
            userId: a, in: context, sync: false
        )
        let packetB = VisitPacketBuilder.build(userId: b, in: context)
        XCTAssertNil(packetB.weight)
        XCTAssertTrue(packetB.symptoms.isEmpty)
        wipe(a); wipe(b)
    }
}
