import XCTest
@testable import plankAI
import PlankFood

// v2.8 (docs/app_v2/29) — the cross-account bleed regression net.
// The motion-QA frame that showed plates=0 beside kcal=860 came from
// todayMacros() summing EVERY account on the device. These tests pin
// the user-scoped reads and the sign-out sweep of per-identity keys.
@MainActor
final class CrossAccountScopingTests: XCTestCase {

    // Fresh identities PER RUN. The persister's JSONL outlives the
    // test process and mergeRemote dedupes by id — fixed ids meant a
    // run after midnight re-read YESTERDAY's rows and todayMacros
    // legitimately returned 0 (caught 2026-07-06, the midnight
    // flake). Unique users + ids make every run self-contained.
    private let runTag = UUID().uuidString
    private var userA: String { "AAAAAAAA-0000-4000-8000-\(String(runTag.replacingOccurrences(of: "-", with: "").prefix(12)))".uppercased() }
    private var userB: String { "BBBBBBBB-0000-4000-8000-\(String(runTag.replacingOccurrences(of: "-", with: "").suffix(12)))".uppercased() }
    private var idA: String { "scope-a1-\(runTag)" }
    private var idB: String { "scope-b1-\(runTag)" }

    override func setUp() async throws {
        FoodLogPersister.mergeRemote([
            .init(id: idA, userId: userA, loggedAt: .now,
                  kcal: 400, protein: 30, carbs: 40, fat: 10, fiber: 5,
                  title: "user a plate", source: "test"),
            .init(id: idB, userId: userB.lowercased(), loggedAt: .now,
                  kcal: 700, protein: 50, carbs: 60, fat: 20, fiber: 6,
                  title: "user b plate", source: "test"),
        ])
    }

    func testTodayMacrosIsUserScoped() {
        let a = FoodLogPersister.todayMacros(userId: userA)
        XCTAssertEqual(Int(a.kcal), 400, "user A must never see user B's calories")
        XCTAssertEqual(Int(a.protein), 30)
        let b = FoodLogPersister.todayMacros(userId: userB)
        XCTAssertEqual(Int(b.kcal), 700)
    }

    func testAllEntriesIsCaseInsensitiveOnUUIDCase() {
        // B was stored lowercased; the read uses the uppercase form.
        let entries = FoodLogPersister.allEntries(userId: userB)
        XCTAssertTrue(entries.contains { $0.id == idB },
                      "uuid case must not split one user into two")
        XCTAssertFalse(entries.contains { $0.id == idA })
    }

    func testSignOutSweepClearsPerIdentityDayKeys() {
        let d = UserDefaults.standard
        d.set("i kept my promise", forKey: "day.note.2026-07-03")
        d.set("proud", forKey: "day.reflection.2026-07-03")
        d.set("breath first", forKey: "lesson.rep.kept.2026-07-03")
        d.set(12, forKey: "stats.shown_up_count")
        AppSync.shared.clearOnboardingUserDefaults()
        XCTAssertNil(d.string(forKey: "day.note.2026-07-03"),
                     "her private note must never survive into the next account")
        XCTAssertNil(d.string(forKey: "day.reflection.2026-07-03"))
        XCTAssertNil(d.string(forKey: "lesson.rep.kept.2026-07-03"))
        XCTAssertEqual(d.integer(forKey: "stats.shown_up_count"), 0)
    }
}
