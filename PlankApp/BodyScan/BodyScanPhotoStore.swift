import UIKit

// MARK: - BodyScanPhotoStore
//
// app v9 P1 — Body Vision's on-device image store, cloned from the
// FoodPhotoStore shape at scan fidelity. Two derivatives per scan id:
// the source photo ({id}.jpg, long-edge 1600, EXIF-free by
// re-render) and the ink-on-paper silhouette ({id}.sil.png,
// long-edge 1200). BOTH always exist — renderMode is a surface
// preference, never a storage fact.
//
// Privacy posture (docs/app_v9 L4/D3): the directory is excluded
// from iCloud backup and NOTHING here touches the network. The
// dormant `onPhotoPersisted` seam is where the OPT-IN private-bucket
// mirror attaches (P1 batch B); until she flips that toggle, these
// bytes never leave the device — and the store itself stays
// Supabase-blind either way.

enum BodyScanPhotoStore {

    /// Batch-B backup seam (default: nil = no cloud anywhere).
    /// Fired with the photo JPEG bytes after a save or rekey.
    static var onPhotoPersisted: ((_ scanId: String, _ data: Data) -> Void)?

    private static let photoMaxDimension: CGFloat = 1600
    private static let silhouetteMaxDimension: CGFloat = 1200

    private static var directory: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("BodyScans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableDir = dir
            try? mutableDir.setResourceValues(values)
        }
        return dir
    }

    private static func photoURL(_ scanId: String) -> URL? {
        directory?.appendingPathComponent("\(scanId).jpg")
    }
    private static func silhouetteURL(_ scanId: String) -> URL? {
        directory?.appendingPathComponent("\(scanId).sil.png")
    }

    /// Persists both derivatives. The photo re-renders through
    /// UIGraphicsImageRenderer, which strips EXIF (no location, no
    /// device metadata rides a body photo — L4).
    static func save(photo: UIImage, silhouette: UIImage, scanId: String) {
        if let url = photoURL(scanId),
           let data = resized(photo, maxDimension: photoMaxDimension)
               .jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
            onPhotoPersisted?(scanId, data)
        }
        if let url = silhouetteURL(scanId),
           let data = resized(silhouette, maxDimension: silhouetteMaxDimension)
               .pngData() {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func photo(scanId: String) -> UIImage? {
        guard let url = photoURL(scanId),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Raw JPEG bytes — the backup queue reads through this so a
    /// deferred upload sends the exact bytes on disk.
    static func photoData(scanId: String) -> Data? {
        guard let url = photoURL(scanId) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func silhouette(scanId: String) -> UIImage? {
        guard let url = silhouetteURL(scanId),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// The face she chose for surfaces; falls back across
    /// derivatives so a record never renders empty.
    static func image(scanId: String, preferring renderMode: String) -> UIImage? {
        if renderMode == "photo" {
            return photo(scanId: scanId) ?? silhouette(scanId: scanId)
        }
        return silhouette(scanId: scanId) ?? photo(scanId: scanId)
    }

    static func delete(scanId: String) {
        if let url = photoURL(scanId) { try? FileManager.default.removeItem(at: url) }
        if let url = silhouetteURL(scanId) { try? FileManager.default.removeItem(at: url) }
    }

    /// Sign-in merge re-keys records to fresh ids; the images follow
    /// (file moves, lossless). Mirrors FoodPhotoStore.rekey.
    static func rekey(from oldId: String, to newId: String) {
        guard oldId != newId else { return }
        for (src, dst) in [(photoURL(oldId), photoURL(newId)),
                           (silhouetteURL(oldId), silhouetteURL(newId))] {
            guard let src, let dst,
                  FileManager.default.fileExists(atPath: src.path) else { continue }
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.moveItem(at: src, to: dst)
        }
        if let dst = photoURL(newId), let data = try? Data(contentsOf: dst) {
            onPhotoPersisted?(newId, data)
        }
    }

    /// Delete-account wipes the whole directory (paired with the
    /// record purge in BodyScanStore.deleteAll — L4 same-commit law).
    static func deleteAllFiles() {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir)
        _ = directory   // recreate empty + re-apply backup exclusion
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        guard scale < 1 else { return image }
        let target = CGSize(width: image.size.width * scale,
                            height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
