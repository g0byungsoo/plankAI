import Foundation
import AuthenticationServices

// MARK: - AppleIdentityPolicy (v25 §39 — THE ACCOUNT REALLY DISAPPEARS)
//
// THE DEFECT, stated once so nobody re-derives it from a comment:
//
//   `AuthService.signInWithApple`'s own doc comment says the uid is
//   preserved — *"the anonymous account links to the Apple identity
//   rather than getting replaced"*. THE PRODUCTION DATABASE SAYS
//   OTHERWISE, WITHOUT A SINGLE EXCEPTION:
//
//     provider  named users  identity created with the uid  attached later
//     apple            559                            559               0
//     email            308                             30             278
//
//   max gap for apple: ZERO SECONDS. Max gap for email: 13.9 days.
//
//   The email path preserves the uid because `signUpWithEmail` calls
//   `auth.update(user:)`, which mutates the CURRENT user. The Apple
//   path replaces it because `completeAppleSignIn` calls
//   `signInWithIdToken`, which posts to `/token?grant_type=id_token`
//   with NO Authorization header and no `link_identity` flag — so
//   GoTrue mints a new user rather than attaching the identity to the
//   session in hand.
//
//   Everything she recorded before tapping the button therefore stays
//   under the abandoned anonymous uid, where `delete_user_account()`
//   (scoped to `auth.uid()`) can never reach it. That is the whole
//   orphan class, and it is created one sign-in at a time.
//
// THE FIX, and why it is this one:
//
//   `linkIdentityWithIdToken` is in the PINNED supabase-swift already.
//   It posts to the same endpoint with `linkIdentity = true` and
//   `Authorization: Bearer <current session>`, so GoTrue attaches the
//   Apple identity to the uid she is already holding. Nothing on the
//   server changes; no migration, no config, no Developer Portal.
//
//   ▎ PREVENTING AN ORPHAN BEATS CLEANING ONE UP. An orphan cannot be
//   ▎ associated back to her — there is no durable record anywhere
//   ▎ that uid A became uid B — so every one that is created is
//   ▎ created forever.
//
// THE SAFETY PROPERTY THAT LETS THIS SHIP ON A FROZEN CANDIDATE:
// linking is attempted ONLY from an anonymous session, and EVERY
// failure falls back to the exact call the product makes today. The
// worst case is today's behaviour. There is no input for which this
// is worse than shipping nothing, which is the only reason it is
// acceptable to touch the auth path at all.

enum AppleSignInStrategy: Equatable {
    /// Attach the Apple identity to the uid this device already holds.
    case linkToCurrentUser
    /// Sign in as the Apple user, minting or adopting a separate uid.
    /// Correct for a returning customer; the orphan-maker for an
    /// anonymous one.
    case signInAsAppleUser
}

enum AppleIdentityPolicy {

    /// Linking is only meaningful when there is a live session AND that
    /// session is anonymous. A named session linking a second identity
    /// is a different feature nobody asked for; no session at all means
    /// there is nothing to link to.
    static func strategy(hasSession: Bool, isAnonymous: Bool) -> AppleSignInStrategy {
        (hasSession && isAnonymous) ? .linkToCurrentUser : .signInAsAppleUser
    }

    /// Every link failure falls back to the shipping call, deliberately
    /// without inspecting the error.
    ///
    /// The common one is real and expected: she already has an account
    /// under this Apple id (reinstall, second device), so GoTrue refuses
    /// the link with `identity_already_exists` and signing in is the
    /// CORRECT outcome. The rest — offline, 5xx, an older GoTrue, an SDK
    /// change — must land in the same place, because a customer who
    /// cannot sign in is a worse failure than an orphaned anonymous uid.
    /// Branching on error codes here would create a path where sign-in
    /// dead-ends; there is no such path.
    static func fallback(after error: any Error) -> AppleSignInStrategy {
        .signInAsAppleUser
    }
}

// MARK: - AppleRevocationPolicy
//
// Apple's TN3194 (*Handling account deletions and revoking tokens for
// Sign in with Apple*, first published 2025-10-03) is explicit about an
// app in Jeni's position:
//
//   > If you don't have the user's refresh token, access token, or
//   > authorization code, you must still fulfill the user's account
//   > deletion request and meet the account deletion requirement.
//   > 1. Delete the user's account data from your systems.
//   > 2. Direct the user to manually revoke access for your client.
//   > 3. Respond to the credential revoked notification to revert the
//   >    client to an unauthenticated state.
//
// Jeni holds NONE of those three credentials — `authorizationCode` has
// zero call sites in first-party code, and `auth.identities.identity_data`
// carries only `sub`/`email`/`iss`/`custom_claims`, no token of any
// kind — so this documented fallback is not a lesser option. It is the
// path, and step 3 is the half that is code.
//
// This type is step 3's decision, kept pure so the response is testable
// without a device, a team key or an Apple account.

