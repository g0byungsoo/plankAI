import XCTest
@testable import PlankFood

@MainActor
final class FoodFlagsTests: XCTestCase {

    // MARK: - Fixtures

    private final class MockEntitlement: FoodFlagsEntitlementProvider {
        var hasProAccess: Bool
        init(hasProAccess: Bool) { self.hasProAccess = hasProAccess }
    }

    override func setUp() async throws {
        try await super.setUp()
        // Always start with a clean slate. Each test sets what it needs.
        FoodFlags.entitlement = nil
        UserDefaults.standard.removeObject(forKey: FoodFlags.devOverrideKey)
    }

    override func tearDown() async throws {
        FoodFlags.entitlement = nil
        UserDefaults.standard.removeObject(forKey: FoodFlags.devOverrideKey)
        try await super.tearDown()
    }

    // MARK: - Layer #1 — DEBUG override

    #if DEBUG
    func testDevOverrideForcesOnEvenWithoutEntitlement() {
        // Layer #1 short-circuits to true regardless of layers #2 + #3.
        UserDefaults.standard.set(true, forKey: FoodFlags.devOverrideKey)

        XCTAssertNil(FoodFlags.entitlement)
        XCTAssertTrue(FoodFlags.isEnabled,
                      "DEBUG override should short-circuit to true even with no entitlement provider configured")
    }

    func testDevOverrideForcesOnWithEntitlementOff() {
        UserDefaults.standard.set(true, forKey: FoodFlags.devOverrideKey)
        FoodFlags.entitlement = MockEntitlement(hasProAccess: false)

        XCTAssertTrue(FoodFlags.isEnabled,
                      "DEBUG override should short-circuit to true even when entitlement is off")
    }

    func testDevOverrideOffFallsThroughToOtherLayers() {
        UserDefaults.standard.set(false, forKey: FoodFlags.devOverrideKey)
        FoodFlags.entitlement = nil

        // Override is false + no entitlement = layer #2 fails = isEnabled false.
        XCTAssertFalse(FoodFlags.isEnabled)
    }
    #endif

    // MARK: - Layer #2 — Paid entitlement

    func testIsEnabledFalseWhenEntitlementNotConfigured() {
        // configure() never called -> safe default false.
        XCTAssertNil(FoodFlags.entitlement)
        // Override is also off (setUp cleared it), so this exercises
        // layer #2 explicitly.
        XCTAssertFalse(FoodFlags.isEnabled)
    }

    func testIsEnabledFalseWhenEntitlementIsOff() {
        FoodFlags.entitlement = MockEntitlement(hasProAccess: false)

        XCTAssertFalse(FoodFlags.isEnabled,
                       "Non-paid user should never see food rail regardless of PostHog flag")
    }

    // MARK: - Configure

    func testConfigureSetsEntitlement() {
        let entitlement = MockEntitlement(hasProAccess: true)
        FoodFlags.configure(entitlement: entitlement)

        XCTAssertNotNil(FoodFlags.entitlement)
        XCTAssertTrue(FoodFlags.entitlement?.hasProAccess ?? false)
    }

    // MARK: - Constants

    func testFlagNameMatchesPostHogConfiguration() {
        // If someone renames this without coordinating with the PostHog
        // dashboard, the food rail silently stops gating. Pin the value.
        XCTAssertEqual(FoodFlags.postHogFlagName, "food_rail_v1")
    }

    func testDevOverrideKeyMatchesDebugAuthView() {
        // DebugAuthView writes to this exact key. If renamed here, the
        // QA toggle stops working silently.
        XCTAssertEqual(FoodFlags.devOverrideKey, "food_rail_dev_override")
    }
}
