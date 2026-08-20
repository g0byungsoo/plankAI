import Foundation

// MARK: - AccountOperation (v25 §41 — THE HANDOFF)
//
// THE DEFECT THIS TYPE EXISTS TO REMOVE.
//
// Three different things have been sharing one condition for the whole
// life of this product:
//
//   · UPGRADE IDENTITY   anonymous A → permanent A.   SAME uid.
//   · ADOPT              anonymous A → permanent B.   Different uid,
//                        and an explicit ownership transfer.
//   · SWITCH ACCOUNT     permanent A → permanent B.   Different uid,
//                        and ZERO ownership transfer.
//
// `AppSync.onAuthChanged` decided between them with `userIdChanged &&
// !isAnonNow`, which is the forbidden inference:
//
//   ▎ oldUid != newUid  ⇒  MERGE
//
// It is forbidden because it is not evidence of anything. A uid change
// is the one fact all three share. `40` closed the worst consequence by
// adding `previousMethod == .anonymous` to that condition — the right
// fix — but the condition still lives inside an async, view-driven
// function beside four other concerns, and nothing names the three
// operations or says what each one is allowed to do.
//
// ▎ THE RULE: A HANDOFF NEEDS POSITIVE PROOF THAT THE SOURCE WAS
// ▎ ANONYMOUS. Not a different uid, not a missing profile, not a fresh
// ▎ account, not the absence of an Apple identity. `AuthMethod
// ▎ .anonymous` is the only value that is proof, and `.unknown` is not
// ▎ a weaker form of it — it is the absence of proof, so it classifies
// ▎ as a SWITCH, which is the outcome that moves nothing.
//
// Pure and nonisolated, so the rule is a sentence a test can read
// rather than a condition buried in a body (`36` §2).

enum AccountOperation: Equatable {

    /// Nothing about the identity moved.
    case none

    /// **OPERATION A — UPGRADE IDENTITY.** The anonymous account she is
    /// already holding became permanent. Same uid, so there is nothing
    /// to transfer, nothing to re-key, nothing to retire and no receipt
    /// to write. This path must be boring.
    case upgradeIdentity(uid: String)

    /// **OPERATION B — ADOPT.** The anonymous period on this device
    /// moves into a permanent account she reached. Different uid, so
    /// this is the one operation that transfers ownership — and the one
    /// that leaves a source identity needing an explicit terminal state.
    case adopt(source: String, destination: String)

    /// **OPERATION C — SWITCH ACCOUNT.** One permanent account to
    /// another on the same phone. **NEVER a data migration.** The
    /// outgoing account's local visibility is cleared under the existing
    /// cross-account isolation contract and the incoming account
    /// hydrates its own record.
    case switchAccount(source: String, destination: String)

    /// She signed out (or the SDK re-anonymised the session). Local data
    /// is preserved by contract; the sweep is the sign-out path's own.
    case signOut(source: String, destination: String)

    // MARK: What each operation is ALLOWED to do

    /// Only ADOPT carries the anonymous period. Stated as a property so
    /// no call site can re-derive it from a uid comparison.
    var carriesTheAnonymousPeriod: Bool {
        if case .adopt = self { return true }
        return false
    }

    /// Only a SWITCH clears the outgoing account's device-local
    /// visibility. An UPGRADE must not (it is the same person AND the
    /// same account) and an ADOPT must not (it is the same person).
    var isolatesTheOutgoingAccount: Bool {
        if case .switchAccount = self { return true }
        return false
    }

    /// Only ADOPT can leave a source identity that no credential will
    /// ever name again. A permanent account is never nominated, whatever
    /// else is true.
    var mayRetireTheSource: Bool {
        if case .adopt = self { return true }
        return false
    }

    var source: String? {
        switch self {
        case .none: return nil
        case .upgradeIdentity(let uid): return uid
        case .adopt(let source, _), .switchAccount(let source, _), .signOut(let source, _):
            return source
        }
    }

    var destination: String? {
        switch self {
        case .none: return nil
        case .upgradeIdentity(let uid): return uid
        case .adopt(_, let destination), .switchAccount(_, let destination),
             .signOut(_, let destination):
            return destination
        }
    }
}

enum AccountOperationClassifier {

    /// The whole rule, in one place, from four facts the auth layer
    /// already has at the instant the session moves.
    ///
    /// `previousMethod` is the load-bearing input and it is used
    /// POSITIVELY: `.anonymous` is proof the source was anonymous, and
    /// nothing else is. `.unknown` — which `40` §0 finding 4 showed a
    /// just-linked Apple customer can genuinely read — is treated as a
    /// permanent account, because the safe direction for an unproven
    /// source is the operation that moves nothing.
    static func classify(
        previousUid: String?,
        previousMethod: AuthMethod,
        newUid: String,
        newIsAnonymous: Bool
    ) -> AccountOperation {
        guard !newUid.isEmpty else { return .none }
        guard let previousUid, !previousUid.isEmpty else { return .none }

        let sameAccount = previousUid.caseInsensitiveCompare(newUid) == .orderedSame

        if sameAccount {
            // The uid did not move. The only interesting case is the
            // identity becoming permanent in place, and it transfers
            // nothing by construction.
            if previousMethod == .anonymous && !newIsAnonymous {
                return .upgradeIdentity(uid: newUid)
            }
            return .none
        }

        if newIsAnonymous {
            return .signOut(source: previousUid, destination: newUid)
        }

        // A different uid, and the incoming account is permanent. The
        // ONLY thing that separates a handoff from an account switch is
        // whether the OUTGOING session was provably anonymous.
        if previousMethod == .anonymous {
            return .adopt(source: previousUid, destination: newUid)
        }
        return .switchAccount(source: previousUid, destination: newUid)
    }
}
