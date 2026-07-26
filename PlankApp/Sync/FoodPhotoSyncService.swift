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
        for item in mine {
            guard let data = FoodPhotoStore.photoData(entryId: item.entryId) else {
                removePending(entryId: item.entryId)   // photo gone locally — nothing to send
                continue
            }
            do {
                try await Self.upload(data, path: Self.path(userId: item.userId, entryId: item.entryId))
                removePending(entryId: item.entryId)
            } catch {
                #if DEBUG
                print("[FoodPhotoSync] flush retry FAILED entry=\(item.entryId): \(error)")
                #endif
                // Still offline (or bucket unreachable) — keep it queued.
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

    private struct PendingUpload: Codable, Equatable {
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
        savePending(items)
    }

    private func removePending(entryId: String) {
        let items = loadPending()
        let kept = items.filter { $0.entryId.lowercased() != entryId.lowercased() }
        guard kept.count != items.count else { return }
        savePending(kept)
    }
}
