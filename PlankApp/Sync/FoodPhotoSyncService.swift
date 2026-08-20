import Combine
import Foundation
import PlankFood
import Supabase

// MARK: - FoodPhotoSyncService
//
// 2026-07-25 photo cloud backup. The plate thumbnails FoodPhotoStore
// keeps on-device were the ONLY copy — a reinstall or device switch
// silently lost every photo while the entries themselves came back
// from food_logs. This service mirrors each ~40KB JPEG to the user's
// private Supabase Storage space and pulls missing ones back after a
// hydrate.
//
// Bucket contract (scripts/food_photos_storage.sql):
//   food-photos (private) / {user_id_lowercase}/{entry_id_lowercase}.jpg
// RLS on storage.objects scopes every operation to the caller's own
// uid folder, so this client can only ever touch the signed-in user's
// photos.
//
// Wiring (see RootView / AppSync):
//   * FoodPhotoStore.onPhotoPersisted -> uploadPhoto (snap persist +
//     sign-in rekey both flow through the store's save/rekey).
//   * flushPendingUploads on launch + after hydrate — offline snaps
//     upload when the network is back.
//   * hydrateMissingPhotos after hydrateFoodLogs — reinstall restore.
//
// Everything is best-effort and fire-and-forget: a failed upload lands
// in a persistent pending queue, a failed download is retried on the
// next hydrate, and no path here can throw into the UI.

@MainActor
final class FoodPhotoSyncService {
    static let shared = FoodPhotoSyncService()
    private init() {}

    private static let bucket = "food-photos"

    /// Guards against overlapping hydrate walks (launch + auth-change
    /// can fire in the same render cycle, same as AppSync's
    /// hydrationsInFlight).
    private var hydrationsInFlight: Set<String> = []
    private var flushInFlight = false

    /// Download backfill caps — newest first, stop at whichever comes
    /// first. 200 photos ≈ 8MB; 90 days covers the becoming filmstrip
    /// and every surface that renders photos today.
    private static let hydrateMaxEntries = 200
    private static let hydrateMaxAge: TimeInterval = 90 * 24 * 3600

    // MARK: - v25 §44 — THE DESTINATION DOES NOT EXIST, AND THIS FILE
    // PAID FOR IT ON EVERY LAUNCH.
    //
    // Read from the LIVE catalog 2026-08-15: `storage.buckets` holds
    // exactly one row, `body-scans`, and `storage.objects` holds zero.
    // **`food-photos` has never existed.** So every upload since this
    // seam shipped (2026-07-25) has failed and landed in an UNCAPPED
    // on-disk queue, and `flushPendingUploads` re-attempted the WHOLE
    // queue — sequentially, awaited — at every launch, from inside
    // `AppSync.onLaunch`, AHEAD of the launch hydrate. Production
    // today: 144 photographed plates across 11 customers, the heaviest
    // holding 58, so that customer makes 58 failing round trips before
    // the restore `43` already measured as the slowest thing on a
    // returning payer's launch.
    //
    // The download half is worse on a reinstalled device: the object
    // can never exist, so `entriesMissingPhoto` never shrinks and the
    // sweep makes up to 200 failing round trips at EVERY launch,
    // forever.
    //
    // ▎ THE BUCKET IS DELIBERATELY NOT CREATED IN THIS PASS.
    //
    // The deployed `delete_user_account()` is `delete from auth.users
    // where id = auth.uid()` and nothing else (read from `pg_proc`,
    // 2026-08-15), and `storage.objects` has NO foreign key to
    // `auth.users`. Creating the bucket before a corrected storage
    // purge exists would make every plate photograph SURVIVE ACCOUNT
    // DELETION — `40` §A1 wrote the ordering itself: *apply the purge
    // before the bucket exists*, and `42` [CORR-1] found the purge as
    // written would throw on a zero-row delete. Founder gate, sequenced.
    //
    // What ships here is the client half: stop paying for a destination
    // that is not there, and self-heal the instant it is.

    /// A flush pass gives up after this many failures in a row. A
    /// genuinely offline device stops just as fast and retries next
    /// launch, which is what the persistent queue is for.
    static let maxConsecutiveUploadFailures = 3

    /// The on-disk queue stops growing without bound. Newest kept — an
    /// old entry whose upload never landed is the one least likely to
    /// matter, and the local photo is untouched either way.
    static let pendingCap = 500

