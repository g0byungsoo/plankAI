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
    case guide         // positioning + form coaching cues
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

// MARK: - ElevenLabs Provider

/// Per-coach ElevenLabs voice IDs. Resolved at request time from
/// `voicePreference` so coach selection drives the actual voice rather
/// than a single hardcoded ID. Naming aligns with the user-facing
/// trainer name (Kira / Jeni / Sam).
public enum CoachVoice {
    public static let kira = "03vEurziQfq3V8WZhQvn"
    public static let jeni = "hA4zGnmTwX2NQiTRMt7o"
    public static let sam  = "ZRwrL4id6j1HPGFkeCzO"

    /// Resolve a `voicePreference` string to the trainer's voice ID.
    /// Anything unrecognized — including the legacy "sarah" key —
    /// falls through to Jeni (the warm/encouraging coach, default
    /// voice for the app).
    public static func voiceId(for preference: String?) -> String {
        switch preference {
        case "keepItReal": return kira
        case "balanced":   return sam
        case "encouraging", "sarah", .none, .some(""): return jeni
        default: return jeni
        }
    }
}

public final class ElevenLabsProvider: VoiceProvider, @unchecked Sendable {
    private let apiKey: String
    /// Read-only fallback when no preference is supplied. Resolution at
    /// request time prefers `UserDefaults["voicePreference"]` so coach
    /// changes from Settings take effect without re-creating the provider.
    private let fallbackVoiceId: String
    private var player: AVAudioPlayer?
    private var _isPlaying = false

    public init(apiKey: String, voiceId: String = CoachVoice.jeni) {
        self.apiKey = apiKey
        self.fallbackVoiceId = voiceId
    }

    public var isPlaying: Bool { _isPlaying }

    /// Coach-aware voice ID. Re-reads the preference at every play() so
    /// switching coaches mid-session works without a provider rebuild.
    private var currentVoiceId: String {
        if let pref = UserDefaults.standard.string(forKey: "voicePreference"),
           !pref.isEmpty {
            return CoachVoice.voiceId(for: pref)
        }
        return fallbackVoiceId
    }

    /// Pass-through for now. Earlier we expanded a few isolated short
    /// phrases ("Go." → "Three, two, one, go!") to give TTS more
    /// emotional context, but the rewritten output read worse than the
    /// shorter original on real workouts. The clip texts authored in
    /// `scripts/generate_voice_clips.sh` already include enough flow
    /// ("And done.", "Okay, rest.", "Beautiful work.") for the model
    /// to interpret rhythm.
    static func expandForTTS(_ text: String) -> String { text }

    public func play(_ line: VoiceLine) async {
        let voiceId = currentVoiceId
        let urlString = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        // Workout coach prompt settings — tuned for the short,
        // command-style phrases the app sends. Medium stability avoids
        // robotic flatness on one-shot phrases; high similarity preserves
        // coach identity on tiny clips; style at 0 keeps short prompts
        // from going overly dramatic / inconsistent; speaker_boost trades
        // a touch of latency for clarity. Defaults per ElevenLabs docs
        // are 0.75 / 0.0; we override stability + similarity for fidelity.
        let body: [String: Any] = [
            "text": Self.expandForTTS(line.text),
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.55,
                "similarity_boost": 0.85,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              !data.isEmpty
        else { return }

        do {
            player = try AVAudioPlayer(data: data)
            _isPlaying = true
            player?.play()
            while player?.isPlaying == true {
                try? await Task.sleep(for: .milliseconds(100))
            }
            _isPlaying = false
        } catch {
            _isPlaying = false
        }
    }

    public func stop() {
        player?.stop()
        player = nil
        _isPlaying = false
    }
}

// MARK: - Clip Bundle Provider (production)

public final class ClipBundleProvider: VoiceProvider, @unchecked Sendable {
    private var player: AVAudioPlayer?
    private let bundle: Bundle

    /// Clip prefix for current trainer. Read from UserDefaults each play.
    private var trainerPrefix: String {
        switch UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging" {
        case "encouraging": return "jeni_"
        case "balanced": return "matson_"
        default: return ""
        }
    }

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    public func play(_ line: VoiceLine) async {
        // Try trainer-prefixed clip first, fall back to base (Kira)
        let prefix = trainerPrefix
        let prefixedId = prefix.isEmpty ? line.id : "\(prefix)\(line.id)"
        let url = bundle.url(forResource: prefixedId, withExtension: "m4a")
            ?? bundle.url(forResource: line.id, withExtension: "m4a")

        guard let url else {
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
