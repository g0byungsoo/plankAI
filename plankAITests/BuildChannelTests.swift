import XCTest
@testable import plankAI

// v25 E8 — the runtime build channel.
//
// The bug this pins: TestFlight compiles as RELEASE, so a compile-time
// `#if DEBUG` split labelled every internal tester "production". These
// assert the three-way classification and — the row that matters — that
// a TestFlight install is never counted as a customer.

final class BuildChannelTests: XCTestCase {

    // MARK: - the table

    func testDebugBuildIsDebugRegardlessOfReceipt() {
        // A debug build may carry any receipt (or none); the compile
        // flag wins, because Xcode-run builds are unambiguously ours.
        XCTAssertEqual(
            BuildChannel.resolve(receiptName: "sandboxReceipt", isDebugBuild: true), .debug
        )
        XCTAssertEqual(
            BuildChannel.resolve(receiptName: "receipt", isDebugBuild: true), .debug
        )
        XCTAssertEqual(
            BuildChannel.resolve(receiptName: nil, isDebugBuild: true), .debug
        )
    }

    func testSandboxReceiptIsTestFlight() {
        XCTAssertEqual(
            BuildChannel.resolve(receiptName: "sandboxReceipt", isDebugBuild: false),
            .testflight
        )
    }

    func testSandboxDetectionIsCaseInsensitive() {
        // The exact casing is convention, not contract.
        for name in ["SandboxReceipt", "sandboxreceipt", "SANDBOXRECEIPT"] {
            XCTAssertEqual(
                BuildChannel.resolve(receiptName: name, isDebugBuild: false),
                .testflight,
                "\(name) should classify as TestFlight"
            )
        }
    }

    func testAppStoreReceiptIsProduction() {
        XCTAssertEqual(
            BuildChannel.resolve(receiptName: "receipt", isDebugBuild: false),
            .appStore
        )
    }

    func testMissingReceiptIsTreatedAsAppStore() {
        // The conservative call: a release build with no receipt yet is
        // a real install that has not talked to the store. Classifying
        // it as a tester would shrink the production denominator, which
        // is the exact failure this type exists to prevent.
        XCTAssertEqual(
            BuildChannel.resolve(receiptName: nil, isDebugBuild: false),
            .appStore
        )
    }

    // MARK: - what analytics reads

    func testEnvironmentValuePreservesTheHistoricalProductionString() {
        // This change SPLITS a value; it must not rename one, or every
        // existing PostHog insight filtering `environment == production`
        // silently empties.
        XCTAssertEqual(BuildChannel.appStore.environmentValue, "production")
        XCTAssertEqual(BuildChannel.debug.environmentValue, "debug")
        XCTAssertEqual(BuildChannel.testflight.environmentValue, "testflight")
    }

    func testOnlyAppStoreIsNotATestUser() {
        XCTAssertTrue(BuildChannel.debug.isTestUser)
        XCTAssertTrue(BuildChannel.testflight.isTestUser)
        XCTAssertFalse(BuildChannel.appStore.isTestUser)
    }

    /// The whole point, stated once: an internal tester and a paying
    /// customer must not be the same row.
    func testTestFlightAndAppStoreAreDistinguishable() {
        let tester  = BuildChannel.resolve(receiptName: "sandboxReceipt", isDebugBuild: false)
        let customer = BuildChannel.resolve(receiptName: "receipt", isDebugBuild: false)
        XCTAssertNotEqual(tester, customer)
        XCTAssertNotEqual(tester.environmentValue, customer.environmentValue)
        XCTAssertTrue(tester.isTestUser)
        XCTAssertFalse(customer.isTestUser)
    }

    // MARK: - hygiene

    func testChannelValuesAreCategorical() {
        // AnalyticsHygiene rejects free text. Three lowercase tokens,
        // no interpolation, no identifiers.
        let all: [BuildChannel] = [.debug, .testflight, .appStore]
        let values = Set(all.map(\.environmentValue))
        XCTAssertEqual(values.count, 3, "channels must not collide")
        for v in values {
            XCTAssertEqual(v, v.lowercased())
            XCTAssertFalse(v.contains(" "))
            XCTAssertTrue(v.count < 20)
        }
    }
}
