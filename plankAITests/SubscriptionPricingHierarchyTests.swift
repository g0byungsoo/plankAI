import XCTest
@testable import plankAI

// MARK: - SubscriptionPricingHierarchyTests
//
// App Store review 2026-08-20, submission b7b6a6d4-914a-44d0-b391-
// 58d18db9aeef, 1.1.7 (32), Guideline 3.1.2(c). Apple measured the
// tier rows and found the calculated weekly rate louder than the
// charge:
//
//   "The auto-renewable subscription displays the weekly calculated
//    pricing for the subscription more clearly and conspicuously than
//    the billed amount."
//
// THE INVARIANT, stated once:
//
//   ON EVERY PURCHASE SURFACE, FOR EVERY PLAN, THE AMOUNT APPLE
//   CHARGES IS THE DOMINANT PRICING ELEMENT — first in reading order,
//   largest in size, strongest in contrast. Every calculated
//   equivalent is subordinate on all three counts.
//
// The live products at the time of review: year $49.99 · quarter
// $29.99 · week $5.99. Those are the fixtures below, so the numbers
// in this file are the numbers the reviewer saw.

final class SubscriptionPricingHierarchyTests: XCTestCase {

    /// The density bucket iPhone 17 Pro Max renders — Apple's review
    /// device. `metrics(forHeight:)`'s `else` branch, tierPriceSize 21.
    private let reviewDeviceBase: CGFloat = 21
    /// The smallest supported phone (iPhone SE 3rd gen), tierPriceSize 19.
    private let smallestPhoneBase: CGFloat = 19

    private func year(base: CGFloat) -> SubscriptionPriceBlock {
        .make(billedAmount: "$49.99", period: .year,
              calculatedWeekly: "$0.96", basePointSize: base)
    }
    private func quarter(base: CGFloat) -> SubscriptionPriceBlock {
        .make(billedAmount: "$29.99", period: .quarter,
              calculatedWeekly: "$2.31", basePointSize: base)
    }
    private func week(base: CGFloat) -> SubscriptionPriceBlock {
        .make(billedAmount: "$5.99", period: .week,
              calculatedWeekly: nil, basePointSize: base)
    }

    private func allPlans(base: CGFloat) -> [(String, SubscriptionPriceBlock)] {
        [("year", year(base: base)),
         ("quarter", quarter(base: base)),
         ("week", week(base: base))]
    }

    // MARK: The rejection, inverted into a rule

    /// THE 3.1.2(c) ROW. For every plan, on every device bucket, the
    /// dominant element must be the charge — not a derived rate.
    func testTheDominantPriceIsAlwaysTheBilledAmount() {
        for base in [reviewDeviceBase, smallestPhoneBase] {
            for (name, block) in allPlans(base: base) {
                XCTAssertTrue(
                    block.dominant.isBilledAmount,
                    "\(name) @\(base): the dominant price is '\(block.dominant.text)', "
                    + "which is not the billed amount. Guideline 3.1.2(c)."
                )
            }
        }
    }

    /// The exact strings, so a refactor cannot quietly swap them.
    func testTheDominantTextIsTheChargeItself() {
        XCTAssertEqual(year(base: reviewDeviceBase).dominant.text, "$49.99")
        XCTAssertEqual(quarter(base: reviewDeviceBase).dominant.text, "$29.99")
        XCTAssertEqual(week(base: reviewDeviceBase).dominant.text, "$5.99")
    }

    /// The period is read with the charge, never separated from it.
    func testEachChargeCarriesItsPeriod() {
        XCTAssertEqual(year(base: reviewDeviceBase).periodSuffix, " /year")
        XCTAssertEqual(quarter(base: reviewDeviceBase).periodSuffix, " /quarter")
        XCTAssertEqual(week(base: reviewDeviceBase).periodSuffix, " /week")
    }

    /// The smallest phone gets a period token that FITS. SE filming
    /// caught "$47.99 /ye…" on the first cut of this fix: the charge
    /// held its size and the term clipped, which is a clarity problem
    /// of its own. Short, but never absent — and never on a bucket
    /// that has room for the word.
    func testTheSmallestPhoneGetsAPeriodThatFits() {
        for (plan, compact, full) in [
            (SubscriptionPriceBlock.Period.year,    " /yr",  " /year"),
            (SubscriptionPriceBlock.Period.quarter, " /qtr", " /quarter"),
            (SubscriptionPriceBlock.Period.week,    " /wk",  " /week"),
        ] {
            XCTAssertEqual(plan.suffix(compact: true), compact)
            XCTAssertEqual(plan.suffix(compact: false), full)
            XCTAssertFalse(plan.suffix(compact: true).isEmpty,
                           "a compact period must still name the term")
        }
    }

