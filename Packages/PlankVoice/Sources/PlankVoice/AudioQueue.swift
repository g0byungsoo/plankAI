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
            perLineCooldown: TimeInterval = 90.0,
            perCategoryCooldown: TimeInterval = 25.0,
            queueDepthCap: Int = 1,
            breathingRoom: TimeInterval = 5.0
        ) {
            self.perLineCooldown = perLineCooldown
            self.perCategoryCooldown = perCategoryCooldown
            self.queueDepthCap = queueDepthCap
            self.breathingRoom = breathingRoom
        }
    }

    // MARK: - Priority

    /// Priority levels:
    ///  4 = form correction (hips! shoulders! stopped!) — always wins
    ///  3 = countdown (5, 4, 3...)
    ///  2 = milestone, camera, session start/end
    ///  1 = compliments (recovery, good form guide) — lowest, never interrupts
    private static func priority(for line: VoiceLine) -> Int {
        switch line.category {
        case .form:
            // Recovery/compliments are low priority, corrections are highest
            if line.triggerState == "recovery" { return 1 }
            return 4
        case .countdown: return 3
        case .milestone, .cameraBad, .sessionStart, .sessionEnd: return 2
        case .guide:
            // "goodForm" guide = compliment = low priority
            if line.triggerState == "goodForm" { return 1 }
            return 2
        }
    }

    // MARK: - State

    private let config: Config
    private let provider: VoiceProvider
    private let lineLibrary: LineLibrary

    private var queue: [(VoiceLine, Int)] = []  // (line, priority)
    private var isPlaying = false
    private var lastPlayedLineId: [String: Date] = [:]         // per-line cooldown
    private var lastPlayedCategory: [VoiceCategory: Date] = [:] // per-category cooldown
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
    private var sessionHasStarted = false

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
            sessionHasStarted = true
            line = lineLibrary.randomLine(for: .sessionStart, triggerState: nil, excluding: playedThisSession)
        case .sessionEnd:
            line = lineLibrary.randomLine(for: .sessionEnd, triggerState: nil, excluding: playedThisSession)
        case .stateChanged(.cameraBad):
            line = lineLibrary.randomLine(for: .cameraBad, triggerState: nil, excluding: playedThisSession)
        case .stateChanged(.notInPosition):
            if sessionHasStarted {
                // Mid-session: they stopped planking — roast them to get back up
                line = lineLibrary.randomLine(for: .form, triggerState: "stopped", excluding: playedThisSession)
            } else {
                // Pre-session: guide them into position
                line = lineLibrary.randomLine(for: .guide, triggerState: "notInPosition", excluding: playedThisSession)
            }
        case .stateChanged(.goodForm):
            line = lineLibrary.randomLine(for: .guide, triggerState: "goodForm", excluding: playedThisSession)
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
        sessionHasStarted = false
    }

    // MARK: - Queue Logic

    private func enqueue(_ line: VoiceLine) async {
        let priority = Self.priority(for: line)
        let now = Date()
        let isUrgent = priority >= 3  // corrections (4) + countdown (3)

        // Per-line cooldown — urgent events skip this entirely
        if !isUrgent,
           let lastPlayed = lastPlayedLineId[line.id],
           now.timeIntervalSince(lastPlayed) < config.perLineCooldown {
            return
        }

        // Per-category cooldown — urgent events skip this
        if !isUrgent,
           let lastCat = lastPlayedCategory[line.category],
           now.timeIntervalSince(lastCat) < config.perCategoryCooldown {
            return
        }

        // If already playing:
        if isPlaying {
            if let currentPriority = queue.first?.1 {
                // Only interrupt if new line has strictly higher priority
                if priority > currentPriority {
                    provider.stop()
                    isPlaying = false
                    queue.removeAll()
                } else {
                    return // drop — don't stack
                }
            } else {
                // Something is playing but queue is empty — only corrections interrupt
                if isUrgent {
                    provider.stop()
                    isPlaying = false
                } else {
                    return
                }
            }
        }

        // Queue depth cap
        if queue.count >= config.queueDepthCap {
            return
        }

        queue.append((line, priority))

        if !isPlaying {
            await processQueue()
        }
    }

    private func processQueue() async {
        while let (line, priority) = queue.first {
            queue.removeFirst()
            isPlaying = true

            playedThisSession.insert(line.id)
            lastPlayedLineId[line.id] = Date()
            lastPlayedCategory[line.category] = Date()
            eventContinuation?.yield(.linePlayed(line))

            await provider.play(line)

            // Breathing room: none for countdown/corrections, full for everything else
            let pause: TimeInterval = priority >= 3 ? 0.3 : config.breathingRoom
            try? await Task.sleep(for: .seconds(pause))
            isPlaying = false
        }
    }
}
