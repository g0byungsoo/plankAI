import XCTest
@testable import plankAI

// MARK: - PurchaseDismissalInvariantTests
//
// App Store review 2026-08-20, submission b7b6a6d4-914a-44d0-b391-
// 58d18db9aeef, 1.1.7 (32), Guideline 5.6 — Developer Code of Conduct:
//
//   "The app attempts to manipulate customers into making unwanted
//    In-App Purchases. Specifically, after we dismissed the purchase
//    screen, another one was displayed."
//
// THE INVARIANT, stated once:
//
//   DISMISSING A PURCHASE SURFACE MAY NOT PRESENT ANOTHER ONE.
//
// The RED artifact for this file ran against `WallExitIntent`, the pure
// rule that used to answer a dismissal with an offer: 3 tests, 8
// failures, the first of them the reviewer's exact path ("A plain
// dismissal produced smallerStep — a second purchase surface"). The
// controls passed: a wall whose offer budget was already spent stood
// down correctly even then, which is precisely why the defect survived
// a previous 5.6 pass — the SPENT state was compliant and the FRESH
// state, the one a reviewer meets, was not.
//
// That rule no longer exists, so the invariant cannot be pinned by
// calling it. It is pinned the way p54 pinned the notification
// chokepoint instead: a SOURCE SWEEP. The machinery is gone, and these
// tests fail the moment anyone types it back.

final class PurchaseDismissalInvariantTests: XCTestCase {

    /// Repo root, derived from this file's own path.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)      // …/plankAITests/ThisFile.swift
            .deletingLastPathComponent()     // …/plankAITests
            .deletingLastPathComponent()     // …/
    }

    private func source(_ relative: String) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every `.swift` under the shipping app target.
    private func shippingSources() throws -> [(path: String, text: String)] {
        let root = repoRoot.appendingPathComponent("PlankApp")
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            out.append((url.path.replacingOccurrences(of: repoRoot.path + "/", with: ""), text))
        }
        return out
    }

    // MARK: The surfaces are gone

    /// The three deleted files. A dismissal cannot present a screen
    /// that does not exist.
    func testTheDismissalOfferSurfacesAreDeleted() {
        for gone in [
            "PlankApp/Views/Paywall/SmallerStepSheet.swift",     // "what if it was just a week?"
            "PlankApp/Views/Paywall/DownsellPaywallView.swift",  // the discounted year
            "PlankApp/App/WallExitIntent.swift",                 // the rule that chose between them
        ] {
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: repoRoot.appendingPathComponent(gone).path
                ),
                "\(gone) is back. A dismissal must not have an offer to present. Guideline 5.6."
            )
        }
    }

    /// …and nothing anywhere in the app target CONSTRUCTS or CALLS
    /// them, in DEBUG or out of it. A QA door that presents an offer
    /// sheet is still an offer sheet in the tree.
    ///
    /// The sweep matches use, not mention: several files carry a note
    /// saying what was deleted and why, and that record should survive.
    func testNoShippingSourceUsesADeletedOfferSurface() throws {
        let bannedUses = [
            "SmallerStepSheet(",       // construction
            "DownsellPaywallView(",
            "WallExitIntent.",         // the rule being consulted
            "WallExitIntent(",
        ]
        for (path, text) in try shippingSources() {
            for banned in bannedUses {
                XCTAssertFalse(
                    text.contains(banned),
                    "\(path) uses `\(banned)`. Guideline 5.6."
                )
            }
        }
    }

    // MARK: The wall answers a dismissal with nothing

    /// WallView holds no state that can present a purchase surface, and
    /// its dismissal callbacks reach `standDown()` and nothing else.
    func testWallViewCannotPresentAnOfferAfterDismissal() throws {
        let wall = try source("PlankApp/App/WallView.swift")

        // The presentation state that drove the chain.
        for banned in [
            "showingDownsell",
            "showingSmallerStep",
            "yearQueuedAfterSave",
            "triggerExitIntent",
            "downsellShownOnce",
            "smallerStepShownOnce",
            "onReclaimDownsell",
        ] {
            XCTAssertFalse(
                wall.contains(banned),
                "WallView still carries `\(banned)` — the dismissal chain. Guideline 5.6."
            )
        }

        // The X leaves the buy surface. Nothing else.
        XCTAssertTrue(
            wall.contains("onDismiss: { standDown() }"),
            "the wall's dismissal no longer routes straight to standDown()"
        )

        // Cancelling Apple's own sheet records the abandon and stops.
        XCTAssertTrue(
            wall.contains("Analytics.track(.paywallTransactionAbandoned"),
            "the cancel path stopped reporting the abandon"
        )
    }

    /// A dismissal must not schedule anything either. A sheet presented
    /// one runloop later is the same sheet.
    func testTheWallSchedulesNothingOnADismissal() throws {
        let wall = try source("PlankApp/App/WallView.swift")
        for deferral in ["asyncAfter", "DispatchQueue.main.async", "Task.sleep"] {
            XCTAssertFalse(
                wall.contains(deferral),
                "WallView defers work via `\(deferral)`; a delayed presentation is still a "
                + "presentation. Guideline 5.6."
            )
        }
    }

    // MARK: The paywall itself offers no second door

    /// PaywallView's dismissal is a plain callback with no offer
    /// routing, and the reclaim row (whose only unlock was the
    /// auto-shown downsell) is gone with it.
    func testPaywallViewHasNoReclaimDoor() throws {
        let paywall = try source("PlankApp/Views/Paywall/PaywallView.swift")
        for banned in ["reclaimRow", "onReclaimDownsell", "downsellUnlocked"] {
            XCTAssertFalse(
                paywall.contains(banned),
                "PaywallView still carries `\(banned)`. Guideline 5.6."
            )
        }
    }

    // MARK: The stand-down is an exit, not a sales floor

    /// Where a dismissal actually lands. It must state no price and
    /// make no offer — and it must keep the recovery doors, so leaving
    /// the wall is never a trap.
    func testTheStandDownStatesNoPriceAndMakesNoOffer() throws {
        let wall = try source("PlankApp/App/WallView.swift")
        guard let start = wall.range(of: "struct StandDownView: View"),
              let end = wall.range(of: "// MARK: - ExpiredWelcomeView")
        else { return XCTFail("StandDownView not found in WallView.swift") }
        let standDown = String(wall[start.lowerBound..<end.lowerBound])

        for priceMark in ["localizedPriceString", "storeProduct", "SubscriptionPriceBlock",
                          "per year", "per week", "per quarter", "/wk", "today"] {
            XCTAssertFalse(
                standDown.contains(priceMark),
                "the stand-down screen quotes `\(priceMark)` — it must ask for nothing."
            )
        }
        // A literal currency amount: `$` followed by a digit. A bare
        // `$` is a SwiftUI binding, which is why this is a pattern and
        // not a substring.
        XCTAssertNil(
            standDown.range(of: #"\$\d"#, options: .regularExpression),
            "the stand-down screen prints a currency amount — it must ask for nothing."
        )
        XCTAssertTrue(standDown.contains("see the plans"),
                      "the stand-down lost its way back to the plans")
        XCTAssertTrue(standDown.contains("already subscribed \u{00B7} restore"),
                      "the stand-down lost Restore")
        XCTAssertTrue(standDown.contains("signed in before? sign in"),
                      "the stand-down lost the sign-in door")
    }
}
