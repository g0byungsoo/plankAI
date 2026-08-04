import Foundation
import SwiftData
import UIKit
import PlankSync

// MARK: - BodyScanStore
//
// app v9 P1 — the record layer over BodyScanRecord + its images.
// @MainActor enum service (house law — no class singletons in the
// app target). One scan per day is the ritual's grain: a re-scan
// on the same day replaces that day's record + images; history
// across days is never rewritten (the ObservationStore stance).
//
// Preferences live under the `bodyScan.` prefix, which rides the
// sign-out sweep as a family (AppSync.scopedPrefixes — L4).

@MainActor
enum BodyScanStore {

    static let consentSeenKey = "bodyScan.consentSeen"
    static let renderModeKey = "bodyScan.renderMode"
    static let backupOnKey = "bodyScan.backupOn"

    /// Backup seam (D3) — fired after a scan is kept. Wired by
    /// AppSync to the opt-in mirror; nil (tests, previews) = no
    /// cloud anywhere.
    static var onScanKept: ((BodyScanRecord) -> Void)?

    /// Cross-surface change signal (the weightLogDidChange pattern):
    /// becoming's body page recomposes the moment a scan lands or
    /// leaves, without waiting for a relaunch.
    static let didChange = Notification.Name("bodyScanDidChange")

    /// "silhouette" unless she explicitly chose the photo (D2:
    /// silhouette-first, photo opt-in).
    static var renderMode: String {
        UserDefaults.standard.string(forKey: renderModeKey) ?? "silhouette"
    }

    static var consentSeen: Bool {
        UserDefaults.standard.bool(forKey: consentSeenKey)
    }

    static func recordConsent(renderMode mode: String) {
        UserDefaults.standard.set(true, forKey: consentSeenKey)
        UserDefaults.standard.set(mode, forKey: renderModeKey)
    }

    // MARK: - Records

    /// Persists a kept scan: replaces the same-day record (one per
    /// day), saves both image derivatives, returns the record.
    @discardableResult
    static func keep(
        photo: UIImage,
        silhouette: UIImage,
        poseQuality: Double,
        userId: String,
        in context: ModelContext,
        capturedAt: Date = .now,
        anchors: (top: Double, bottom: Double, centerX: Double)? = nil
    ) -> BodyScanRecord? {
        guard !userId.isEmpty else { return nil }
        let dayKey = TodayStateService.dayKey(for: capturedAt)
        if let existing = all(userId: userId, in: context)
            .first(where: { $0.dayKey == dayKey }) {
            BodyScanPhotoStore.delete(scanId: existing.id)
            context.delete(existing)
        }
        let record = BodyScanRecord(
            userId: userId,
            capturedAt: capturedAt,
            dayKey: dayKey,
            poseQuality: poseQuality,
            renderMode: renderMode
        )
        if let anchors {
            record.figureTopY = anchors.top
            record.figureBottomY = anchors.bottom
            record.figureCenterX = anchors.centerX
        }
        context.insert(record)
        try? context.save()
        BodyScanPhotoStore.save(photo: photo, silhouette: silhouette, scanId: record.id)
        onScanKept?(record)
        NotificationCenter.default.post(name: didChange, object: nil)
        return record
    }

    /// Newest-first.
    static func all(userId: String, in context: ModelContext) -> [BodyScanRecord] {
        let descriptor = FetchDescriptor<BodyScanRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func latest(userId: String, in context: ModelContext) -> BodyScanRecord? {
        all(userId: userId, in: context).first
    }

    static func count(userId: String, in context: ModelContext) -> Int {
        all(userId: userId, in: context).count
    }

    /// The ritual's anchor: her scans repeat on the weekday of the
    /// latest scan (the shot-day anchor pattern — no ask needed).
    /// nil before the first scan; batch B's invitation defaults the
    /// first offer to Sunday.
    static func anchorWeekday(userId: String, in context: ModelContext) -> Int? {
        latest(userId: userId, in: context).map {
            Calendar.current.component(.weekday, from: $0.capturedAt)
        }
    }

    static func delete(_ record: BodyScanRecord, in context: ModelContext) {
        BodyScanPhotoStore.delete(scanId: record.id)
        context.delete(record)
        try? context.save()
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Delete-account: records + every image, together (L4).
    static func deleteAll(userId: String, in context: ModelContext) {
        for record in all(userId: userId, in: context) {
            context.delete(record)
        }
        try? context.save()
        BodyScanPhotoStore.deleteAllFiles()
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
