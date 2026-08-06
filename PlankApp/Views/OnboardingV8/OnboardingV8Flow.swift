import SwiftUI

// MARK: - OnboardingV8Flow — THE CONSULT host
//
// docs/onboarding_v8/00_DIRECTION.md. One continuous experience:
// paper conversation ↔ ink chapters ↔ structured instruments, joined
// by in-place surface crossfades. The completion pipeline is the v4.5
// contract, byte-for-byte (assemble → reveal cover → refresh derived
// → onComplete) — the engineering that already works, untouched.

struct OnboardingV8Flow: View {
    let onComplete: (OnboardingData) -> Void
    var context: OnboardingContext = .consumer

    @State private var store = OV5Store()
    @State private var currentID: String = "ch_arrival"
    @State private var history: [String] = []
    @State private var restored = false
    /// Bumps on back-nav so the stage rebuilds its paragraph settled.
    @State private var stageRun = 0
    @State private var showReveal = false
    @State private var pendingData: OnboardingData? = nil
    @State private var showSignInSheet = false
    /// The opening move: launch lands on paper (continuous with the
    /// loader, no luminance jump), then the surface crossfades to ink
    /// UNDER the arriving mark.
    @State private var arrivalWarm = true

    var body: some View {
        let node = V8Script.node(for: currentID, store: store)
        let onInk = isInk(node) && !arrivalWarm

        ZStack(alignment: .top) {
            // The one surface. Paper or ink; the flip is a crossfade
            // in place — never a push, never a slide.
            Rectangle()
                .fill(V8InkAware.surface(onInk))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: V8Tempo.surfaceFlip), value: onInk)

