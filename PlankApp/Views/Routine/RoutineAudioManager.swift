import AVFoundation

/// Plays voice clips during routine sessions. Simple, no queue priority — just play one clip at a time.
@Observable
@MainActor
final class RoutineAudioManager {
    private var player: AVAudioPlayer?

    func setup() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Playback

    func play(_ clipName: String) {
        guard let url = Bundle.main.url(forResource: clipName, withExtension: "m4a") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func playRandom(_ clipNames: [String]) {
        guard let clip = clipNames.randomElement() else { return }
        play(clip)
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - Routine Events

    func onSessionStart() {
        playRandom(["routine_start_1", "routine_start_2", "routine_start_3"])
    }

    func onSessionDone() {
        playRandom(["routine_done_1", "routine_done_2", "routine_done_3"])
    }

    func onExercisePreview(exerciseId: String) {
        play("intro_\(exerciseId)")
    }

    func onExerciseStart() {
        play("exercise_countdown")
    }

    func onExerciseHalfway() {
        play("exercise_halfway")
    }

    func onExerciseAlmost() {
        play("exercise_almost")
    }

    func onExerciseDone() {
        play("exercise_done")
    }

    func onRest() {
        playRandom(["rest_1", "rest_2", "rest_3", "rest_4"])
    }

    func onRestNext() {
        playRandom(["rest_next_1", "rest_next_2", "rest_next_3"])
    }

    func onSkip() {
        playRandom(["skip_1", "skip_2"])
    }

    /// Periodic encouragement during active phase.
    func onActiveTick(exerciseType: ExerciseType, secondsIn: Int, duration: Int) {
        let remaining = duration - secondsIn

        // Halfway mark
        if secondsIn == duration / 2 {
            onExerciseHalfway()
            return
        }

        // 5 seconds left
        if remaining == 5 {
            onExerciseAlmost()
            return
        }

        // Periodic tempo/hold cues every ~8 seconds (not on halfway or almost)
        guard secondsIn > 0, secondsIn % 8 == 0, remaining > 6 else { return }

        if exerciseType == .static {
            playRandom(["hold_1", "hold_2", "hold_3", "hold_4", "hold_5", "hold_6"])
        } else {
            playRandom([
                "tempo_1", "tempo_2", "tempo_3", "tempo_4",
                "tempo_twist_1", "tempo_twist_2",
                "tempo_drive_1", "tempo_drive_2",
            ])
        }
    }
}
