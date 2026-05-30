import SwiftUI
import UIKit
import AVFoundation
import PlankEngine
import PlankVoice

/// The active plank session screen.
/// Audio-led with minimal glance-check visuals.
/// Design principle: user should complete the plank without looking at the phone.
struct SessionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine: PlankSessionEngine
    @State private var camera = CameraManager()
    @State private var audioQueue = AudioQueue(
        provider: ClipBundleProvider(),
        lineLibrary: .devLibrary
    )
    @State private var elapsedTime: TimeInterval = 0
    @State private var currentState: FormState = .notInPosition
    @State private var sessionActive = false
    @State private var sessionEnded = false
    @State private var holdTime: TimeInterval = 0
    @State private var qualityScore: Double = 0
    @State private var showEndConfirm = false
    @State private var audioMuted = false
    @State private var showGuideFrame = true
    @State private var timer: Timer?
    @State private var pausedByBackground = false

    let exerciseType: String
    let dayNumber: Int
    let targetTime: TimeInterval
    let onComplete: (Double, Double, Int) -> Void  // holdTime, qualityScore, faults

    init(
        exerciseType: String = "Standard Plank",
        dayNumber: Int = 1,
        targetTime: TimeInterval = 60,
        onComplete: @escaping (Double, Double, Int) -> Void
    ) {
        self.exerciseType = exerciseType
        self.dayNumber = dayNumber
        self.targetTime = targetTime
        self.onComplete = onComplete
        self._engine = State(initialValue: PlankSessionEngine())
    }

    @State private var borderRotation: Double = 0
    @State private var emergencyBlink = false

    /// Form is imperfect but still planking — show colored lines, no emergency.
    private var isFormFault: Bool {
        switch currentState {
        case .hipSag, .hipPike, .shoulderCreep: return true
        default: return false
        }
    }

    /// Completely out of position — emergency light.
    private var isOutOfPosition: Bool {
        currentState == .notInPosition && sessionActive
    }

    /// Short form label.
    private var formLabel: String? {
        switch currentState {
        case .hipSag: return "hips"
        case .hipPike: return "hips down"
        case .shoulderCreep: return "shoulders"
        case .notInPosition where sessionActive: return "get back down"
        default: return nil
        }
    }

    // Neon colors
    private static let neonGreen = Color(hex: "#30FF00")
    private static let neonPink = Color(hex: "#FF13F0")

    /// Border colors based on state.
    private var borderColors: [Color] {
        if currentState == .goodForm {
            return [Self.neonGreen, Self.neonGreen.opacity(0.4), Self.neonGreen, Self.neonGreen.opacity(0.6)]
        } else if isOutOfPosition {
            return [Self.neonPink, Self.neonPink.opacity(0.4), Self.neonPink, Self.neonPink.opacity(0.6)]
        } else if isFormFault {
            // Partial fault — warm amber border, no emergency
            return [Palette.accent, Palette.accentSubtle, Palette.accent, Palette.accentSubtle]
        } else {
            return [Palette.accentSubtle, Palette.accentSubtle.opacity(0.2), Palette.accentSubtle, Palette.accentSubtle.opacity(0.4)]
        }
    }

    /// Border thickness based on state.
    private var borderWidth: CGFloat {
        if isOutOfPosition { return 14 }
        if currentState == .goodForm { return 10 }
        if isFormFault { return 10 }
        return 8
    }

    /// Timer adapts color to state for max contrast.
    private var timerColor: Color {
        if currentState == .goodForm { return .white }
        if isOutOfPosition { return Palette.accentSubtle }
        return .white
    }

    var body: some View {
        ZStack {
            // Layer 1: Full-screen camera
            CameraPreview(previewLayer: camera.previewLayer)
                .ignoresSafeArea()

            // Layer 2: Pose skeleton (toggleable)
            if showGuideFrame {
                PoseOverlay(joints: camera.detectedJoints, state: currentState)
                    .ignoresSafeArea()
            }

            // Layer 3: Rotating border — uses device screen corner radius
            // UnsafeArea inset by half the border width so the stroke
            // sits flush against the physical screen edge on every iPhone.
            GeometryReader { geo in
                let screenRadius = UIScreen.main.displayCornerRadius
                RoundedRectangle(cornerRadius: max(screenRadius - borderWidth / 2, 0))
                    .inset(by: borderWidth / 2)
                    .stroke(
                        AngularGradient(
                            colors: borderColors + borderColors,
                            center: .center,
                            angle: .degrees(borderRotation)
                        ),
                        lineWidth: borderWidth
                    )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(Motion.crossFade, value: currentState)

            // Layer 4a: Good form — steady neon green glow from edges
            if currentState == .goodForm {
                RoundedRectangle(cornerRadius: UIScreen.main.displayCornerRadius)
                    .fill(
                        RadialGradient(
                            colors: [.clear, .clear, Self.neonGreen.opacity(0.15)],
                            center: .center,
                            startRadius: 100,
                            endRadius: 500
                        )
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Layer 4b: EMERGENCY — only when completely out of position (RED)
            if isOutOfPosition {
                Color(hex: "#FF0000")
                    .opacity(emergencyBlink ? 0.35 : 0.08)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                            emergencyBlink = true
                        }
                    }
                    .onDisappear { emergencyBlink = false }
            }

            // Layer 5: Overlaid UI
            VStack {
                // Top bar
                HStack {
                    Text("day \(dayNumber)")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Button {
                        showEndConfirm = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .tappableArea()
                    }
                    .accessibilityLabel("End plank")
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.top, Space.sm)

                Spacer()

                // Timer — adapts color to background state
                Text(formatTime(elapsedTime))
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(timerColor)
                    .shadow(color: .black.opacity(0.7), radius: 20, y: 6)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .contentTransition(.numericText())
                    .animation(Motion.crossFade, value: currentState)

                // Form fault label
                if let label = formLabel {
                    Text(label)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Palette.stateBad.opacity(0.7))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .padding(.top, Space.sm)
                }

                Spacer()

                // Bottom controls
                HStack {
                    Button {
                        withAnimation(Motion.tap) { showGuideFrame.toggle() }
                    } label: {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 15))
                            .foregroundStyle(showGuideFrame ? Palette.accent : .white.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button {
                        audioMuted.toggle()
                    } label: {
                        Image(systemName: audioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .tappableArea()
                    }

                    Spacer()
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.lg)
            }
            // Pause overlay when returning from background
            if pausedByBackground {
                plankPausedOverlay
                    .transition(.opacity)
            }
        }
        .alert("end session?", isPresented: $showEndConfirm) {
            Button("end", role: .destructive) {
                Task { await engine.endSession() }
            }
            Button("keep going", role: .cancel) {}
        }
        .task {
            // Keep the screen awake for the whole plank hold — auto-lock
            // mid-hold is frustrating. Re-enabled on disappear.
            UIApplication.shared.isIdleTimerDisabled = true
            // Unlock all orientations for session (user planks in landscape)
            OrientationManager.shared.allowedOrientations = .all
            // Defensive: clear any voice-line dedup / cooldown state that
            // could survive across .fullScreenCover presentations.
            await audioQueue.resetSession()
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                borderRotation = 360
            }
            await startSession()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            stopTimer()
            camera.stopSession()
            // Lock back to portrait
            OrientationManager.shared.allowedOrientations = .portrait
            // Defer the audio session release so the end-of-session voice
            // cue (e.g. "i'm proud of you") finishes before the session
            // goes silent. The immediate setActive(false) was cutting the
            // line mid-word during the transition to PostSessionView.
            Task.detached {
                try? await Task.sleep(for: .seconds(5))
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if sessionActive && !sessionEnded {
                    stopTimer()
                    camera.stopSession()
                    pausedByBackground = true
                }
            }
        }
    }

    // MARK: - Plank Pause Overlay

    private var plankPausedOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Text("paused")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(2)

                Text("plank hold")
                    .font(Typo.titleItalic)
                    .foregroundStyle(.white)

                Text("\(formatTime(elapsedTime)) elapsed")
                    .font(Typo.body)
                    .foregroundStyle(.white.opacity(0.65))

                VStack(spacing: Space.sm) {
                    Button {
                        Haptics.medium()
                        pausedByBackground = false
                        camera.startSession()
                        startTimer()
                    } label: {
                        HStack {
                            Text("resume")
                                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 22)
                        .frame(height: 60)
                        .background(Palette.accent)
                        .clipShape(Capsule())
                    }

                    Button {
                        pausedByBackground = false
                        Task { await engine.endSession() }
                    } label: {
                        Text("end session")
                            .font(Typo.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: Space.minTapTarget + 4)
                    }
                }
                .padding(.top, Space.md)
            }
            .padding(Space.lg)
            .padding(.horizontal, Space.screenPadding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - Session Logic

    private func startSession() async {
        // Set up audio session for voice playback over speaker.
        // .duckOthers lowers music volume during voice clips.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // IMPORTANT: Access the event stream BEFORE starting the camera.
        // This creates the AsyncStream continuation. If the camera starts
        // first, processFrame() calls emit() with a nil continuation
        // and all events are silently dropped.
        let eventStream = await engine.events

        camera.onPoseFrame = { [engine] frame in
            Task { await engine.processFrame(frame) }
        }
        camera.startSession()

        // Play setup instruction after 2 seconds if user hasn't gotten into position
        Task {
            try? await Task.sleep(for: .seconds(2))
            if !sessionActive && !audioMuted {
                await audioQueue.handleEvent(.stateChanged(.notInPosition))
            }
        }

        // Listen for events
        for await event in eventStream {
            // Forward all events to voice feedback.
            if !audioMuted {
                Task { await audioQueue.handleEvent(event) }
            }

            switch event {
            case .stateChanged(let state):
                withAnimation(Motion.crossFade) {
                    currentState = state
                }
                // Haptic feedback for state changes
                switch state {
                case .goodForm: Haptics.success()
                case .hipSag, .hipPike, .shoulderCreep: Haptics.warning()
                case .notInPosition where sessionActive: Haptics.error()
                default: break
                }
                // Pause/resume timer based on plank state
                if sessionActive {
                    if state == .notInPosition || state == .cameraBad {
                        stopTimer()
                    } else if timer == nil {
                        startTimer()
                    }
                }
            case .sessionStart:
                if !sessionActive {
                    sessionActive = true
                    startTimer()
                }
            case .sessionEnd(let time, let score):
                Haptics.heavy()
                holdTime = time
                qualityScore = score
                sessionEnded = true
                stopTimer()
                camera.stopSession()
                onComplete(time, score, 0)
            case .milestone:
                Haptics.medium()
            case .countdown:
                Haptics.light()
            default:
                break
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = Int(time)
        return "\(total)s"
    }
}

// MARK: - Camera Preview

/// Hosts the CameraManager-owned AVCaptureVideoPreviewLayer.
/// The layer's rotation is managed by CameraManager's RotationCoordinator.
class CameraPreviewView: UIView {
    let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> CameraPreviewView {
        CameraPreviewView(previewLayer: previewLayer)
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}

// MARK: - Pose Overlay

/// Body segment zones for per-area coloring.
private enum BodyZone {
    case shoulder  // shoulder-related bones
    case core      // shoulder-to-hip (torso), hip-to-hip
    case legs      // hip-to-knee, knee-to-ankle
    case arms      // shoulder-to-elbow, elbow-to-wrist
}

struct PoseOverlay: View {
    let joints: [JointName: CGPoint]
    let state: FormState

    /// Each bone tagged with its body zone.
    private let bones: [(JointName, JointName, BodyZone)] = [
        (.leftShoulder, .rightShoulder, .shoulder),
        (.leftShoulder, .leftElbow, .arms),
        (.leftElbow, .leftWrist, .arms),
        (.rightShoulder, .rightElbow, .arms),
        (.rightElbow, .rightWrist, .arms),
        (.leftShoulder, .leftHip, .core),
        (.rightShoulder, .rightHip, .core),
        (.leftHip, .rightHip, .core),
        (.leftHip, .leftKnee, .legs),
        (.leftKnee, .leftAnkle, .legs),
        (.rightHip, .rightKnee, .legs),
        (.rightKnee, .rightAnkle, .legs),
    ]

    // Neon colors matching the border
    private static let neonGreen = Color(hex: "#30FF00")
    private static let neonPink = Color(hex: "#FF13F0")

    /// Color for a specific body zone — neon green (ok) or neon pink (problem).
    private func colorForZone(_ zone: BodyZone) -> Color {
        switch state {
        case .shoulderCreep:
            return zone == .shoulder ? Self.neonPink : Self.neonGreen
        case .hipSag, .hipPike:
            return zone == .core ? Self.neonPink : Self.neonGreen
        case .goodForm:
            return Self.neonGreen
        case .cameraBad, .notInPosition, .shaking:
            return Palette.accentSubtle
        }
    }

    /// Joint dot color.
    private func colorForJoint(_ name: JointName) -> Color {
        switch state {
        case .shoulderCreep:
            let bad = (name == .leftShoulder || name == .rightShoulder || name == .nose)
            return bad ? Self.neonPink : Self.neonGreen
        case .hipSag, .hipPike:
            let bad = (name == .leftHip || name == .rightHip || name == .root)
            return bad ? Self.neonPink : Self.neonGreen
        case .goodForm:
            return Self.neonGreen
        default:
            return Palette.accentSubtle
        }
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                func screenPoint(_ p: CGPoint) -> CGPoint {
                    CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
                }

                // Draw bones — thick neon lines with glow
                for (a, b, zone) in bones {
                    guard let pa = joints[a], let pb = joints[b] else { continue }
                    let color = colorForZone(zone)
                    var path = Path()
                    path.move(to: screenPoint(pa))
                    path.addLine(to: screenPoint(pb))
                    // Wide glow
                    context.stroke(path, with: .color(color.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    // Main line
                    context.stroke(path, with: .color(color.opacity(0.9)),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                }

                // Draw joint dots
                let dotSize: CGFloat = 18
                for (name, point) in joints {
                    let sp = screenPoint(point)
                    let color = colorForJoint(name)
                    // Glow
                    let glowSize = dotSize * 2.5
                    let glowRect = CGRect(x: sp.x - glowSize/2, y: sp.y - glowSize/2, width: glowSize, height: glowSize)
                    context.fill(Ellipse().path(in: glowRect), with: .color(color.opacity(0.2)))
                    // Dot
                    let rect = CGRect(x: sp.x - dotSize/2, y: sp.y - dotSize/2, width: dotSize, height: dotSize)
                    context.fill(Ellipse().path(in: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .animation(Motion.tap, value: state)
    }
}

// MARK: - Screen Corner Radius

extension UIScreen {
    /// The physical display corner radius. Uses the private `_displayCornerRadius`
    /// key with a safe fallback for devices where it's unavailable.
    var displayCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        guard let radius = value(forKey: key) as? CGFloat, radius > 0 else {
            return 50 // safe default for modern iPhones
        }
        return radius
    }
}
