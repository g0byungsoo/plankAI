import XCTest
@testable import plankAI

final class ClinicalBaselineTests: XCTestCase {
    func testBMIComputation() throws {
        // 70 kg, 170 cm -> 24.22 kg/m²
        let bmi = try XCTUnwrap(ClinicalBaseline.bmi(weightKg: 70, heightCm: 170))
        XCTAssertEqual(bmi, 24.22, accuracy: 0.05)
    }

    func testBMINilWhenHeightMissing() {
        XCTAssertNil(ClinicalBaseline.bmi(weightKg: 70, heightCm: 0))
    }
}
