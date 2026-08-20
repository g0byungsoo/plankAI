import Foundation

// MARK: - AnonymousAccountRetirement (v25 §40 — THE LAST ORPHAN)
//
// WHAT `39` FIXED, AND THE HOLE IT LEFT.
//
// `39` stopped the orphan factory for the case that makes 559 of them:
// an anonymous customer signing in with a BRAND-NEW Apple identity now
// LINKS, so the uid never splits. That is the right fix and it is not
// in question here.
//
// Its fallback is. Every link failure falls back to today's exact call,
// deliberately and without inspecting the error — and GoTrue refuses the
// link with `identity_already_exists` in the single most common
// non-first-time case there is:
//
//   ▎ SHE ALREADY HAS A JENI ACCOUNT UNDER THIS APPLE ID.
//   ▎ (a reinstall · a second phone · a returning customer)
//
// Read from the GoTrue source rather than inferred
// (`internal/api/identity.go`, `linkIdentityToUser`):
//
//     if identity != nil {
//         if identity.UserID == targetUser.ID {
//             return … ErrorCodeIdentityAlreadyExists, "Identity is already linked"
//         }
//         return … ErrorCodeIdentityAlreadyExists, "Identity is already linked to another user"
//     }
//
// TWO OPPOSITE SITUATIONS, ONE ERROR CODE. The first is harmless (the
// identity is already on this very uid, so the fallback lands back on
// the same account). The second abandons the anonymous uid this device
// is holding — with everything she recorded before she tapped the
// button still under it, on the server, forever.
//
// ▎ SO THE FALLBACK REINTRODUCES THE P0 — for every RETURNING customer
// ▎ instead of every NEW one.
//
// WHY THE ERROR IS NOT THE SIGNAL. The two cases share an error code and
// differ only by an English sentence, and a 5xx or an offline link
// followed by a successful sign-in abandons the uid just as completely
// with no error to read at all. The reliable signal is the OUTCOME:
//
//   ▎ THE ANONYMOUS UID WAS ABANDONED IF, AFTER THE SIGN-IN, THE
//   ▎ SESSION NAMES A DIFFERENT ACCOUNT.
//
// WHAT TO DO ABOUT IT, AND WHY IT IS THIS.
//
// `39` §4 proved that an orphan, once created, can never be associated
// back to anyone: nothing anywhere records that uid A became uid B. But
// there is exactly ONE INSTANT at which the association is not lost —
// the instant of the switch, on this device, while the outgoing
// anonymous access token is still in memory. That is the only moment a
// credential for A will ever exist again.
//
// So the anonymous account is RETIRED there: one call to the shipping
// `delete_user_account()` RPC, carrying A's own token.
//
// WHY THIS DESTROYS NOTHING.
//
//   1. An anonymous uid is minted by THIS install and can never be
//      signed back into by anyone, on any device, ever. It has no
//      password, no email, no identity row.
//   2. Every server row under A was pushed FROM this device, so the
//      local store is a superset of it.
//   3. The shipping sign-in merge (`AppSync.onAuthChanged` →
//      `reattributeLocalRows`) re-keys those local rows to B with fresh
//      ids and marks them `pendingUpsert`, so they are re-uploaded under
//      the account she just reached. Her record MOVES; only the
//      unreachable copy goes.
//   4. The RPC is `SECURITY DEFINER` scoped to `auth.uid()`, so the
//      token decides the victim. A token for A can only ever delete A.
//
// WHY IT CANNOT BE RETRIED, STATED RATHER THAN DRESSED UP.
//
// A retry needs a credential, and the only credential is a bearer token
// we refuse to persist — writing an access token to `UserDefaults` to
// make a cleanup retryable would be a worse defect than the one it
// fixes. So this is ONE best-effort attempt at the one moment it is
// possible. If it fails, the outcome is exactly today's: an orphan.
// It is never worse than shipping nothing, which is the same property
// that let `39` touch this path at all.

enum AnonymousRetirementDecision: Equatable {
    /// The outgoing anonymous account was abandoned by this sign-in and
    /// a credential for it is still in hand. Retire it.
    case retire(uid: String)
    /// Leave it alone, and say exactly why.
    case leave(LeaveReason)

    enum LeaveReason: Equatable {
        /// The outgoing session was a NAMED account. Deleting a named
        /// account she can still sign back into would be catastrophic,
        /// and it is not what this mechanism is for.
        case outgoingWasNotAnonymous
        /// The sign-in landed on the SAME uid — which is the success
        /// case: the identity linked, or was already linked here.
        case sameAccount
        /// No outgoing uid, or no token to speak with. Nothing can be
        /// proven and nothing may be deleted on a guess.
        case noCredential
        /// v25 §41 — this device holds no row for the outgoing account,
        /// so it cannot prove it is carrying her record. See
        /// `SourceRetirementSafety`.
        case nothingToCarry
    }
}

