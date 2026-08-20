import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - AppleSignInService
//
// Coordinates an ASAuthorizationController flow and bridges it to async/await.
// Generates a fresh nonce per attempt: the SHA-256 hash goes into the request,
// the raw nonce gets returned so AuthService can pass it to Supabase. Supabase
// re-hashes the raw nonce server-side and verifies it against the identity
// token's `nonce` claim, which is how we prove the token was issued for this
// specific sign-in attempt and not replayed from elsewhere.

@MainActor
final class AppleSignInService: NSObject {

    struct Result {
        let identityToken: String
        let rawNonce: String
        let fullName: PersonNameComponents?
        let email: String?
        /// `credential.user` — the stable Apple user identifier, the
        /// same value Supabase already stores as `identity_data.sub`.
        /// v25 §39: carried so `getCredentialState(forUserID:)` can
        /// confirm a revocation notice before the app acts on it
        /// (Apple TN3194). It is an identifier, never a token.
        let userIdentifier: String
    }

    enum SignInError: LocalizedError {
        case canceled
        case missingIdentityToken
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .canceled: return "Sign in with Apple was cancelled."
            case .missingIdentityToken: return "Apple did not return an identity token."
            case .underlying(let err): return err.localizedDescription
            }
        }
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var rawNonce: String = ""

    func signIn() async throws -> Result {
        let nonce = Self.randomNonce()
        rawNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { cont in
            // Release audit 2026-08-08: a second signIn() while the
            // first sheet is pending used to overwrite the stored
            // continuation — the first awaiter then never resumed (a
            // silent hang behind a double-tapped button). Reject the
            // late entrant instead; the live sheet keeps its owner.
            guard self.continuation == nil else {
                cont.resume(throwing: ASAuthorizationError(.failed))
                return
            }
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce
    //
    // Exposed so SignInPromptView's SignInWithAppleButton path can reuse the
    // same nonce generation as the programmatic ASAuthorizationController path.
    // Each call returns a fresh value; never reuse a nonce across attempts.

    static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = max(1, length)

        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            if status != errSecSuccess {
                // Release audit 2026-08-08: the precondition here was
                // the one release-active hard-crash line in first-party
                // code — a SecRandomCopyBytes failure crashed the app on
                // the "sign in with Apple" tap. SystemRandomNumberGenerator
                // is CSPRNG-backed on Apple platforms, so the fallback
                // keeps the nonce cryptographically sound and the tap
                // alive.
                for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
            }

            for byte in bytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Delegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                self.resume(throwing: SignInError.missingIdentityToken)
                return
            }
            // NOTE (v25 §39): `credential.authorizationCode` is
            // deliberately NOT captured here. It is the only credential
            // Apple's `/auth/revoke` can be reached with, and capturing
            // it is worth nothing without a server that can exchange it
            // at `/auth/token` and store the resulting refresh token.
            // That server is designed in §39 §11 and gated on a secret
            // this pass may not create. Capturing a credential the app
            // cannot use would be dead code that looks like compliance.
            self.resume(returning: Result(
                identityToken: token,
                rawNonce: self.rawNonce,
                fullName: credential.fullName,
                email: credential.email,
                userIdentifier: credential.user
            ))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                self.resume(throwing: SignInError.canceled)
            } else {
                self.resume(throwing: SignInError.underlying(error))
            }
        }
    }

    private func resume(returning value: Result) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    private func resume(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - Presentation anchor

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
            return windowScene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
