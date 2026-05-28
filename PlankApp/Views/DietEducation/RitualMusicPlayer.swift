import AVFoundation
import Foundation

/// Minimal ambient-music player for the JeniMethod ritual. Phase 9.6.
///
/// Plays `lesson_zen_lofi.mp3` from `PlankApp/Resources/Music/` on a
/// loop, fades in over 1.5s on `play()`, fades out over 1.0s on
/// `stop()`. Independent of `BackgroundMusicService` (which is owned
/// by the routine flow) so the ritual + a workout can coexist without
/// fighting over the same player.
///
/// Designed as an observable @State value type? No — AVAudioPlayer is
/// reference-typed and the fade timers need persistent state, so this
/// is a class. Owned by the ritual view via @State as a reference.
final class RitualMusicPlayer {
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    private let trackName: String
    private let trackExtension: String
    private let subdirectory: String
    private let targetVolume: Float

    init(
        trackName: String = "lesson_zen_lofi",
        trackExtension: String = "mp3",
        subdirectory: String = "Music",
        targetVolume: Float = 0.38
    ) {
        self.trackName = trackName
        self.trackExtension = trackExtension
        self.subdirectory = subdirectory
        self.targetVolume = targetVolume
    }

    /// Load + start playback at volume 0, fade up to `targetVolume`.
    /// Loops indefinitely until `stop()`. Idempotent — already-playing
    /// no-ops. Silent on missing file (logs in DEBUG).
    func play() {
        guard player == nil else { return }

        guard let url = Bundle.main.url(
            forResource: trackName,
            withExtension: trackExtension,
            subdirectory: subdirectory
        ) ?? Bundle.main.url(forResource: trackName, withExtension: trackExtension) else {
            #if DEBUG
            print("[RitualMusicPlayer] missing track: \(trackName).\(trackExtension)")
            #endif
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1  // infinite loop
            p.volume = 0
            p.prepareToPlay()
            p.play()
            player = p
            fadeTo(targetVolume, over: 1.5)
        } catch {
            #if DEBUG
            print("[RitualMusicPlayer] failed to start: \(error)")
            #endif
        }
    }

    /// Fade out + stop. Idempotent — no-op if not playing. Releases
    /// the AVAudioPlayer instance once faded.
    func stop(fadeOver seconds: TimeInterval = 1.0) {
        guard player != nil else { return }
        fadeTo(0, over: seconds) { [weak self] in
            self?.player?.stop()
            self?.player = nil
        }
    }

    /// Linear volume fade via a repeating Timer at 30Hz. Cancels any
    /// in-flight fade before starting a new one.
    private func fadeTo(_ target: Float, over seconds: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        guard let player else { completion?(); return }

        let steps = max(1, Int(seconds * 30))
        let startVolume = player.volume
        let delta = target - startVolume
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            step += 1
            guard let self, let p = self.player else { timer.invalidate(); return }
            let progress = Float(step) / Float(steps)
            p.volume = startVolume + delta * min(1, progress)
            if step >= steps {
                p.volume = target
                timer.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
    }
}
