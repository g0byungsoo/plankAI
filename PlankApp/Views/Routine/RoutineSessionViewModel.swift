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
        timeRemaining = 3
        audio.setup()
        audio.onSessionStart()
        // Play exercise intro after session start clip
        if let slot = workout.exercises.first {
            Task {
                try? await clock.sleep(for: .seconds(2))
                audio.onExercisePreview(exerciseId: slot.exerciseId)
            }
        }
        startTimer()
    }

    func pause() {
        isPaused = true
        timerTask?.cancel()
    }

    func resume() {
        isPaused = false
        startTimer()
    }

    func skip() {
        guard case .active(let index) = phase else { return }

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
            if timeRemaining <= 0 {
                // Move to active
                audio.onExerciseStart()
                let slot = workout.exercises[index]
                phase = .active(exerciseIndex: index)
                timeRemaining = slot.duration
                exerciseElapsed = 0
            }

        case .active(let index):
            exerciseElapsed += 1
            let slot = workout.exercises[index]
            // Voice cues during exercise
            if let exercise = slot.exercise {
                audio.onActiveTick(
                    exerciseType: exercise.type,
                    secondsIn: exerciseElapsed,
                    duration: slot.duration
                )
            }
            if timeRemaining <= 0 {
                // Exercise complete
                audio.onExerciseDone()
                exerciseResults.append(ExerciseResultEntry(
                    exerciseId: slot.exerciseId,
                    duration: slot.duration,
                    completedDuration: slot.duration,
                    skipped: false
                ))
                advanceToRest(index: index)
            }

        case .rest(let index):
            // Play rest transition at start of rest
            if timeRemaining == workout.exercises[index].restAfter - 1 {
                audio.onRest()
            }
            // Preview next exercise 3 seconds before rest ends
            if timeRemaining == 3 {
                let nextIndex = index + 1
                if nextIndex < workout.exercises.count {
                    audio.onRestNext()
                    let nextSlot = workout.exercises[nextIndex]
                    audio.onExercisePreview(exerciseId: nextSlot.exerciseId)
                }
            }
            if timeRemaining <= 0 {
                let nextIndex = index + 1
                if nextIndex < workout.exercises.count {
                    // Preview next exercise
                    phase = .preview(exerciseIndex: nextIndex)
                    timeRemaining = 3
                } else {
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
        audio.onSessionDone()
        onComplete(exerciseResults, totalElapsed)
    }
}
