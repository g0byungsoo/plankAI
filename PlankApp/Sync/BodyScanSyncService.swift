import Foundation
import SwiftData
import UIKit
import Supabase
import PlankSync

// MARK: - BodyScanSyncService
//
// app v9 P1 (D3) — the OPT-IN backup mirror for Body Vision. Default
// OFF: until she flips the toggle, nothing here runs and her scans
// exist only on her iPhone. When ON, the source JPEG mirrors to her
// private `body-scans` bucket (scripts/body_scans_storage.sql, own-
// prefix RLS); the silhouette never uploads — it re-renders from the
// photo after a restore.
//
// Records are deliberately local-only, so the object path carries
// the dayKey ({uid}/{dayKey}_{scanId}.jpg) and a reinstall rebuilds
// records from the folder listing (poseQuality is lost — restored
// scans carry 0, which P2's compare floors treat as unknown).
//
// Turning backup OFF deletes her cloud copies — for body photos,
// "backup off" must mean gone, not paused (L4). Everything is
// best-effort with a persistent retry queue, the food-photos shape.

@MainActor
final class BodyScanSyncService {
    static let shared = BodyScanSyncService()
    private init() {}

    private static let bucket = "body-scans"

    private var flushInFlight = false
    private var restoreInFlight = false

    private var backupOn: Bool {
        UserDefaults.standard.bool(forKey: BodyScanStore.backupOnKey)
    }

    // MARK: Toggle flows

    /// Flips backup ON and queues every existing scan for upload.
    func enableBackup(userId: String, in context: ModelContext) async {
        UserDefaults.standard.set(true, forKey: BodyScanStore.backupOnKey)
        for scan in BodyScanStore.all(userId: userId, in: context) {
            addPending(scanId: scan.id, dayKey: scan.dayKey, userId: userId)
        }
        await flushPendingUploads(userId: userId, in: context)
    }

    /// Flips backup OFF and removes her cloud copies (gone, not
    /// paused). Local scans are untouched.
    func disableBackup(userId: String) async {
        UserDefaults.standard.set(false, forKey: BodyScanStore.backupOnKey)
        savePending([])
        await deleteAllRemote(userId: userId)
    }

    // MARK: Upload

    /// Called through BodyScanStore.onScanKept. No-op unless backup
    /// is on; a failed upload queues and retries at next launch.
    func scanKept(_ record: BodyScanRecord) {
        guard backupOn else { return }
        let scanId = record.id
        let dayKey = record.dayKey
        let userId = record.userId
        Task { await self.upload(scanId: scanId, dayKey: dayKey, userId: userId, record: record) }
    }

    private func upload(
        scanId: String, dayKey: String, userId: String, record: BodyScanRecord?
    ) async {
        guard backupOn, !userId.isEmpty,
              let data = BodyScanPhotoStore.photoData(scanId: scanId) else { return }
        do {
            try await supabase.storage
                .from(Self.bucket)
                .upload(Self.path(userId: userId, dayKey: dayKey, scanId: scanId),
                        data: data,
                        options: FileOptions(contentType: "image/jpeg", upsert: true))
            removePending(scanId: scanId)
            record?.backedUp = true
        } catch {
            #if DEBUG
            print("[BodyScanSync] upload FAILED scan=\(scanId): \(error) — queued")
            #endif
            addPending(scanId: scanId, dayKey: dayKey, userId: userId)
        }
    }

    func flushPendingUploads(userId: String, in context: ModelContext) async {
        guard backupOn, !userId.isEmpty, !flushInFlight else { return }
        flushInFlight = true
        defer { flushInFlight = false }
        let uid = userId.lowercased()
        let mine = loadPending().filter { $0.userId.lowercased() == uid }
        guard !mine.isEmpty else { return }
        let records = BodyScanStore.all(userId: userId, in: context)
        for item in mine {
            guard BodyScanPhotoStore.photoData(scanId: item.scanId) != nil else {
                removePending(scanId: item.scanId)   // deleted locally meanwhile
                continue
            }
            await upload(scanId: item.scanId, dayKey: item.dayKey, userId: item.userId,
                         record: records.first { $0.id == item.scanId })
        }
    }

