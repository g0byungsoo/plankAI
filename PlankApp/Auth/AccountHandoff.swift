import Foundation
import CryptoKit

// MARK: - AccountHandoff (v25 §42 — THE HANDOFF ACTUALLY RUNS)
//
// THE ONE SENTENCE THIS FILE EXISTS FOR:
//
//   ▎ THE CLIENT MAY REQUEST AN OWNERSHIP TRANSITION.
//   ▎ ONLY THE SERVER MAY DECLARE IT COMPLETE.
//
// `40` retired the abandoned anonymous account with ONE best-effort call
// carrying its own access token, and said plainly that it could not be
// retried: a retry needs a bearer token this build refuses to persist.
// `41` designed the server contract that removes the dependency and
// deliberately did not write the client against it, because the contract
// had never been executed against a Postgres.
//
// It has now. `supabase/migrations/20260814120000_v25_e1_account_handoffs.sql`
// is applied, and eight corrections were found by auditing `41`'s staged
// file against the LIVE catalog first — one of them a blocker that would
// have made every single call throw (§42 [CORR-1]).
//
// ==========================================================================
// THE PROTOCOL, AND WHY EACH HALF IS WHERE IT IS
// ==========================================================================
//
//   BEGIN     while the anonymous source is STILL AUTHENTICATED, and
//             before the Apple token exchange, because afterwards no
//             credential for her will ever exist again. It pre-commits to
//             a SHA-256 of "apple:<sub>" — the destination she is about
//             to reach — and names no destination uid, because a uid the
//             client supplies is not evidence of anything.
//
//   COMPLETE  as the DESTINATION, whose credential is permanent and
//             legitimately hers. It takes NO identity at all: the server
//             computes the subjects this caller demonstrably owns from
//             its own `auth.identities` rows and acts only on receipts
//             whose pre-commitment is in that set.
//
//   ▎ SO THE PROOF IS NOT A BEARER CREDENTIAL, AND NOTHING SECRET IS
//   ▎ PERSISTED ON THIS DEVICE. A client that lies at BEGIN produces a
//   ▎ receipt nobody, including itself, can ever complete.
//
// That property is what makes it safe to read the `sub` claim locally
// rather than verifying the Apple id token against Apple's JWKS: a lie
// only locks the liar out.
//
// ==========================================================================
// APPLE ONLY, AND IT IS NOT AN OVERSIGHT
// ==========================================================================
//
// The deployed `begin_account_handoff` refuses every provider but
// `apple`, and the client must not try. The Apple `sub` arrives inside a
// token Apple SIGNED for this device after the customer authenticated.
// A typed email address is not evidence: BEGIN necessarily runs BEFORE
// the sign-in, so an email subject would be a string nobody has
// verified, and a single typo landing on another real customer's address
// would hand him her record. That is exfiltration, and it is worse than
// the injection residual the migration names. The email door keeps
// `40`'s client-side best-effort retirement. Stated as a limitation
// rather than closed with a guess.
//
// ==========================================================================
// DEGRADE, NEVER BREAK
// ==========================================================================
//
// Every call here is best-effort and CANNOT throw, cannot fail a sign-in
// and is never shown to the customer: she asked to sign in, not to
// perform a database transaction. A 404 (`PGRST202`, the function does
// not exist) means this build is talking to a project where the
// migration has not been applied — the client then behaves EXACTLY as
// build 30 does, which is the whole reason the deploy order can be
// "schema first, client second" in either order.

enum AccountHandoff {

    /// The only provider the deployed contract accepts. See the header.
    static let provider = "apple"

    // MARK: - The subject (pure)

