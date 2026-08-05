import XCTest
@testable import plankAI

// v10.4 — the supporting number under test: a real scale reading
// outranks the formula, the formula always renders as a BAND, the
// inputs are honestly required, and nothing is ever derived from a
// photograph (L3 — the provenance strings carry that promise).
final class BodyFatEstimateTests: XCTestCase {

    func testMeasuredReadingWins() throws {
        let read = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: 28.4, weightKg: 70, heightCm: 165,
            ageYears: 34, isFemale: true
        ))
        XCTAssertTrue(read.isMeasured)
        XCTAssertEqual(read.value, "28%")
        XCTAssertTrue(read.provenance.contains("apple health"))
    }

    func testEstimateIsAlwaysABand() throws {
        let read = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: nil, weightKg: 70, heightCm: 165,
            ageYears: 34, isFemale: true
        ))
        XCTAssertFalse(read.isMeasured)
        XCTAssertEqual(read.high - read.low, BodyFatEstimate.estimateBand * 2)
        XCTAssertTrue(read.value.contains("–"), "a point value claims precision it lacks")
        // Deurenberg for BMI 25.7, age 34, female ≈ 33.2
        XCTAssertEqual((read.low + read.high) / 2, 33, accuracy: 1)
    }

    func testSexTermMovesTheEstimate() throws {
        let her = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: nil, weightKg: 80, heightCm: 175, ageYears: 40, isFemale: true))
        let him = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: nil, weightKg: 80, heightCm: 175, ageYears: 40, isFemale: false))
        XCTAssertGreaterThan(her.low, him.low, "the sex term is inverted")
        XCTAssertEqual(her.low - him.low, 11, accuracy: 1)
    }

    func testMissingInputsMeanNoPanel() {
        XCTAssertNil(BodyFatEstimate.read(healthPct: nil, weightKg: nil, heightCm: 165,
                                          ageYears: 30, isFemale: true))
        XCTAssertNil(BodyFatEstimate.read(healthPct: nil, weightKg: 70, heightCm: nil,
                                          ageYears: 30, isFemale: true))
        XCTAssertNil(BodyFatEstimate.read(healthPct: nil, weightKg: 70, heightCm: 165,
                                          ageYears: nil, isFemale: true))
        XCTAssertNil(BodyFatEstimate.read(healthPct: nil, weightKg: 70, heightCm: 165,
                                          ageYears: 30, isFemale: nil),
                     "sex unknown must not be silently assumed")
    }

    func testEstimateNeverDropsBelowEssentialFat() throws {
        let read = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: nil, weightKg: 46, heightCm: 178, ageYears: 19, isFemale: true))
        XCTAssertGreaterThanOrEqual(read.low, 12)
    }

    func testEveryReadCarriesItsHonesty() throws {
        let estimated = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: nil, weightKg: 70, heightCm: 165, ageYears: 34, isFemale: true))
        XCTAssertTrue(estimated.caveat.contains("never read from your photo"))
        XCTAssertFalse(estimated.caveat.isEmpty)
        let measured = try XCTUnwrap(BodyFatEstimate.read(
            healthPct: 30, weightKg: 70, heightCm: 165, ageYears: 34, isFemale: true))
        XCTAssertFalse(measured.caveat.isEmpty)
        // The voice law: the word never appears in user copy.
        for text in [estimated.provenance, estimated.caveat,
                     measured.provenance, measured.caveat] {
            XCTAssertFalse(text.lowercased().contains(" ai "), "AI never speaks in copy")
        }
    }
}
