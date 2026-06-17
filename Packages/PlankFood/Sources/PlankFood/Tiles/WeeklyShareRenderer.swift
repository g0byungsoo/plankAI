#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - WeeklyShareRenderer
//
// v1.0.10 — synchronous ImageRenderer wrapper for the weekly 9:16
// share card. Mirrors DailyShareRenderer's contract (1080×1920,
// scale 1.0) so the Becoming "share her week" affordance can hand
// iOS a ready-to-go Story-format PNG with no async churn.
//
// Public API: `render(for:userId:)` builds WeeklyShareCard with the
// week's logs + preloaded photos and returns a UIImage. Returns nil
// when the week has zero photo-backed logs (nothing to share = no
// card). Pass an explicit `weekStart` to share a past week; defaults
// to the current week's Sunday.
//
// MainActor-bound (ImageRenderer requirement). Cell selection is
// deterministic so re-renders produce the same collage: up to one
// cell per calendar day, taken in chronological order, capped at 6.

@MainActor
public enum WeeklyShareRenderer {

    /// Render the weekly 9:16 share card for the calendar week
    /// containing `referenceDate`. Returns nil when the week has no
    /// photo-backed food logs (caller should hide the share affordance
    /// in that case so the user doesn't tap into an empty card).
    public static func render(
        for referenceDate: Date = Date(),
        userId: String
    ) -> UIImage? {
        let cal = Calendar.current
        let weekStart = cal.weekStart(for: referenceDate)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? referenceDate

        // Pull the week's entries from FoodLogPersister, filter to the
        // span, and pick the most-recent entry per calendar day with a
        // stored photo. Chronological order means the collage reads
        // top-left (oldest) → bottom-right (newest).
        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= weekStart && $0.loggedAt < weekEnd }

        var perDay: [Date: FoodLogPersister.FoodLogEntry] = [:]
        for entry in entries {
            guard FoodPhotoStore.hasPhoto(entryId: entry.id) else { continue }
            let day = cal.startOfDay(for: entry.loggedAt)
            // Keep the most recent photo-backed entry per day (the
            // user's typical "best plate" of the day tends to be the
            // dinner shot, which lands latest in the timeline).
            if let prior = perDay[day], prior.loggedAt >= entry.loggedAt { continue }
            perDay[day] = entry
        }

        guard !perDay.isEmpty else { return nil }

        let chronological = perDay
            .sorted { $0.key < $1.key }
            .prefix(6)
            .map { (day, entry) in
                WeeklyShareCell(entryId: entry.id, date: day, title: entry.title)
            }

        // Preload photos so the offscreen render is synchronous.
        var photos: [String: UIImage] = [:]
        for cell in chronological {
            if let img = FoodPhotoStore.photo(entryId: cell.entryId) {
                photos[cell.entryId] = img
            }
        }

        let card = WeeklyShareCard(
            weekStart: weekStart,
            cells: Array(chronological),
            photos: photos
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }

    /// True when the user has at least one photo-backed log this week.
    /// Lets the Becoming entry point hide the share button when there's
    /// nothing to share — cheaper than rendering then noticing the nil.
    public static func hasShareableWeek(
        for referenceDate: Date = Date(),
        userId: String
    ) -> Bool {
        let cal = Calendar.current
        let weekStart = cal.weekStart(for: referenceDate)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? referenceDate
        return FoodLogPersister.allEntries(userId: userId)
            .contains { entry in
                entry.loggedAt >= weekStart
                    && entry.loggedAt < weekEnd
                    && FoodPhotoStore.hasPhoto(entryId: entry.id)
            }
    }
}

// MARK: - Calendar.weekStart helper

private extension Calendar {
    /// First day of the calendar week containing `date`. The system
    /// `dateInterval(of: .weekOfYear, for:)` returns the week start
    /// at midnight (local), which matches what we want — Sunday or
    /// Monday depending on the user's locale.
    func weekStart(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start
            ?? startOfDay(for: date)
    }
}

#endif  // canImport(UIKit)
