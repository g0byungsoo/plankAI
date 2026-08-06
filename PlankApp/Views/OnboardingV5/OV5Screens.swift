import SwiftUI

// MARK: - OnboardingV5Flow (host)
//
// The v5 flow host. Owns: the persistent Grainfield atmosphere (one
// surface end to end — never mix flat bgPrimary with an atmosphere
// screen per the seam rule), the act chrome, the founder-approved
// afterimage cross-dissolve between screens, the reveal handoff, and
// the exact v4.5 completion pipeline (assemble → reveal → refresh →
// onComplete).

struct OnboardingV5Flow: View {
    let onComplete: (OnboardingData) -> Void
    /// v8 Stage A — the typed entry seam. `.consumer` is today's
    /// only live context; `.clinicEnrollment` exists as a type so
    /// the future clinic door threads HERE (org consent, paywall
    /// skip, assigned protocol) without forking the machine.
    /// Nothing reads it yet; nothing clinic-shaped renders.
    var context: OnboardingContext = .consumer

    @State private var flow = OV5Flow()
    @State private var showReveal = false
    @State private var pendingData: OnboardingData? = nil
    @State private var showSignInSheet = false

    var body: some View {
        ZStack {
            GrainfieldBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if !flow.current.hidesChrome {
                    OV5TopBar(
                        canGoBack: flow.canGoBack,
                        act: flow.progress.act,
                        fraction: flow.progress.fraction,
                        eyebrow: OV5Step.eyebrow(
                            forAct: flow.progress.act,
                            persona: flow.store.persona
                        ),
                        onBack: { flow.back() }
                    )
                    .transition(.opacity)
                }

                ZStack {
                    screen(for: flow.current)
                        .id(flow.current)
                        .transition(JFPageTransition.softDissolve)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(Motion.crossFade, value: flow.current.hidesChrome)
        .onAppear {
            flow.onQuestionsComplete = { beginReveal() }
            UserDefaults.standard.set(true, forKey: "onb_v5_seen")
            // v6 release pass — canonical funnel start (once per
            // install; remounts never re-fire).
            V6Funnel.track("onboarding_started", once: true)
        }
        .fullScreenCover(isPresented: $showReveal) {
            OnboardingRevealView(
                bodyFocus: [],
                sessionLengthKey: sessionLengthKey,
                voicePreference: "encouraging",
                commitmentDaysKey: commitmentDaysKey,
                currentWeightKg: flow.store.currentWeightKg,
                goalWeightKg: flow.store.goalWeightKg,
                onRevealComplete: { completeAfterReveal() },
                // v5 already ran the disclaimer (signature screen) and
                // the safety gate (care cluster) — start at the loader.
                skipsPreamble: true
            )
        }
        .sheet(isPresented: $showSignInSheet) {
            NavigationStack {
                SignInPromptView(onContinue: {
                    showSignInSheet = false
                    if !AuthService.shared.isAnonymous {
                        // Recovering an existing account: skip onboarding,
                        // AppSync hydrates from the cloud.
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                }, mode: .signIn)
                .background(Palette.bgPrimary)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { showSignInSheet = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .accessibilityLabel("Close sign in")
                    }
                }
            }
        }
    }

    // MARK: completion pipeline (v4.5 contract, byte-for-byte semantics)

    private var sessionLengthKey: String {
        switch flow.store.derivedSessionMinutes {
        case 20: return "twenty"
        case 15: return "fifteen"
        default: return "ten"
        }
    }
    private var commitmentDaysKey: String {
        switch flow.store.derivedCommitmentDays {
        case 3: return "three"
        case 7: return "seven"
        default: return "five"
        }
    }

    private func beginReveal() {
        Analytics.track(.onboardingComplete, properties: [
            "user_goal": flow.store.legacyGoal,
            "body_focus_count": 0,
            "coach": "encouraging",
            "onb_version": "v5",
        ])
        // v6 release pass — the hold-to-build seal = personalization
        // complete (once; a re-entry from a killed reveal never
        // re-fires).
        V6Funnel.track("personalization_completed", once: true)
        pendingData = flow.store.assembleData()
        showReveal = true
    }

    private func completeAfterReveal() {
        guard var data = pendingData else { showReveal = false; return }
        pendingData = nil
        // The reveal's PacePicker + NudgePermissionAsk wrote canonical
        // keys AFTER assembly — refresh the derived fields so the stored
        // plan matches what she committed to (v4.5 onRevealComplete).
        data.commitmentDaysPerWeek = flow.store.derivedCommitmentDays
        data.sessionLengthMinutes = flow.store.derivedSessionMinutes
        let d = UserDefaults.standard
        let bucket = d.string(forKey: "plankTime") ?? ""
        let notifsOn = d.bool(forKey: "notificationsEnabled")
        if !bucket.isEmpty { data.plankTime = bucket }
        data.notificationsEnabled = notifsOn
        data.notificationTime = notifsOn ? OV5Store.reminderTime(fromBucket: bucket) : nil
        showReveal = false
        onComplete(data)
    }

    // MARK: registry

    @ViewBuilder
    private func screen(for step: OV5Step) -> some View {
        switch step {
        // act i
        case .welcome:
            OV5WelcomeCollage(
                onBegin: { flow.advance() },
                onSignIn: { showSignInSheet = true }
            )
        case .antiShame: OV5AntiShameScreen(flow: flow)
        case .outcome: OV5OutcomeScreen(flow: flow)
        case .attribution: OV5AttributionScreen(flow: flow)
        case .credibility: OV5CredibilityScreen(flow: flow)
        case .name: OV5NameScreen(flow: flow)
        // act ii
        case .glp1Status: OV5Glp1StatusScreen(flow: flow)
        case .glp1Phase: OV5Glp1PhaseScreen(flow: flow)
        case .appetiteRhythm: OV5AppetiteRhythmScreen(flow: flow)
        case .shotDay: OV5ShotDayScreen(flow: flow)
        case .muscleMath: OV5MuscleMathScreen(flow: flow)
        case .stopWindow: OV5StopWindowScreen(flow: flow)
        case .appetiteReturn: OV5AppetiteReturnScreen(flow: flow)
        case .regainTruth: OV5RegainTruthScreen(flow: flow)
        case .consideringAgency: OV5ConsideringScreen(flow: flow)
        case .foodRelationship: OV5FoodRelationshipScreen(flow: flow)
        case .foodNoise: OV5FoodNoiseScreen(flow: flow)
        case .preEat: OV5PreEatScreen(flow: flow)
        case .snapDemo: OV5SnapDemoScreen(store: flow.store, onAdvance: { flow.advance() })
        case .eatingCadence: OV5EatingCadenceScreen(flow: flow)
        case .proteinRule: OV5ProteinRuleScreen(flow: flow)
        case .cuisine: OV5CuisineScreen(flow: flow)
        case .dietary: OV5DietaryScreen(flow: flow)
        case .supports: OV5SupportsScreen(flow: flow)
        case .receiptFood: OV5FoodReceiptScreen(flow: flow)
        // act iii
        case .numbersBridge: OV5NumbersBridgeScreen(flow: flow)
        case .movement: OV5MovementScreen(flow: flow)
        case .sleep: OV5SleepScreen(flow: flow)
        case .stress: OV5StressScreen(flow: flow)
        case .gender: OV5GenderScreen(flow: flow)
        case .age: OV5AgeScreen(flow: flow)
        case .height: OV5HeightScreen(flow: flow)
        case .weight: OV5WeightScreen(flow: flow)
        case .weightTrend: OV5WeightTrendScreen(flow: flow)
        case .goalDirection: OV5GoalDirectionScreen(flow: flow)
        case .goalWeight: OV5GoalWeightScreen(flow: flow)
        case .targetReframe: OV5TargetReframeScreen(flow: flow)
        case .nsv: OV5NsvScreen(flow: flow)
        case .careBridge: OV5CareBridgeScreen(flow: flow)
        case .medication: OV5MedicationScreen(flow: flow)
        case .safetyGate: OV5SafetyGateScreen(flow: flow)
        case .receiptNumbers: OV5NumbersReceiptScreen(flow: flow)
        // act iv
        case .identity: OV5IdentityScreen(flow: flow)
        case .hormonal: OV5HormonalScreen(flow: flow)
        case .startedOver: OV5StartedOverScreen(flow: flow)
        case .dataMirror: OV5DataMirrorScreen(flow: flow)
        case .fear1: OV5FearScreen(flow: flow, index: 0)
        case .fear2: OV5FearScreen(flow: flow, index: 1)
        case .fear3: OV5FearScreen(flow: flow, index: 2)
        case .whyItCameBack: OV5WhyItCameBackScreen(flow: flow)
        case .receiptCarry: OV5CarryReceiptScreen(flow: flow)
        // act v
        case .herFile: OV5HerFileScreen(flow: flow)
        case .signature: OV5SignatureScreen(flow: flow)
        case .healthKit: OV5HealthKitScreen(flow: flow)
        case .holdToBuild: OV5HoldToBuildScreen(flow: flow)
        }
    }
}
