import XCTest
@testable import PlankFood

// MARK: - SpokenDayTests (p72 — the stated day survives the words door)
//
// RED shape: before this pass, a plate whose sentence said "last night"
// persisted at `Date()` — today — so today's dial dropped for a meal she
// ate yesterday and yesterday's record stayed empty. Her stated numbers
// survive verbatim (p61), her qualifiers are statements (p53); the day
// she names is the same class of fact.

@MainActor
final class SpokenDayTests: XCTestCase {

    private var scratch: URL!

    override func setUp() async throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpokenDayTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: scratch, withIntermediateDirectories: true
        )
        FoodLogPersister.debugResetStore(
            to: scratch.appendingPathComponent("entries.jsonl")
        )
    }

    override func tearDown() async throws {
        FoodLogPersister.debugResetStore(to: nil)
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: the detector — statements it accepts

    func testPlainYesterdayStatementsRead() {
        for sentence in [
            "last night i had a bowl of chicken soup",
            "yesterday i had a burrito",
            "i had a burrito yesterday",
            "forgot to log yesterday: two eggs and toast",
            "yesterday's dinner was salmon and rice",
            "chicken salad for lunch yesterday",
            "Last Night I Had Pizza",
        ] {
            XCTAssertEqual(SpokenDayReference.daysAgo(in: sentence), 1,
                           "should read as yesterday: \(sentence)")
        }
    }

    // MARK: the detector — statements it refuses (nil = file today)

    func testMixedAndPresentStatementsRefuse() {
        for sentence in [
            "a bowl of soup",                                  // no day named
            "today i had oatmeal",
            "pizza last night and a salad today",              // mixed
            "this morning i had eggs",
            "soup tonight",
        ] {
            XCTAssertNil(SpokenDayReference.daysAgo(in: sentence),
                         "should refuse: \(sentence)")
        }
    }

    func testComparisonsAndProvenanceRefuse() {
        // The day names WHAT the food is, not WHEN she ate it.
        for sentence in [
            "same as yesterday",
            "the same smoothie as last night",
            "more than yesterday",
            "leftovers from last night",
            "leftover pizza from yesterday",
            "i had yesterday's leftovers",
            "the day before yesterday i had ramen",            // 2 days — V1 refuses over guessing
        ] {
            XCTAssertNil(SpokenDayReference.daysAgo(in: sentence),
                         "should refuse: \(sentence)")
        }
    }

    func testWordBoundariesHold() {
        XCTAssertNil(SpokenDayReference.daysAgo(in: "a late nightcap after my last nightcap"))
        XCTAssertEqual(SpokenDayReference.daysAgo(in: "yesterday's oatmeal"), 1)
    }

    // MARK: the timestamp law (setLoggedDay's own clock-preserving rule)

    func testStatedLoggedAtKeepsTheClockAndMovesTheDay() {
        let cal = Calendar.current
        let now = Date()
        let stamped = FoodLogPersister.statedLoggedAt(daysAgo: 1, now: now, calendar: cal)
        XCTAssertEqual(
            cal.dateComponents([.hour, .minute], from: stamped),
            cal.dateComponents([.hour, .minute], from: now),
            "the clock time is not hers to lose — setLoggedDay's own law"
        )
        XCTAssertTrue(
            cal.isDate(stamped, inSameDayAs: cal.date(byAdding: .day, value: -1, to: now)!),
            "the day is the one she stated"
        )
        XCTAssertEqual(FoodLogPersister.statedLoggedAt(daysAgo: nil, now: now), now)
        XCTAssertEqual(FoodLogPersister.statedLoggedAt(daysAgo: 0, now: now), now)
        XCTAssertEqual(FoodLogPersister.statedLoggedAt(daysAgo: -3, now: now), now,
                       "a future day can never be stated into the record")
    }

    // MARK: persist — the record lands on the stated day

    func testAStatedYesterdayPlatePersistsOnYesterday() throws {
        let userId = UUID().uuidString
        guard let statement = StatedPlate.parse("chicken soup, 250 cal, 20g protein") else {
            return XCTFail("statement must parse")
        }
        var food = StatedPlate.plate(from: statement)
        food.statedDaysAgo = 1
        _ = try FoodLogPersister.persist(food, userId: userId)

        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        let cal = Calendar.current
        XCTAssertTrue(
            cal.isDate(entry.loggedAt,
                       inSameDayAs: cal.date(byAdding: .day, value: -1, to: .now)!),
            "she said last night; the record must not say today"
        )
    }

    func testAnUnstatedDayStillFilesToToday() throws {
        let userId = UUID().uuidString
        guard let statement = StatedPlate.parse("chicken soup, 250 cal, 20g protein") else {
            return XCTFail("statement must parse")
        }
        _ = try FoodLogPersister.persist(StatedPlate.plate(from: statement), userId: userId)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertTrue(Calendar.current.isDateInToday(entry.loggedAt))
    }
}
