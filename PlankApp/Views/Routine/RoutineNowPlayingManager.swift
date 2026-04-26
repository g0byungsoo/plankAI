import AVFoundation
import MediaPlayer
import UIKit

/// Manages MPNowPlayingInfoCenter and MPRemoteCommandCenter for lock screen display.
/// Shows current exercise name, session info, and pause/play controls.
@MainActor
final class RoutineNowPlayingManager {
    private var onPause: (() -> Void)?
    private var onPlay: (() -> Void)?
    private var commandsRegistered = false

    // MARK: - Setup

    func setup(onPause: @escaping () -> Void, onPlay: @escaping () -> Void) {
        self.onPause = onPause
        self.onPlay = onPlay
        print("=== Now Playing Setup ===")
        UIApplication.shared.beginReceivingRemoteControlEvents()
        print("beginReceivingRemoteControlEvents called")
        registerCommands()
        print("Remote commands registered")
        print("==========================")
    }

    private func registerCommands() {
        guard !commandsRegistered else { return }
        commandsRegistered = true

        let center = MPRemoteCommandCenter.shared()

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            // Toggle — check current playback rate
            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            let rate = info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 1.0
            Task { @MainActor in
                if rate > 0 {
                    self?.onPause?()
                } else {
                    self?.onPlay?()
                }
            }
            return .success
        }

        // Disable skip controls
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    // MARK: - Update Now Playing

    func updateNowPlaying(
        title: String,
        subtitle: String,
        elapsed: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        // App icon as artwork
        if let image = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        print("=== Now Playing Update ===")
        print("Audio session category: \(AVAudioSession.sharedInstance().category.rawValue)")
        print("Audio session mode: \(AVAudioSession.sharedInstance().mode.rawValue)")
        print("Audio session options: \(AVAudioSession.sharedInstance().categoryOptions.rawValue)")
        print("Output route: \(AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portName })")
        print("isOtherAudioPlaying: \(AVAudioSession.sharedInstance().isOtherAudioPlaying)")
        print("Now Playing info dict:")
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            for (key, value) in info.sorted(by: { $0.key < $1.key }) {
                print("  \(key): \(value)")
            }
        } else {
            print("  (nil)")
        }
        let cmdCenter = MPRemoteCommandCenter.shared()
        print("Remote commands - play: \(cmdCenter.playCommand.isEnabled), pause: \(cmdCenter.pauseCommand.isEnabled), toggle: \(cmdCenter.togglePlayPauseCommand.isEnabled)")
        print("==========================")
    }

    // MARK: - Clear

    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let center = MPRemoteCommandCenter.shared()
        center.pauseCommand.removeTarget(nil)
        center.playCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        commandsRegistered = false
        onPause = nil
        onPlay = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}
