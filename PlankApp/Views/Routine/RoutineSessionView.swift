import SwiftUI
import PlankSync

struct RoutineSessionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State var vm: RoutineSessionViewModel
    @State private var showEndConfirm = false
    @State private var animateProgress = false
    @State private var pausedByBackground = false

    init(
        workout: WorkoutPreset,
        onComplete: @escaping ([ExerciseResultEntry], TimeInterval) -> Void
    ) {
        self._vm = State(initialValue: RoutineSessionViewModel(
            workout: workout,
            onComplete: onComplete
        ))
    }

    var body: some View {
        ZStack {
            // Background gradient — warm, not dark
            LinearGradient(
                colors: [Palette.bgPrimary, backgroundAccent],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                exerciseContent
                Spacer()
                timerSection
                bottomControls
            }

            // Pause overlay when returning from background
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
            Color.black.opacity(0.5)
                .ignoresSafeArea()

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
                            .font(Typo.body)
                            .fontWeight(.bold)
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
                            .font(Typo.body)
                            .fontWeight(.medium)
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

    // MARK: - Background

    private var backgroundAccent: Color {
        switch vm.phase {
        case .preview: return Palette.accentSubtle.opacity(0.3)
        case .active: return Palette.accent.opacity(0.15)
        case .rest: return Palette.stateGood.opacity(0.1)
        case .done: return Palette.stateGood.opacity(0.2)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Progress indicator
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("\(vm.currentExerciseIndex + 1) of \(vm.exerciseCount)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Palette.divider)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Palette.accent)
                            .frame(width: geo.size.width * vm.progress, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: vm.progress)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Close button
            Button {
                showEndConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)
    }

    // MARK: - Exercise Content

    private var exerciseContent: some View {
        VStack(spacing: Space.md) {
            if let exercise = vm.currentExercise {
                // Phase label
                phaseLabel

                // Exercise name
                Text(exercise.name)
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())

                // Target area badge
                Text(exercise.targetArea.rawValue.camelCaseToWords.uppercased())
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(2)

                // Animation placeholder — will be Lottie
                exerciseAnimationPlaceholder(exercise: exercise)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.currentExerciseIndex)
    }

    private var phaseLabel: some View {
        Group {
            switch vm.phase {
            case .preview:
                Text("NEXT UP")
                    .foregroundStyle(Palette.accent)
            case .active:
                Text("GO")
                    .foregroundStyle(Palette.stateGood)
            case .rest:
                Text("REST")
                    .foregroundStyle(Palette.textSecondary)
            case .done:
                Text("DONE")
                    .foregroundStyle(Palette.stateGood)
            }
        }
        .font(Typo.caption)
        .tracking(3)
        .fontWeight(.bold)
    }

    private func exerciseAnimationPlaceholder(exercise: Exercise) -> some View {
        // Placeholder until Lottie is integrated
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Palette.bgElevated)
                .frame(width: 200, height: 200)
                .plankShadow()

            VStack(spacing: Space.sm) {
                Image(systemName: exerciseIcon(for: exercise))
                    .font(.system(size: 48))
                    .foregroundStyle(Palette.accent)

                Text(exercise.type == .static ? "HOLD" : "MOVE")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(2)
            }
        }
    }

    private func exerciseIcon(for exercise: Exercise) -> String {
        switch exercise.targetArea {
        case .frontCore: return "figure.core.training"
        case .obliques: return "figure.flexibility"
        case .lowerBack: return "figure.strengthtraining.traditional"
        case .fullCore: return "figure.highintensity.intervaltraining"
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        VStack(spacing: Space.sm) {
            // Big countdown
            Text("\(vm.timeRemaining)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: vm.timeRemaining)

            // Total elapsed
            Text(formatTotalTime(vm.totalElapsed))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

            // Next exercise preview (during rest)
            if case .rest(let index) = vm.phase {
                let nextIndex = index + 1
                if nextIndex < vm.exerciseCount,
                   let next = vm.workout.exercises[nextIndex].exercise {
                    Text("Next: \(next.name)")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .fontWeight(.medium)
                        .transition(.opacity)
                }
            }
        }
        .padding(.bottom, Space.lg)
    }

    private var timerColor: Color {
        switch vm.phase {
        case .preview: return Palette.accent
        case .active: return vm.timeRemaining <= 5 ? Palette.stateWarn : Palette.textPrimary
        case .rest: return Palette.stateGood
        case .done: return Palette.stateGood
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Pause/Resume
            Button {
                Haptics.light()
                if vm.isPaused { vm.resume() } else { vm.pause() }
            } label: {
                Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .plankShadow()
            }

            Spacer()

            // Skip (only during active)
            if vm.isActive {
                Button {
                    Haptics.medium()
                    vm.skip()
                } label: {
                    HStack(spacing: Space.xs) {
                        Text("Skip")
                            .font(Typo.body)
                            .fontWeight(.medium)
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.sm + 4)
                    .background(Palette.bgElevated)
                    .clipShape(Capsule())
                    .plankShadow()
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.bottom, Space.xl)
        .animation(.easeInOut(duration: 0.2), value: vm.isActive)
    }

    // MARK: - Helpers

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
