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

    // MARK: - v25 §44 — two families the census found outside every sweep

    /// TOMORROW'S INTENTION.
    ///
    /// `HomeEvening` writes `day.intention.<tomorrow>` and
    /// `day.intention.text.<tomorrow>`; `TodayStateService` reads the
    /// text back into `morningIntention`, and `DailyBriefEngine` prints
    /// it in the morning brief. `day.note.`, `day.reflection.`,
    /// `day.sit.` and `day.dose.` are all swept prefixes — this sibling
    /// is not, so the decision she made last night arrived in the NEXT
    /// account's morning brief, and survived "delete my account" on disk
    /// and in every device backup taken afterwards.
    func testSignOutSweepClearsTomorrowsIntention() {
        let d = UserDefaults.standard
        let key = TodayStateService.dayKey()
        d.set("protein_first", forKey: "day.intention.\(key)")
        d.set("one plate, protein first.", forKey: "day.intention.text.\(key)")

        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertNil(d.string(forKey: "day.intention.\(key)"))
        XCTAssertNil(
            d.string(forKey: "day.intention.text.\(key)"),
            "the next account must not read her intention back in its morning brief"
        )
    }

    /// A CLINIC'S SERVED PROTOCOL.
    ///
    /// `careProtocol.served.v1` caches the last sane clinical config a
    /// clinic served, and `CareProtocolStore.current` is a process-
    /// lifetime static adopted at cold start by
    /// `bootstrapFromCacheIfNeeded`. Neither was in any sweep, so after
    /// account A (a clinic patient) signed out, account B's protein
    /// floor, pace ceiling and hydration aim were composed from a
    /// protocol B's clinic never served — the same sentence `41` §2
    /// wrote for care-team regimen rows, one layer down. Offline, it
    /// never healed at all.
    func testSignOutSweepForgetsAClinicsServedProtocol() {
        let d = UserDefaults.standard
        var clinic = CareProtocol.default
        clinic.id = "clinic.test.acme"
        clinic.version = 99
        XCTAssertTrue(CareProtocolStore.apply(clinic), "fixture must be clinically sane")
        XCTAssertEqual(CareProtocolStore.current.id, "clinic.test.acme")

        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertEqual(
            CareProtocolStore.current.id, CareProtocol.default.id,
            "a clinic's config must not compose the next account's targets"
        )
        XCTAssertNil(
            d.data(forKey: "careProtocol.served.v1"),
            "and it must not survive on disk after account deletion"
        )
        // The cold start after the switch, which is where the cache
        // actually bites: a relaunch must not adopt it either.
        CareProtocolStore.resetForTesting()
        CareProtocolStore.bootstrapFromCacheIfNeeded()
        XCTAssertEqual(CareProtocolStore.current.id, CareProtocol.default.id)
    }

    /// v25 §44 — THE PHOTO BACKFILL IS BOUNDED, AND ITS STAMP IS HERS.
    ///
    /// `food-photos` has never existed in this project (read from
    /// `storage.buckets`, 2026-08-15), so the download sweep's candidate
    /// list never shrinks and it made up to 200 failing round trips at
    /// every launch, twice, forever. Once per user per day now — and the
    /// stamp is identity-scoped, so the next account gets its own.
    func testThePhotoBackfillSweepsAtMostOncePerDayAndIsAccountScoped() {
        let d = UserDefaults.standard
        d.removeObject(forKey: FoodPhotoSyncService.sweepStampKey)

        XCTAssertTrue(FoodPhotoSyncService.shouldSweepDownloads(userId: userA))
        XCTAssertFalse(
            FoodPhotoSyncService.shouldSweepDownloads(userId: userA),
            "a second launch the same day must not re-walk the whole journal"
        )
        XCTAssertTrue(
            FoodPhotoSyncService.shouldSweepDownloads(userId: userB),
            "a different account gets its own answer"
        )
        // Tomorrow it runs again.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        XCTAssertTrue(FoodPhotoSyncService.shouldSweepDownloads(userId: userB, now: tomorrow))

        AppSync.shared.clearOnboardingUserDefaults()
        XCTAssertNil(d.string(forKey: FoodPhotoSyncService.sweepStampKey))
    }

    /// The pending-upload queue had no cap and a destination that has
    /// never existed, so it grew by one entry per photographed plate
    /// forever. Newest kept.
    func testThePendingPhotoQueueIsCapped() {
        let items = (0..<(FoodPhotoSyncService.pendingCap + 25)).map {
            FoodPhotoSyncService.PendingUpload(entryId: "e\($0)", userId: userA)
        }
        let capped = FoodPhotoSyncService.capped(items)
        XCTAssertEqual(capped.count, FoodPhotoSyncService.pendingCap)
        XCTAssertEqual(capped.last?.entryId, items.last?.entryId,
                       "the newest queued photo must survive the cap")
        XCTAssertEqual(
            FoodPhotoSyncService.capped(Array(items.prefix(3))).count, 3,
            "a small queue is untouched"
        )
    }
}
