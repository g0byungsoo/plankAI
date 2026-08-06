import UIKit

// MARK: - FoodPhotoStore
//
// v1.1 Becoming dashboard — persists a small thumbnail of each scanned
// plate so her own photos can render on the Becoming filmstrip + the
// food log timeline. Forward-only: entries logged before this shipped
// simply have no photo (the filmstrip collapses when empty — never a
// placeholder).
//
// 2026-07-25 photo cloud backup — thumbnails now ALSO mirror to the
// user's private Supabase Storage space (food-photos bucket, per-user
// RLS) via the `onPhotoPersisted` seam below, so a reinstall or device
// switch no longer loses every plate photo. The store itself stays
// Supabase-blind: the app layer registers the closure and owns the
// network. The local directory REMAINS excluded from iCloud backup on
// purpose — the cloud mirror is the durability layer now, and letting
// iCloud back up the same JPEGs would double-spend the user's quota
// for no added safety.

public enum FoodPhotoStore {

    /// Fired after a thumbnail lands on disk, with the raw JPEG bytes
    /// that were written. Registered by the main app at launch (nil =
    /// cloud backup disabled — tests, previews); the app layer uploads
    /// to the user's private cloud space. Also fired by `rekey` under
    /// the NEW entry id so a sign-in merge re-uploads the photo at the
    /// path the signed-in account owns.
    public static var onPhotoPersisted: ((_ entryId: String, _ data: Data) -> Void)?

    /// Long-edge cap for stored thumbnails. 480pt covers the 56pt
    /// filmstrip and the 9:16 share card at 3x without storing the
    /// full camera frame (~40KB/photo vs ~3MB).
    private static let maxDimension: CGFloat = 480

    private static var directory: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("FoodPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableDir = dir
            try? mutableDir.setResourceValues(values)
        }
        return dir
    }

    private static func url(for entryId: String) -> URL? {
        directory?.appendingPathComponent("\(entryId).jpg")
    }

    static func save(_ image: UIImage, entryId: String) {
        guard let url = url(for: entryId) else { return }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale,
                            height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = thumb.jpegData(compressionQuality: 0.7) else { return }
        do {
            try data.write(to: url, options: .atomic)
            onPhotoPersisted?(entryId, data)
        } catch {
            // Local write failed — nothing on disk, nothing to mirror.
        }
    }

    /// 2026-07-25 photo cloud backup — write an already-encoded JPEG
    /// (a thumbnail downloaded from the user's cloud space) straight to
    /// disk. No re-encode, and deliberately NO `onPhotoPersisted` fire:
    /// this is the download path, and echoing it back into the upload
    /// seam would ping-pong every hydrated photo.
    public static func store(_ data: Data, entryId: String) {
        guard let url = url(for: entryId) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Raw JPEG bytes for an entry's thumbnail, nil when none exists.
    /// The upload retry queue reads through this so a deferred upload
    /// sends the exact bytes on disk instead of a decode + re-encode.
    public static func photoData(entryId: String) -> Data? {
        guard let url = url(for: entryId) else { return nil }
        return try? Data(contentsOf: url)
    }

    public static func photo(entryId: String) -> UIImage? {
        guard let url = url(for: entryId),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    public static func hasPhoto(entryId: String) -> Bool {
        guard let url = url(for: entryId) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// v1.1.1 (2026-06-19) — remove the thumbnail for a single
    /// entry. Called from `FoodLogPersister.deleteEntry`. Silent
    /// no-op when the file doesn't exist (the store is forward-
    /// only — pre-v1.1 entries never had a photo).
    ///
    /// Before this, the JSONL row went away but the JPEG lingered
    /// on disk indefinitely — a privacy regression (user thinks
    /// she wiped her food diary; she didn't) and a slow disk leak.
    public static func delete(entryId: String) {
        guard let url = url(for: entryId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Move a thumbnail from one entry id to another. The sign-in merge
    /// re-keys anonymous entries to fresh ids (so the cloud push is a
    /// clean INSERT the new account owns instead of an RLS-rejected
    /// UPDATE); the photo is keyed by entry id, so it has to follow. A
    /// file move, not a decode/re-encode — lossless and cheap. No-op when
    /// the source has no photo (forward-only store).
    public static func rekey(from oldId: String, to newId: String) {
        guard oldId != newId,
              let src = url(for: oldId),
              let dst = url(for: newId),
              FileManager.default.fileExists(atPath: src.path) else { return }
        try? FileManager.default.removeItem(at: dst)   // defensive; dst is a fresh id
        try? FileManager.default.moveItem(at: src, to: dst)
        // 2026-07-25 — announce the photo under its NEW id so the app
        // layer re-uploads it to the path the signed-in account owns
        // (the old account's cloud object is unreachable to the new
        // uid under RLS).
        if let data = try? Data(contentsOf: dst) {
            onPhotoPersisted?(newId, data)
        }
    }

    /// v1.1.1 — wipe the whole photo directory. Wired into
    /// `FoodLogPersister.deleteAllEntries` so the delete-account
    /// path actually wipes plate photos too. Recreates an empty
    /// directory afterward so subsequent saves still land.
    public static func deleteAll() {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir)
        // Touch the directory back into existence + re-apply the
        // backup exclusion (cheap; happens once per delete-account).
        _ = directory
    }
}
