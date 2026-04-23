import SwiftUI
import AVFoundation
import PlankEngine

/// The active plank session screen.
/// Audio-led with minimal glance-check visuals.
/// Design principle: user should complete the plank without looking at the phone.
struct SessionView: View {
    @State private var engine: PlankSessionEngine
    @State private var camera = CameraManager()
    @State private var elapsedTime: TimeInterval = 0
    @State private var currentState: FormState = .notInPosition
    @State private var sessionEnded = false
    @State private var holdTime: TimeInterval = 0
    @State private var qualityScore: Double = 0
    @State private var showEndConfirm = false
    @State private var audioMuted = false

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

    var body: some View {
        ZStack {
            // Layer 1: Camera feed (darkened, desaturated)
            CameraPreview(session: camera.previewSession)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.5))
                .saturation(0.3)

            // Layer 2: Pose overlay dots (color reflects form state)
            PoseOverlay(state: currentState)

            // Layer 3: Timer + context
            VStack {
                Spacer()

                // Timer (count-up, accumulation framing)
                Text(formatTime(elapsedTime))
                    .font(Typo.display)
                    .foregroundStyle(Palette.textInverse)
                    .contentTransition(.numericText())

                Text("Day \(dayNumber) · \(exerciseType)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textInverse.opacity(0.6))
                    .padding(.top, Space.xs)

                Spacer()

                // Camera guidance (only visible in CAMERA_BAD state)
                if currentState == .cameraBad {
                    Text("Move your phone back a bit")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textInverse)
                        .padding(Space.md)
                        .background(Palette.stateBad.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .transition(.opacity)
                }

                Spacer()

                // Bottom controls
                HStack {
                    // Audio toggle
                    Button {
                        audioMuted.toggle()
                    } label: {
                        Image(systemName: audioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.textInverse.opacity(0.6))
                            .frame(width: Space.minTapTarget, height: Space.minTapTarget)
                    }

                    Spacer()

                    // End session (hold to confirm)
                    Button {
                        showEndConfirm = true
                    } label: {
                        Text("End Session")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textInverse.opacity(0.5))
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.sm)
                            .background(Palette.textInverse.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.lg)
            }
        }
        .background(Color.black)
        .alert("End Session?", isPresented: $showEndConfirm) {
            Button("End", role: .destructive) {
                Task { await engine.endSession() }
            }
            Button("Keep Going", role: .cancel) {}
        }
        .task {
            await startSession()
        }
        .onDisappear {
            camera.stopSession()
        }
    }

    // MARK: - Session Logic

    private func startSession() async {
        camera.onPoseFrame = { frame in
            Task { await engine.processFrame(frame) }
        }
        camera.startSession()

        // Listen for events
        for await event in await engine.events {
            switch event {
            case .stateChanged(let state):
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentState = state
                }
            case .sessionEnd(let time, let score):
                holdTime = time
                qualityScore = score
                sessionEnded = true
                camera.stopSession()
                onComplete(time, score, 0)
            case .milestone:
                // Subtle flash
                break
            default:
                break
            }

            // Update elapsed time
            if case .stateChanged(.goodForm) = event {
                // Start counting once in good form
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
        return "\(seconds)s"
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - Pose Overlay

struct PoseOverlay: View {
    let state: FormState

    var overlayColor: Color {
        switch state {
        case .goodForm: Palette.stateGood
        case .hipSag, .shoulderCreep: Palette.stateWarn
        case .cameraBad: Palette.stateBad
        case .notInPosition, .shaking: .gray
        }
    }

    var body: some View {
        // Minimal dot overlay. In production, joint positions would be
        // projected from VNHumanBodyPoseObservation recognized points.
        Circle()
            .fill(overlayColor.opacity(0.4))
            .frame(width: 12, height: 12)
            .position(x: 100, y: 200)  // Placeholder positions
            .animation(.easeInOut(duration: 0.5), value: state)
    }
}
