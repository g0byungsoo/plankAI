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

    /// 2026-08-13 wrote this as "absent-only: the local write is always
    /// the newer fact". 2026-08-14 proved the premise wrong in the field.
    ///
    /// A local write is not "newer" in general — it is newer only until
    /// the server acknowledges it, and `pendingUpsert` is exactly that
    /// bit. Absent-only meant a support repair landed in the local
    /// `UserRecord` and could never reach the `@AppStorage` key the
    /// surfaces read: the database said 110 and the phone said 124, for
    /// as long as the account existed. See `AutymRecoveryTests`.
    ///
    /// The rule is per-record, not per-key.
    func testAnUnsentLocalEditIsNeverOverwritten() {
        d.set(48.0, forKey: "onboardingGoalWeightKg")
        let pending = record()
        pending.pendingUpsert = true
        AppSync.restoreBodyDefaults(from: pending, into: d)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), 48.0, accuracy: 0.001,
            "she changed her goal offline; the server has not heard it yet and does not get to argue")
    }

    func testAServerRepairCorrectsAStaleValueTheDeviceAlreadyHolds() {
        d.set(56.245, forKey: "onboardingGoalWeightKg")   // goal == her weight: the corrupt shape
        let clean = record()                             // support fixed it to 49.895
        clean.pendingUpsert = false
        AppSync.restoreBodyDefaults(from: clean, into: d)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), 49.895, accuracy: 0.001,
            "a record with nothing pending IS server truth; if it disagrees, something newer than this device said so")
    }

    /// The other direction of the same defect: an empty column must not
    /// delete a fact the device holds.
    func testACleanRecordWithAnEmptyColumnDeletesNothing() {
        d.set(49.895, forKey: "onboardingGoalWeightKg")
        let partial = record()
        partial.onboardingGoalWeightKg = nil
        partial.pendingUpsert = false
        AppSync.restoreBodyDefaults(from: partial, into: d)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), 49.895, accuracy: 0.001,
            "NULL means the server never learned it, never that she gave it up")
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
