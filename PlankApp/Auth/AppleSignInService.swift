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
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")

            for byte in bytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
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
            self.resume(returning: Result(
                identityToken: token,
                rawNonce: self.rawNonce,
                fullName: credential.fullName,
                email: credential.email
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
