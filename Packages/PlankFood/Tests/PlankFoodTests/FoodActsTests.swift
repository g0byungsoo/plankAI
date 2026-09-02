import XCTest
@testable import PlankFood

// p66 — the package half of the speech-grammar constant pin. The app
// half lives in plankAITests/JeniBurstShowerTests.swift
// (JeniActsGrammarTests); both pin the same literals so the mirror
// cannot drift (the FoodThemeTests mechanism, applied to time).
final class FoodActsTests: XCTestCase {
    func testTheSpeechBeatMatchesTheAppGrammar() {
        XCTAssertEqual(FoodActs.beat, 0.55, accuracy: 0.0001)
    }
    func testTheActionPauseMatchesTheAppGrammar() {
        XCTAssertEqual(FoodActs.actionPause, 0.30, accuracy: 0.0001)
    }
}
