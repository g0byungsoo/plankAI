import Foundation
import PlankSync

// MARK: - Session Phase

enum RoutinePhase: Equatable {
    /// Combined rest + preview before an exercise. Index points at the
    /// **upcoming** exercise (the one whose Lottie + name show on screen).
    /// Duration lives in `timeRemaining` — set by the VM from the previous
    /// slot's `restAfter`, with a minimum 3s and a fixed 4s for the very
    /// first prep of the session ("get ready" countdown).
    case prep(exerciseIndex: Int)
    case active(exerciseIndex: Int)         // timed interval
    case done                              // session complete
}

/// Initial countdown before the first exercise of any session.
private let initialPrepSeconds = 4
/// Floor for inter-exercise prep, even if the slot's `restAfter` is smaller.
/// Just enough to read the next move's name.
private let minPrepSeconds = 3

// MARK: - View Model

@Observable
@MainActor
final class RoutineSessionViewModel {

    // MARK: - State

    private(set) var phase: RoutinePhase = .prep(exerciseIndex: 0)
    private(set) var timeRemaining: Int = initialPrepSeconds  // countdown for current phase
    private(set) var totalElapsed: TimeInterval = 0    // total session time
    private(set) var isPaused: Bool = false

    // MARK: - Workout Data

    let workout: WorkoutPreset
    private(set) var exerciseResults: [ExerciseResultEntry] = []
    private(set) var activeStartTime: Date? = nil

    // MARK: - Dependencies

    private let clock: any Clock<Duration>
    private let audio = RoutineAudioManager()
    private let music = BackgroundMusicService()
    private let onComplete: ([ExerciseResultEntry], TimeInterval) -> Void

    // MARK: - Internal

    private var timerTask: Task<Void, Never>?
    private var exerciseElapsed: Int = 0   // time spent in current active phase

    // MARK: - Computed

    var currentExerciseIndex: Int {
        switch phase {
        case .prep(let i), .active(let i): return i
        case .done: return workout.exercises.count - 1
        }
    }

    var currentSlot: ExerciseSlot? {
        // Once the session is done (natural completion or user quit), stop
        // surfacing the last exercise — otherwise the view flickers a frame
        // of "exercise N" content while HomeView dismisses the cover.
        if case .done = phase { return nil }
        let idx = currentExerciseIndex
        guard idx < workout.exercises.count else { return nil }
        return workout.exercises[idx]
    }

    var currentExercise: Exercise? {
        currentSlot?.exercise
    }

    var exerciseCount: Int { workout.exercises.count }

    /// Highest `round` value across the workout's slots. 1 for normal
    /// sessions; 2-3 for long sessions emitted with Pamela Reif's
    /// "and now repeat" structure. RoutineSessionView reads this to
    /// surface "round 1/2" inline.
    var totalRounds: Int {
        workout.exercises.map { $0.round }.max() ?? 1
    }

    var progress: Double {
        guard exerciseCount > 0 else { return 0 }
        switch phase {
        case .done: return 1.0
        case .active:
            let frac = Double(exerciseElapsed) / Double(workout.exercises[currentExerciseIndex].duration)
            return (Double(exerciseResults.count) + frac) / Double(exerciseCount)
        case .prep:
            // Prep: show completed exercises, no fractional drop
            return Double(exerciseResults.count) / Double(exerciseCount)
        }
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
        // Voice manager ducks BGM while cues play — wire the back-reference
        // at init so the play path can reach the music service.
        self.audio.music = self.music
    }

    // MARK: - Lifecycle

    func start() {
        guard case .prep(0) = phase else { return }
        activeStartTime = Date()
        timeRemaining = initialPrepSeconds
        audio.activate()
        music.start()
        Haptics.vibrate()
        startTimer()
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        timerTask?.cancel()
        audio.stop()
        music.stop()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        music.start()
        startTimer()
    }

    // MARK: - Audio toggles (independent music + voice mute)

    var musicMuted: Bool { music.isMuted }
    var voiceMuted: Bool { audio.isMuted }

    func toggleMusic() {
        music.setMuted(!music.isMuted)
    }

    func toggleVoice() {
        audio.setMuted(!audio.isMuted)
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

        advanceToPrep(afterIndex: index)
    }

