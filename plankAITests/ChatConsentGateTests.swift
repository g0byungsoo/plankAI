import XCTest
@testable import plankAI

// p81 — THE CHAT DISCLOSURE GATE (5.1.2(i), "including with
// third-party AI", 2025-11-13). The envelope carries the medication
// compound, dose events, symptoms and her own notes; nothing may
// leave the device before the disclosure is accepted — including the
// card-tap seed path, which sends the whole envelope without a typed
// message. These pins hold the gate at both doors.
@MainActor
final class ChatConsentGateTests: XCTestCase {

    /// The iOS 26.2 sim aborts when a @MainActor class deinits off
    /// the actor (the documented sim class — see CLAUDE.md QA notes).
    /// Sessions are retained for the process lifetime so the tests
    /// exercise the gate, not the runtime's teardown.
    private static var retainedSessions: [ChatSession] = []

    private func makeSession() -> ChatSession {
        let s = ChatSession()
        s.transport = MockChatTransport()
        Self.retainedSessions.append(s)
        return s
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ChatAIConsent.acceptedKey)
        UserDefaults.standard.removeObject(forKey: ChatAIConsent.acceptedAtKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ChatAIConsent.acceptedKey)
        UserDefaults.standard.removeObject(forKey: ChatAIConsent.acceptedAtKey)
        super.tearDown()
    }

    /// A first send with no consent raises the gate, keeps her words
    /// in the composer (send() clears it only when it proceeds), and
    /// appends nothing to the transcript.
    func testFirstSendRaisesTheGateAndNothingLeaves() {
        let s = makeSession()
        s.composerText = "why am i hungrier this week?"
        s.send()
        XCTAssertTrue(s.consentGateShowing, "the disclosure must present before anything leaves")
        XCTAssertEqual(s.composerText, "why am i hungrier this week?",
                       "a gated send must not consume her words")
        XCTAssertTrue(s.entries.isEmpty, "nothing may enter the transcript before consent")
        XCTAssertFalse(s.isStreaming)
        XCTAssertFalse(ChatAIConsent.hasAccepted())
    }

    /// The seed path (a card tap elsewhere in the app) fires the full
    /// envelope with no typed message — it is gated identically.
    func testSeedPathIsGatedToo() {
        let s = makeSession()
        s.openWithSeed("their dose era changed this week")
        XCTAssertTrue(s.consentGateShowing)
        XCTAssertTrue(s.entries.isEmpty)
        XCTAssertFalse(s.isStreaming)
    }

    /// Decline stands the gate down without consenting; the next send
    /// re-raises it. Consent is never inferred from a dismissal.
    func testDeclineLeavesConsentUnsetAndTheNextSendReasks() {
        let s = makeSession()
        s.composerText = "hello"
        s.send()
        s.consentDeclined()
        XCTAssertFalse(s.consentGateShowing)
        XCTAssertFalse(ChatAIConsent.hasAccepted())
        XCTAssertTrue(s.entries.isEmpty)
        s.send()
        XCTAssertTrue(s.consentGateShowing, "a declined disclosure must re-present on the next send")
    }

    /// Accept stamps the durable record (flag + timestamp) and
    /// replays the held send — her words leave the composer only now.
    func testAcceptStampsConsentAndReplaysTheHeldSend() {
        let s = makeSession()
        s.composerText = "what did i eat yesterday?"
        s.send()
        XCTAssertTrue(s.consentGateShowing)
        s.consentAccepted()
        XCTAssertTrue(ChatAIConsent.hasAccepted())
        XCTAssertNotNil(
            UserDefaults.standard.string(forKey: ChatAIConsent.acceptedAtKey)
                .flatMap { ISO8601DateFormatter().date(from: $0) },
            "the acceptance timestamp must be a real, parseable instant"
        )
        XCTAssertFalse(s.consentGateShowing)
        XCTAssertEqual(s.composerText, "", "accept must continue the send she was making")
    }

    /// Once accepted, the gate never re-presents.
    func testAcceptedConsentNeverReasks() {
        ChatAIConsent.markAccepted()
        let s = makeSession()
        s.composerText = "hi"
        s.send()
        XCTAssertFalse(s.consentGateShowing)
    }
}