    /// The reinstall download sweep is throttled to once per user per
    /// day, the same idiom `AppSync.shouldHydrateOnLaunch` already uses
    /// for the launch hydrate. Identity-scoped, so it is swept on
    /// sign-out.
    static let sweepStampKey = "sync.photoSweepStamp"

    /// Pure, so the cap is a rule a test can read.
    static func capped(_ items: [PendingUpload]) -> [PendingUpload] {
        items.count <= pendingCap ? items : Array(items.suffix(pendingCap))
    }

    /// Pure. True at most once per user per calendar day.
    static func shouldSweepDownloads(
        userId: String, now: Date = .now, defaults: UserDefaults = .standard
    ) -> Bool {
        guard !userId.isEmpty else { return false }
        let stamp = "\(userId):\(Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970))"
        guard defaults.string(forKey: sweepStampKey) != stamp else { return false }
        defaults.set(stamp, forKey: sweepStampKey)
        return true
    }

    // MARK: Upload

    /// Mirror one thumbnail to the user's private cloud space.
    /// upsert:true so replays (rekey re-announce, queue retry racing a
    /// live upload) overwrite instead of erroring. On failure the
    /// entry id is queued and retried by `flushPendingUploads`.
    func uploadPhoto(entryId: String, data: Data, userId: String) async {
        guard !userId.isEmpty, !entryId.isEmpty else { return }
        do {
            try await Self.upload(data, path: Self.path(userId: userId, entryId: entryId))
            removePending(entryId: entryId)
        } catch {
            #if DEBUG
            print("[FoodPhotoSync] uploadPhoto FAILED entry=\(entryId): \(error) — queued for retry")
            #endif
            addPending(entryId: entryId, userId: userId)
        }
    }

    /// Retry every queued upload for this user. Reads the JPEG bytes
    /// back from FoodPhotoStore so a snap made offline uploads the
    /// exact bytes on disk once the network returns. A queue row whose
    /// local photo no longer exists (entry deleted meanwhile) is
    /// dropped. Safe to call repeatedly.
    func flushPendingUploads(userId: String) async {
        guard !userId.isEmpty, !flushInFlight else { return }
        flushInFlight = true
        defer { flushInFlight = false }

        let uid = userId.lowercased()
        let mine = loadPending().filter { $0.userId.lowercased() == uid }
        guard !mine.isEmpty else { return }
        #if DEBUG
        print("[FoodPhotoSync] flushPendingUploads: \(mine.count) queued")
        #endif
        var consecutiveFailures = 0
        for item in mine {
            guard let data = FoodPhotoStore.photoData(entryId: item.entryId) else {
                removePending(entryId: item.entryId)   // photo gone locally — nothing to send
                continue
            }
            do {
                try await Self.upload(data, path: Self.path(userId: item.userId, entryId: item.entryId))
                removePending(entryId: item.entryId)
                consecutiveFailures = 0
            } catch {
                #if DEBUG
                print("[FoodPhotoSync] flush retry FAILED entry=\(item.entryId): \(error)")
                #endif
                // Still offline (or the bucket does not exist) — keep it
                // queued. v25 §44: but STOP. The destination has never
                // existed in this project, so before this line the whole
                // queue was re-attempted sequentially at every launch,
                // ahead of the launch hydrate.
                consecutiveFailures += 1
                if consecutiveFailures >= Self.maxConsecutiveUploadFailures {
                    #if DEBUG
                    print("[FoodPhotoSync] flush standing down after \(consecutiveFailures) failures in a row")
                    #endif
                    return
                }
            }
        }
    }

    // MARK: Download (reinstall restore)

