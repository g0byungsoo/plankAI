#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HandwrittenDailyShareRenderer
//
// v1.0.10 (2026-06-17) — sync ImageRenderer wrapper for the Pinterest
// it-girl handwritten daily share card. Mirrors DailyShareRenderer's
// contract exactly so the call site can swap renderers with a single
// import switch.

@MainActor
public enum HandwrittenDailyShareRenderer {

    public static func render(
        for date: Date = Date(),
        userId: String,
        archetype: String? = nil
    ) -> UIImage? {
        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }

        var photos: [String: UIImage] = [:]
        for entry in entries.prefix(4) {
            if let photo = FoodPhotoStore.photo(entryId: entry.id) {
                photos[entry.id] = photo
            }
        }

        let card = HandwrittenDailyShareCard(
            date: date,
            entries: entries,
            photos: photos,
            archetype: archetype
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

#endif  // canImport(UIKit)
