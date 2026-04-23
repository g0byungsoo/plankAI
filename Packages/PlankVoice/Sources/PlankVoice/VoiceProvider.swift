import Foundation
import AVFoundation

/// Protocol for audio playback. Swappable between system TTS and pre-rendered clips.
public protocol VoiceProvider: Sendable {
    func play(_ line: VoiceLine) async
    func stop()
    var isPlaying: Bool { get }
}

/// A single coaching line with metadata.
public struct VoiceLine: Sendable, Identifiable, Equatable {
    public let id: String
    public let text: String
    public let category: VoiceCategory
    public let triggerState: String?  // e.g., "hipSag", "shoulderCreep"
    public let duration: TimeInterval

    public init(id: String, text: String, category: VoiceCategory, triggerState: String? = nil, duration: TimeInterval = 2.0) {
        self.id = id
        self.text = text
        self.category = category
        self.triggerState = triggerState
        self.duration = duration
    }
}

public enum VoiceCategory: String, Sendable, Equatable {
    case form          // roasts + encouragements
    case milestone     // 10s, 30s, 60s markers
    case countdown     // final 10, 5, 3-2-1
    case sessionStart
    case sessionEnd
    case cameraBad
}

/// Events emitted by PlankVoice for the app layer.
public enum VoiceEvent: Sendable {
    case linePlayed(VoiceLine)
    case routeChanged(reason: String)
    case queueFlushed
}

// MARK: - System TTS Provider (dev fallback)

public final class SystemTTSProvider: NSObject, VoiceProvider, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var _isPlaying = false

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public var isPlaying: Bool { _isPlaying }

    public func play(_ line: VoiceLine) async {
        let utterance = AVSpeechUtterance(string: line.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        _isPlaying = true
        synthesizer.speak(utterance)

        // Wait for completion
        while _isPlaying {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        _isPlaying = false
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        _isPlaying = false
    }
}

// MARK: - Clip Bundle Provider (production)

public final class ClipBundleProvider: VoiceProvider, @unchecked Sendable {
    private var player: AVAudioPlayer?
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    public func play(_ line: VoiceLine) async {
        guard let url = bundle.url(forResource: line.id, withExtension: "m4a") else {
            // Fallback: skip if clip not found
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            // Wait for completion
            while player?.isPlaying == true {
                try? await Task.sleep(for: .milliseconds(100))
            }
        } catch {
            // Audio playback failure is non-fatal
        }
    }

    public func stop() {
        player?.stop()
        player = nil
    }
}
