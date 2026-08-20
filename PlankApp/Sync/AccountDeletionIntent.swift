import Foundation

// MARK: - AccountDeletionError

enum AccountDeletionError: LocalizedError {
    /// The RPC neither succeeded nor definitively rejected us, so the
    /// server's state is unknown and nothing local may be destroyed.
    case serverDidNotConfirm

    var errorDescription: String? {
        "The server didn't confirm the deletion."
    }
}

// MARK: - AccountDeletionVerdict (v25 §39)
//
// THE DEFECT: `deleteCurrentAccount` is two steps — the server RPC,
// then the local purge — with nothing between them that survives a
// crash, and a single `catch` that aborts the whole thing.
//
// So the operation converges toward ROLLBACK, and in one case toward a
// lie:
//
//   * The RPC succeeds and the response is lost (timeout, radio drop,
//     backgrounded). `deleteAccount()` throws, the local cleanup is
//     skipped entirely, and the sheet says *"Couldn't delete account.
//     Try again."* Her SERVER data is already gone. She taps again —
//     but the SDK has since dropped the dead session and bootstrapped a
//     FRESH ANONYMOUS uid, so the second RPC deletes that empty account
//     and returns success, and the sheet says **"account deleted."**
//     while every weigh-in, plate and workout from the real account is
//     still on the disk and in every backup taken afterwards.
//
// ▎ DELETION MUST CONVERGE TOWARD DELETION, NEVER TOWARD ROLLBACK —
// ▎ AND NEVER TOWARD A SCREEN THAT CLAIMS MORE THAN HAPPENED.
//
// The verdict is what makes that possible: it separates "the server is
// done with this account" from "I do not know what the server did".

enum AccountDeletionVerdict: Equatable {
    /// The account is gone server-side, or is unreachable because it is
    /// gone. The local purge is owed and must run.
    case serverComplete
    /// The server's state is unknown. The local purge must NOT run:
    /// destroying the only copy she can still reach, while the server
    /// keeps its own, is strictly worse than not starting.
    case retryable

    /// The screen may only say "account deleted." for the first.
    var isSafeToReportAsDeleted: Bool { self == .serverComplete }

    /// `nil` means the RPC returned. Everything else is classified
    /// through `AuthService.classifyVerifyFailure`, the seam that
    /// already decides this exact question for session restore and is
    /// already pinned by `AuthVerifyClassificationTests` — a DEFINITIVE
    /// rejection (user_not_found, session gone, 401/403) means the
    /// credential names an account that no longer exists.
    ///
    /// Everything else — timeout, offline, 5xx, rate limit, and the
    /// RPC's own `Not authenticated` (28000, which arrives as a
    /// PostgREST error and not an `AuthError`) — is RETRYABLE. That
    /// last one matters: a null `auth.uid()` says the session is bad,
    /// never that the account was deleted.
    static func classify(_ error: (any Error)?) -> AccountDeletionVerdict {
        guard let error else { return .serverComplete }
        return AuthService.classifyVerifyFailure(error) == .definitive
            ? .serverComplete
            : .retryable
    }
}

// MARK: - AccountDeletionIntent
//
// The durable half. One UserDefaults key, deliberately NOT a `@Model`
// — for the same reason `DeletionLedger` is not one (§38 §5): a new
// SwiftData entity is a store migration that can fail, and the thing
// whose job is to survive a crash must not be the thing that can break
// a launch.
//
// Two stages, and the difference between them is the whole safety
// argument:
//
//   .requested       she asked; the server's answer is unknown. NOTHING
//                    is purged on the strength of this. It exists so a
//                    later launch knows the transaction was open.
//   .serverComplete  the server confirmed, or confirmed by absence. The
//                    local purge is now OWED and will be finished at the
//                    next launch if it did not finish at this one.
//
// It names the userId because the account she deleted is frequently NOT
// the account the app is holding by the time the purge runs — the
// sign-out at the end of deletion bootstraps a fresh anonymous uid, so
// a purge scoped to "the current user" would sweep the wrong one.

enum AccountDeletionIntent {

    private static let key = "account.deletion.intent.v1"
    private static let userKey = "uid"
    private static let stageKey = "stage"

    private enum Stage: String {
        case requested
        case serverComplete
    }

    /// Written BEFORE the RPC, so a process that dies during the call
    /// still leaves a record that a deletion was in flight.
    static func begin(userId: String) {
        guard !userId.isEmpty else { return }
        UserDefaults.standard.set(
            [userKey: userId, stageKey: Stage.requested.rawValue], forKey: key
        )
    }

    /// Written the moment the server half is known to be done. From
    /// here the local purge is owed unconditionally.
    static func markServerComplete(userId: String) {
        guard !userId.isEmpty else { return }
        UserDefaults.standard.set(
            [userKey: userId, stageKey: Stage.serverComplete.rawValue], forKey: key
        )
    }

    /// The account whose LOCAL purge is owed, or nil. Deliberately
    /// returns nil for `.requested`: an unconfirmed deletion must never
    /// cause a device to destroy data the server may still be holding.
    static func pendingLocalPurge() -> String? {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String],
              dict[stageKey] == Stage.serverComplete.rawValue,
              let uid = dict[userKey], !uid.isEmpty
        else { return nil }
        return uid
    }

    /// Any open deletion, at either stage. Used to tell the customer
    /// that something is unfinished rather than silently forgetting it.
    static func pending() -> String? {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String],
              let uid = dict[userKey], !uid.isEmpty
        else { return nil }
        return uid
    }

    /// Called only once the local purge has actually completed.
    static func finish() { clear() }

    /// Also called by `clearOnboardingUserDefaults`, because an
    /// intent is a fact about one account and must never reach the
    /// next person on this phone.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
