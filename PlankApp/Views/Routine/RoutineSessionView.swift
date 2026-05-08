import SwiftUI
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
                ) { _, _ in
                    // Rating handled by HomeView on save
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
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

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

            if pausedByBackground {
                sessionPausedOverlay
                    .transition(.opacity)
            }
        }
        .alert("End Workout?", isPresented: $showEndConfirm) {
            Button("End", role: .destructive) { vm.end() }
            Button("Keep Going", role: .cancel) {}
        }
        .task { vm.start() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if !vm.isPaused, case .done = vm.phase {} else if !vm.isPaused {
                    vm.pause()
                    pausedByBackground = true
                }
            }
        }
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

    private var topBar: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            progressSegments
                .frame(maxWidth: .infinity)

            audioToggle(
                onIcon: "music.note",
                offIcon: "speaker.slash.fill",
                isMuted: vm.musicMuted,
                action: { Haptics.light(); vm.toggleMusic() }
            )
            .accessibilityLabel(vm.musicMuted ? "Unmute music" : "Mute music")

            audioToggle(
                onIcon: "mic.fill",
                offIcon: "mic.slash.fill",
                isMuted: vm.voiceMuted,
                action: { Haptics.light(); vm.toggleVoice() }
            )
            .accessibilityLabel(vm.voiceMuted ? "Unmute voice" : "Mute voice")

            Button {
                showEndConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .tappableArea()
            }
            .accessibilityLabel("End workout")
        }
        .padding(.horizontal, Space.screenPadding)
    }

    private func audioToggle(
        onIcon: String,
        offIcon: String,
        isMuted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: isMuted ? offIcon : onIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isMuted ? Palette.textSecondary : Palette.accent)
                .frame(width: 32, height: 32)
                .background(Palette.bgElevated)
                .clipShape(Circle())
        }
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
            LottieExerciseView(rendering: rendering)
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
