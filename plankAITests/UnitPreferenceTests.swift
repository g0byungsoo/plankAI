import XCTest
@testable import plankAI

// MARK: - UnitPreferenceTests
//
// THE UNIT SHE CHOSE IS THE UNIT SHE SEES.
//
// Onboarding's rulers carry their own lb/kg toggle and persist the
// answer to `onb_v5_unit_lb` (a Bool). Every weight surface in the
// app — the weigh-in ritual, Becoming's body card, Home's tile, the
// journey read, the visit packet, the insight engine — reads a
// different key, `weightUnit` (a String), which **nothing in
// onboarding ever wrote.** It defaults to "lb".
//
// So a user who typed her weight in kilograms during onboarding met
// pounds on every screen afterwards, with no setting anywhere to
// change it back. The two keys are now one decision.

@MainActor
final class UnitPreferenceTests: XCTestCase {

    private let d = UserDefaults.standard

    override func setUpWithError() throws {
        d.removeObject(forKey: "onb_v5_unit_lb")
        d.removeObject(forKey: "weightUnit")
    }

    override func tearDownWithError() throws {
        d.removeObject(forKey: "onb_v5_unit_lb")
        d.removeObject(forKey: "weightUnit")
    }

    func testChoosingKilogramsInOnboardingMakesTheAppSpeakKilograms() {
        let store = OV5Store.bootFallback
        store.usesLb = true      // establish, then switch
        store.usesLb = false

        XCTAssertEqual(WeightUnit.current, .kg,
            "the unit she picked on the ruler is the unit every weight surface uses")
    }

    func testChoosingPoundsKeepsPounds() {
        let store = OV5Store.bootFallback
        store.usesLb = false
        store.usesLb = true

        XCTAssertEqual(WeightUnit.current, .lb)
    }

    /// US default: an untouched flow still lands on pounds.
    func testDefaultRemainsPounds() {
        XCTAssertEqual(WeightUnit.current, .lb)
    }
}
