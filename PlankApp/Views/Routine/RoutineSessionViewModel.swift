import Foundation
import PlankSync

// MARK: - Session Phase

enum RoutinePhase: Equatable {
    case preview(exerciseIndex: Int)        // 3s exercise preview
    case active(exerciseIndex: Int)         // timed interval
    case rest(exerciseIndex: Int)           // rest between exercises
    case done                              // session complete
}

// MARK: - View Model

@Observable
@MainActor
final class RoutineSessionViewModel {

    // MARK: - State

    private(set) var phase: RoutinePhase = .preview(exerciseIndex: 0)
    private(set) var timeRemaining: Int = 3            // countdown for current phase
    private(set) var totalElapsed: TimeInterval = 0    // total session time
    private(set) var isPaused: Bool = false

    // MARK: - Workout Data

    let workout: WorkoutPreset
    private(set) var exerciseResults: [ExerciseResultEntry] = []
    private(set) var activeStartTime: Date? = nil

    // MARK: - Dependencies

    private let clock: any Clock<Duration>
    private let audio = RoutineAudioManager()
    private let onComplete: ([ExerciseResultEntry], TimeInterval) -> Void

    // MARK: - Internal

    private var timerTask: Task<Void, Never>?
    private var exerciseElapsed: Int = 0   // time spent in current active phase

    // MARK: - Computed

    var currentExerciseIndex: Int {
        switch phase {
        case .preview(let i), .active(let i), .rest(let i): return i
        case .done: return workout.exercises.count - 1
        }
    }

    var currentSlot: ExerciseSlot? {
        let idx = currentExerciseIndex
        guard idx < workout.exercises.count else { return nil }
        return workout.exercises[idx]
    }

    var currentExercise: Exercise? {
        currentSlot?.exercise
    }

    var exerciseCount: Int { workout.exercises.count }

    var progress: Double {
        guard exerciseCount > 0 else { return 0 }
        let completedExercises = Double(exerciseResults.count)
        let currentProgress: Double
        switch phase {
        case .preview: currentProgress = 0
        case .active(let i):
            let slot = workout.exercises[i]
            currentProgress = Double(exerciseElapsed) / Double(slot.duration)
        case .rest: currentProgress = 1.0
        case .done: return 1.0
        }
        return (completedExercises + currentProgress * 0.9) / Double(exerciseCount)
    }

    var isActive: Bool {
        if case .active = phase { return true }
        return false
    }

    // MARK: - Init

    init(
        workout: WorkoutPreset,
        clock: any Clock<Duration> = ContinuousClock(),
        onComplete: @escaping ([ExerciseResultEntry], TimeInterval) -> Void
    ) {
        self.workout = workout
        self.clock = clock
        self.onComplete = onComplete
    }

    // MARK: - Lifecycle

    func start() {
        guard case .preview(0) = phase else { return }
        activeStartTime = Date()
        timeRemaining = 4
        audio.activate()
        Haptics.vibrate()
        startTimer()
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        timerTask?.cancel()
        audio.stop()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        startTimer()
    }

    func skip() {
        guard case .active(let index) = phase else { return }

        Haptics.light()
        audio.onSkip()
        let slot = workout.exercises[index]
        exerciseResults.append(ExerciseResultEntry(
            exerciseId: slot.exerciseId,
            duration: slot.duration,
            completedDuration: exerciseElapsed,
            skipped: true
        ))

        advanceToRest(index: index)
    }

    func end() {
        timerTask?.cancel()
        audio.deactivate()
        finishSession()
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await self?.clock.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await self?.tick()
            }
        }
    }

    private func tick() {
        guard !isPaused else { return }

        totalElapsed += 1
        timeRemaining -= 1

        switch phase {
        case .preview(let index):
            if timeRemaining == 2 {
                audio.onExercisePreview(exerciseId: workout.exercises[index].exerciseId)
            }
            if timeRemaining <= 0 {
                Haptics.vibrate()
                audio.onExerciseStart()
                let slot = workout.exercises[index]
                phase = .active(exerciseIndex: index)
                timeRemaining = slot.duration
                exerciseElapsed = 0
            }

        case .active(let index):
            exerciseElapsed += 1
            let slot = workout.exercises[index]
            let remaining = timeRemaining

            // Haptic countdown: tick at 3, 2, 1
            if remaining <= 3 && remaining >= 1 {
                Haptics.tick()
            }

            // Voice: "five seconds" at 5s remaining
            if remaining == 5 {
                audio.onExerciseAlmost()
            }

            // Periodic voice cues
            if let exercise = slot.exercise, remaining > 8 {
                audio.onActiveTick(
                    exerciseType: exercise.type,
                    secondsIn: exerciseElapsed,
                    duration: slot.duration
                )
            }

            if remaining <= 0 {
                let isLastExercise = (index + 1) >= workout.exercises.count
                exerciseResults.append(ExerciseResultEntry(
                    exerciseId: slot.exerciseId,
                    duration: slot.duration,
                    completedDuration: slot.duration,
                    skipped: false
                ))
                if isLastExercise {
                    Haptics.doubleVibrate()
                    finishSession()
                } else {
                    Haptics.rigid()
                    audio.onExerciseDone()
                    advanceToRest(index: index)
                }
            }

        case .rest(let index):
            if timeRemaining == workout.exercises[index].restAfter - 1 {
                Haptics.soft()
                audio.onRest()
            }
            if timeRemaining == 2 {
                Haptics.tick()
            }
            if timeRemaining <= 0 {
                let nextIndex = index + 1
                if nextIndex < workout.exercises.count {
                    phase = .preview(exerciseIndex: nextIndex)
                    timeRemaining = 4
                } else {
                    Haptics.success()
                    finishSession()
                }
            }

        case .done:
            timerTask?.cancel()
        }
    }

    private func advanceToRest(index: Int) {
        let nextIndex = index + 1
        if nextIndex < workout.exercises.count {
            let slot = workout.exercises[index]
            phase = .rest(exerciseIndex: index)
            timeRemaining = slot.restAfter
        } else {
            finishSession()
        }
    }

    private func finishSession() {
        timerTask?.cancel()
        phase = .done
        Task {
            try? await clock.sleep(for: .seconds(1))
            audio.onSessionDone()
            try? await clock.sleep(for: .seconds(2))
            audio.deactivate()
        }
        onComplete(exerciseResults, totalElapsed)
    }
}
