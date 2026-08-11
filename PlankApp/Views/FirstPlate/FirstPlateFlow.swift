import SwiftUI
import SwiftData
import PlankFood
import Auth

// MARK: - FirstPlateFlow (v25 E5 — THE FIRST PLATE)
//
// The one real thing Jeni does before she asks for money.
//
// docs/app_v25/17_E5_DECISION.md is why. Across three shipping builds
// 6-10% of everyone who finishes onboarding ever reached one screen of
// the product; the rest were asked to buy a coach they had never met.
//
// Bounded on purpose: ONE invite → the REAL capture flow → the wall.
// Not a free tier, not a free day, not a free tab. Everything inside is
// the shipping pipeline — `CaptureFlowView` (whose consent sheet still
// satisfies Apple 5.1.2(i)), the real vision EF, the real
// `FoodLogPersister`. Nothing here is a demo, which is the whole point:
// the plate she logs is in her record when she pays.
//
// The flow owns no state beyond "which beat" — the outcome is stamped
// into `FirstPlateState` and the phase machine routes on it.

struct FirstPlateFlow: View {

    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared
    @State private var beat: Beat = .invite

    /// Plates already on file when the capture opened. The capture flow
    /// dismisses the same way whether she logged or backed out, so the
    /// record itself is the only honest witness.
    @State private var platesBefore = 0

    private enum Beat { case invite, capture }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            switch beat {
            case .invite:
                FirstPlateInvite(
                    floorG: proteinFloorG,
                    onStart: startCapture,
                    onSkip: skip
                )
                .transition(JFPageTransition.softDissolve)

            case .capture:
                if let userId = auth.currentUser?.id.uuidString {
                    CaptureFlowView(
                        userId: userId,
                        cuisineProfile: cuisineProfile,
                        onDismiss: captureClosed
                    )
                    .transition(.opacity)
                } else {
                    // Unreachable: `.proof` only derives once auth is
                    // ready. Defensive — never strand her on a blank.
                    Color.clear.onAppear { skip() }
                }
            }
        }
        .animation(Motion.crossFade, value: beat)
        .onAppear {
            Analytics.track("first_plate_offered", properties: [
                "has_floor": proteinFloorG != nil,
            ])
        }
    }

    // MARK: - Her floor
    //
    // The SAME formula Today, Becoming, the reading and chat render —
    // TargetsService is the one source. Nil when no weight is on file,
    // and a nil floor renders a plain invite rather than a guessed
    // number (provenance law).

    private var proteinFloorG: Int? {
        let stored = UserDefaults.standard
            .double(forKey: "onboardingCurrentWeightKg")
        guard stored > 0 else { return nil }
        return TargetsService.proteinTargetG(
            weightKg: stored, careProtocol: CareProtocolStore.current
        )
    }

    /// E4 fixed the threading bug that stranded this at CaptureFlowView;
    /// the proof beat passes it the same way every other caller does.
    private var cuisineProfile: String? {
        let csv = UserDefaults.standard.string(forKey: "onb_food_cuisines") ?? ""
        return csv.isEmpty ? nil : csv
    }

    // MARK: - Beats

    private func startCapture() {
        platesBefore = plateCountToday
        Analytics.track("first_plate_started")
        beat = .capture
    }

    /// The capture flow dismisses on "log it", on close, and on a
    /// declined consent sheet alike. Ask the record what happened
    /// rather than trusting the callback.
    private func captureClosed() {
        if plateCountToday > platesBefore {
            Analytics.track("first_plate_completed")
            FirstPlateState.markLogged()
        } else {
            Analytics.track("first_plate_skipped", properties: ["at": "capture"])
            FirstPlateState.markSkipped()
        }
        // The phase machine re-derives off the stamped outcome and
        // hands over to the wall.
        NotificationCenter.default.post(name: .firstPlateResolved, object: nil)
    }

    private func skip() {
        Analytics.track("first_plate_skipped", properties: ["at": "invite"])
        FirstPlateState.markSkipped()
        NotificationCenter.default.post(name: .firstPlateResolved, object: nil)
    }

    /// Her own plates only — `allEntries(userId:)` is the user-scoped
    /// read (the unscoped variants sum every account on the device).
    private var plateCountToday: Int {
        guard let userId = auth.currentUser?.id.uuidString else { return 0 }
        return FoodLogPersister.allEntries(userId: userId).count
    }
}

extension Notification.Name {
    /// The proof beat is over (logged or skipped). RootView re-derives.
    static let firstPlateResolved = Notification.Name("e5.firstPlateResolved")
}
