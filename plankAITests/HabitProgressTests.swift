import XCTest
@testable import plankAI

final class HabitProgressTests: XCTestCase {
    func testShowsUpCopy() {
        XCTAssertEqual(HabitProgress.weeklyStatus(actionsThisWeek: 4, target: 5),
                       "you're showing up, 4 of 5 this week")
    }
    func testNeverMentionsWeightOrBehind() {
        let s = HabitProgress.weeklyStatus(actionsThisWeek: 0, target: 5)
        XCTAssertFalse(s.lowercased().contains("behind"))
        XCTAssertFalse(s.lowercased().contains("lb"))
        XCTAssertFalse(s.lowercased().contains("kg"))
    }
}
