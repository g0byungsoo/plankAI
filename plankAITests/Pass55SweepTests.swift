import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - Pass55SweepTests (pass 55 §14)
//
// The recurring defect class, swept again: user-scoped state added
// AFTER the sweeps were written. This pass's census found her weekly
// re-signing decisions surviving account deletion on disk
// (WeeklyReviews/reviews.jsonl — the move.manual.v1 shape, one level
// up in the filesystem), the notification brain's budget/silence
// ledger crossing accounts (B's first week rationed and muted by A's
// behaviour), a plaintext medication-status fingerprint outliving
// deletion, and a dozen smaller keys. Every key seeded here is
// asserted GONE after the sign-out sweep; the review rows are
// asserted gone after the deletion purge.

@MainActor
final class Pass55SweepTests: XCTestCase {

    private let d = UserDefaults.standard

    /// Every newly-swept key, with a sentinel value.
    private let sentinelKeys: [String: Any] = [
        // the notification brain's ledger family (P1-b)
        "brain.ledger.v1": ["some_id": 123.0],
        "brain.ignores.support": 4,
        "brain.silenced.support": true,
        // plaintext medication-status fingerprint (P2-a)
        "analytics.cohortIdentity.fingerprint": "glp1_cohort=on_glp1|medicated=true",
        // shelved coach notes about her weeks (P2-b)
        "coach_notes_v1": Data("notes".utf8),
        // packet-question tombstones (P2-c; uid-suffixed)
        "visitq.removed.rhythm.abc-123": true,
        // notification opt-outs + her chosen hour (P3-a/b)
        "notif.winback_enabled": false,
        "notif.evening_plate_review_enabled": false,
        "notificationHour": 7,
        "notificationMinute": 30,
        // rating one-shots (P3-d)
        "ratingPrompt.postPlanReveal.shown": true,
        "ratingPrompt.lastDate": "2026-08-01",
        // same-day surface gates (P3-e)
        "evening.moment.presentedDayKey": "2026-08-20",
        "letter.presentedDayKey": "2026-08-20",
        // the unswept breathwork sibling (P3-f)
        "breathwork.weekly_day_keys": ["2026-08-18"],
        // per-week milestone family (P3-g)
        "weight_outcome_milestone_w4": true,
        // first-run gates + backfill marker (P3-h/i)
        "coach_intro_shown_at": "2026-08-01",
        "cohortIntakeBackfillV1Done": true,
        // the consult's last answer (P3-j)
        "onb_v8_last_answer": "ozempic",
        // post-purchase one-shot (P3-k)
        "postPurchase.firstRunPending": true,
        // walk analytics day-stamps (P4-b)
        "analytics.walkShown.day": "2026-08-20",
        "analytics.walkGoalHit.day": "2026-08-20",
        // the first-plate proof beat (P3-c — reset() finally called)
        "e5.firstPlate.outcome": "logged",
        "e5.firstPlate.attempts": 2,
    ]

    override func tearDown() {
        for key in sentinelKeys.keys { d.removeObject(forKey: key) }
        super.tearDown()
    }

    func testTheSignOutSweepClearsEveryNewlyFoundKey() {
        for (key, value) in sentinelKeys { d.set(value, forKey: key) }
        AppSync.shared.clearOnboardingUserDefaults()
        for key in sentinelKeys.keys {
            XCTAssertNil(
                d.object(forKey: key),
                "user-scoped key survived the sign-out sweep: \(key)"
            )
        }
    }

    func testAccountDeletionPurgesHerWeeklyReviewRowsFromDisk() throws {
        let uid = "P55-SWEEP-REVIEWS"
        WeeklyReview.purge(userId: uid)   // prior-run residue
        WeeklyReview.record(.init(
            id: "\(uid)-w4", userId: uid, weekIndex: 4,
            decidedAtISO: "2026-08-18T09:00:00Z", proposalKey: "protein_floor",
            decision: "kept", stampLine: "protein floor → 95g",
            reasonLine: "you cleared 95g on 5 of 7 days",
            weekName: "the steady week"
        ))
        XCTAssertEqual(WeeklyReview.records(userId: uid).count, 1)

        let container = TestModelContainer.shared
        AppSync.clearLocalUserRecords(userId: uid, in: container.mainContext)

        WeeklyReview._resetCacheForTesting()
        XCTAssertTrue(
            WeeklyReview.records(userId: uid).isEmpty,
            "her re-signing decisions survived account deletion"
        )
        // The container-walk law: after the purge, no file under
        // Application Support may still contain the deleted uid.
        if let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first {
            let files = (FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: nil
            )?.compactMap { $0 as? URL } ?? [])
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
            for file in files {
                guard let text = try? String(contentsOf: file, encoding: .utf8)
                else { continue }
                XCTAssertFalse(
                    text.contains(uid),
                    "deleted uid still on disk in \(file.lastPathComponent)"
                )
            }
        }
    }

    /// Other users' review rows survive one user's purge — deletion
    /// is scoped, never a wipe.
    func testTheReviewPurgeIsScopedToOneUser() {
        let a = "P55-SWEEP-A", b = "P55-SWEEP-B"
        for uid in [a, b] { WeeklyReview.purge(userId: uid) }
        for uid in [a, b] {
            WeeklyReview.record(.init(
                id: "\(uid)-w2", userId: uid, weekIndex: 2,
                decidedAtISO: "2026-08-18T09:00:00Z", proposalKey: "steps",
                decision: "kept", stampLine: "steps → 7,500",
                reasonLine: "walked most days", weekName: "the walking week"
            ))
        }
        AppSync.clearLocalUserRecords(
            userId: a, in: TestModelContainer.shared.mainContext
        )
        WeeklyReview._resetCacheForTesting()
        XCTAssertTrue(WeeklyReview.records(userId: a).isEmpty)
        XCTAssertEqual(WeeklyReview.records(userId: b).count, 1)
        AppSync.clearLocalUserRecords(
            userId: b, in: TestModelContainer.shared.mainContext
        )
    }
}
