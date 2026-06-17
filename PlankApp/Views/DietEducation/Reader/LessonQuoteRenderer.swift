import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - LessonQuoteRenderer
//
// v1.0.10 (2026-06-17) — synchronous ImageRenderer wrapper for the
// lesson quote share card. Mirrors the daily / weekly food-share
// renderer contracts (1080×1920, scale 1.0) so the lesson reader's
// share affordance can hand iOS a ready-to-go Story-format PNG with
// no async churn.
//
// MainActor-bound (ImageRenderer requirement). Built to be called
// from the LessonReaderView top-bar share button.

@MainActor
enum LessonQuoteRenderer {

    /// Render the page-as-quote share card. Returns nil only on
    /// memory pressure (rare). Caller should defer the result into
    /// a sheet-driven UIActivityViewController.
    static func render(
        headline: String,
        italicWords: [String],
        bodyLine: String?,
        dayLabel: String,
        pillarTitle: String
    ) -> UIImage? {
        let card = LessonQuoteCard(
            headline: headline,
            italicWords: italicWords,
            bodyLine: bodyLine,
            dayLabel: dayLabel,
            pillarTitle: pillarTitle
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

// MARK: - LessonQuoteShareItem

/// Identifiable wrapper so `.sheet(item:)` can drive the share
/// PNG's lifecycle without re-rendering on every state change.
struct LessonQuoteShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - LessonQuoteShareSheet
//
// Inlined SwiftUI bridge for UIActivityViewController. Kept private
// to the lesson reader area for the same reason the food layer
// inlines its own copy: avoid public API surface bloat on PlankFood
// for what is ultimately a 15-line UIKit wrapper.

struct LessonQuoteShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onComplete() }
        }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#endif  // canImport(UIKit)
