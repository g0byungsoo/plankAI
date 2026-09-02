import XCTest
@testable import plankAI

// p66 — THE CELEBRATION SHOWER's physics pins. The shower is the
// full-page confetti volley behind the moment page; these pin the
// properties the filmed bake-off decided, so a tuning pass cannot
// silently un-decide them.
final class JeniBurstShowerTests: XCTestCase {

    func testShowerIsDeterministicPerSeed() {
        let a = JeniBurst.particles(tier: .moment, mode: .shower, seed: 42)
        let b = JeniBurst.particles(tier: .moment, mode: .shower, seed: 42)
        XCTAssertEqual(a.count, b.count)
        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.vx, y.vx)
            XCTAssertEqual(x.vy, y.vy)
            XCTAssertEqual(x.birth, y.birth)
        }
    }

    func testSparkTierHasNoShower() {
        // The frequency law by construction: several-times-a-day acts
        // never earn the full-page volley.
        XCTAssertTrue(JeniBurst.particles(tier: .spark, mode: .shower, seed: 7).isEmpty)
    }

    func testShowerScalesWithRarity() {
        let crest = JeniBurst.particles(tier: .crest, mode: .shower, seed: 7).count
        let moment = JeniBurst.particles(tier: .moment, mode: .shower, seed: 7).count
        XCTAssertGreaterThan(crest, 0)
        XCTAssertGreaterThan(moment, crest, "the lifetime tier must outscale the daily one")
    }

    func testShowerLaunchesUpFromTheBottomEdge() {
        for p in JeniBurst.particles(tier: .moment, mode: .shower, seed: 3) {
            XCTAssertLessThan(p.vy, 0, "a cannon fleck launches upward")
            XCTAssertGreaterThan(p.originY, 1.0, "the volley starts just below the page")
            XCTAssertTrue((0.0...1.0).contains(p.originX))
        }
    }

    func testPopFieldIsUntouchedByTheShower() {
        // p64's word-anchored pop is a settled, filmed decision — the
        // shower must not have changed its field.
        for p in JeniBurst.particles(tier: .moment, mode: .pop, seed: 9) {
            XCTAssertEqual(p.originX, 0.5)
            XCTAssertEqual(p.originY, 0.5)
            XCTAssertEqual(p.sway, 0)
        }
    }
}