    /// Compacting the period changes nothing about the hierarchy.
    func testTheCompactFormKeepsTheChargeDominant() {
        let block = SubscriptionPriceBlock.make(
            billedAmount: "$49.99", period: .year,
            calculatedWeekly: "$0.96",
            basePointSize: smallestPhoneBase, compactPeriod: true
        )
        XCTAssertTrue(block.dominant.isBilledAmount)
        XCTAssertEqual(block.dominant.text, "$49.99")
        XCTAssertEqual(block.periodSuffix, " /yr")
        XCTAssertEqual(block.subordinate?.text, "$0.96 a week")
        XCTAssertLessThan(block.subordinate!.pointSize, block.dominant.pointSize)
    }

    // MARK: Subordination, on Apple's own three axes

    /// SIZE. Apple names size first. A one-point difference is not a
    /// hierarchy — the calculated rate must be decisively smaller.
    func testCalculatedEquivalentsAreDecisivelySmaller() {
        for base in [reviewDeviceBase, smallestPhoneBase] {
            for (name, block) in allPlans(base: base) {
                guard let sub = block.subordinate else { continue }
                XCTAssertLessThan(
                    sub.pointSize, block.dominant.pointSize,
                    "\(name) @\(base): '\(sub.text)' is not smaller than the charge."
                )
                XCTAssertLessThanOrEqual(
                    sub.pointSize, block.dominant.pointSize * 0.6,
                    "\(name) @\(base): '\(sub.text)' at \(sub.pointSize)pt against a "
                    + "\(block.dominant.pointSize)pt charge is a technical difference, "
                    + "not a visible hierarchy. Guideline 3.1.2(c)."
                )
            }
        }
    }

    /// COLOR. The charge takes the primary ink; the equivalent recedes.
    func testTheChargeHoldsTheStrongerContrast() {
        for base in [reviewDeviceBase, smallestPhoneBase] {
            for (name, block) in allPlans(base: base) {
                XCTAssertTrue(block.dominant.usesPrimaryContrast,
                              "\(name): the charge is not in the primary ink.")
                if let sub = block.subordinate {
                    XCTAssertFalse(sub.usesPrimaryContrast,
                                   "\(name): '\(sub.text)' competes with the charge for contrast.")
                }
            }
        }
    }

    /// LOCATION. Exactly one element may claim to be the charge, and
    /// a calculated rate may never be it.
    func testOnlyOneElementClaimsToBeTheCharge() {
        for base in [reviewDeviceBase, smallestPhoneBase] {
            for (name, block) in allPlans(base: base) {
                if let sub = block.subordinate {
                    XCTAssertFalse(
                        sub.isBilledAmount,
                        "\(name): '\(sub.text)' is marked as a billed amount but is a "
                        + "calculated equivalent."
                    )
                }
            }
        }
    }

    // MARK: Arithmetic and absence

    /// The weekly tier's charge already IS its weekly rate, so there is
    /// nothing to restate underneath it. Two prices for one number is
    /// the ambiguity 3.1.2(c) exists to prevent.
    func testTheWeeklyTierPublishesNoSecondPrice() {
        XCTAssertNil(week(base: reviewDeviceBase).subordinate,
                     "the weekly row carries a second price beneath its charge")
    }

    /// An unresolved equivalent must drop the line, never invent one.
    func testAMissingEquivalentSimplyDoesNotRender() {
        let block = SubscriptionPriceBlock.make(
            billedAmount: "$49.99", period: .year,
            calculatedWeekly: nil, basePointSize: reviewDeviceBase
        )
        XCTAssertNil(block.subordinate)
        XCTAssertEqual(block.dominant.text, "$49.99")
    }

    /// The equivalent reads as an approximation of a week, not as a
    /// charge with its own term.
    func testTheEquivalentIsWordedAsAnApproximation() {
        XCTAssertEqual(year(base: reviewDeviceBase).subordinate?.text, "$0.96 a week")
        XCTAssertEqual(quarter(base: reviewDeviceBase).subordinate?.text, "$2.31 a week")
    }

    /// VoiceOver hears the charge first, for the same reason the eye
    /// sees it first.
    func testTheSpokenFormLeadsWithTheCharge() {
        let spoken = year(base: reviewDeviceBase).accessibilityDescription
        XCTAssertTrue(spoken.hasPrefix("$49.99 /year, billed today"),
                      "spoken form led with something other than the charge: \(spoken)")
    }
}
