#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - DailyShareRenderer
//
// v1.0.9 D3.C — synchronous ImageRenderer wrapper for the daily 9:16
// share card. Mirrors the existing pattern in
// PhotoCaptureView.renderAllShareableSlides (1080×1920, scale 1.0).
//
// Public API: `render(for:userId:dailyTarget:)` returns a UIImage
// suitable for ShareLink. Build the SwiftUI card with TODAY's logs +
// derived pills, render off-screen, return.
//
// MainActor-bound because ImageRenderer requires it. Call from any
// main-actor context (e.g. FoodLogTimelineView's share button).

@MainActor
public enum DailyShareRenderer {

    /// Build + render the daily 9:16 card for `date`. Pulls today's
    /// logs from FoodLogPersister; computes the pill row from those
    /// totals + the user's dailyTarget. Returns a 1080×1920 UIImage,
    /// or nil if rendering failed (rare — only on memory pressure).
    public static func render(
        for date: Date = Date(),
        userId: String,
        dailyTarget: Double
    ) -> UIImage? {
        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }
        let macros = FoodLogPersister.todayMacros()
        let pills = buildPills(entries: entries, macros: macros, dailyTarget: dailyTarget)

        // Photo-backed polaroids — load each gridded entry's stored
        // photo up front so the offscreen render is synchronous.
        var photos: [String: UIImage] = [:]
        for entry in entries.prefix(4) {
            if let photo = FoodPhotoStore.photo(entryId: entry.id) {
                photos[entry.id] = photo
            }
        }

        let card = DailyShareCard(
            date: date,
            entries: entries,
            photos: photos,
            pillTexts: pills
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }

    /// Derive 2-3 soft pills from real data only (no fabrication per
    /// data-provenance lock). All copy passes the post-Ozempic vocab
    /// filter: no labor verbs, no scale shame, no diet-culture verbs.
    private static func buildPills(
        entries: [FoodLogPersister.FoodLogEntry],
        macros: FoodLogPersister.TodayMacros,
        dailyTarget: Double
    ) -> [String] {
        var pills: [String] = []

        // Protein pill — "on track ♡" when within range of the
        // standard 25%-of-kcal target, "still room" when below 60%.
        // Never "missed it" / "short" register.
        if dailyTarget > 0 {
            let proteinTarget = (dailyTarget * 0.25) / 4
            if proteinTarget > 0 {
                let ratio = macros.protein / proteinTarget
                if ratio >= 0.85 {
                    pills.append("protein on track ♡")
                } else if ratio >= 0.5 {
                    pills.append("building up protein")
                } else if macros.protein > 0 {
                    pills.append("still room for protein")
                }
            }
        }

        // Log count pill — celebrates showing up, not the number.
        if entries.count >= 3 {
            pills.append("logged \(entries.count) ♡")
        } else if entries.count == 2 {
            pills.append("two plates today")
        } else if entries.count == 1 {
            pills.append("one plate, on purpose")
        }

        // Permission pill — anti-diet vocab anchor. Always appended
        // last if we have room (max 3 pills). Lock-in voice signal.
        if pills.count < 3 {
            pills.append("permission ♡")
        }

        return pills
    }
}

#endif  // canImport(UIKit)
