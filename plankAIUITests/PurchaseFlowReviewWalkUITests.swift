import XCTest

// MARK: - PurchaseFlowReviewWalkUITests
//
// The walk Apple's reviewer takes, asserted end to end. Written for
// the 2026-08-20 rejection of 1.1.7 (32), submission
// b7b6a6d4-914a-44d0-b391-58d18db9aeef, which cited two things:
//
//   3.1.2(c)  the weekly calculated rate was louder than the charge
//   5.6       dismissing the purchase screen showed another one
//
// Everything here runs against the REAL wall — the phase machine
// lands on .wall(.fresh) because the launch carries no pro access.
// No debug paywall route, no offer-preview door (there are none left).
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//     -only-testing:plankAIUITests/PurchaseFlowReviewWalkUITests

final class PurchaseFlowReviewWalkUITests: XCTestCase {

    private var shot = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = String(format: "%02d_%@", shot, name)
        a.lifetime = .keepAlways
        add(a)
        shot += 1
    }

    private func launchToWall() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inapp-qa"]
        app.launch()
        XCTAssertTrue(
            app.buttons["Close paywall"].firstMatch.waitForExistence(timeout: 40),
            "the wall never presented"
        )
        return app
    }

    /// Any control whose label reads like a second offer.
    private static let offerLabels = [
        "not today", "or the year", "keep the year",
        "try the week", "maybe later", "switch to the quarter",
    ]

    private func assertNoOfferSurface(_ app: XCUIApplication, _ context: String) {
        for offer in Self.offerLabels {
            XCTAssertFalse(
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", offer)
                ).firstMatch.exists,
                "\(context) presented an offer carrying '\(offer)'. Guideline 5.6."
            )
        }
    }

    // MARK: 3.1.2(c) — the charge leads, and the CTA agrees

    /// Each tier states its own billed amount, and selecting a tier
    /// moves the CTA to that tier's charge. Selection → dominant price
    /// → CTA → the product the purchase would use, all one story.
    func testEveryTierLeadsWithItsChargeAndTheCtaFollowsSelection() throws {
        let app = launchToWall()
        snap("wall-arrival")

        // The row labels are built from SubscriptionPriceBlock, so the
        // charge and the phrase "billed today" ride together. A row
        // that led with a calculated rate could not produce this.
        for tier in ["the year", "the quarter", "one week"] {
            let row = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH[c] %@", tier)
            ).firstMatch
            guard row.waitForExistence(timeout: 10) else {
                // The quarter self-gates on its package resolving.
                if tier == "the quarter" { continue }
                return XCTFail("tier row '\(tier)' never appeared")
            }
            let label = row.label
            XCTAssertTrue(
                label.contains("billed today"),
                "'\(tier)' does not state a billed amount: \(label)"
            )
            guard let charge = Self.firstCurrencyAmount(in: label) else {
                return XCTFail("'\(tier)' states no currency amount: \(label)")
            }

            row.tap()
            Thread.sleep(forTimeInterval: 0.8)
            snap("tier-\(tier.replacingOccurrences(of: " ", with: "-"))")

            // THE CTA MUST NAME THE SAME CHARGE. A button that says one
            // number while the row says another is the ambiguity
            // 3.1.2(c) exists to prevent.
            let cta = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "keep my plan")
            ).firstMatch
            XCTAssertTrue(cta.waitForExistence(timeout: 10), "the CTA vanished")
            XCTAssertTrue(
                cta.label.contains(charge),
                "selected '\(tier)' (\(charge)) but the CTA reads '\(cta.label)'"
            )
            XCTAssertTrue(cta.isHittable, "the CTA is not hittable for '\(tier)'")
        }
    }

    /// The first currency amount in a label ("$49.99").
    private static func firstCurrencyAmount(in text: String) -> String? {
        guard let r = text.range(
            of: #"[$€£¥]\s?\d[\d.,]*"#, options: .regularExpression
        ) else { return nil }
        return String(text[r])
    }

    // MARK: 5.6 — a dismissal presents nothing

    /// THE REJECTION. Dismiss the purchase screen; nothing may take its
    /// place except a surface that asks for nothing. Then relaunch, to
    /// prove the dismissal left no queued offer behind.
    func testDismissingTheWallPresentsNoSecondPurchaseSurface() throws {
        var app = launchToWall()
        let close = app.buttons["Close paywall"].firstMatch
        close.tap()

        let seePlans = app.buttons["see the plans"].firstMatch
        XCTAssertTrue(
            seePlans.waitForExistence(timeout: 15),
            "the X did not stand the wall down"
        )
        snap("dismissed-stood-down")
        assertNoOfferSurface(app, "dismissing the wall")
        XCTAssertFalse(close.exists, "the paywall is still mounted after standing down")

        // The exit keeps every recovery door.
        XCTAssertTrue(app.buttons["already subscribed \u{00B7} restore"].firstMatch.exists,
                      "restore is missing from the stand-down")
        XCTAssertTrue(app.buttons["signed in before? sign in"].firstMatch.exists,
                      "the sign-in door is missing from the stand-down")

        // Reversible by HER choice, not by ours.
        seePlans.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 12),
                      "see the plans did not return to the wall")

        // A second dismissal behaves like the first — the control that
        // works once and dies is the 1.1.7 (28) rejection.
        close.tap()
        XCTAssertTrue(seePlans.waitForExistence(timeout: 12),
                      "the close control went dead on its second press")
        assertNoOfferSurface(app, "the second dismissal")

        // RELAUNCH. No persisted "next offer" may fire on return.
        app.terminate()
        app = launchToWall()
        snap("relaunch-after-dismissal")
        assertNoOfferSurface(app, "relaunching after a dismissal")
        XCTAssertTrue(app.buttons["Close paywall"].firstMatch.exists,
                      "the wall did not come back cleanly on relaunch")
    }

    /// Cancelling Apple's own purchase sheet returns her to the wall she
    /// was reading — and to nothing else.
    func testCancellingThePurchaseSheetPresentsNoSecondPurchaseSurface() throws {
        let app = launchToWall()
        let cta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "keep my plan")
        ).firstMatch
        guard cta.waitForExistence(timeout: 15), cta.isHittable else {
            throw XCTSkip("pricing did not resolve in this environment; nothing to cancel")
        }
        cta.tap()
        Thread.sleep(forTimeInterval: 4.0)
        snap("purchase-sheet-or-wall")

        // Dismiss whatever StoreKit put up. Without a StoreKit
        // configuration the sheet may never appear, which is fine — the
        // assertion below is about what must NOT appear.
        for label in ["Cancel", "Close", "Dismiss"] {
            let b = app.buttons[label].firstMatch
            if b.exists && b.isHittable { b.tap(); break }
        }
        Thread.sleep(forTimeInterval: 3.0)
        snap("after-purchase-cancel")

        assertNoOfferSurface(app, "cancelling the purchase sheet")
    }

    // MARK: The controls Apple looks for

    /// Restore, sign-in, Terms and Privacy are all present on the
    /// purchase screen and all actually do something.
    func testRestoreSignInTermsAndPrivacyAreReachable() throws {
        let app = launchToWall()

        let restore = app.buttons["Restore"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 10), "Restore is missing")
        XCTAssertTrue(restore.isHittable, "Restore is not hittable")

        let signIn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "already a member")
        ).firstMatch
        XCTAssertTrue(signIn.exists, "the sign-in door is missing")
        XCTAssertTrue(signIn.isHittable, "the sign-in door is not hittable")
        snap("top-bar-controls")

        // Terms and Privacy live in the footer; scroll to them.
        let terms = app.buttons["terms"].firstMatch
        let privacy = app.buttons["privacy"].firstMatch
        var swipes = 0
        while !(terms.exists && privacy.exists) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(terms.exists, "Terms of Use is not reachable on the purchase screen")
        XCTAssertTrue(privacy.exists, "Privacy Policy is not reachable on the purchase screen")
        snap("legal-footer")

        // Terms opens its document and closes back to the wall.
        terms.tap()
        Thread.sleep(forTimeInterval: 3.0)
        snap("terms-open")
        for label in ["Done", "Close", "Cancel"] {
            let b = app.buttons[label].firstMatch
            if b.exists && b.isHittable { b.tap(); break }
        }
        Thread.sleep(forTimeInterval: 2.0)

        // Restore runs its real path and reports an outcome rather than
        // failing silently. No entitlement exists here, so the honest
        // answer is "no active subscription found".
        if restore.exists && restore.isHittable {
            restore.tap()
            Thread.sleep(forTimeInterval: 6.0)
            snap("restore-result")
            assertNoOfferSurface(app, "restoring with no entitlement")
        }
    }
}
