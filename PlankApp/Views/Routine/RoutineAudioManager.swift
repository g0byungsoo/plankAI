import AVFoundation
import SwiftUI

/// Plays voice clips during routine sessions. Trainer-aware: plays the right voice based on voicePreference.
@Observable
@MainActor
final class RoutineAudioManager {
    private var player: AVAudioPlayer?
    private var lastPlayTime: Date = .distantPast
    private let cooldown: TimeInterval = 3.0

    /// Clip prefix for current trainer. Kira = "" (no prefix), Sarah = "sarah_", Matson = "matson_"
    private var prefix: String {
        switch UserDefaults.standard.string(forKey: "voicePreference") ?? "keepItReal" {
        case "encouraging": return "sarah_"
        case "balanced": return "matson_"
        default: return ""
        }
    }

    /// Whether current trainer has roast clips (Kira + Matson yes, Sarah no)
    private var hasRoasts: Bool {
        prefix != "sarah_"
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    func deactivate() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Playback

    func play(_ clipName: String, force: Bool = false) {
        if !force && isPlaying { return }
        if !force && Date().timeIntervalSince(lastPlayTime) < cooldown { return }

        // Try trainer-prefixed clip first, fall back to base (Kira)
        let trainerClip = prefix.isEmpty ? clipName : "\(prefix)\(clipName)"
        let url = Bundle.main.url(forResource: trainerClip, withExtension: "m4a")
            ?? Bundle.main.url(forResource: clipName, withExtension: "m4a")

        guard let url else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        lastPlayTime = Date()
    }

    func playRandom(_ clipNames: [String], force: Bool = false) {
        guard let clip = clipNames.randomElement() else { return }
        play(clip, force: force)
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - Routine Events

    func onSessionDone() {
        playRandom(["routine_done_1", "routine_done_2", "routine_done_3", "routine_done_4", "routine_done_5"], force: true)
    }

    func onExercisePreview(exerciseId: String) {
        play("intro_\(exerciseId)", force: true)
    }

    func onExerciseStart() {
        play("exercise_countdown", force: true)
    }

    func onExerciseAlmost() {
        play("exercise_almost")
    }

    func onExerciseDone() {
        play("exercise_done")
    }

    func onRest() {
        playRandom(["rest_1", "rest_2", "rest_3", "rest_4"], force: true)
    }

    func onSkip() {
        playRandom(["skip_1", "skip_2"], force: true)
    }

    func onActiveTick(exerciseType: ExerciseType, secondsIn: Int, duration: Int) {
        let remaining = duration - secondsIn

        if remaining == 5 {
            onExerciseAlmost()
            return
        }

        guard secondsIn >= 10, secondsIn % 12 == 0, remaining > 8 else { return }

        let roll = Int.random(in: 1...10)

        if roll <= 2 {
            playRandom(["encourage_1", "encourage_2", "encourage_3", "encourage_4", "encourage_5"])
        } else if roll == 3 && hasRoasts {
            playRandom(["roast_1", "roast_2", "roast_3", "roast_4"])
        } else if exerciseType == .static {
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
