import XCTest
@testable import plankAI

// MARK: - AnalyticsHygieneTests (v25 E2 — B1)
//
// The hygiene law as a mechanism: the registry must cover the spine +
// medication families, pass their real payload shapes, and refuse
// free text, unregistered keys, out-of-vocabulary words, and
// non-categorical types.

final class AnalyticsHygieneTests: XCTestCase {

    func testRegistryCoversTheSpineAndMedicationFamilies() {
        let required: [AnalyticsEvent] = [
            .weeklyReadShown, .weeklyReadDecision, .programFactChanged,
            .walkActionShown, .walkGoalHit,
            .doseMarked, .doseReminderAction, .regimenChanged,
            .sideEffectLogged, .healthkitRequested,
            .notifCandidate, .notifDelivered, .notifSilenced,
        ]
        for event in required {
            XCTAssertNotNil(
                AnalyticsHygiene.rules[event.rawValue],
                "\(event.rawValue) has no hygiene rule"
            )
        }
    }

    func testRealPayloadShapesPass() {
        let clean: [(AnalyticsEvent, [String: Any])] = [
            (.doseMarked, ["status": "taken", "source": "sheet",
                           "route": "injection", "cadence": "weeklyAnchor",
                           "late": false]),
            (.doseReminderAction, ["action": "log_later"]),
            (.regimenChanged, ["change": "dose_changed", "route": "oral",
                               "cadence": "daily", "authority": "self"]),
            (.sideEffectLogged, ["symptom": "nausea", "severity": 2,
                                 "action": "logged"]),
            (.healthkitRequested, ["source": "onboarding", "action": "completed"]),
            (.weeklyReadShown, ["anchor": "doseDay", "offer": "step_goal_recalc",
                                "signals": 3]),
            (.weeklyReadDecision, ["anchor": "enrollment", "offer": "hold_steady",
                                   "decision": "accepted", "fact_written": true]),
            (.programFactChanged, ["kind": "stepGoal", "authority": "recommended",
                                   "source": "weekly_read"]),
            (.notifCandidate, ["category": "weeklyRead", "admitted": true,
                               "why": "ok"]),
            (.walkActionShown, [:]),
            (.walkGoalHit, [:]),
        ]
        for (event, payload) in clean {
            let v = AnalyticsHygiene.violations(
                event: event.rawValue, properties: payload
            )
            XCTAssertTrue(v.isEmpty, "\(event.rawValue): \(v)")
        }
    }

    func testFreeTextIsRefused() {
        let v = AnalyticsHygiene.violations(
            event: AnalyticsEvent.sideEffectLogged.rawValue,
            properties: ["symptom": "felt queasy after my shot today",
                         "action": "logged"]
        )
        XCTAssertFalse(v.isEmpty)
    }

    func testUnregisteredKeyIsRefused() {
        let v = AnalyticsHygiene.violations(
            event: AnalyticsEvent.doseMarked.rawValue,
            properties: ["status": "taken", "source": "sheet",
                         "dose_mg": 2]
        )
        XCTAssertEqual(v.count, 1)
        XCTAssertTrue(v[0].contains("dose_mg"))
    }

    func testOutOfVocabularyWordIsRefused() {
        let v = AnalyticsHygiene.violations(
            event: AnalyticsEvent.doseMarked.rawValue,
            properties: ["status": "forgot"]
        )
        XCTAssertFalse(v.isEmpty)
    }

    func testNonCategoricalTypeIsRefused() {
        // A Double smells like a measured value (weight, dose) —
        // exactly what must never ride analytics.
        let v = AnalyticsHygiene.violations(
            event: AnalyticsEvent.sideEffectLogged.rawValue,
            properties: ["symptom": "nausea", "severity": 2.5]
        )
        XCTAssertFalse(v.isEmpty)
    }

    func testStampedKeysAreAlwaysAllowed() {
        let v = AnalyticsHygiene.violations(
            event: AnalyticsEvent.walkGoalHit.rawValue,
            properties: ["app_version": "1.1.7 (28)",
                         "timestamp": "2026-08-10T09:00:00Z",
                         "environment": "debug", "is_test_user": true]
        )
        XCTAssertTrue(v.isEmpty)
    }

    func testUnregisteredEventsAreUnpoliced() {
        XCTAssertTrue(AnalyticsHygiene.violations(
            event: "legacy_funnel_event",
            properties: ["free": "text with spaces"]
        ).isEmpty)
    }
}

// MARK: - CohortIdentityTests

final class CohortIdentityTests: XCTestCase {

    func testNonMedicatedDerivation() {
        let p = CohortIdentity.properties(
            cohortWord: "general", route: nil, cadence: nil, authority: nil
        )
        XCTAssertEqual(p["glp1_cohort"] as? String, "general")
        XCTAssertEqual(p["medicated"] as? Bool, false)
        XCTAssertEqual(p["med_route"] as? String, "none")
        XCTAssertEqual(p["med_cadence"] as? String, "none")
        XCTAssertEqual(p["med_authority"] as? String, "none")
    }

    func testMedicatedSelfWeeklyInjection() {
        let p = CohortIdentity.properties(
            cohortWord: "on_glp1", route: "injection",
            cadence: "weeklyAnchor", authority: "self"
        )
        XCTAssertEqual(p["medicated"] as? Bool, true)
        XCTAssertEqual(p["med_route"] as? String, "injection")
        XCTAssertEqual(p["med_cadence"] as? String, "weeklyAnchor")
        XCTAssertEqual(p["med_authority"] as? String, "self")
    }

    func testPreV24PlanWithoutRouteReadsUnknownNotNone() {
        let p = CohortIdentity.properties(
            cohortWord: "on_glp1", route: nil,
            cadence: "weeklyAnchor", authority: "care_team"
        )
        XCTAssertEqual(p["medicated"] as? Bool, true)
        XCTAssertEqual(p["med_route"] as? String, "unknown")
        XCTAssertEqual(p["med_authority"] as? String, "care_team")
    }

    func testEveryDerivedWordSatisfiesTheHygieneShape() {
        for cohort in [Glp1Cohort.onGlp1, .postGlp1, .considering, .generalWL] {
            let p = CohortIdentity.properties(
                cohortWord: CohortIdentity.cohortWord(cohort),
                route: "injection", cadence: "daily", authority: "self"
            )
            for (_, value) in p {
                if let s = value as? String {
                    XCTAssertTrue(AnalyticsHygiene.isCategoricalWord(s), s)
                }
            }
        }
    }

    func testFingerprintChangesWithIdentityAndNotWithOrder() {
        let a = CohortIdentity.properties(
            cohortWord: "on_glp1", route: "injection",
            cadence: "weeklyAnchor", authority: "self"
        )
        let b = CohortIdentity.properties(
            cohortWord: "on_glp1", route: "injection",
            cadence: "weeklyAnchor", authority: "self"
        )
        let c = CohortIdentity.properties(
            cohortWord: "on_glp1", route: "oral",
            cadence: "daily", authority: "self"
        )
        XCTAssertEqual(
            CohortIdentity.fingerprint(of: a),
            CohortIdentity.fingerprint(of: b)
        )
        XCTAssertNotEqual(
            CohortIdentity.fingerprint(of: a),
            CohortIdentity.fingerprint(of: c)
        )
    }
}
