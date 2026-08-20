import XCTest
@testable import plankAI

// MARK: - SpineSyncHealthTests (v25 §45 — MAKE THE SPINE REAL)
//
// `44` found that E1's two families had never once reached the server
// and that NOTHING ANYWHERE REPORTED IT: every write is fire-and-forget
// inside a `try?`, and every hydrate's `catch` only prints under DEBUG.
// The grant was one defect. **A structural server refusal that can only
// be seen by attaching a debugger is a second one**, and it is the
// reason the first survived five passes.
//
// The rule these tests pin:
//
//   A REFUSAL THE SERVER WILL GIVE AGAIN IS NEWS. A CONNECTION THAT
//   DROPPED IS NOT.
//
// So the polarity is deliberate: silence is granted only to codes
// POSITIVELY IDENTIFIED as transient. Everything else — including a
// code nobody has seen before — is reported, because the alternative is
// exactly what happened on 2026-08-10.
//
// No new error framework, no customer-facing string, no crash: one pure
// classifier, one bounded once-per-day report through the analytics
// vocabulary the hygiene registry already governs.

final class SpineSyncHealthTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SpineSyncHealthTests"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func day(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f.date(from: iso)!
    }

    // MARK: - The classifier

    /// THE EXACT CODE THE SPINE RETURNED FOR FIVE DAYS. It is not a
    /// network problem, it will be identical on every retry forever, and
    /// it must never be silent.
    func testPermissionDeniedIsStructural() {
        let v = SyncFailureClassifier.verdict(forCode: "42501")
        XCTAssertEqual(v, .permissionDenied)
        XCTAssertTrue(v.isStructural)
    }

    /// The client and the schema disagree: an un-applied migration, a
    /// renamed column, a stale PostgREST schema cache. Also permanent.
    func testSchemaMismatchIsStructural() {
        for code in ["42P01", "42703", "PGRST204", "PGRST205", "PGRST202"] {
            let v = SyncFailureClassifier.verdict(forCode: code)
            XCTAssertEqual(v, .schemaMismatch, "\(code)")
            XCTAssertTrue(v.isStructural, "\(code)")
        }
    }

    /// An expired or absent bearer token. Recoverable by re-auth, never
    /// by retrying the same request — so it is news too.
    func testAuthorizationIsStructural() {
        for code in ["PGRST301", "PGRST302"] {
            let v = SyncFailureClassifier.verdict(forCode: code)
            XCTAssertEqual(v, .authorization, "\(code)")
            XCTAssertTrue(v.isStructural, "\(code)")
        }
    }

    /// A CHECK / UNIQUE / FK the client violated. The row will be
    /// refused identically every time it is retried, which is the
    /// definition of a write that will never land.
    func testConstraintRejectionIsStructural() {
        for code in ["23514", "23505", "23503"] {
            XCTAssertEqual(SyncFailureClassifier.verdict(forCode: code), .constraintRejected, code)
        }
    }

    /// THE CONTROL, and the half that must stay quiet. Being offline in
    /// a lift is the normal case for a phone; `pendingUpsert` already
    /// carries the row to the next launch. Reporting it would be the
    /// retry storm this pass is forbidden to create.
    func testTransientCodesAreSilent() {
        for code in ["urlerror", "PGRST001", "PGRST002",
                     "08000", "08003", "08006", "08P01",
                     "53300", "53400", "57014", "40001", "40P01"] {
            let v = SyncFailureClassifier.verdict(forCode: code)
            XCTAssertEqual(v, .transient, code)
            XCTAssertFalse(v.isStructural, code)
        }
    }

    /// The polarity. A code nobody has classified is REPORTED, not
    /// assumed harmless — `42501` was an unknown code once.
    func testAnUnrecognisedCodeIsReportedNotAssumedTransient() {
        let v = SyncFailureClassifier.verdict(forCode: "XX999")
        XCTAssertEqual(v, .unclassified)
        XCTAssertTrue(v.isStructural)
    }

    // MARK: - The bounded report

    func testATransientFailureReportsNothing() {
        XCTAssertFalse(SyncHealth.report(
            family: "program_facts", code: "urlerror",
            now: day("2026-08-15 09:00"), defaults: defaults
        ))
    }

    /// Once per family per reason per day. Two hundred failing launches
    /// in one day are one event, not two hundred.
    func testAStructuralFailureReportsOncePerDay() {
        XCTAssertTrue(SyncHealth.report(
            family: "program_facts", code: "42501",
            now: day("2026-08-15 09:00"), defaults: defaults
        ))
        XCTAssertFalse(SyncHealth.report(
            family: "program_facts", code: "42501",
            now: day("2026-08-15 09:01"), defaults: defaults
        ))
        XCTAssertFalse(SyncHealth.report(
            family: "program_facts", code: "42501",
            now: day("2026-08-15 23:59"), defaults: defaults
        ))
        // A new day is a new fact: it is still broken TODAY.
        XCTAssertTrue(SyncHealth.report(
            family: "program_facts", code: "42501",
            now: day("2026-08-16 00:01"), defaults: defaults
        ))
    }

    /// The two spine families are separate news. `weekly_reads` failing
    /// must not be hidden by `program_facts` having already spoken.
    func testEachFamilyAndEachReasonSpeaksForItself() {
        XCTAssertTrue(SyncHealth.report(
            family: "program_facts", code: "42501",
            now: day("2026-08-15 09:00"), defaults: defaults
        ))
        XCTAssertTrue(SyncHealth.report(
            family: "weekly_reads", code: "42501",
            now: day("2026-08-15 09:00"), defaults: defaults
        ))
        XCTAssertTrue(SyncHealth.report(
            family: "program_facts", code: "PGRST204",
            now: day("2026-08-15 09:00"), defaults: defaults
        ))
    }

    /// NOTHING THE SERVER SAID IN PROSE MAY TRAVEL. PostgREST's 42501
    /// body carries a `hint` that names the table and the exact GRANT,
    /// and its `message` names the table too — useful to a developer,
    /// and not ours to ship to an analytics vendor.
    func testThePayloadIsCategoricalOnly() {
        let props = SyncHealth.properties(family: "program_facts", code: "42501")
        XCTAssertEqual(props["family"] as? String, "program_facts")
        XCTAssertEqual(props["reason"] as? String, "permission_denied")
        XCTAssertEqual(props["code"] as? String, "42501")
        XCTAssertEqual(props.count, 3)
        XCTAssertTrue(
            AnalyticsHygiene.violations(
                event: AnalyticsEvent.syncStructuralFailure.rawValue,
                properties: props
            ).isEmpty
        )
    }

    /// A code of an unexpected shape never becomes a payload. The
    /// vocabulary is the app's, not the server's.
    func testAMalformedCodeIsFlattened() {
        let props = SyncHealth.properties(
            family: "program_facts",
            code: "permission denied for table program_facts"
        )
        XCTAssertEqual(props["code"] as? String, "other")
        XCTAssertTrue(
            AnalyticsHygiene.violations(
                event: AnalyticsEvent.syncStructuralFailure.rawValue,
                properties: props
            ).isEmpty
        )
    }

    /// The registry cannot drift behind the classifier — the same pin
    /// `AnalyticsHygieneTests` puts on the method + food vocabularies.
    func testTheHygieneRegistryKnowsEveryReason() {
        let rule = AnalyticsHygiene.rules[AnalyticsEvent.syncStructuralFailure.rawValue]
        XCTAssertNotNil(rule)
        let vocabulary = rule?.words["reason"] ?? []
        for verdict in SyncFailureClassifier.Verdict.allCases where verdict.isStructural {
            XCTAssertTrue(
                vocabulary.contains(verdict.rawValue),
                "reason '\(verdict.rawValue)' is not in the hygiene vocabulary"
            )
        }
    }
}
