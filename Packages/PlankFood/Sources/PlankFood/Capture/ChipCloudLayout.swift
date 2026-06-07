#if canImport(UIKit)
import SwiftUI

// MARK: - ChipCloudLayout
//
// v1.0.7 round 18 (founder feedback: "i also want to show a lot of
// food and restaurant types with very small chip because i don't
// want users to feel there are not many options and this app is
// not complete yet feeling").
//
// SwiftUI Layout protocol implementation for natural-width chips
// that wrap to the next row when they hit the container width.
// LazyVGrid forces uniform column widths which makes
// variable-width chips ("matcha latte" vs "boba" vs "chick-fil-a")
// look ugly. This layout lets each chip be its own natural width.
//
// iOS 16+ (Layout protocol). Cache is unused — chip count is
// small enough (~50-100) that re-measuring on every layout pass
// is cheap.

public struct ChipCloudLayout: Layout {
    public var horizontalSpacing: CGFloat = 6
    public var verticalSpacing: CGFloat = 6

    public init(horizontalSpacing: CGFloat = 6, verticalSpacing: CGFloat = 6) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowIsEmpty = true

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let extraSpacing = rowIsEmpty ? 0 : horizontalSpacing
            if rowWidth + extraSpacing + size.width > maxWidth, !rowIsEmpty {
                // wrap
                totalHeight += rowHeight + verticalSpacing
                rowWidth = size.width
                rowHeight = size.height
                rowIsEmpty = false
            } else {
                rowWidth += extraSpacing + size.width
                rowHeight = max(rowHeight, size.height)
                rowIsEmpty = false
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        var rowIsEmpty = true

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let extraSpacing = rowIsEmpty ? 0 : horizontalSpacing
            if x + extraSpacing + size.width > bounds.maxX, !rowIsEmpty {
                // wrap to next row
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
                rowIsEmpty = true
            }
            subview.place(
                at: CGPoint(x: x + (rowIsEmpty ? 0 : horizontalSpacing), y: y),
                proposal: ProposedViewSize(size)
            )
            x += (rowIsEmpty ? 0 : horizontalSpacing) + size.width
            rowHeight = max(rowHeight, size.height)
            rowIsEmpty = false
        }
    }
}

#endif  // canImport(UIKit)
