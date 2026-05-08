import Foundation
import AVFoundation

/// Loops a random workout track during the session at a low volume so the
/// trainer voice sits cleanly on top. The track is picked once per
/// `start()` call and looped — no shuffle within a session.
///
/// Bundled tracks live under `PlankApp/Resources/Music/` and are wired in
/// via a folder reference in the pbxproj.
@MainActor
final class BackgroundMusicService {

    private var player: AVAudioPlayer?

    /// User-set mute state. Persists across session pause/resume.
    private(set) var isMuted: Bool = false

    /// Currently playing? Used by the UI to drive the speaker icon.
    var isPlaying: Bool { player?.isPlaying ?? false }

    /// Pick a random track and start looping at low volume.
    /// No-op if currently muted.
    func start() {
        guard !isMuted else { return }
        guard player == nil else { return }   // already playing
        guard let url = Self.randomTrackURL() else { return }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.35   // sits under the voice
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            #if DEBUG
            print("[BackgroundMusicService] Failed to start: \(error)")
            #endif
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// User tapped the music toggle. Updates `isMuted` and starts/stops.
    func setMuted(_ muted: Bool) {
        guard isMuted != muted else { return }
        isMuted = muted
        if muted {
            stop()
        } else {
            start()
        }
    }

    /// Volume duck for when a voice cue is about to play. Kept as a tunable
    /// fallback; the voice manager currently prefers `pauseForVoice()` /
    /// `resumeAfterVoice()` because the source voice clips are mastered
    /// quiet enough that even 0.10 BGM drowns them.
    func duck(to volume: Float = 0.15) { player?.volume = volume }
    func unduck(to volume: Float = 0.35) { player?.volume = volume }

    /// Voice-priority pause. Stops the music output without dropping the
    /// player so `resumeAfterVoice()` continues from the same offset —
    /// users keep their track, just lose 1–2s while Jeni speaks. This is
    /// the GPS-nav pattern; less smooth than ducking but guarantees voice
    /// audibility regardless of source-clip mastering.
    func pauseForVoice() { player?.pause() }
    func resumeAfterVoice() {
        guard !isMuted else { return }
        // Restore normal volume in case duck() was called separately.
        player?.volume = 0.35
        player?.play()
    }

    private static func randomTrackURL() -> URL? {
        // First, look inside the bundled "Music" folder reference.
        if let urls = Bundle.main.urls(
            forResourcesWithExtension: "mp3",
            subdirectory: "Music"
        ), !urls.isEmpty {
            return urls.randomElement()
        }
        // Fallback: any mp3 in the bundle root (defensive — shouldn't trigger).
        if let urls = Bundle.main.urls(
            forResourcesWithExtension: "mp3",
            subdirectory: nil
        ), !urls.isEmpty {
            return urls.randomElement()
        }
        return nil
    }
}
