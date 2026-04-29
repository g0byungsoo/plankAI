import SwiftUI

/// Shown while AuthService.bootstrap() runs. Returning users with a cached
/// session will see this for one or two frames; fresh installs see it for
/// however long the anonymous sign-in network call takes.
struct AuthBootstrapSplash: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var pulse = false
    @State private var lineVisible = false

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("absmaxxing")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Palette.textPrimary)

                Spacer().frame(height: 12)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.accent)
                    .frame(width: lineVisible ? 120 : 0, height: 4)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: lineVisible)

                Spacer().frame(height: Space.lg)

                content

                Spacer()
            }
        }
        .onAppear {
            lineVisible = true
            pulse = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .running:
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Palette.accent.opacity(pulse ? 0.8 : 0.2))
                        .frame(width: 6, height: 6)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: pulse
                        )
                }
            }
        case .ready:
            // Briefly visible during the fade-out frame to the next view.
            EmptyView()
        case .failed(let message):
            VStack(spacing: Space.md) {
                Text("Couldn't connect")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)

                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)

                Button(action: onRetry) {
                    Text("Try again")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                        .frame(width: 160, height: 44)
                        .background(Palette.bgInverse)
                        .clipShape(Capsule())
                }
                .padding(.top, Space.xs)
            }
        }
    }
}