enum AppleRevocationResponse: Equatable {
    /// Delete this customer's local data and drop the session, per
    /// TN3194's "revert the client to an unauthenticated state".
    case revertToUnauthenticated
    /// The notice does not concern this customer. Signing somebody out
    /// of an account Apple never mentioned is its own defect.
    case ignore
}

enum AppleRevocationPolicy {

    /// `state` is nil when the credential state could not be read —
    /// which is the case for EVERY customer who signed in before this
    /// build, because the Apple user identifier was never stored and
    /// `getCredentialState(forUserID:)` needs it. That is the whole
    /// installed base, so an inert watcher for them would be a fix that
    /// helps nobody who currently has the problem.
    ///
    /// For them the notification itself is the evidence: the system
    /// posts `credentialRevokedNotification` for THIS app's credential,
    /// and the customer is signed in with Apple. Reverting to
    /// unauthenticated is recoverable in one tap; ignoring it leaves an
    /// app authenticated on a credential Apple has withdrawn, which is
    /// the state TN3194 exists to prevent.
    static func response(
        authMethod: AuthMethod,
        state: ASAuthorizationAppleIDProvider.CredentialState?
    ) -> AppleRevocationResponse {
        // Only an Apple-signed-in customer has an Apple credential to
        // lose. An email or anonymous identity is untouched by an Apple
        // revocation, whatever the system posts.
        guard authMethod == .apple else { return .ignore }

        guard let state else { return .revertToUnauthenticated }

        switch state {
        case .revoked:
            return .revertToUnauthenticated
        case .notFound:
            // The system no longer knows this Apple id for this app,
            // which is the same fact arriving by a different name.
            return .revertToUnauthenticated
        case .authorized:
            // The notification fired but the credential is still good.
            // Believing the notice over the state would sign out a
            // customer who revoked nothing.
            return .ignore
        case .transferred:
            // App transfer between developer teams (TN3159), not a
            // revocation. Handling it as one would sign out everybody
            // on the day of a transfer.
            return .ignore
        @unknown default:
            // A state Apple adds later is not evidence of revocation.
            // Unknown is never permission, and it is never a sign-out.
            return .ignore
        }
    }
}

// MARK: - AppleCredentialWatcher
//
// TN3194 step 3, the half that is code: *"Respond to the credential
// revoked notification to revert the client to an unauthenticated
// state."* Before this, `ASAuthorizationAppleIDProvider` appeared in
// exactly one place in the repository — creating the sign-in request —
// and Jeni observed no revocation signal of any kind. A customer who
// removed Jeni from Settings › Sign in with Apple stayed signed in, with
// her record on the phone, indefinitely.
//
// Deliberately NOT built: a server-to-server notification endpoint.
// TN3194 offers it as the alternative for web services; Jeni is a native
// client, the native notification is the documented route for it, and an
// endpoint would be a deploy plus an Apple Developer Portal change —
// both outside what can be proven here. Named in §39, not smuggled.

@MainActor
enum AppleCredentialWatcher {

    /// The Apple user identifier (`credential.user`, the same value
    /// Supabase stores as `identity_data.sub`). Needed only to confirm
    /// the credential state before acting. Swept with every other
    /// account-scoped key, so it never reaches the next person on this
    /// phone.
    static let userIdentifierKey = "apple.user.identifier.v1"

    private static var observer: NSObjectProtocol?

    /// Idempotent. Started from `AuthService.bootstrap`, beside the
    /// auth-event listener, and never torn down: both are
    /// process-lifetime.
    static func start(onRevoked: @escaping @MainActor () async -> Void) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard await shouldRevert() else { return }
                await onRevoked()
            }
        }
    }

    /// Confirms with Apple where it can, and answers from the policy
    /// where it cannot.
    static func shouldRevert() async -> Bool {
        let method = AuthService.shared.authMethod
        let state = await currentCredentialState()
        return AppleRevocationPolicy.response(authMethod: method, state: state)
            == .revertToUnauthenticated
    }

    private static func currentCredentialState() async
        -> ASAuthorizationAppleIDProvider.CredentialState? {
        guard let appleUserID = UserDefaults.standard.string(forKey: userIdentifierKey),
              !appleUserID.isEmpty
        else { return nil }
        return await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { state, error in
                continuation.resume(returning: error == nil ? state : nil)
            }
        }
    }
}
