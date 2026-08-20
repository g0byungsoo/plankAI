import Foundation

// MARK: - SyncFailureClassifier / SyncHealth (v25 §45)
//
// ▎ A REFUSAL THE SERVER WILL GIVE AGAIN IS NEWS.
// ▎ A CONNECTION THAT DROPPED IS NOT.
//
// `44` found that `public.program_facts` and `public.weekly_reads` held
// zero rows because `authenticated` had no privileges on either. The
// grant was one defect. The reason it survived five passes was a
// SECOND one, and this file is that one's whole fix:
//
//   · every spine write is fire-and-forget inside a `try?`;
//   · every spine hydrate's `catch` body is `#if DEBUG print(...)`.
//
// So a server that answered `42501 · permission denied` to four calls
// per launch, for 4,293 accounts, for five days, produced exactly zero
// evidence anywhere a human would look. No number moved, no screen
// changed, no test failed.
//
// THE REQUIREMENT IS THE BEHAVIOUR, NOT THE MECHANISM. What must be
// true: a permission / schema / authorization failure on an
// account-durable family is distinguishable from being offline in a
// lift, with no customer-facing database string, no crash, no
// fabricated success, no retry storm, and no DEBUG-only disappearance.
//
// What that costs here: a pure classifier, a once-per-day bound, and
// one event in the analytics vocabulary the hygiene registry already
// governs. No error framework, no new UI, no new state machine.
//
// **THE POLARITY IS DELIBERATE.** Silence is granted only to codes
// POSITIVELY IDENTIFIED as transient; anything unrecognised is
// reported. `42501` was an unrecognised code once, and the default of
// assuming harmlessness is the exact habit that lost five passes.

enum SyncFailureClassifier {

    enum Verdict: String, CaseIterable {
        /// SQLSTATE 42501. Postgres uses it BOTH for "the role has no
        /// privilege on this table" and for "row-level security refused
        /// this row" — they differ only in the message, and the message
        /// is not ours to ship. Both are permanent for the request as
        /// made, which is all the caller needs to know.
        case permissionDenied   = "permission_denied"
        /// The client and the database disagree about the shape of the
        /// world: an unapplied migration, a renamed column, a stale
        /// PostgREST schema cache, a missing RPC.
        case schemaMismatch     = "schema_mismatch"
        /// The bearer token is absent, expired or not accepted. Fixed
        /// by re-authenticating, never by repeating the request.
        case authorization      = "authorization"
        /// A CHECK / UNIQUE / FOREIGN KEY the client's row violated. It
        /// will be refused identically forever — a write that can never
        /// land, which `pendingUpsert` will otherwise retry for the
        /// life of the install.
        case constraintRejected = "constraint_rejected"
        /// Not recognised. REPORTED, not assumed harmless.
        case unclassified       = "unclassified"
        /// Positively identified as temporary. Silent, because
        /// `pendingUpsert` already carries the row to the next launch
        /// and a phone in a lift is the normal case.
        case transient          = "transient"

        var isStructural: Bool { self != .transient }
    }

    /// Codes that mean "try again later", and nothing else does.
    /// `urlerror` is this client's own token for any `URLError`
    /// (offline, DNS, timeout, connection lost). The rest are the
    /// Postgres connection-exception class, the resource-limit class,
    /// the cancellation/serialization codes, and PostgREST's two
    /// "cannot reach the database" codes.
    private static let transientCodes: Set<String> = [
        "urlerror",
        "PGRST001", "PGRST002",
        "08000", "08003", "08006", "08P01",
        "53300", "53400",
        "57014",
        "40001", "40P01",
    ]

    private static let schemaCodes: Set<String> = [
        "42P01",      // undefined table
        "42703",      // undefined column
        "42883",      // undefined function
        "PGRST202",   // function not found in schema cache
        "PGRST204",   // column not found in schema cache
        "PGRST205",   // table not found in schema cache
        "PGRST106",   // schema is not exposed
    ]

    private static let authorizationCodes: Set<String> = [
        "PGRST301",   // JWT expired / invalid
        "PGRST302",   // anonymous access to a protected resource
    ]

    static func verdict(forCode code: String) -> Verdict {
        if transientCodes.contains(code) { return .transient }
        if code == "42501" { return .permissionDenied }
        if schemaCodes.contains(code) { return .schemaMismatch }
        if authorizationCodes.contains(code) { return .authorization }
        // Postgres class 23 — integrity constraint violation.
        if code.count == 5, code.hasPrefix("23") { return .constraintRejected }
        return .unclassified
    }
}

enum SyncHealth {

    /// Families this pass wires. Deliberately the two the pass is
    /// scoped to: `45`'s brief forbids expanding into a generic sync
    /// framework, and a vocabulary that names families it does not
    /// report would be a false contract.
    static let programFacts = "program_facts"
    static let weeklyReads  = "weekly_reads"
    static let families: Set<String> = [programFacts, weeklyReads]

    /// One event per (family, reason) per calendar day per install.
    /// Two hundred failing launches in a day are one event, not two
    /// hundred; a new day re-reports, because "still broken today" is
    /// the fact the founder actually needs.
    ///
    /// The stamp is device diagnostics, not customer content, so it is
    /// deliberately NOT in `clearOnboardingUserDefaults` — a sign-out
    /// that reset the bound would let the same failure speak again for
    /// every identity on the phone.
    @discardableResult
    static func report(
        family: String,
        code: String,
        now: Date = .now,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let verdict = SyncFailureClassifier.verdict(forCode: code)
        guard verdict.isStructural else { return false }

        let key = "sync.health.\(family).\(verdict.rawValue)"
        let day = dayKey(now)
        guard defaults.string(forKey: key) != day else { return false }
        defaults.set(day, forKey: key)

        Analytics.track(
            .syncStructuralFailure,
            properties: properties(family: family, code: code)
        )
        return true
    }

    /// CATEGORICAL ONLY. PostgREST's 42501 body carries a `hint` that
    /// names the table and prints the exact `GRANT` to run, and a
    /// `message` that names the table too. Useful to a developer with a
    /// debugger attached; not ours to hand to an analytics vendor. The
    /// SQLSTATE itself is a five-character machine token and travels.
    static func properties(family: String, code: String) -> [String: Any] {
        [
            "family": family,
            "reason": SyncFailureClassifier.verdict(forCode: code).rawValue,
            "code": safeCode(code),
        ]
    }

    /// A code of an unexpected shape never becomes a payload: the
    /// vocabulary is the app's, not the server's. SQLSTATE is five
    /// alphanumerics; PostgREST's are `PGRSTnnn`; this client's own
    /// tokens are lowercase words.
    private static func safeCode(_ code: String) -> String {
        let ok = (5...9).contains(code.count)
            && code.allSatisfy { $0.isLetter || $0.isNumber }
        return ok ? code : "other"
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.timeZone = Calendar.current.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