    /// Pull thumbnails for entries that exist in the journal but have
    /// no photo on this device — the reinstall / new-device path.
    /// Newest first, capped at ~90 days / 200 entries. A missing
    /// remote object is EXPECTED (quick-add, dining-out, relog, and
    /// pre-backup entries never had a photo) and skips silently.
    func hydrateMissingPhotos(userId: String) async {
        guard !userId.isEmpty else { return }
        if hydrationsInFlight.contains(userId) { return }
        hydrationsInFlight.insert(userId)
        defer { hydrationsInFlight.remove(userId) }

        let cutoff = Date().addingTimeInterval(-Self.hydrateMaxAge)
        let candidates = FoodLogPersister.entriesMissingPhoto(userId: userId)
            .prefix(while: { $0.loggedAt >= cutoff })
            .prefix(Self.hydrateMaxEntries)
        guard !candidates.isEmpty else { return }
        // v25 §44 — at most once per user per day, and the day is spent
        // ONLY when there is real work. A missing object is EXPECTED
        // here (quick-add, words, relog and every pre-backup entry never
        // had a photo), so this walk never shrinks its own candidate
        // list — and on a reinstalled device, where the bucket does not
        // exist at all, it made up to 200 failing round trips at EVERY
        // launch, twice (onLaunch and again after hydrateFoodLogs),
        // forever.
        //
        // The stamp is read AFTER the candidates, not before: on a
        // reinstall `onLaunch` calls this before the journal has
        // hydrated, so an empty walk would otherwise burn the day and
        // the real sweep — the one right after `hydrateFoodLogs`, which
        // is the whole reason this function exists — would be skipped
        // until tomorrow.
        guard Self.shouldSweepDownloads(userId: userId) else { return }

        var restored = 0
        for entry in candidates {
            do {
                let data = try await supabase.storage
                    .from(Self.bucket)
                    .download(path: Self.path(userId: userId, entryId: entry.id))
                FoodPhotoStore.store(data, entryId: entry.id)
                restored += 1
            } catch {
                // No cloud object for this entry (never had a photo /
                // pre-backup) or transient network failure — either
                // way, skip and let the next hydrate try again.
                continue
            }
        }
        #if DEBUG
        print("[FoodPhotoSync] hydrateMissingPhotos: restored \(restored)/\(candidates.count) for \(userId)")
        #endif
        if restored > 0 {
            FoodLogPersister.changeNotifier.send(())   // filmstrip re-reads photos
        }
    }

    // MARK: Delete

    /// Remove the cloud object for a deleted entry so a wiped plate is
    /// wiped everywhere (same privacy invariant as the local
    /// FoodPhotoStore.delete call in deleteEntry). Missing object is a
    /// silent no-op; also drops any queued upload for the entry so the
    /// retry path can't resurrect it.
    func deleteRemotePhoto(entryId: String, userId: String) async {
        guard !userId.isEmpty, !entryId.isEmpty else { return }
        removePending(entryId: entryId)
        do {
            _ = try await supabase.storage
                .from(Self.bucket)
                .remove(paths: [Self.path(userId: userId, entryId: entryId)])
        } catch {
            #if DEBUG
            print("[FoodPhotoSync] deleteRemotePhoto FAILED entry=\(entryId): \(error)")
            #endif
        }
    }

    // MARK: - Storage helpers

    /// Path contract shared with scripts/food_photos_storage.sql —
    /// lowercase on both segments (Postgres-normalized uuid casing) so
    /// the RLS folder check and the client always agree.
    private static func path(userId: String, entryId: String) -> String {
        "\(userId.lowercased())/\(entryId.lowercased()).jpg"
    }

    private static func upload(_ data: Data, path: String) async throws {
        try await supabase.storage
            .from(bucket)
            .upload(path, data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    // MARK: - Pending-upload queue (persistent)
    //
    // A tiny JSON file in Application Support — survives relaunches so
    // a snap made offline still reaches the cloud days later. Entries
    // are (entryId, userId) pairs; the bytes themselves stay in
    // FoodPhotoStore, which the flush reads back.

    struct PendingUpload: Codable, Equatable {
        let entryId: String
        let userId: String
    }

    private var queueURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("FoodPhotoSync", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("pending.json")
    }

    private func loadPending() -> [PendingUpload] {
        guard let url = queueURL,
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([PendingUpload].self, from: data)
        else { return [] }
        return items
    }

    private func savePending(_ items: [PendingUpload]) {
        guard let url = queueURL else { return }
        if items.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func addPending(entryId: String, userId: String) {
        var items = loadPending()
        let item = PendingUpload(entryId: entryId, userId: userId)
        guard !items.contains(item) else { return }
        items.append(item)
        // v25 §44 — the queue had no cap, and its destination has never
        // existed, so it grew by one entry per photographed plate
        // forever. Newest kept.
        savePending(Self.capped(items))
    }

    private func removePending(entryId: String) {
        let items = loadPending()
        let kept = items.filter { $0.entryId.lowercased() != entryId.lowercased() }
        guard kept.count != items.count else { return }
        savePending(kept)
    }
}
