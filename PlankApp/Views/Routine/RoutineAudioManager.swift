import AVFoundation
import SwiftUI

/// Plays voice clips during routine sessions. Trainer-aware: plays the right voice based on voicePreference.
@Observable
@MainActor
final class RoutineAudioManager {
    private var player: AVAudioPlayer?
    private var lastPlayTime: Date = .distantPast
    private let cooldown: TimeInterval = 3.0

    /// System TTS used as fallback when no bundled clip exists for an
    /// exercise (most of the 128-exercise bank doesn't have prep clips
    /// yet — those land with the next ElevenLabs run). Without a fallback
    /// the prep window is silent and the user can't tell what's coming
    /// next. TTS is robotic but functional; ElevenLabs-rendered clips
    /// will replace it on the same code path once available.
    private let synthesizer = AVSpeechSynthesizer()

    /// Reference back to the BGM service so voice cues can duck it. Set by
    /// the VM at init; nil during tests / preview where music isn't wired.
    /// Weak to avoid a retain cycle with the VM that owns both.
    weak var music: BackgroundMusicService?

    /// Bumps every time `play(...)` fires. The deferred unduck check uses
    /// this to confirm a newer cue hasn't started before it lifts the
    /// duck — back-to-back cues keep BGM ducked end-to-end.
    private var duckGeneration: Int = 0

    /// BGM volumes around voice cues. 0.05 leaves a bare bed of music
    /// audible without fighting the voice; 0.10 was tested and still
    /// drowned the (quietly-mastered) voice clips. Normal at 0.35
    /// matches BackgroundMusicService's start volume.
    private let duckedVolume: Float = 0.05
    private let normalVolume: Float = 0.35

    /// User-toggled voice mute. When `true`, all voice cues are silently
    /// suppressed (music keeps playing). Persists across pause/resume.
    private(set) var isMuted: Bool = false

    func setMuted(_ muted: Bool) {
        guard isMuted != muted else { return }
        isMuted = muted
        if muted { stop() }
    }

