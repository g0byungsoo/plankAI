import CoreGraphics
import Foundation

// MARK: - SubscriptionPriceBlock
//
// App Store review 2026-08-20, submission b7b6a6d4-914a-44d0-b391-
// 58d18db9aeef, 1.1.7 (32), Guideline 3.1.2(c):
//
//   "The auto-renewable subscription displays the weekly calculated
//    pricing for the subscription more clearly and conspicuously than
//    the billed amount."
//
//   "...ensure that the billed amount is the most clear and conspicuous
//    pricing element in the layout. Any other pricing elements,
//    including free trial, introductory pricing, and calculated pricing
//    information, must be displayed in a subordinate position and size
//    to the total billed amount. Factors that contribute to whether the
//    billed amount is clear and conspicuous include, but are not limited
//    to, the font, size, color, and location."
//
// The rule Apple measures is a TYPOGRAPHY rule, and until now it lived
// inside a SwiftUI view body — four literals (font, size, colour,
// stacking order) with nothing able to read them. That is the §36
// lesson for the third time: a rule inside a view body cannot be
// tested, which is why nobody noticed it was a rule.
//
// So the decision moves here. This type owns WHICH string is dominant
// and WHICH is subordinate; the tier rows render from it and hold no
// pricing literals of their own. SubscriptionPricingHierarchyTests
// pins the invariant, so the next inversion fails a test instead of a
// review.

/// One subscription row's pricing block: the amount actually billed,
/// dominant by construction, with any calculated equivalent beneath it.
struct SubscriptionPriceBlock: Equatable {

    /// A single rendered pricing element and the four attributes Apple
    /// names when it decides what is "clear and conspicuous".
    struct Element: Equatable {
        /// The string as rendered.
        let text: String
        /// Point size at the current density bucket.
        let pointSize: CGFloat
        /// True when drawn in the primary ink; false = a receded tone.
        let usesPrimaryContrast: Bool
        /// True when this element states the amount Apple charges.
        /// Exactly one element in a block may carry this.
        let isBilledAmount: Bool
    }

    /// The billing period a row buys. Its `suffix` rides the billed
    /// amount so the charge and the term are read together.
    enum Period: Equatable {
        case year, quarter, week

        /// Plain-language suffix. Deliberately unabbreviated: a
        /// reviewer should not have to expand "/qtr".
        ///
        /// `compact` is the smallest-phone form. SE filming caught
        /// "$47.99 /ye…" — the charge held its size and the period
        /// truncated, and a truncated term is its own clarity problem.
        /// A short token that fits beats a long one that clips, and it
        /// is only ever used on the bucket that needs it.
        func suffix(compact: Bool) -> String {
            switch self {
            case .year:    return compact ? " /yr"  : " /year"
            case .quarter: return compact ? " /qtr" : " /quarter"
            case .week:    return compact ? " /wk"  : " /week"
            }
        }

        /// How many of this period fit in a year — the divisor for the
        /// calculated weekly equivalent.
        var weeksPerPeriod: Int {
            switch self {
            case .year:    return 52
            case .quarter: return 13
            case .week:    return 1
            }
        }
    }

    /// Rendered first and largest. Always the billed amount.
    let dominant: Element
    /// The period suffix riding `dominant` at caption size.
    let periodSuffix: String
    /// Rendered beneath `dominant`, smaller and receded. nil when the
    /// billed amount already IS the weekly rate (nothing to calculate)
    /// or when the equivalent could not be derived.
    let subordinate: Element?

    // MARK: Type scale
    //
    // One place decides the two sizes, so the ratio cannot drift.

    /// Size of the billed amount, from the row's density bucket.
    static func billedPointSize(base: CGFloat) -> CGFloat { base + 1 }

    /// Size of a calculated equivalent. Held at the caption size the
    /// row's supporting text already uses — roughly half the billed
    /// amount at every bucket, which is the margin that makes the
    /// hierarchy obvious rather than technical.
    static let calculatedPointSize: CGFloat = 11

    // MARK: Construction

    /// Build the block for one tier row.
    ///
    /// - Parameters:
    ///   - billedAmount: the localized charge from StoreKit
    ///     (`storeProduct.localizedPriceString`) — never invented.
    ///   - period: what that charge buys.
    ///   - calculatedWeekly: the localized per-week equivalent, already
    ///     formatted in the product's own currency. Pass nil for the
    ///     weekly tier, and nil whenever it cannot be derived.
    ///   - basePointSize: the row's density-bucket price size.
    ///   - compactPeriod: use the smallest-phone period token. The
    ///     caller passes true on the density bucket whose rows are too
    ///     narrow for the spelled-out word.
    static func make(
        billedAmount: String,
        period: Period,
        calculatedWeekly: String?,
        basePointSize: CGFloat,
        compactPeriod: Bool = false
    ) -> SubscriptionPriceBlock {
        // The weekly tier's billed amount already is its weekly rate;
        // restating it underneath would be a second price for the same
        // number.
        let equivalent: Element? = {
            guard period != .week, let weekly = calculatedWeekly else { return nil }
            return Element(
                text: "\(weekly) a week",
                pointSize: calculatedPointSize,
                usesPrimaryContrast: false,
                isBilledAmount: false
            )
        }()

        return SubscriptionPriceBlock(
            dominant: Element(
                text: billedAmount,
                pointSize: billedPointSize(base: basePointSize),
                usesPrimaryContrast: true,
                isBilledAmount: true
            ),
            periodSuffix: period.suffix(compact: compactPeriod),
            subordinate: equivalent
        )
    }

    /// Spoken form for VoiceOver. The charge leads here too.
    var accessibilityDescription: String {
        var parts = ["\(dominant.text)\(periodSuffix), billed today"]
        if let subordinate { parts.append("about \(subordinate.text)") }
        return parts.joined(separator: ", ")
    }
}
