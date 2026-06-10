import SwiftUI
import UIKit
import PlankSync

struct RoutineSessionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State var vm: RoutineSessionViewModel
    @State private var showEndConfirm = false
    @State private var pausedByBackground = false
    @State private var showPostRoutine = false
    /// Surfaced briefly when the round number changes mid-session
    /// (Pamela Reif "round 2" beat). Auto-clears 1.6s later.
    @State private var roundToast: Int? = nil

    /// Justfit-pattern right-side button stack opens three discrete
    /// sheets — modeled here so each can present + dismiss independently.
    /// Fullscreen toggle is a placeholder until Phase B lands the
    /// landscape layout (no-op tap clearly logged).
    @State private var showVolumeSheet = false
    @State private var showMusicSheet = false
    @State private var showInfoSheet = false

    /// Shared bridge that publishes the active VM to the external-display
    /// scene + drives the AirPlay button's "TV connected" affordance.
    /// Lifecycle is owned by `.task` / `.onDisappear` below.
    private var sessionBridge: SessionBridge { SessionBridge.shared }

    /// Landscape "cinema" mode for the live session — animation fills
    /// the screen, controls reduce to the essentials. Toggled by the
    /// fullscreen button in the right-side stack; auto-locks back to
    /// portrait on disappear so the rest of the app keeps its
    /// portrait-only contract.
    @State private var isFullScreen = false

    /// Adaptive feedback loop: the post-session "how'd that feel?" answer
    /// nudges the persistent baseline `workoutLevel` so the NEXT session is
    /// easier/harder. (Per-session "today's energy" is a separate value that
    /// resets daily, so the loop never fights a one-off override.)
    @AppStorage("workoutLevel") private var workoutLevel = 0

    let onDismiss: ([ExerciseResultEntry], TimeInterval) -> Void

    init(
        workout: WorkoutPreset,
        onDismiss: @escaping ([ExerciseResultEntry], TimeInterval) -> Void
    ) {
        self.onDismiss = onDismiss
        self._vm = State(initialValue: RoutineSessionViewModel(
            workout: workout,
            onComplete: { _, _ in }
        ))
    }

    var body: some View {
        ZStack {
            // Main session UI
            if !showPostRoutine {
                sessionContent
                    .transition(.opacity)
            }

            // Post-routine celebration (shown inline when done)
            if showPostRoutine {
                PostRoutineView(
                    exerciseResults: vm.exerciseResults,
                    totalDuration: vm.totalElapsed,
                    workoutName: vm.workout.name,
                    streakCount: 0,  // HomeView recalculates on save
                    isFirstWorkoutToday: true,
                    didMeetThreshold: SessionCompletion.didMeetThreshold(vm.exerciseResults)
                ) { _, tags in
                    // Relative-effort feedback nudges next session's energy
                    // (clamped to the same -1…+1 range as the home knob).
                    if tags.contains("too_hard") {
                        workoutLevel = max(-1, workoutLevel - 1)
                        Analytics.track(.sessionFeedbackGiven, properties: ["feel": "too_hard"])
                    } else if tags.contains("too_easy") {
                        workoutLevel = min(1, workoutLevel + 1)
                        Analytics.track(.sessionFeedbackGiven, properties: ["feel": "too_easy"])
                    } else if tags.contains("just_right") {
                        Analytics.track(.sessionFeedbackGiven, properties: ["feel": "just_right"])
                    }
                } onDone: {
                    onDismiss(vm.exerciseResults, vm.totalElapsed)
                }
                .transition(.opacity)
            }

            // Round-change toast — fires when slot.round increments
            // (Pamela Reif "and now repeat" moment). Sits above the
            // session UI but below the post-routine cover.
            if let round = roundToast, !showPostRoutine {
                roundToastBanner(round: round)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: vm.phase) { _, newPhase in
            if case .done = newPhase {
                // Small delay for the done voice clip, then show celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(Motion.crossFade) {
                        showPostRoutine = true
                    }
                }
            }
        }
        .onChange(of: vm.currentSlot?.round) { oldRound, newRound in
            guard let new = newRound, let old = oldRound, new > old else { return }
            // Round just incremented mid-session. Show toast briefly.
            withAnimation(Motion.gentleSpring) { roundToast = new }
            Haptics.medium()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(Motion.exit) { roundToast = nil }
            }
        }
    }

    /// "round N · of M" banner — italic Fraunces, accent rose, scrapbook
    /// chrome consistent with PreRoutineView's round divider. Renders
    /// near the top of the screen so it doesn't compete with the timer.
    private func roundToastBanner(round: Int) -> some View {
        VStack {
            (
                Text("round \(round)").font(Typo.titleItalic) +
                Text(" · of \(vm.totalRounds)").font(Typo.title)
            )
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.bgElevated)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.accent, lineWidth: 1.5)
                }
            )
            .padding(.top, Space.xl + Space.md)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Session Content

    private var sessionContent: some View {
        ZStack(alignment: .topTrailing) {
            // v8 P8.4: portrait/in-rest UI inherits PlanView's pink.
            // The fullScreenLayout below KEEPS Palette.bgPrimary —
            // designer call: immersive timer stays neutral so the
            // exercise illustration carries the screen.
            Palette.programEraBg.ignoresSafeArea()

            if isFullScreen {
                fullScreenLayout
            } else {
                portraitLayout
            }

            if pausedByBackground {
                sessionPausedOverlay
                    .transition(.opacity)
            }
        }
        .alert("End Workout?", isPresented: $showEndConfirm) {
            Button("End", role: .destructive) { vm.end() }
            Button("Keep Going", role: .cancel) {}
        }
        .sheet(isPresented: $showVolumeSheet) {
            VolumeSheet(onChange: { vm.applyVolumeChanges() })
        }
        .sheet(isPresented: $showMusicSheet) {
            MusicSourceSheet(onChange: { source in vm.setMusicSource(source) })
        }
        .sheet(isPresented: $showInfoSheet) {
            if let exercise = vm.currentExercise {
                ExerciseInfoSheet(
                    exercise: exercise,
                    stepLabel: "step \(vm.currentExerciseIndex + 1)/\(vm.exerciseCount)"
                )
            }
        }
        .task {
            vm.start()
            sessionBridge.vm = vm
        }
        .onAppear {
            Analytics.captureScreen("RoutineSession")
            // Keep the screen awake for the whole workout. SYNCHRONOUS
            // `.onAppear` (not `.task`) so the flag flips BEFORE iOS
            // schedules the next auto-lock countdown. The earlier
            // `.task` version was async — on cold session starts iOS
            // could begin the dim → lock countdown a few hundred ms
            // before the flag actually flipped, causing the screen to
            // dim mid-session.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            sessionBridge.vm = nil
            // Restore the system auto-lock so it doesn't keep the
            // screen awake forever after the user leaves the session.
            UIApplication.shared.isIdleTimerDisabled = false
            // Always lock back to portrait when leaving the session so
            // the rest of the app honors its portrait-only contract.
            setOrientation(landscape: false)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-assert the idle-timer flag on every active transition.
            // iOS can reset the flag across background → foreground
            // returns; without re-applying, a user who locks then
            // unlocks mid-rest would re-enter a session that's no
            // longer protected from auto-lock.
            if newPhase == .active {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            if newPhase == .background || newPhase == .inactive {
                if !vm.isPaused, case .done = vm.phase {} else if !vm.isPaused {
                    vm.pause()
                    pausedByBackground = true
                }
            }
        }
    }

    // MARK: - Portrait + Fullscreen Layouts

    /// Default portrait layout — top bar with progress + back X, hero
    /// animation centered, info panel with timer + media controls,
    /// right-side button stack overlay.
    private var portraitLayout: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                topBar
                    .padding(.top, Space.sm)

                heroAnimation
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, Space.lg)

                infoPanel
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.bottom, Space.lg)
            }

            rightButtonStack
                .padding(.top, Space.sm + Space.lg + Space.sm)
                .padding(.trailing, Space.screenPadding)
        }
    }

    /// Landscape cinema layout — animation fills the left half, minimal
    /// timer + name + step in the bottom-left, phase eyebrow in the
    /// bottom-right, progress bar at the top, minimize icon top-right.
    /// All session controls (audio toggles, sheets) collapse away — to
    /// adjust them, user exits fullscreen first.
    private var fullScreenLayout: some View {
        GeometryReader { geo in
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()

                // Progress bar pinned to the very top
                VStack {
                    progressSegments
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.sm)
                    Spacer()
                }

                // Center: huge Lottie filling available space
                fullScreenHero(in: geo.size)

                // Minimize button top-right
                VStack {
                    HStack {
                        Spacer()
                        Button { exitFullScreen() } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    ZStack {
                                        Circle().fill(Palette.bgElevated.opacity(0.92))
                                        Circle().stroke(Palette.accent.opacity(0.35), lineWidth: 1)
                                    }
                                )
                        }
                        .accessibilityLabel("Exit fullscreen")
                    }
                    .padding(.trailing, Space.lg)
                    .padding(.top, Space.sm)
                    Spacer()
                }

                // Bottom-left: pause/timer + exercise meta
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        fullScreenMetaPanel
                        Spacer()
                        fullScreenPhaseLabel
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.lg)
                }
            }
        }
    }

    private func fullScreenHero(in size: CGSize) -> some View {
        let dim = min(size.width, size.height) - Space.xl - Space.lg
        return Group {
            if let rendering = vm.currentSlot?.rendering {
                LottieExerciseView(rendering: rendering, isPaused: vm.isPaused)
                    .id(rendering.exercise.id + (rendering.side?.rawValue ?? ""))
                    .frame(width: dim, height: dim)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var fullScreenMetaPanel: some View {
        if let exercise = vm.currentExercise {
            HStack(alignment: .center, spacing: Space.md) {
                Button {
                    Haptics.medium()
                    if vm.isPaused { vm.resume() } else { vm.pause() }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Palette.accent, lineWidth: 2.5)
                            .frame(width: 56, height: 56)
                        Circle()
                            .fill(Palette.bgElevated)
                            .frame(width: 48, height: 48)
                        Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .accessibilityLabel(vm.isPaused ? "Resume" : "Pause")

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name.lowercased())
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
                        .foregroundStyle(Palette.textPrimary)
                    Text("step \(vm.currentExerciseIndex + 1)/\(vm.exerciseCount) · \(vm.timeRemaining)s")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)
                }
            }
        }
    }

    private var fullScreenPhaseLabel: some View {
        let label: String
        let color: Color
        switch (vm.phase, vm.currentSlot?.category ?? .main) {
        case (.prep, .warmup):     label = "warm up";   color = Palette.accent
        case (.prep, .cooldown):   label = "cool down"; color = Palette.stateGood
        case (.prep(let i), .main):
            let initial = (i == 0 && vm.exerciseResults.isEmpty)
            label = initial ? "get ready" : "rest"
            color = initial ? Palette.accent : Palette.textSecondary
        case (.active, .warmup):     label = "warm up";   color = Palette.accent
        case (.active, .cooldown):   label = "cool down"; color = Palette.stateGood
        case (.active, _):           label = "go";        color = Palette.stateGood
        case (.done, _):             label = "done";      color = Palette.stateGood
        }
        return Text(label)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 36))
            .tracking(3)
            .foregroundStyle(color)
    }

    // MARK: - Fullscreen orientation control

    private func enterFullScreen() {
        setOrientation(landscape: true)
        withAnimation(Motion.crossFade) { isFullScreen = true }
    }

    private func exitFullScreen() {
        Haptics.light()
        setOrientation(landscape: false)
        withAnimation(Motion.crossFade) { isFullScreen = false }
    }

    /// Drives the iOS-16+ orientation update path. `OrientationManager`
    /// gates the allowed mask (read by `AppDelegate.supportedInterfaceOrientationsFor`);
    /// `requestGeometryUpdate` actually nudges the window to rotate.
    private func setOrientation(landscape: Bool) {
        OrientationManager.shared.allowedOrientations = landscape ? .landscape : .portrait

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let mask: UIInterfaceOrientationMask = landscape ? .landscapeRight : .portrait
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        scene?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    // MARK: - Right-Side Button Stack (Justfit pattern)
    //
    // Five circular scrapbook buttons stacked vertically: fullscreen,
    // music, volume, AirPlay, info. Music + volume tap open bottom
    // sheets; AirPlay surfaces the system route picker; info opens an
    // exercise detail sheet. Fullscreen is a placeholder until Phase B.

    private var rightButtonStack: some View {
        VStack(spacing: Space.sm) {
            stackButton(icon: "arrow.up.left.and.arrow.down.right",
                        accessibilityLabel: "Enter fullscreen") {
                Haptics.light()
                enterFullScreen()
            }
            stackButton(
                icon: vm.musicMuted ? "music.note.list" : "music.note",
                accent: !vm.musicMuted,
                accessibilityLabel: "Music source"
            ) {
                Haptics.light()
                showMusicSheet = true
            }
            stackButton(icon: "speaker.wave.2.fill",
                        accessibilityLabel: "Set volume") {
                Haptics.light()
                showVolumeSheet = true
            }
            airPlayButton
            stackButton(icon: "info",
                        accessibilityLabel: "Exercise info") {
                Haptics.light()
                showInfoSheet = true
            }
        }
    }

    private func stackButton(
        icon: String,
        accent: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent ? Palette.textInverse : Palette.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    ZStack {
                        Circle()
                            .fill(Palette.accent.opacity(0.18))
                            .offset(x: 2, y: 2)
                        Circle()
                            .fill(accent ? Palette.accent : Palette.bgElevated)
                        Circle()
                            .stroke(Palette.accent.opacity(accent ? 0.0 : 0.35), lineWidth: 1)
                    }
                )
                .tappableArea()
        }
        .accessibilityLabel(accessibilityLabel)
    }

    /// AirPlay wraps `AVRoutePickerView` so the system handles route
    /// discovery + the picker UI. We surface the same circular chrome as
    /// the rest of the stack so it reads as a single family of controls.
    /// When an external screen is connected, a tiny accent dot pulses at
    /// the top-right corner so the user knows the TV cinema view is live.
    private var airPlayButton: some View {
        let mirroring = sessionBridge.isMirroring
        return ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 2, y: 2)
                Circle()
                    .fill(mirroring ? Palette.accent : Palette.bgElevated)
                Circle()
                    .stroke(Palette.accent.opacity(mirroring ? 0.0 : 0.35), lineWidth: 1)
                AirPlayPickerView(tint: UIColor(mirroring ? Palette.textInverse : Palette.textPrimary))
                    .frame(width: 28, height: 28)
            }
            .frame(width: 40, height: 40)

            if mirroring {
                Circle()
                    .fill(Palette.stateGood)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 1.5))
                    .offset(x: 2, y: -2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel(mirroring ? "AirPlay, TV connected" : "AirPlay")
    }

    // MARK: - Pause Overlay

    private var sessionPausedOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Text("SESSION PAUSED")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(3)

                if let exercise = vm.currentExercise {
                    Text(exercise.name)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                }

                Text("\(vm.timeRemaining)s remaining")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)

                VStack(spacing: Space.sm) {
                    Button {
                        Haptics.medium()
                        pausedByBackground = false
                        vm.resume()
                    } label: {
                        Text("RESUME")
                            .font(Typo.body).fontWeight(.bold)
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: Space.minTapTarget + 12)
                            .background(Palette.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }

                    Button {
                        pausedByBackground = false
                        vm.end()
                    } label: {
                        Text("END SESSION")
                            .font(Typo.body).fontWeight(.medium)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Space.minTapTarget + 4)
                    }
                }
                .padding(.top, Space.md)
            }
            .padding(Space.lg)
            .padding(.horizontal, Space.screenPadding)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .plankShadow()
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - Top Bar

    /// Top bar — Justfit-shaped: progress segments span the width, with a
    /// single back/end button on the left. Music + voice + AirPlay + info
    /// + fullscreen all live in the right-side stack now.
    private var topBar: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Button {
                showEndConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        ZStack {
                            Circle()
                                .fill(Palette.accent.opacity(0.18))
                                .offset(x: 2, y: 2)
                            Circle().fill(Palette.bgElevated)
                            Circle().stroke(Palette.accent.opacity(0.35), lineWidth: 1)
                        }
                    )
                    .tappableArea()
            }
            .accessibilityLabel("End workout")

            progressSegments
                .frame(maxWidth: .infinity)
                // Reserve the right edge so segments don't slide under the
                // overlay button stack and look truncated.
                .padding(.trailing, 48)
        }
        .padding(.horizontal, Space.screenPadding)
    }

    private var progressSegments: some View {
        let current = vm.currentExerciseIndex
        let count = max(1, vm.exerciseCount)
        return HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(segmentColor(for: idx, current: current))
                    .frame(height: 3)
                    .animation(Motion.crossFade, value: current)
            }
        }
    }

    private func segmentColor(for index: Int, current: Int) -> Color {
        if index < current { return Palette.accent }
        if index == current { return Palette.accent.opacity(0.55) }
        return Palette.divider
    }

    // MARK: - Hero Animation

    @ViewBuilder
    private var heroAnimation: some View {
        if let rendering = vm.currentSlot?.rendering {
            LottieExerciseView(rendering: rendering, isPaused: vm.isPaused)
                .aspectRatio(1, contentMode: .fit)
                .id(rendering.exercise.id + (rendering.side?.rawValue ?? ""))
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Color.clear
        }
    }

    // MARK: - Info Panel (phase, name, meta, timer, controls)

    @ViewBuilder
    private var infoPanel: some View {
        if let exercise = vm.currentExercise {
            VStack(spacing: Space.md) {
                phaseEyebrow

                Text(exercise.name.lowercased())
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                // Position cue — only during prep, when the user is
                // transitioning into the next move. Tells them HOW to set
                // up before the timer starts (lying on side, hands and
                // knees, etc.) so the position-block flow lands viscerally.
                if isPrepPhase {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("set up · \(positionLabel(exercise.position))")
                            .font(Typo.eyebrow).tracking(2)
                    }
                    .foregroundStyle(Palette.accent)
                    .transition(.opacity)
                }

                Text(metaLine(for: exercise))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(1)

                Text("\(vm.timeRemaining)")
                    .font(.custom("Fraunces72pt-SemiBold", size: 88, relativeTo: .largeTitle))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(timerColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: vm.timeRemaining)
                    .padding(.top, Space.xs)

                Text(formatTotalTime(vm.totalElapsed))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)

                mediaControls
                    .padding(.top, Space.sm)
            }
            .animation(.easeInOut(duration: 0.25), value: vm.currentExerciseIndex)
        }
    }

    private var phaseEyebrow: some View {
        let category = vm.currentSlot?.category ?? .main
        let label: String
        let color: Color
        switch (vm.phase, category) {
        case (.prep, .warmup):
            label = "warm up"; color = Palette.accent
        case (.prep, .cooldown):
            label = "cool down"; color = Palette.stateGood
        case (.prep(let index), .main):
            // First slot of the session = "get ready" countdown.
            // Mid-session prep = the user is recovering; show "rest".
            let isInitial = (index == 0 && vm.exerciseResults.isEmpty)
            label = isInitial ? "get ready" : "rest"
            color = isInitial ? Palette.accent : Palette.textSecondary
        case (.active, .warmup):     label = "warm up";    color = Palette.accent
        case (.active, .cooldown):   label = "cool down";  color = Palette.stateGood
        case (.active, _):           label = "go";          color = Palette.stateGood
        case (.done, _):             label = "done";        color = Palette.stateGood
        }
        return Text(label)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
            .tracking(2)
            .foregroundStyle(color)
            .contentTransition(.opacity)
    }

    private var isPrepPhase: Bool {
        if case .prep = vm.phase { return true }
        return false
    }

    private func positionLabel(_ p: ExercisePosition) -> String {
        switch p {
        case .standing:   return "standing"
        case .quadruped:  return "hands & knees"
        case .plank:      return "plank position"
        case .prone:      return "lying face-down"
        case .sideLying:  return "lying on side"
        case .supine:     return "lying on back"
        case .seated:     return "seated"
        }
    }

    private func metaLine(for exercise: Exercise) -> String {
        var parts: [String] = [exercise.primaryArea.rawValue.camelCaseToWords.lowercased()]
        if exercise.symmetry == .unilateral, let side = vm.currentSlot?.side {
            parts.append(side.rawValue)
        }
        parts.append("step \(vm.currentExerciseIndex + 1)/\(vm.exerciseCount)")
        // Surface round position when the workout has multiple rounds
        // (Pamela Reif "Round 1 of 2" pattern). Quietly skipped when
        // the session is single-round so we don't add chrome to short
        // workouts that don't need it.
        let totalRounds = vm.totalRounds
        if totalRounds > 1, let round = vm.currentSlot?.round {
            parts.append("round \(round)/\(totalRounds)")
        }
        return parts.joined(separator: " · ")
    }

    private var timerColor: Color {
        switch vm.phase {
        case .prep:    return Palette.accent
        case .active:  return vm.timeRemaining <= 5 ? Palette.stateWarn : Palette.textPrimary
        case .done:    return Palette.stateGood
        }
    }

    // MARK: - Media Controls

    private var mediaControls: some View {
        HStack(spacing: Space.lg) {
            // Skip back is unsupported — render disabled to preserve symmetry
            mediaButton(systemName: "backward.end.fill", size: 46, disabled: true) {}

            // Pause / play — primary CTA. Hard offset shadow (cocoa
            // ghost behind) instead of the soft drop shadow per
            // anti-design idiom.
            Button {
                Haptics.medium()
                if vm.isPaused { vm.resume() } else { vm.pause() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Palette.bgInverse.opacity(0.25))
                        .frame(width: 64, height: 64)
                        .offset(x: 4, y: 4)
                    Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Palette.textInverse)
                        .frame(width: 64, height: 64)
                        .background(Palette.accent)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Palette.bgInverse.opacity(0.15), lineWidth: 1.5)
                        )
                }
                .frame(width: 68, height: 68)
            }
            .accessibilityLabel(vm.isPaused ? "Resume" : "Pause")

            mediaButton(systemName: "forward.end.fill", size: 46, disabled: !vm.isActive) {
                Haptics.medium()
                vm.skip()
            }
        }
    }

    private func mediaButton(
        systemName: String,
        size: CGFloat,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(disabled ? Palette.divider : Palette.textPrimary)
                .frame(width: size, height: size)
                .background(Palette.bgElevated)
                .clipShape(Circle())
        }
        .disabled(disabled)
    }

    private func formatTotalTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - String Helpers

extension String {
    var camelCaseToWords: String {
        unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) && !result.isEmpty {
                return result + " " + String(scalar)
            }
            return result + String(scalar)
        }
    }
}
