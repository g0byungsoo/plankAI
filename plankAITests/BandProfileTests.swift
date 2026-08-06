import XCTest
import UIKit
@testable import plankAI

// v10.4 — the progress read under test: the profile measures ink
// width per row; the read speaks only in words, keeps a noise floor,
// never scolds a fuller week, and refuses plates it can't vouch for.
final class BandProfileTests: XCTestCase {

    /// An ink-on-paper plate built as the engine reads one: three
    /// stacked thirds (ribs / navel / lower abdomen), each a centered
    /// ink block of the given width fraction.
    private func plate(
        top: CGFloat, middle: CGFloat? = nil, lower: CGFloat? = nil,
        size: CGSize = CGSize(width: 300, height: 150)
    ) -> UIImage {
        let thirds = [top, middle ?? top, lower ?? top]
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 252/255, green: 250/255, blue: 247/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 42/255, green: 31/255, blue: 30/255, alpha: 1).setFill()
            for (i, frac) in thirds.enumerated() where frac > 0 {
                let w = size.width * frac
                ctx.fill(CGRect(x: (size.width - w) / 2,
                                y: size.height * CGFloat(i) / 3,
                                width: w,
                                height: size.height / 3))
            }
        }
    }

    func testProfileMeasuresRowWidths() throws {
        let profile = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.5)))
        XCTAssertEqual(profile.widths.count, BandProfile.rows)
        XCTAssertEqual(profile.middle, 0.5, accuracy: 0.06)
        XCTAssertTrue(profile.isReadable)
    }

    func testEmptyPaperIsNotReadable() throws {
        let profile = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.0)))
        XCTAssertFalse(profile.isReadable, "blank paper must never speak")
        XCTAssertNil(BandProfile.read(now: profile, then: profile))
    }

    func testThirdsAreReadIndependently() throws {
        // Wide at the ribs, narrow at the lower abdomen.
        let profile = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.6, middle: 0.45, lower: 0.3)))
        XCTAssertGreaterThan(profile.upper, profile.middle)
        XCTAssertGreaterThan(profile.middle, profile.lower)
    }

    func testLeanerWaistLeadsTheRead() throws {
        let then = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.60)))
        let now = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.50)))
        let read = try XCTUnwrap(BandProfile.read(now: now, then: then))
        XCTAssertTrue(read.headline.contains("leaner"), "got: \(read.headline)")
        XCTAssertTrue(read.confident)
        XCTAssertEqual(read.region, .middle, "the plate must know where to look")
        // L3: the words carry no number.
        XCTAssertFalse(read.headline.contains("%"))
        XCTAssertNil(read.headline.rangeOfCharacter(from: .decimalDigits))
    }

    func testSmallDriftIsTheSameWeek() throws {
        let then = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.500)))
        let now = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.505)))
        let read = try XCTUnwrap(BandProfile.read(now: now, then: then))
        XCTAssertTrue(read.headline.contains("same"), "got: \(read.headline)")
    }

    func testHoldingShapeSpeaksWithAFallingScale() throws {
        let same = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.5)))
        let read = try XCTUnwrap(BandProfile.read(now: same, then: same, trendFalling: true))
        XCTAssertTrue(read.headline.contains("holding"), "got: \(read.headline)")
    }

    func testFullerWeekIsNeverScolded() throws {
        let then = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.45)))
        let now = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.58)))
        let read = try XCTUnwrap(BandProfile.read(now: now, then: then))
        XCTAssertTrue(read.headline.contains("fuller"), "got: \(read.headline)")
        XCTAssertFalse(read.confident, "a fuller week always carries its caveat")
        XCTAssertNil(read.region, "a fuller week is never pointed at")
        let all = ([read.headline] + read.notes).joined(separator: " ")
        for scold in ["gained", "worse", "backwards", "slipped", "failed"] {
            XCTAssertFalse(all.contains(scold), "the anti-shame floor broke on: \(scold)")
        }
    }

    func testLowerAbdomenCanLeadOnItsOwn() throws {
        let then = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.5)))
        let now = try XCTUnwrap(BandProfile.profile(of: plate(top: 0.5, middle: 0.5, lower: 0.40)))
        let read = try XCTUnwrap(BandProfile.read(now: now, then: then))
        XCTAssertTrue(read.headline.contains("lower abdomen"), "got: \(read.headline)")
        XCTAssertEqual(read.region, .lower)
    }
}