    // MARK: Restore (reinstall / new device)

    /// Rebuilds her record from the bucket when backup is on and the
    /// device holds no scans. Bounded by the weekly cadence (~52
    /// objects/yr). Silhouettes re-render on-device.
    func restoreIfEnabled(userId: String, in context: ModelContext) async {
        guard backupOn, !userId.isEmpty, !restoreInFlight,
              BodyScanStore.count(userId: userId, in: context) == 0 else { return }
        restoreInFlight = true
        defer { restoreInFlight = false }

        let objects: [FileObject]
        do {
            objects = try await supabase.storage
                .from(Self.bucket)
                .list(path: userId.lowercased())
        } catch {
            #if DEBUG
            print("[BodyScanSync] restore list FAILED: \(error)")
            #endif
            return
        }

        var restored = 0
        for object in objects {
            // {dayKey}_{scanId}.jpg
            let name = object.name
            guard name.hasSuffix(".jpg") else { continue }
            let stem = String(name.dropLast(4))
            let parts = stem.split(separator: "_", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let (dayKey, scanId) = (parts[0], parts[1])

            do {
                let data = try await supabase.storage
                    .from(Self.bucket)
                    .download(path: "\(userId.lowercased())/\(name)")
                guard let photo = UIImage(data: data) else { continue }
                let silhouette = await Task.detached(priority: .utility) {
                    BodySilhouetteRenderer.render(from: photo)
                }.value
                let capturedAt = Self.noon(of: dayKey) ?? .now
                let record = BodyScanRecord(
                    id: scanId,
                    userId: userId,
                    capturedAt: capturedAt,
                    dayKey: dayKey,
                    poseQuality: 0,   // lost in restore — P2 treats as unknown
                    renderMode: BodyScanStore.renderMode
                )
                record.backedUp = true
                context.insert(record)
                BodyScanPhotoStore.save(photo: photo, silhouette: silhouette, scanId: scanId)
                restored += 1
            } catch {
                continue   // transient — next launch retries
            }
        }
        try? context.save()
        #if DEBUG
        print("[BodyScanSync] restored \(restored)/\(objects.count) scans")
        #endif
    }

    // MARK: Delete

    /// Removes every cloud object under her folder (backup-off +
    /// delete-account paths).
    func deleteAllRemote(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            let objects = try await supabase.storage
                .from(Self.bucket)
                .list(path: userId.lowercased())
            guard !objects.isEmpty else { return }
            let paths = objects.map { "\(userId.lowercased())/\($0.name)" }
            _ = try await supabase.storage.from(Self.bucket).remove(paths: paths)
        } catch {
            #if DEBUG
            print("[BodyScanSync] deleteAllRemote FAILED: \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    private static func path(userId: String, dayKey: String, scanId: String) -> String {
        "\(userId.lowercased())/\(dayKey)_\(scanId.lowercased()).jpg"
    }

    private static func noon(of dayKey: String) -> Date? {
        let f = DateFormatter()
        f.calendar = .current
        f.dateFormat = "yyyy-MM-dd"
        guard let day = f.date(from: dayKey) else { return nil }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day)
    }

    // MARK: - Pending queue (persistent, the food-photos shape)

    private struct PendingUpload: Codable, Equatable {
        let scanId: String
        let dayKey: String
        let userId: String
    }

    private var queueURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("BodyScanSync", isDirectory: true)
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

    private func addPending(scanId: String, dayKey: String, userId: String) {
        var items = loadPending()
        let item = PendingUpload(scanId: scanId, dayKey: dayKey, userId: userId)
        guard !items.contains(item) else { return }
        items.append(item)
        savePending(items)
    }

    private func removePending(scanId: String) {
        let items = loadPending()
        let kept = items.filter { $0.scanId.lowercased() != scanId.lowercased() }
        guard kept.count != items.count else { return }
        savePending(kept)
    }
}