    /// Clip prefix for current trainer. Kira = "" (no prefix), Jeni =
    /// "jeni_", Sam = "matson_". The "matson_" prefix is the legacy
    /// asset name (per docs/workout_session_rules.md §7 migration note);
    /// the user-facing display name is "Sam". Rename happens in lockstep
    /// with the next ElevenLabs re-recording pass.
    private var prefix: String {
        switch UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging" {
        case "encouraging": return "jeni_"
        case "balanced": return "matson_"   // display: Sam
        default: return ""
        }
    }

    /// Whether current trainer has roast clips (Kira + Sam yes, Jeni no).
    private var hasRoasts: Bool {
        prefix != "jeni_"
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
        if isMuted { return }
        if !force && isPlaying { return }
        if !force && Date().timeIntervalSince(lastPlayTime) < cooldown { return }

        // Try trainer-prefixed clip first, fall back to base (Kira)
        let trainerClip = prefix.isEmpty ? clipName : "\(prefix)\(clipName)"
        let url = Bundle.main.url(forResource: trainerClip, withExtension: "m4a")
            ?? Bundle.main.url(forResource: clipName, withExtension: "m4a")

        guard let url else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 1.0    // defensive — defaults to 1.0 but pin it
        player?.play()
        lastPlayTime = Date()

        // Duck BGM hard (0.05) under the voice. Pausing entirely worked
        // for audibility but the user found the silent gap too jarring
        // — they'd rather hear quiet music as a bed. iOS's `.duckOthers`
        // session option only ducks OTHER apps; same-app players need
        // explicit volume control like this. The generation counter
        // ensures back-to-back voice cues keep BGM ducked end-to-end.
        if let player {
            duckGeneration &+= 1
            let myGeneration = duckGeneration
            music?.duck(to: duckedVolume)
            let lift = player.duration + 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + lift) { [weak self] in
                guard let self else { return }
                guard self.duckGeneration == myGeneration else { return }
                self.music?.unduck(to: self.normalVolume)
            }
        }
    }

    func playRandom(_ clipNames: [String], force: Bool = false) {
        guard let clip = clipNames.randomElement() else { return }
        play(clip, force: force)
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Countdown beep

    /// Dedicated player for the 5-4-3-2-1 countdown beep. Separate from
    /// the voice `player` so beeps don't preempt a prep cue still
    /// playing in the same tick — both can sound at once.
    private var beepPlayer: AVAudioPlayer?

    /// Short high-pitched beep for the 5-4-3-2-1 countdown in both prep
    /// and active phases. Replaces the prior voice "Five seconds left"
    /// cue and the prep-window silence. Respects `isMuted`. Uses its
    /// own player instance so the BGM duck logic + voice-clip path are
    /// unaffected.
    func playCountdownBeep() {
        if isMuted { return }
        if let beepPlayer, beepPlayer.isPlaying { return }
        guard let url = Bundle.main.url(forResource: "countdown_beep", withExtension: "m4a") else { return }
        do {
            beepPlayer = try AVAudioPlayer(contentsOf: url)
            beepPlayer?.volume = 0.85
            beepPlayer?.play()
        } catch {
            // Beep failure is non-fatal — haptics still mark the countdown.
        }
    }

    // MARK: - Routine Events

    func onSessionDone() {
        playRandom(["routine_done_1", "routine_done_2", "routine_done_3", "routine_done_4", "routine_done_5"], force: true)
    }

    func onExercisePreview(exerciseId: String) {
        play("intro_\(exerciseId)", force: true)
    }

    /// Pick the right prep cue based on context. Per
    /// docs/workout_session_rules.md §7:
    ///   - Switch-sides hop (same exerciseId, different side) → minimal
    ///     "switch sides" cue, never re-introduce.
    ///   - Long prep window (≥12s) → full prep w/ position instruction.
    ///   - Medium 6–11s → short "next up is X" cue.
    ///   - ≤5s window → silent (any cue would risk getting cut).
    ///
    /// Cascade: tries the most specific clip first, falls back to less
    /// specific variants if the asset isn't bundled. Lets us ship the
    /// logic ahead of the ElevenLabs voice generation pass — until the
    /// new variants exist, calls fall through to the legacy `intro_X`
    /// the way `onExercisePreview` always did.
    func onExercisePrep(upcoming: Exercise, upcomingSide: Side?,
                        previous: Exercise?, previousSide: Side?,
                        prepWindow: Int) {
        // Switch-sides: same exercise, different side. Never re-intro.
        if let prev = previous,
           prev.id == upcoming.id,
           previousSide != upcomingSide {
            playFirstAvailable(["switch_sides_1", "switch_sides_2"], force: true)
            return
        }

        let id = upcoming.id

        let played: Bool
        if prepWindow >= 12 {
            // Long window — full prep cue with position instruction
            // baked in. Falls through to short / legacy if the full
            // variant hasn't been generated yet.
            played = playFirstAvailable([
                "prep_full_\(id)",
                "prep_short_\(id)",
                "intro_\(id)"
            ], force: true)
        } else if prepWindow >= 2 {
            // Anything from 2 to 11s — short cue announcing the next
            // exercise. The clip may briefly overrun the prep window
            // into the active phase; onActiveTick + onExerciseStart
            // are already gated so they never interrupt mid-utterance.
            played = playFirstAvailable([
                "prep_short_\(id)",
                "intro_\(id)"
            ], force: true)
        } else {
            // ≤1s window — too short to even start a clip. Silent.
            played = true
        }

        // TTS fallback when no clip resolved (e.g., a brand-new exercise
        // added before its clip is generated). Speaking the name beats
        // silence; the next ElevenLabs run replaces TTS on the same
        // code path.
        if !played {
            speakNextUp(name: upcoming.name)
        }
    }

    /// Speak the upcoming exercise name via system TTS. Ducks BGM for the
    /// estimated utterance duration. Cooperates with the voice-clip
    /// `play()` ducking via the same `duckGeneration` counter so cue
    /// stacking stays sane.
    private func speakNextUp(name: String) {
        if isMuted { return }
        let text = "Next: \(name)"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)

        // Estimate duration at ~14 chars/sec (typical English TTS at
        // default rate). Pad 0.4s for the leading silence + tail.
        let estimated = max(1.5, Double(text.count) / 14.0 + 0.4)
        duckGeneration &+= 1
        let myGeneration = duckGeneration
        music?.duck(to: duckedVolume)
        DispatchQueue.main.asyncAfter(deadline: .now() + estimated) { [weak self] in
            guard let self else { return }
            guard self.duckGeneration == myGeneration else { return }
            self.music?.unduck(to: self.normalVolume)
        }
    }

    /// Try a list of clip names in order; play the first one that
    /// resolves to a bundled asset. Returns true if one played.
    @discardableResult
    private func playFirstAvailable(_ candidates: [String], force: Bool = false) -> Bool {
        for name in candidates where clipExists(name) {
            play(name, force: force)
            return true
        }
        return false
    }

    /// True when a bundled m4a exists for either the trainer-prefixed
    /// variant or the base name. Mirrors the resolution logic inside
    /// `play()` — the two must agree.
    private func clipExists(_ baseName: String) -> Bool {
        let trainerName = prefix.isEmpty ? baseName : "\(prefix)\(baseName)"
        if Bundle.main.url(forResource: trainerName, withExtension: "m4a") != nil {
            return true
        }
        return Bundle.main.url(forResource: baseName, withExtension: "m4a") != nil
    }

    func onExerciseStart() {
        play("exercise_countdown", force: true)
    }

    func onExerciseAlmost() {
        // Force — the 5-second warning is a hard transition cue and must
        // not be silently dropped just because a tempo / hold cue is
        // still mid-utterance.
        play("exercise_almost", force: true)
    }

    func onExerciseDone() {
        // Force — completion acknowledgment. A non-force call here used
        // to drop silently if a recent encourage/hold cue was still
        // playing, leaving the slot transition unannounced.
        play("exercise_done", force: true)
    }

    func onRest() {
        playRandom(["rest_1", "rest_2", "rest_3", "rest_4"], force: true)
    }

    func onSkip() {
        playRandom(["skip_1", "skip_2"], force: true)
    }

    func onActiveTick(pace: Pace, secondsIn: Int, duration: Int) {
        let remaining = duration - secondsIn

        if remaining == 5 {
            onExerciseAlmost()
            return
        }

        // Periodic encourage / hold / tempo cues. Floor at remaining > 10
        // so the cue (typical 2-3s) finishes by remaining ~7-8, leaving
        // a clean gap before onExerciseAlmost cuts in at remaining=5.
        guard secondsIn >= 10, secondsIn % 12 == 0, remaining > 10 else { return }

        let roll = Int.random(in: 1...10)

        if roll <= 2 {
            playRandom(["encourage_1", "encourage_2", "encourage_3", "encourage_4", "encourage_5"])
        } else if roll == 3 && hasRoasts {
            playRandom(["roast_1", "roast_2", "roast_3", "roast_4"])
        } else if pace == .hold {
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
