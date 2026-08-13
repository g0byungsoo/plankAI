import XCTest
import PlankSync
@testable import plankAI

// MARK: - BodyInputsRestoreTests
//
// THE RESTORE HOLE.
//
// `AppSync.clearOnboardingUserDefaults()` sweeps `onboardingHeightCm`,
// `onboardingCurrentWeightKg`, `onboardingGoalWeightKg` and
// `onboardingGender` on sign-out / account switch / delete — correctly,
// because they are identity-scoped body data and leaking them to the
// next account on a shared device would be worse.
//
// `syncUserDefaultsFromUserRecord` then restores fifteen keys after
// hydrate — name, motivation, age band, activity, barriers, focus
// area, plank time, session length, body focus, notification prefs,
// enrollment flags — and **not those four**, even though `UserRecord`
// carries all four and syncs them to Supabase.
//
// So the returning payer (new phone, restore purchase, or just
// sign-out/sign-in) comes back with:
//
//   heightCm  = 0   → TargetsService.calorieTarget guards on
//                     `heightCm > 100` and returns nil. No energy
//                     number at all, silently.
//   goalKg    = 0   → no goal; two views used to default it to 60 kg.
//   sex       = ""  → BMR falls to the conservative female formula.
//
// The record on the server knew all of it the whole time.

@MainActor
final class BodyInputsRestoreTests: XCTestCase {

    private let d = UserDefaults.standard
    private static let keys = [
        "onboardingHeightCm", "onboardingCurrentWeightKg",
        "onboardingGoalWeightKg", "onboardingGender",
    ]

    override func setUpWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
    }

    override func tearDownWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
    }

    private func record() -> UserRecord {
        let r = UserRecord(id: "restore-test", name: "maya")
        r.onboardingHeightCm = 160.02
        r.onboardingCurrentWeightKg = 56.245
        r.onboardingGoalWeightKg = 49.895
        r.onboardingGender = "female"
        return r
    }

    /// The four body inputs the energy math runs on must come back.
    func testHydrateRestoresTheBodyInputsTheEnergyMathNeeds() {
        AppSync.restoreBodyDefaults(from: record(), into: d)

        XCTAssertEqual(d.double(forKey: "onboardingHeightCm"), 160.02, accuracy: 0.001)
        XCTAssertEqual(d.double(forKey: "onboardingCurrentWeightKg"), 56.245, accuracy: 0.001)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), 49.895, accuracy: 0.001)
        XCTAssertEqual(d.string(forKey: "onboardingGender"), "female")
    }

    /// A returning payer must get her calorie target back, not silence.
    func testCalorieTargetSurvivesASignInRoundTrip() {
        d.set("walks", forKey: "onb_v4_movement_baseline")
        d.set("loss", forKey: "program_mode")
        defer { d.removeObject(forKey: "onb_v4_movement_baseline")
                d.removeObject(forKey: "program_mode") }

        // Post-sweep: no body data at all.
        XCTAssertNil(
            TargetsService.calorieTarget(plan: nil, latestWeightKg: 56.245, defaults: d),
            "with height swept there is genuinely nothing to state"
        )

        AppSync.restoreBodyDefaults(from: record(), into: d)

        let kcal = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: 56.245, defaults: d
        )
        XCTAssertNotNil(kcal, "after hydrate the target must come back")
    }

    /// Restoring must never overwrite a value the device already holds
    /// with a stale server one — the local write is the newer fact
    /// (she may have just changed her goal offline).
    func testRestoreNeverOverwritesAValueAlreadyOnTheDevice() {
        d.set(48.0, forKey: "onboardingGoalWeightKg")
        AppSync.restoreBodyDefaults(from: record(), into: d)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), 48.0, accuracy: 0.001)
    }

    /// A record with nothing to say must not write zeros over absence.
    func testEmptyRecordWritesNothing() {
        let blank = UserRecord(id: "blank", name: "")
        AppSync.restoreBodyDefaults(from: blank, into: d)
        for key in Self.keys {
            XCTAssertNil(d.object(forKey: key), "\(key) must stay absent")
        }
    }
}
