import XCTest
import PlankFood
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

    // MARK: - v25 E8 — the food family

    func testRegistryCoversTheFoodFamilyE8Touched() {
        for event: AnalyticsEvent in [.foodLogSaved, .foodScanStarted, .foodScanCompleted] {
            XCTAssertNotNil(
                AnalyticsHygiene.rules[event.rawValue],
                "\(event.rawValue) has no hygiene rule"
            )
        }
    }

    /// The registry's entry-method vocabulary must equal PlankFood's
    /// enum. If a future input mode adds a case and forgets this list,
    /// its logs would be REFUSED in debug — which is the loud failure
    /// we want, but only if this test says why.
    func testEntryMethodVocabularyMatchesTheEnum() {
        let fromEnum = Set(EntryMethod.allCases.map(\.rawValue))
        XCTAssertEqual(
            AnalyticsHygiene.entryMethodWords, fromEnum,
            "AnalyticsHygiene.entryMethodWords has drifted from EntryMethod"
        )
    }

    /// The real payloads the three touched call sites now send.
    func testE8FoodPayloadsPass() {
        let clean: [(AnalyticsEvent, [String: Any])] = [
            // the words door (E7's headline, uninstrumented until E8)
            (.foodScanStarted, ["mode": "words"]),
            (.foodScanCompleted, ["mode": "words", "items_count": 2]),
            // E8.1 — `source` and `entry_method` are the same vocabulary
            // now, so a words log says words in both.
            (.foodLogSaved, [
                "items_count": 2, "source": "words", "entry_method": "words",
            ]),
            // the older sites, unchanged shapes
            (.foodScanStarted, ["mode": "barcode"]),
            (.foodScanCompleted, [
                "items_count": 1, "source": "barcode", "mode": "barcode",
            ]),
            (.foodScanCompleted, [
                "items_count": 3, "has_restaurant_range": false, "mode": "label",
            ]),
            (.foodScanCompleted, [
                "items_count": 3, "has_restaurant_range": true,
                "mode": "library", "source": "library",
            ]),
            // the again door, which fired no save event at all from the
            // chooser until E8.1 moved it into the persister
            (.foodLogSaved, [
                "items_count": 3, "source": "again", "entry_method": "again",
            ]),
        ]
        for (event, props) in clean {
            XCTAssertEqual(
                AnalyticsHygiene.violations(event: event.rawValue, properties: props), [],
                "\(event.rawValue) \(props) should pass"
            )
        }
    }

    /// A typo in the mode word would read as "the words door was never
    /// used" rather than failing — so it must fail.
    func testMisspelledModeIsRefused() {
        XCTAssertFalse(
            AnalyticsHygiene.violations(
                event: AnalyticsEvent.foodScanStarted.rawValue,
                properties: ["mode": "word"]
            ).isEmpty
        )
    }

    /// The payload must never be able to carry what was eaten.
    func testFoodLogSavedRefusesFreeText() {
        XCTAssertFalse(
            AnalyticsHygiene.violations(
                event: AnalyticsEvent.foodLogSaved.rawValue,
                properties: ["items_count": 1, "source": "photo",
                             "entry_method": "words",
                             "description": "two slices of pepperoni pizza"]
            ).isEmpty,
            "an unregistered free-text key must be refused"
        )
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

    // MARK: - p61: the nutrition telemetry joins the mechanism

    /// The payloads that used to fire straight at PostHogSDK from
    /// inside the package (with item names aboard) now pass the same
    /// gate as everything else — numbers, categorical words, and
    /// arrays of categorical words.
    func testNutritionTelemetryShapesPass() {
        let clean: [(String, [String: Any])] = [
            ("nutrition_lookup_completed",
             ["search_terms_count": 3,
              "attempted_sources": ["usda_fdc", "open_food_facts"],
              "duration_ms": 412]),
            ("nutrition_density_resolved",
             ["search_terms_count": 3,
              "attempted_sources": ["usda_fdc"],
              "duration_ms": 380, "source": "usda_fdc",
              "kcal_per_100g": 165.5]),
            ("nutrition_calibration_overrode",
             ["confidence": 0.42, "llm_kcal": 900, "usda_kcal": 310,
              "drift_pct": 65, "usda_source": "usda_override"]),
            ("food_log_save_failed", ["source": "photo"]),
        ]
        for (event, payload) in clean {
            let v = AnalyticsHygiene.violations(event: event, properties: payload)
            XCTAssertTrue(v.isEmpty, "\(event): \(v)")
        }
    }

    /// An array element that is prose still fails — the array gate
    /// applies the word rule per element.
    func testAnArrayOfProseIsRefused() {
        let v = AnalyticsHygiene.violations(
            event: "nutrition_lookup_completed",
            properties: ["attempted_sources": ["two slices of pizza"],
                         "search_terms_count": 1, "duration_ms": 10]
        )
        XCTAssertFalse(v.isEmpty)
    }

    /// A stated words-submit is a registered Bool, and a food NAME on
    /// the same event is still refused.
    func testStatedFlagPassesAndAFoodNameStillFails() {
        XCTAssertTrue(
            AnalyticsHygiene.violations(
                event: AnalyticsEvent.foodScanCompleted.rawValue,
                properties: ["mode": "words", "items_count": 1, "stated": true]
            ).isEmpty
        )
        XCTAssertFalse(
            AnalyticsHygiene.violations(
                event: AnalyticsEvent.foodScanCompleted.rawValue,
                properties: ["mode": "words", "item_name": "protein bar"]
            ).isEmpty
        )
    }
}