// MARK: - SourceRetirementSafety (v25 §41 — [CORR] on §40 §3.4)
//
// `40` §3.4 gave four reasons retiring the abandoned anonymous account
// destroys nothing, and reason 2 was stated as a fact:
//
//   > Every server row under A was pushed FROM this device, so the
//   > local store is a superset of it.
//
// **IT IS NOT, IN ONE REACHABLE STATE.** The Supabase session lives in
// the Keychain, which survives deleting the app, so a reinstall can
// re-adopt the SAME anonymous uid with an EMPTY local store. The launch
// hydrate normally repairs that — `shouldHydrateOnLaunch` fires exactly
// when a synced family is empty — but it is a network call, and it can
// fail. If she signs in during that window, the local store holds
// nothing to carry and the retirement deletes the only copy of her
// record that exists anywhere.
//
//   ▎ A HANDOFF MAY ONLY RETIRE AN ACCOUNT WHOSE RECORD THIS DEVICE IS
//   ▎ ACTUALLY CARRYING.
//
// The guard is one count and it costs nothing to be wrong about in the
// safe direction: an anonymous account with zero local rows is either
// genuinely empty — in which case retiring it removes nothing and
// leaving it costs an `auth.users` row with no data, the shape 1,242 of
// the 3,425 anonymous accounts already have — or it is a record this
// device has not seen, in which case retiring it is data loss. The two
// are indistinguishable from here, so the trade is: **never delete what
// you are not carrying; accept an empty identity row.**
enum SourceRetirementSafety {

    /// `false` refuses the retirement. The customer sees nothing either
    /// way: she asked to sign in, not to clean up.
    static func mayRetire(sourceLocalRowCount: Int) -> Bool {
        sourceLocalRowCount > 0
    }
}

enum AnonymousRetirementPolicy {

    /// Pure. Decides ONLY from what is knowable at the switch.
    ///
    /// The `outgoingWasAnonymous` gate is the load-bearing one and it is
    /// checked first: this function must be incapable of nominating a
    /// named account, whatever else is true.
    static func decide(
        outgoingUid: String?,
        outgoingWasAnonymous: Bool,
        outgoingAccessToken: String?,
        incomingUid: String
    ) -> AnonymousRetirementDecision {
        guard outgoingWasAnonymous else { return .leave(.outgoingWasNotAnonymous) }
        guard let outgoingUid, !outgoingUid.isEmpty,
              let token = outgoingAccessToken, !token.isEmpty,
              !incomingUid.isEmpty
        else { return .leave(.noCredential) }
        guard outgoingUid.caseInsensitiveCompare(incomingUid) != .orderedSame else {
            return .leave(.sameAccount)
        }
        return .retire(uid: outgoingUid)
    }
}

// MARK: - The call

enum AnonymousAccountRetirement {

    /// What the one attempt achieved. Never surfaced to the customer:
    /// she asked to sign in, not to clean up, and a failure here changes
    /// nothing she can see.
    enum Outcome: Equatable {
        /// The server confirmed. No orphan was created.
        case retired
        /// The server answered, and the answer was not success. The
        /// orphan stands — today's behaviour.
        case refused(status: Int)
        /// The server never answered. The orphan stands.
        case unreachable
        /// The policy said leave it.
        case skipped(AnonymousRetirementDecision.LeaveReason)
    }

    /// PostgREST returns 204 for a void RPC and 200 when it echoes.
    /// Everything else means the row is still there as far as this
    /// device can prove, and proving is the whole point.
    static func classify(status: Int) -> Outcome {
        (200...299).contains(status) ? .retired : .refused(status: status)
    }

    /// Pure request builder, so the shape is testable without a network
    /// or an account. The token is the OUTGOING one and is passed
    /// explicitly for exactly one reason: the shared client's session
    /// belongs to the INCOMING account by the time this runs, and using
    /// it would delete the account she just signed into.
    static func request(baseURL: URL, anonKey: String, accessToken: String) -> URLRequest {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("rest/v1/rpc/delete_user_account")
        )
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 8
        return request
    }

    /// One attempt, bounded, never throwing. The customer is already
    /// waiting on a sign-in round trip; this adds at most one more and
    /// cannot fail her sign-in, because there is no path here that
    /// returns anything the caller acts on.
    static func retire(
        accessToken: String,
        baseURL: URL = SupabaseConfig.url,
        anonKey: String = SupabaseConfig.anonKey,
        session: URLSession = .shared
    ) async -> Outcome {
        let request = request(baseURL: baseURL, anonKey: anonKey, accessToken: accessToken)
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unreachable }
            return classify(status: http.statusCode)
        } catch {
            return .unreachable
        }
    }
}
