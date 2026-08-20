import XCTest
@testable import PlankSync

// MARK: - FoodSourceHydrationTests
//
// v25 pass 51 — UNKNOWN STAYS UNKNOWN.
//
// The write side has carried this law since E8.1: a locally-stored
// entry with no source upserts as `unknown`, because defaulting it to
// `photo` "invented an attribution" and inflated the largest real
// category (`EntryMethod.persistedSourceValue`, and the comment at
// `AppSync.syncRow`). The READ side still carried the pre-law default:
// `FoodLogSyncRow`'s decode-tolerant init turned a NULL `source` into
// `"photo"` — so a row whose attribution was honestly absent on the
// server hydrated onto the device claiming "read from your photo".
// Provenance manufactured at the boundary, in exactly the direction
// the law was written to forbid.
//
// The contract pinned here: the DTO is TRANSPORT. Absent stays absent
// (nil), present passes through byte-for-byte, and no boundary is
// allowed to guess a door.

final class FoodSourceHydrationTests: XCTestCase {

    private func decode(_ json: String) throws -> SyncService.FoodLogSyncRow {
        try JSONDecoder().decode(
            SyncService.FoodLogSyncRow.self, from: Data(json.utf8)
        )
    }

    func testANullSourceHydratesAsAbsentNeverAsPhoto() throws {
        let row = try decode("""
        {"id":"r1","user_id":"u1","logged_at":"2026-08-18T12:00:00Z",
         "kcal_total":410,"protein_g":30,"carbs_g":40,"fat_g":12,
         "fiber_g":4,"sugar_g":6,"source":null,"payload":null}
        """)
        XCTAssertNil(row.source,
            "a NULL source is an absence of attribution; hydrating it as 'photo' manufactures provenance")
    }

    func testAMissingSourceKeyHydratesAsAbsent() throws {
        let row = try decode("""
        {"id":"r2","user_id":"u1","logged_at":"2026-08-18T12:00:00Z",
         "kcal_total":300}
        """)
        XCTAssertNil(row.source)
    }

    /// Control — a stated door passes through untouched, including one
    /// this build would never write (history is left exactly as found).
    func testAPresentSourceSurvivesVerbatim() throws {
        for door in ["words", "barcode", "unknown", "im_out"] {
            let row = try decode("""
            {"id":"r3","user_id":"u1","logged_at":"2026-08-18T12:00:00Z",
             "kcal_total":300,"source":"\(door)"}
            """)
            XCTAssertEqual(row.source, door)
        }
    }
}
