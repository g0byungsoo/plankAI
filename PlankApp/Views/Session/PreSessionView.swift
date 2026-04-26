import SwiftUI
import AVFoundation

/// Pre-session instruction screen. Shows phone setup + form guide before entering camera session.
/// Also handles camera permission check.
struct PreSessionView: View {
    let exerciseType: String
    let dayNumber: Int
    let onStart: () -> Void
    let onDismiss: () -> Void

    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Day \(dayNumber)")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Palette.bgElevated)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.top, Space.md)

                Spacer()

                // Content based on camera status
                if cameraStatus == .authorized {
                    setupInstructions
                } else if cameraStatus == .denied || cameraStatus == .restricted {
                    cameraBlockedView
                } else {
                    cameraRequestView
                }

                Spacer()

                // CTA
                if cameraStatus == .authorized {
                    Button {
                        Haptics.heavy()
                        onStart()
                    } label: {
                        Text("Start Session")
                            .font(Typo.body)
                            .fontWeight(.bold)
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: Space.minTapTarget + 12)
                            .background(Palette.bgInverse)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.bottom, Space.lg)
                }
            }
        }
    }

    // MARK: - Setup Instructions

    private var setupInstructions: some View {
        VStack(spacing: Space.xl) {
            // Step 1: Phone placement
            VStack(spacing: Space.sm) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.accent)
                Text("Prop your phone up")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)
                Text("About 6 feet away, leaned against something.\nMake sure I can see your whole body.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Step 2: Form guide
            VStack(spacing: Space.sm) {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.accent)
                Text("Get into plank")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)
                Text("Forearms on the floor, elbows under shoulders.\nBody straight from head to heels. Core tight.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Step 3: AI handles the rest
            VStack(spacing: Space.sm) {
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.accent)
                Text("We'll handle the rest")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)
                Text("Your coach watches your form\nand talks you through it.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Keep screen on tip
            HStack(spacing: Space.sm) {
                Image(systemName: "lock.open.display")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.accent)
                Text("Keep your phone unlocked during sessions. Locking or switching apps will pause your workout.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Space.sm + 4)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .padding(.horizontal, Space.screenPadding)
    }

    // MARK: - Camera Permission Request

    private var cameraRequestView: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.accent)

            Text("Your AI Coach\nNeeds to See You")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("So your coach can see your form\nand roast you properly.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    cameraStatus = granted ? .authorized : .denied
                }
            } label: {
                Text("Enable Camera")
                    .font(Typo.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: Space.minTapTarget + 12)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .padding(.horizontal, Space.xl)
        }
        .padding(.horizontal, Space.screenPadding)
    }

    // MARK: - Camera Blocked

    private var cameraBlockedView: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.stateBad)

            Text("Camera Access\nis Turned Off")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("plankAI needs camera access to track your form.\nOpen Settings to enable it.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(Typo.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: Space.minTapTarget + 12)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .padding(.horizontal, Space.xl)
        }
        .padding(.horizontal, Space.screenPadding)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}
