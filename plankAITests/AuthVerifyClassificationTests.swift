import XCTest
import Supabase
@testable import plankAI

// MARK: - AuthVerifyClassificationTests
//
// The 2026-07 re-key bug: bootstrap() treated EVERY failed session
// verification (including plain timeouts and offline launches) as a stale
// session, signed it out, and minted a new anonymous user_id, orphaning
// all userId-scoped data and the RevenueCat entitlement.
//
// AuthService.classifyVerifyFailure is the pure seam that now decides
// whether a verify failure may destroy the keychain session. This table is
// the specification: only DEFINITIVE server rejections are allowed to.
// Everything ambiguous must fail open as transient.

final class AuthVerifyClassificationTests: XCTestCase {

    // MARK: Helpers

    private func apiError(code: ErrorCode, status: Int) -> AuthError {
        .api(
            message: "test",
            errorCode: code,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse(
                url: URL(string: "https://example.supabase.co/auth/v1/user")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

    // MARK: Transient: network never delivered a verdict

    func testOfflineURLErrorIsTransient() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    func testTimedOutURLErrorIsTransient() {
        let error = URLError(.timedOut)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    func testCannotFindHostIsTransient() {
        // Captive portal / DNS failure.
        let error = URLError(.cannotFindHost)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    func testCancellationIsTransient() {
        // withTimeout now cancels the losing task; a cancellation error
        // must never read as a server rejection.
        XCTAssertEqual(AuthService.classifyVerifyFailure(CancellationError()), .transient)
    }

    func testGenericNSErrorIsTransient() {
        let error = NSError(domain: "Test", code: -1)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    // MARK: Transient: server answered, but not with a rejection

    func testServer500IsTransient() {
        let error = apiError(code: .unexpectedFailure, status: 500)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    func testServer503IsTransient() {
        let error = apiError(code: .unknown, status: 503)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    func testRateLimit429IsTransient() {
        let error = apiError(code: .overRequestRateLimit, status: 429)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .transient)
    }

    // MARK: Definitive: the server rejected this session/user

    func testSessionMissingIsDefinitive() {
        // The SDK maps its session-cleanup codes (session_not_found,
        // session_expired, refresh_token_not_found,
        // refresh_token_already_used) to .sessionMissing after removing
        // the local session itself.
        XCTAssertEqual(AuthService.classifyVerifyFailure(AuthError.sessionMissing), .definitive)
    }

    func testUserNotFoundIsDefinitive() {
        // Server-side user deletion, the case the verify exists for
        // (commit b13e12c), regardless of the HTTP status it rode in on.
        let error = apiError(code: .userNotFound, status: 404)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testRefreshTokenAlreadyUsedIsDefinitive() {
        let error = apiError(code: .refreshTokenAlreadyUsed, status: 400)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testRefreshTokenNotFoundIsDefinitive() {
        let error = apiError(code: .refreshTokenNotFound, status: 400)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testSessionNotFoundCodeIsDefinitive() {
        let error = apiError(code: .sessionNotFound, status: 400)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testSessionExpiredIsDefinitive() {
        let error = apiError(code: .sessionExpired, status: 400)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testUserBannedIsDefinitive() {
        let error = apiError(code: .userBanned, status: 403)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testHTTP401WithUnknownCodeIsDefinitive() {
        // An auth-endpoint 401 is a rejection even when the body carried
        // no recognizable error code.
        let error = apiError(code: .unknown, status: 401)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testHTTP403WithUnknownCodeIsDefinitive() {
        let error = apiError(code: .unknown, status: 403)
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }

    func testJWTVerificationFailedIsDefinitive() {
        let error = AuthError.jwtVerificationFailed(message: "bad signature")
        XCTAssertEqual(AuthService.classifyVerifyFailure(error), .definitive)
    }
}