    /// The `sub` claim of an Apple identity token, read locally and NOT
    /// verified.
    ///
    /// Not verifying is a deliberate decision, not a shortcut. The value
    /// is used for ONE thing: to pre-commit a receipt that only an
    /// account already owning that subject can ever redeem. A forged
    /// subject produces a receipt that is unredeemable by anyone,
    /// including the forger, so the client cannot gain anything by
    /// lying — and the server never trusts this value as an identity, it
    /// only matches it against subjects it computed itself.
    static func appleSubject(fromIdentityToken token: String) -> String? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return nil }
        guard let payload = base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let sub = json["sub"] as? String,
              !sub.isEmpty
        else { return nil }
        return sub
    }

    /// `sha256("apple:<sub>")`, 64 lowercase hex characters — byte for
    /// byte what `complete_account_handoff` computes server-side with
    /// `encode(sha256(convert_to('apple:' || sub, 'UTF8')), 'hex')`. If
    /// these two ever disagree, every handoff silently stops working, so
    /// the equality is pinned by a test against a known vector.
    static func subjectHash(appleSubject sub: String) -> String {
        let digest = SHA256.hash(data: Data("\(provider):\(sub)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var s = value.replacingOccurrences(of: "-", with: "+")
                     .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    // MARK: - Outcomes

    enum BeginOutcome: Equatable {
        /// A receipt exists on the server for this source and subject.
        case opened
        /// The migration is not applied on this project. Behave as
        /// build 30 does.
        case unavailable
        /// The server answered and refused. The commonest legitimate
        /// refusal is `42501` — a permanent account may not open a
        /// handoff — which is the named → named firewall working.
        case refused(status: Int)
        /// The network never answered.
        case unreachable
    }

    enum CompleteOutcome: Equatable {
        case done(moved: Int, retired: Int)
        case unavailable
        case refused(status: Int)
        case unreachable

        /// **THE ID POLICY DEPENDS ON THIS AND ON NOTHING ELSE.** When
        /// the server moved the rows it changed the OWNER and kept the
        /// ID, so the cloud row is already hers under that id and the
        /// local carry must not mint a new one.
        var movedTheRecord: Bool {
            if case .done(let moved, _) = self { return moved > 0 }
            return false
        }

        /// The source reached its terminal state server-side, so the
        /// client's own best-effort retirement has nothing left to do.
        var retiredTheSource: Bool {
            if case .done(_, let retired) = self { return retired > 0 }
            return false
        }
    }

    // MARK: - Requests (pure, so the shape is testable without a network)

    static func beginRequest(
        baseURL: URL, anonKey: String, accessToken: String, subjectHash: String
    ) -> URLRequest {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("rest/v1/rpc/begin_account_handoff")
        )
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "p_provider": provider,
            "p_subject_hash": subjectHash
        ])
        request.timeoutInterval = 8
        return request
    }

    /// **NO IDENTITY IS SENT.** Not the source, not the destination, not
    /// a receipt id. The only argument is which of the two things the
    /// client already did, so the server does not move a record the
    /// client has already carried under fresh ids.
    static func completeRequest(
        baseURL: URL, anonKey: String, accessToken: String, mode: String = "move"
    ) -> URLRequest {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("rest/v1/rpc/complete_account_handoff")
        )
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["p_mode": mode])
        request.timeoutInterval = 12
        return request
    }

    // MARK: - Classification (pure)

    static func classifyBegin(status: Int) -> BeginOutcome {
        if (200...299).contains(status) { return .opened }
        if status == 404 { return .unavailable }
        return .refused(status: status)
    }

    /// `{"moved": n, "retired": n}`. A 2xx with an unreadable body is
    /// reported as `done(0, 0)` — the server did something and this
    /// device cannot prove what, so the client keeps its receipt and
    /// keeps the CAUTIOUS id policy. Guessing `moved > 0` here would
    /// duplicate her record; guessing `moved == 0` only costs fresh ids.
    static func classifyComplete(status: Int, body: Data?) -> CompleteOutcome {
        if status == 404 { return .unavailable }
        guard (200...299).contains(status) else { return .refused(status: status) }
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return .done(moved: 0, retired: 0) }
        let moved = (json["moved"] as? Int) ?? 0
        let retired = (json["retired"] as? Int) ?? 0
        return .done(moved: moved, retired: retired)
    }

    // MARK: - The calls (never throw)

    static func begin(
        appleSubject sub: String,
        accessToken: String,
        baseURL: URL = SupabaseConfig.url,
        anonKey: String = SupabaseConfig.anonKey,
        session: URLSession = .shared
    ) async -> BeginOutcome {
        guard !sub.isEmpty, !accessToken.isEmpty else { return .unreachable }
        let request = beginRequest(
            baseURL: baseURL, anonKey: anonKey, accessToken: accessToken,
            subjectHash: subjectHash(appleSubject: sub)
        )
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unreachable }
            return classifyBegin(status: http.statusCode)
        } catch {
            return .unreachable
        }
    }

    static func complete(
        accessToken: String,
        mode: String = "move",
        baseURL: URL = SupabaseConfig.url,
        anonKey: String = SupabaseConfig.anonKey,
        session: URLSession = .shared
    ) async -> CompleteOutcome {
        guard !accessToken.isEmpty else { return .unreachable }
        let request = completeRequest(
            baseURL: baseURL, anonKey: anonKey, accessToken: accessToken, mode: mode
        )
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unreachable }
            return classifyComplete(status: http.statusCode, body: data)
        } catch {
            return .unreachable
        }
    }
}

// MARK: - HandoffIdPolicy (v25 §42)

/// **WHO MOVED THE CLOUD ROW DECIDES WHETHER THE LOCAL CARRY MAY KEEP
/// ITS ID.** This is the one thing `41` said could not be shipped before
/// the migration was verified, and it is the reason.
///
/// The client has minted fresh uuids for weight, sessions, plans, checks
/// and food since v1.1 for a precise reason: the cloud row still belonged
/// to the OLD uid, so a same-id upsert resolved to an UPDATE that RLS
/// rejected with a silent 42501, and the row lived only on the device.
///
/// After `complete_account_handoff(mode: 'move')` that reason is gone —
/// the server changed the owner and kept the id — and the old behaviour
/// becomes the bug: every local row would be pushed under a NEW id
/// alongside the server's copy of the SAME record.
///
///   ▎ MINTING A FRESH ID AFTER A SERVER MOVE DUPLICATES HER ENTIRE
///   ▎ RECORD. KEEPING ONE WITHOUT A SERVER MOVE STRANDS IT.
///
/// Deterministic ids (dose · symptom · weekly read) and composite keys
/// (day progress · calibration) are NOT affected: the uid is inside the
/// key, so both sides always rewrite them by the same prefix swap.
enum HandoffIdPolicy: String, Equatable {

    /// The legacy path. The server did not move anything, so the cloud
    /// rows still answer to the outgoing uid.
    case mintFresh

    /// The server moved them, ids intact. The local rows only need to
    /// answer to the new uid.
    case preserve

    /// **Under `.preserve` the SERVER holds the authoritative copy**, so
    /// the carry must not queue a push. If it did, a device that has not
    /// yet hydrated the destination's own plans would push A's plan back
    /// as live and undo the archive the server just performed — two live
    /// plans, which is the one state this whole line of work forbids.
    /// Leaving the rows clean lets `ProgramPlanMerge` adopt the server's
    /// answer, which is the correct one by construction.
    var queuesAPush: Bool { self == .mintFresh }
}
