import XCTest
@testable import plankAI

final class Day1PromiseBodyTests: XCTestCase {
    func testReplaysHerWordsWithName() {
        let b = NotificationPermission.day1PromiseBody(action: "log breakfast", anchor: "coffee", userName: "Jen")
        XCTAssertTrue(b.contains("coffee"))
        XCTAssertTrue(b.contains("Jen"))
        XCTAssertFalse(b.lowercased().contains("don't forget"))   // no nagging
    }
    func testNoNameStillReads() {
        let b = NotificationPermission.day1PromiseBody(action: "log breakfast", anchor: "coffee", userName: nil)
        XCTAssertFalse(b.isEmpty)
    }
}
