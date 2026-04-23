import Foundation

/// The core session engine. Consumes pose frames, emits session events.
/// Pure logic actor. No UI, no audio, no persistence.
///
/// ```
/// Camera → [PoseFrame] → PlankSessionEngine → [SessionEvent] → PlankVoice / UI
/// ```
public actor PlankSessionEngine {

    // MARK: - Configuration

    public struct Config: Sendable {
        public var debounceInterval: TimeInterval
        public var cameraBadThreshold: TimeInterval
        public var milestones: [Int]
        public var countdownStart: Int
        public var thresholds: PoseAnalyzer.Thresholds

        public init(
            debounceInterval: TimeInterval = 2.0,
            cameraBadThreshold: TimeInterval = 3.0,
            milestones: [Int] = [10, 30, 60, 90, 120],
            countdownStart: Int = 10,
            thresholds: PoseAnalyzer.Thresholds = .init()
        ) {
            self.debounceInterval = debounceInterval
            self.cameraBadThreshold = cameraBadThreshold
            self.milestones = milestones
            self.countdownStart = countdownStart
            self.thresholds = thresholds
        }
    }

    // MARK: - State

    private let config: Config
    private let analyzer: PoseAnalyzer

    private var currentState: FormState = .notInPosition
    private var pendingState: FormState?
    private var pendingStateStart: TimeInterval = 0

    private var sessionActive = false
    private var sessionStartTime: TimeInterval = 0
    private var goodFormTime: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0
    private var lastGoodFormCheck: TimeInterval = 0

    private var firedMilestones: Set<Int> = []
    private var firedCountdowns: Set<Int> = []
    private var formFaultCount = 0
    private var targetTime: TimeInterval = 60.0

    private var eventContinuation: AsyncStream<SessionEvent>.Continuation?
    private var _events: AsyncStream<SessionEvent>?

    // MARK: - Thermal

    public enum ThermalState: Sendable {
        case nominal, fair, serious, critical
    }

    private var thermalState: ThermalState = .nominal

    /// Frames per second based on thermal state.
    public var targetFPS: Int {
        switch thermalState {
        case .nominal: 10
        case .fair: 7
        case .serious: 5
        case .critical: 0
        }
    }

    // MARK: - Init

    public init(config: Config = .init()) {
        self.config = config
        self.analyzer = PoseAnalyzer(thresholds: config.thresholds)
    }

    // MARK: - Event Stream

    /// The event stream. Subscribe to receive session events.
    public var events: AsyncStream<SessionEvent> {
        if let existing = _events { return existing }
        let stream = AsyncStream<SessionEvent> { continuation in
            self.eventContinuation = continuation
        }
        _events = stream
        return stream
    }

    // MARK: - Public API

    /// Process a single pose frame. Called at ~10fps (thermal-adjusted).
    public func processFrame(_ frame: PoseFrame) {
        guard thermalState != .critical else { return }

        lastFrameTime = frame.timestamp
        let assessment = analyzer.analyze(frame)
        let rawState = mapAssessmentToState(assessment, at: frame.timestamp)

        updateState(rawState, at: frame.timestamp)

        if sessionActive {
            updateTimers(at: frame.timestamp)
            checkMilestones(at: frame.timestamp)
            checkCountdown(at: frame.timestamp)
        }
    }

    /// Update thermal state. Called every 10 seconds from the app layer.
    public func updateThermalState(_ state: ThermalState) {
        thermalState = state
    }

    /// Set the target hold time for this session.
    public func setTargetTime(_ seconds: TimeInterval) {
        targetTime = seconds
    }

    /// End the session manually (user taps "End session").
    public func endSession() {
        guard sessionActive else { return }
        sessionActive = false
        let holdTime = lastFrameTime - sessionStartTime
        let quality = computeQualityScore(holdTime: holdTime)
        emit(.sessionEnd(holdTime: holdTime, qualityScore: quality))
        eventContinuation?.finish()
    }

    /// Pause the session (phone call, route change).
    public func pause() {
        // Pause is tracked externally. Engine just stops processing
        // frames until resumed. No state change emitted.
    }

    // MARK: - State Machine

    private func mapAssessmentToState(_ assessment: FormAssessment, at time: TimeInterval) -> FormState {
        switch assessment {
        case .notDetected:
            return .notInPosition
        case .lowConfidence:
            return .cameraBad
        case .good:
            return .goodForm
        case .hipSag:
            return .hipSag
        case .shoulderCreep:
            return .shoulderCreep
        }
    }

    /// Apply debounce: state only changes if the new state holds for >= debounceInterval.
    private func updateState(_ rawState: FormState, at time: TimeInterval) {
        if rawState == currentState {
            pendingState = nil
            return
        }

        if let pending = pendingState, pending == rawState {
            let elapsed = time - pendingStateStart
            if elapsed >= config.debounceInterval {
                transitionTo(rawState, at: time)
                pendingState = nil
            }
        } else {
            pendingState = rawState
            pendingStateStart = time
        }
    }

    private func transitionTo(_ newState: FormState, at time: TimeInterval) {
        let oldState = currentState
        currentState = newState
        emit(.stateChanged(newState))

        switch (oldState, newState) {
        case (_, .goodForm) where oldState == .hipSag || oldState == .shoulderCreep:
            emit(.recovery)
        case (.notInPosition, .goodForm):
            if !sessionActive {
                sessionActive = true
                sessionStartTime = time
                lastGoodFormCheck = time
                emit(.sessionStart)
            }
        case (_, .hipSag), (_, .shoulderCreep):
            formFaultCount += 1
            emit(.formFault(newState))
        default:
            break
        }
    }

    // MARK: - Timers & Milestones

    private func updateTimers(at time: TimeInterval) {
        if currentState == .goodForm {
            goodFormTime += time - lastGoodFormCheck
        }
        lastGoodFormCheck = time
    }

    private func checkMilestones(at time: TimeInterval) {
        let elapsed = Int(time - sessionStartTime)
        for milestone in config.milestones where elapsed >= milestone && !firedMilestones.contains(milestone) {
            firedMilestones.insert(milestone)
            emit(.milestone(seconds: milestone))
        }
    }

    private func checkCountdown(at time: TimeInterval) {
        let elapsed = time - sessionStartTime
        let remaining = Int(targetTime - elapsed)
        if remaining <= config.countdownStart && remaining >= 0 && !firedCountdowns.contains(remaining) {
            firedCountdowns.insert(remaining)
            emit(.countdown(seconds: remaining))
        }
        if elapsed >= targetTime && sessionActive {
            endSession()
        }
    }

    // MARK: - Quality Score

    /// Session quality = (% of hold time with good form) * 0.7 + (total hold time / target time) * 0.3
    private func computeQualityScore(holdTime: TimeInterval) -> Double {
        guard holdTime > 0 else { return 0 }
        let formRatio = min(goodFormTime / holdTime, 1.0)
        let timeRatio = min(holdTime / targetTime, 1.0)
        return (formRatio * 0.7 + timeRatio * 0.3) * 10.0
    }

    // MARK: - Helpers

    private func emit(_ event: SessionEvent) {
        eventContinuation?.yield(event)
    }
}
