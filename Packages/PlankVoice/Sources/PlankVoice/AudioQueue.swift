import Foundation
import PlankEngine

/// Priority-based audio queue with cooldowns and depth cap.
///
/// Three channels: form (roasts/encouragements), milestone, countdown.
/// Priority: countdown > milestone > form.
/// Per-line cooldown: 30s. Per-category cooldown: 5s. Queue depth: 2.
public actor AudioQueue {

    // MARK: - Config

    public struct Config: Sendable {
        public var perLineCooldown: TimeInterval
        public var perCategoryCooldown: TimeInterval
        public var queueDepthCap: Int
        public var breathingRoom: TimeInterval

        public init(
            perLineCooldown: TimeInterval = 30.0,
            perCategoryCooldown: TimeInterval = 5.0,
            queueDepthCap: Int = 2,
            breathingRoom: TimeInterval = 1.0
        ) {
            self.perLineCooldown = perLineCooldown
            self.perCategoryCooldown = perCategoryCooldown
            self.queueDepthCap = queueDepthCap
            self.breathingRoom = breathingRoom
        }
    }

    // MARK: - Priority

    private static func priority(for category: VoiceCategory) -> Int {
        switch category {
        case .countdown: 3
        case .milestone: 2
        case .form, .sessionStart, .sessionEnd, .cameraBad: 1
        }
    }

    // MARK: - State

    private let config: Config
    private let provider: VoiceProvider
    private let lineLibrary: LineLibrary

    private var queue: [(VoiceLine, Int)] = []  // (line, priority)
    private var isPlaying = false
    private var lastPlayedLineId: [String: Date] = [:]         // per-line cooldown
    private var lastPlayedCategory: [VoiceCategory: Date] = [] // per-category cooldown
    private var playedThisSession: Set<String> = []            // session no-repeat

    private var eventContinuation: AsyncStream<VoiceEvent>.Continuation?
    private var _events: AsyncStream<VoiceEvent>?

    // MARK: - Init

    public init(provider: VoiceProvider, lineLibrary: LineLibrary, config: Config = .init()) {
        self.provider = provider
        self.lineLibrary = lineLibrary
        self.config = config
    }

    /// Event stream for the app layer.
    public var events: AsyncStream<VoiceEvent> {
        if let existing = _events { return existing }
        let stream = AsyncStream<VoiceEvent> { continuation in
            self.eventContinuation = continuation
        }
        _events = stream
        return stream
    }

    // MARK: - Public API

    /// Handle a session event from PlankEngine.
    public func handleEvent(_ event: SessionEvent) async {
        let line: VoiceLine?

        switch event {
        case .formFault(let state):
            line = lineLibrary.randomLine(for: .form, triggerState: state.rawValue, excluding: playedThisSession)
        case .recovery:
            line = lineLibrary.randomLine(for: .form, triggerState: "recovery", excluding: playedThisSession)
        case .milestone(let seconds):
            line = lineLibrary.randomLine(for: .milestone, triggerState: "\(seconds)s", excluding: playedThisSession)
        case .countdown(let seconds):
            line = lineLibrary.randomLine(for: .countdown, triggerState: "\(seconds)", excluding: playedThisSession)
        case .sessionStart:
            line = lineLibrary.randomLine(for: .sessionStart, triggerState: nil, excluding: playedThisSession)
        case .sessionEnd:
            line = lineLibrary.randomLine(for: .sessionEnd, triggerState: nil, excluding: playedThisSession)
        case .stateChanged(.cameraBad):
            line = lineLibrary.randomLine(for: .cameraBad, triggerState: nil, excluding: playedThisSession)
        default:
            line = nil
        }

        guard let line else { return }
        await enqueue(line)
    }

    /// Flush the queue (e.g., on audio route change).
    public func flush() {
        queue.removeAll()
        provider.stop()
        isPlaying = false
        eventContinuation?.yield(.queueFlushed)
    }

    /// Reset session state for a new session.
    public func resetSession() {
        playedThisSession.removeAll()
        queue.removeAll()
        lastPlayedLineId.removeAll()
        lastPlayedCategory.removeAll()
    }

    // MARK: - Queue Logic

    private func enqueue(_ line: VoiceLine) async {
        let priority = Self.priority(for: line.category)
        let now = Date()

        // Per-line cooldown check
        if let lastPlayed = lastPlayedLineId[line.id],
           now.timeIntervalSince(lastPlayed) < config.perLineCooldown {
            return
        }

        // Per-category cooldown check (form only)
        if line.category == .form,
           let lastCat = lastPlayedCategory[.form],
           now.timeIntervalSince(lastCat) < config.perCategoryCooldown {
            return
        }

        // Higher priority interrupts current playback
        if isPlaying, let currentPriority = queue.first?.1, priority > currentPriority {
            provider.stop()
            isPlaying = false
            queue.removeAll()
        }

        // Queue depth cap
        if queue.count >= config.queueDepthCap {
            return  // Drop newer events
        }

        queue.append((line, priority))

        if !isPlaying {
            await processQueue()
        }
    }

    private func processQueue() async {
        while let (line, _) = queue.first {
            queue.removeFirst()
            isPlaying = true

            playedThisSession.insert(line.id)
            lastPlayedLineId[line.id] = Date()
            lastPlayedCategory[line.category] = Date()
            eventContinuation?.yield(.linePlayed(line))

            await provider.play(line)

            // Breathing room between lines
            try? await Task.sleep(for: .seconds(config.breathingRoom))
            isPlaying = false
        }
    }
}
