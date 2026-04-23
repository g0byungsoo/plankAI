/// Day-1 Spike: Throwaway app to validate VNDetectHumanBodyPoseRequest for planks.
///
/// Run this BEFORE writing any production code.
/// Create a new Xcode project, paste this file, and run on a real device.
///
/// What it does:
/// - Live camera feed with VNDetectHumanBodyPoseRequest
/// - Overlays detected joint dots with per-joint confidence scores
/// - Computes and displays hip angle and shoulder angle
/// - Logs every frame to disk as JSON for test fixture generation
///
/// 4 test scenarios (30 seconds each):
/// 1. Prescribed setup — phone propped on book, 2-3 feet from side, camera horizontal
/// 2. Phone flat on floor — worst-case low angle
/// 3. Intentional hip sag — deliberately drop hips mid-plank
/// 4. Transition states — walk in, plank, hold, get up
///
/// Decision gates:
/// - Scenario 1 confidence <0.5 → fundamental problem, evaluate fallbacks
/// - Scenario 1 passes but 2 fails → enforce propped setup in onboarding
/// - Scenario 3 no clear angle delta → form detection unreliable
/// - All pass → proceed with full pipeline
///
/// Usage:
///   1. Create new Xcode iOS App project (SwiftUI, iOS 17+)
///   2. Add Camera Usage Description to Info.plist
///   3. Replace ContentView.swift with this file
///   4. Run on a real iPhone (Vision requires real camera)
///   5. Prop phone, do a plank, observe joint dots and confidence scores
///   6. Check Documents/ folder for frame JSON logs

import SwiftUI
import AVFoundation
import Vision

// This file is a self-contained spike. In production, this logic
// lives in PlankEngine and CameraManager as separate modules.
// See: Packages/PlankEngine/ and PlankApp/Camera/

struct SpikeContentView: View {
    @State private var jointInfo: [(String, Double, CGPoint)] = []
    @State private var hipAngle: Double = 0
    @State private var shoulderAngle: Double = 0
    @State private var avgConfidence: Double = 0
    @State private var frameCount: Int = 0
    @State private var isRecording = false
    @State private var scenarioName = "prescribed_setup"

    var body: some View {
        ZStack {
            // Camera preview would go here (AVCaptureSession + UIViewRepresentable)
            Color.black.ignoresSafeArea()

            VStack {
                // Joint overlay dots
                ForEach(Array(jointInfo.enumerated()), id: \.offset) { _, joint in
                    Circle()
                        .fill(joint.1 > 0.5 ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                        .position(joint.2)
                        .overlay(
                            Text(String(format: "%.1f", joint.1))
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .position(CGPoint(x: joint.2.x, y: joint.2.y - 15))
                        )
                }

                Spacer()

                // Live metrics
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Confidence: \(String(format: "%.2f", avgConfidence))")
                    Text("Hip Angle: \(String(format: "%.1f°", hipAngle))")
                    Text("Shoulder Angle: \(String(format: "%.1f°", shoulderAngle))")
                    Text("Frames: \(frameCount)")
                    Text("Scenario: \(scenarioName)")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)

                // Scenario selector
                HStack {
                    ForEach(["prescribed", "flat", "hip_sag", "transition"], id: \.self) { name in
                        Button(name) {
                            scenarioName = name
                            frameCount = 0
                        }
                        .font(.caption)
                        .padding(6)
                        .background(scenarioName == name ? Color.green : Color.gray)
                        .cornerRadius(4)
                    }
                }
                .padding(.bottom)
            }
        }
    }
}

/// Frame log entry for fixture generation.
struct FrameLog: Codable {
    let timestamp: Double
    let scenario: String
    let joints: [String: JointLog]
    let hipAngle: Double
    let shoulderAngle: Double
    let avgConfidence: Double
}

struct JointLog: Codable {
    let x: Double
    let y: Double
    let confidence: Double
}
