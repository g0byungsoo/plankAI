import SwiftUI

/// Root view hosted in the external-display window. Observes the shared
/// `SessionBridge` so the cinema view re-evaluates when the phone starts
/// a session (bridge.vm set), ends one (set to nil), or swaps to a new
/// session. Empty/idle state shows a quiet "ready when you are" panel so
/// the TV isn't a blank rectangle until the user taps Start.
struct ExternalSessionRoot: View {
    private let bridge = SessionBridge.shared

    var body: some View {
        Group {
            if let vm = bridge.vm {
                ExternalSessionView(vm: vm)
            } else {
                idleView
            }
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    private var idleView: some View {
        VStack(spacing: 18) {
            Text("jenifit.")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 72))
                .foregroundStyle(Palette.accent)
            Text("ready when you are.")
                .font(.custom("DMSans-Medium", size: 24))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Cinema-mode session view rendered on the external display when AirPlay
/// Mirroring or an HDMI cable is connected. Stripped down: no controls,
/// no settings — just the animation, the phase eyebrow, the exercise
/// name, the step counter, and the timer. Phone keeps the full UI; this
/// surface is for the room to watch.
///
/// Designed for a 16:9 landscape TV: animation on the left, label + timer
/// on the right. The view reads from `RoutineSessionViewModel` directly
/// (it's @Observable), so every tick on the phone propagates instantly.
struct ExternalSessionView: View {
    let vm: RoutineSessionViewModel

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 64)
                    .padding(.top, 36)

                HStack(spacing: 48) {
                    heroAnimation
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    rightPanel
                        .frame(maxWidth: 540, alignment: .leading)
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 32)
            }

            // Lightweight watermark — JeniFit voice signal — so the
            // cinema view doesn't read as a stock video player.
            VStack {
                HStack {
                    Spacer()
                    Text("jenifit.")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        .foregroundStyle(Palette.accent.opacity(0.65))
                        .padding(.trailing, 64)
                        .padding(.top, 28)
                }
                Spacer()
            }
        }
    }

    // MARK: - Top progress bar

    private var progressBar: some View {
        let current = vm.currentExerciseIndex
        let count = max(1, vm.exerciseCount)
        return HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(segmentColor(for: idx, current: current))
                    .frame(height: 5)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
    }

    private func segmentColor(for index: Int, current: Int) -> Color {
        if index < current { return Palette.accent }
        if index == current { return Palette.accent.opacity(0.55) }
        return Palette.divider
    }

    // MARK: - Hero animation

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

    // MARK: - Right side panel (eyebrow / name / step / timer)

    @ViewBuilder
    private var rightPanel: some View {
        if let exercise = vm.currentExercise {
            VStack(alignment: .leading, spacing: 24) {
                phaseEyebrow
                Text(exercise.name.lowercased())
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 64))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("step \(vm.currentExerciseIndex + 1) of \(vm.exerciseCount)")
                    .font(.custom("DMSans-Medium", size: 20))
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(2)

                Spacer().frame(height: 4)

                Text("\(vm.timeRemaining)")
                    .font(.custom("Fraunces72pt-SemiBold", size: 168))
                    .foregroundStyle(timerColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: vm.timeRemaining)
            }
        }
    }

    private var phaseEyebrow: some View {
        let label: String
        let color: Color
        switch (vm.phase, vm.currentSlot?.category ?? .main) {
        case (.prep, .warmup):    label = "warm up";   color = Palette.accent
        case (.prep, .cooldown):  label = "cool down"; color = Palette.stateGood
        case (.prep(let i), .main):
            let initial = (i == 0 && vm.exerciseResults.isEmpty)
            label = initial ? "get ready" : "rest"
            color = initial ? Palette.accent : Palette.textSecondary
        case (.active, .warmup):    label = "warm up";   color = Palette.accent
        case (.active, .cooldown):  label = "cool down"; color = Palette.stateGood
        case (.active, _):          label = "go";        color = Palette.stateGood
        case (.done, _):            label = "done";      color = Palette.stateGood
        }
        return Text(label)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
            .tracking(3)
            .foregroundStyle(color)
    }

    private var timerColor: Color {
        switch vm.phase {
        case .prep:    return Palette.accent
        case .active:  return vm.timeRemaining <= 5 ? Palette.stateWarn : Palette.textPrimary
        case .done:    return Palette.stateGood
        }
    }
}