            VStack(spacing: 0) {
                chrome(onInk: onInk)
                    .opacity(hidesChrome ? 0 : 1)
                    .animation(.easeInOut(duration: 0.25), value: hidesChrome)

                ZStack {
                    content(for: node)
                        .id(contentIdentity)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: V8Tempo.surfaceFlip * 0.8), value: contentIdentity)
            }
        }
        .environment(\.v8OnInk, onInk)
        .onAppear {
            UserDefaults.standard.set(true, forKey: "onb_v5_seen")
            V6Funnel.track("onboarding_started", once: true)
        }
        .task {
            guard arrivalWarm else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 0.7)) { arrivalWarm = false }
        }
        .fullScreenCover(isPresented: $showReveal) {
            OnboardingRevealView(
                bodyFocus: [],
                sessionLengthKey: sessionLengthKey,
                voicePreference: "encouraging",
                commitmentDaysKey: commitmentDaysKey,
                currentWeightKg: store.currentWeightKg,
                goalWeightKg: store.goalWeightKg,
                onRevealComplete: { completeAfterReveal() },
                skipsPreamble: true
            )
        }
        .sheet(isPresented: $showSignInSheet) {
            NavigationStack {
                SignInPromptView(onContinue: {
                    showSignInSheet = false
                    if !AuthService.shared.isAnonymous {
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

    // MARK: chrome

    @ViewBuilder
    private func chrome(onInk: Bool) -> some View {
        VStack(spacing: 0) {
            V8ProgressHairline(fraction: V8Script.fraction(at: currentID, store: store))
                .padding(.horizontal, Space.gutter)
                .padding(.top, 6)

            HStack {
                Button {
                    back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(V8InkAware.secondary(onInk))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(canGoBack ? 1 : 0)
                .allowsHitTesting(canGoBack && !hidesChrome)
                .accessibilityLabel("back")
                Spacer()
            }
            .padding(.horizontal, Space.sm)
        }
    }

    private var canGoBack: Bool { !history.isEmpty && currentID != "ch_arrival" }

    private var hidesChrome: Bool {
        switch currentID {
        case "ch_arrival", "s_snapDemo", "s_safetyGate", "s_hold": return true
        default: return false
        }
    }

    // MARK: content

    private func isInk(_ node: V8Node?) -> Bool {
        if case .chapter = node { return true }
        return false
    }

    /// Consecutive talk beats share ONE identity so the transcript
    /// flows across them; chapters and structured moments get their
    /// own, so the crossfade fires exactly at surface seams.
    private var contentIdentity: String {
        switch V8Script.node(for: currentID, store: store) {
        case .talk: return "talk-\(stageRun)"
        case .chapter(let kind): return "ch-\(kind.rawValue)"
        case .structured(let kind): return "s-\(kind.rawValue)"
        case nil: return "none"
        }
    }

    @ViewBuilder
    private func content(for node: V8Node?) -> some View {
        switch node {
        case .talk(let beat):
            V8Stage(
                beat: beat,
                store: store,
                restored: restored,
                onAdvance: { _ in advance() }
            )

        case .chapter(let kind):
            V8Chapter(
                kind: kind,
                content: V8Script.chapterContent(kind, store: store),
                onContinue: { advance() },
                onSecondary: kind == .arrival ? { showSignInSheet = true } : nil
            )

        case .structured(let kind):
            structuredView(kind)

        case nil:
            Color.clear
        }
    }

    @ViewBuilder
    private func structuredView(_ kind: V8StructuredKind) -> some View {
        switch kind {
        case .snapDemo:
            OV5SnapDemoScreen(store: store, onAdvance: { advance() })
        case .safetyGate:
            V8SafetyGateMoment(onPassed: { advance() })
        case .signature:
            V8SignatureMoment(store: store, onDone: { advance() })
        case .healthKit:
            V8HealthMoment(onDone: { advance() })
        case .hold:
            V8HoldMoment(store: store, onSealed: {
                JeniHaptic.swell()
                advance()
            })
        }
    }

    // MARK: navigation

    private func advance() {
        guard let next = V8Script.next(after: currentID, store: store) else {
            beginReveal()
            return
        }
        #if DEBUG
        print("[v8] advance \(currentID) -> \(next)")
        #endif
        Analytics.track("ov5_step_advanced", properties: [
            "from": currentID,
            "to": next,
            "act": actIndex(of: currentID),
            "glp1": store.glp1Status.isEmpty ? "unset" : store.glp1Status,
        ])
        history.append(currentID)
        restored = false
        // A talk run entered from a chapter/structured moment is a NEW
        // paragraph — a fresh stage identity, never a resurrected one.
        let wasTalk = isTalk(currentID)
        if !wasTalk, isTalk(next) { stageRun += 1 }
        withAnimation(.easeInOut(duration: 0.3)) { currentID = next }
    }

    private func isTalk(_ id: String) -> Bool {
        if case .talk = V8Script.node(for: id, store: store) { return true }
        return false
    }

    private func back() {
        guard canGoBack else { return }
        var target: String? = history.popLast()
        // Statement beats are transient — walking back onto one would
        // just replay its auto-advance. Skip to the last answerable.
        while let t = target, isTransient(t), !history.isEmpty {
            target = history.popLast()
        }
        guard let prev = target else { return }
        Analytics.track("ov5_step_back", properties: [
            "from": currentID, "to": prev,
        ])
        restored = true
        stageRun += 1
        withAnimation(.easeInOut(duration: 0.3)) { currentID = prev }
    }

    private func isTransient(_ id: String) -> Bool {
        guard case .talk(let beat) = V8Script.node(for: id, store: store) else { return false }
        return beat.input(store).isStatement
    }

    private func actIndex(of id: String) -> Int {
        switch id {
        case "ch_arrival", "hello", "name", "outcome", "history",
             "foodRelationship", "ch_mirror":
            return 0
        case "glp1Status", "glp1Phase", "appetiteRhythm", "shotDay",
             "muscleMath", "stopWindow", "appetiteReturn", "considering",
             "cadence", "dietary", "cuisine", "supports", "demoIntro",
             "s_snapDemo", "proteinRule", "ch_evidence":
            return 1
        case "numbersLine", "gender", "age", "height", "weight",
             "weightTrend", "goalDirection", "goalWeight", "movement",
             "sleep", "stress", "nsv", "medication", "s_safetyGate":
            return 2
        case "hormonal", "identity", "fears", "attribution", "ch_file":
            return 3
        default:
            return 4
        }
    }

    // MARK: completion pipeline (v4.5 contract, byte-for-byte)

    private var sessionLengthKey: String {
        switch store.derivedSessionMinutes {
        case 20: return "twenty"
        case 15: return "fifteen"
        default: return "ten"
        }
    }

    private var commitmentDaysKey: String {
        switch store.derivedCommitmentDays {
        case 3: return "three"
        case 7: return "seven"
        default: return "five"
        }
    }

    private func beginReveal() {
        Analytics.track(.onboardingComplete, properties: [
            "user_goal": store.legacyGoal,
            "body_focus_count": 0,
            "coach": "encouraging",
            "onb_version": "v8",
        ])
        V6Funnel.track("personalization_completed", once: true)
        pendingData = store.assembleData()
        showReveal = true
    }

    private func completeAfterReveal() {
        guard var data = pendingData else { showReveal = false; return }
        pendingData = nil
        data.commitmentDaysPerWeek = store.derivedCommitmentDays
        data.sessionLengthMinutes = store.derivedSessionMinutes
        let d = UserDefaults.standard
        let bucket = d.string(forKey: "plankTime") ?? ""
        let notifsOn = d.bool(forKey: "notificationsEnabled")
        if !bucket.isEmpty { data.plankTime = bucket }
        data.notificationsEnabled = notifsOn
        data.notificationTime = notifsOn ? OV5Store.reminderTime(fromBucket: bucket) : nil
        showReveal = false
        onComplete(data)
    }
}