    /// User-initiated quit (End button). Stops everything immediately and
    /// hands control back to the host without firing the celebration voice
    /// — calling `finishSession()` here would schedule an `audio.onSessionDone()`
    /// "beautiful / good work" cue 1s later, which feels wrong on a quit
    /// (and racy with the cover dismiss). Natural completion flows through
    /// `finishSession()` directly from the timer.
    func end() {
        timerTask?.cancel()
        audio.stop()              // kill any in-flight cue immediately
        audio.deactivate()
        music.stop()

        // Pad results to the full workout length so the post-session
        // "X/Y completed" denominator reflects the workout the user
        // started, not the subset they reached. Without this padding, a
        // 10-slot workout that the user quit on slot 3 reads as e.g.
        // "2/3" — wrong denominator. The current in-flight slot (active
        // or prep) is recorded with whatever credit it earned; later
        // slots count as skipped with 0 completed time.
        if case .active(let index) = phase {
            let slot = workout.exercises[index]
            exerciseResults.append(ExerciseResultEntry(
                exerciseId: slot.exerciseId,
                duration: slot.duration,
                completedDuration: exerciseElapsed,
                skipped: true
            ))
        } else if case .prep(let index) = phase {
            let slot = workout.exercises[index]
            exerciseResults.append(ExerciseResultEntry(
                exerciseId: slot.exerciseId,
                duration: slot.duration,
                completedDuration: 0,
                skipped: true
            ))
        }
        if exerciseResults.count < workout.exercises.count {
            for i in exerciseResults.count..<workout.exercises.count {
                let slot = workout.exercises[i]
                exerciseResults.append(ExerciseResultEntry(
                    exerciseId: slot.exerciseId,
                    duration: slot.duration,
                    completedDuration: 0,
                    skipped: true
                ))
            }
        }

        phase = .done
        onComplete(exerciseResults, totalElapsed)
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
        case .prep(let index):
            // Voice orchestration during prep is single-cue per window:
            // prep cue plays once, nothing else. The previous design
            // stacked onRest + prep + onExerciseStart inside the same
            // 5-15s window — they cut each other. Now the prep cue is
            // the only voice during prep; "Go" only fires for the
            // initial first-slot prep where no prep cue plays.
            let isInitial = (index == 0 && exerciseResults.isEmpty)
            if !isInitial && timeRemaining == workout.exercises[index].restAfter {
                Haptics.soft()
            }
            // Fire the prep cue early enough that the full clip lands
            // before the active phase starts. Budgets bumped from the
            // original (6 / 2) — prep_full clips run 3-5s and prep_short
            // 1.5-2.5s; the previous 2s budget for medium windows
            // routinely cut the prep_short tail.
            //   prepWindow ≥ 12 (rest=15 or 20) → 7s budget for prep_full
            //   prepWindow 6-11 (rest=10)        → 4s budget for prep_short
            //   prepWindow ≤ 5  (rest=5)         → silent (voice would cut)
                let upcoming = workout.exercises[index]
                let prepWindow = upcoming.restAfter
                let cueTime: Int
                if prepWindow >= 12 { cueTime = 7 }       // long: prep_full
                else if prepWindow >= 6 { cueTime = 4 }   // medium: prep_short
                else { cueTime = -1 }                      // ≤5s: silent

            if timeRemaining == cueTime {
                let prev = (index > 0) ? workout.exercises[index - 1] : nil
                if let upcomingEx = upcoming.exercise {
                    audio.onExercisePrep(
                        upcoming: upcomingEx,
                        upcomingSide: upcoming.side,
                        previous: prev?.exercise,
                        previousSide: prev?.side,
                        prepWindow: prepWindow
                    )
                } else {
                    // Defensive fallback for any slot whose exerciseId
                    // doesn't resolve in the bank — keeps the legacy
                    // intro_X path firing rather than going silent.
                    audio.onExercisePreview(exerciseId: upcoming.exerciseId)
                }
            }
            if timeRemaining <= 0 {
                Haptics.vibrate()
                // Only fire "Go" on the initial 4s prep where no prep
                // cue plays. Mid-session, the prep cue is the
                // announcement; firing onExerciseStart here would
                // force-cut the prep cue's tail.
                if isInitial {
                    audio.onExerciseStart()
                }
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
                    pace: exercise.pace,
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
                    advanceToPrep(afterIndex: index)
                }
            }

        case .done:
            timerTask?.cancel()
        }
    }

    /// Advance from a finished active phase into the prep for the next slot.
    /// Prep duration = the just-finished slot's `restAfter`, floored at
    /// `minPrepSeconds`. The combined rest + preview lives here.
    private func advanceToPrep(afterIndex index: Int) {
        let nextIndex = index + 1
        if nextIndex < workout.exercises.count {
            let prevRest = workout.exercises[index].restAfter
            phase = .prep(exerciseIndex: nextIndex)
            timeRemaining = max(minPrepSeconds, prevRest)
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
