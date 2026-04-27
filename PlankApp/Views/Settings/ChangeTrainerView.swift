import SwiftUI
import AVFoundation

struct ChangeTrainerView: View {
    @AppStorage("voicePreference") private var voicePreference = "keepItReal"
    @State private var previewPlayer: AVAudioPlayer?
    @State private var playingId: String?

    // Animation
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = 12
    @State private var cardOpacity: [Double] = [0, 0, 0]
    @State private var cardOffset: [CGFloat] = [24, 24, 24]
    @State private var cardScale: [CGFloat] = [0.92, 0.92, 0.92]
    @State private var hasAnimated = false

    private let trainers: [(id: String, photo: String, name: String, vibe: String, quote: String, preview: String)] = [
        ("keepItReal", "coach-kira", "Kira", "Sassy & Real", "\"My mama planks better than this\"", "kira_preview"),
        ("encouraging", "coach-sarah", "Sarah", "Warm & Supportive", "\"You're doing amazing, keep breathing\"", "sarah_preview"),
        ("balanced", "coach-matson", "Matson", "Charming & Motivating", "\"Come on darlin', you got this\"", "matson_preview"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Your Coach")
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)

                    Text("Tap to preview their voice.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                .opacity(headerOpacity)
                .offset(y: headerOffset)

                VStack(spacing: 12) {
                    ForEach(Array(trainers.enumerated()), id: \.element.id) { i, trainer in
                        trainerCard(trainer)
                            .opacity(cardOpacity[i])
                            .offset(y: cardOffset[i])
                            .scaleEffect(cardScale[i], anchor: .center)
                    }
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .onAppear { animateIn() }
        .onDisappear { previewPlayer?.stop() }
    }

    // MARK: - Animation

    private func animateIn() {
        guard !hasAnimated else { return }
        hasAnimated = true

        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
            headerOpacity = 1
            headerOffset = 0
        }

        for i in 0..<3 {
            let delay = 0.2 + Double(i) * 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Haptics.soft()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    cardOpacity[i] = 1
                    cardOffset[i] = 0
                    cardScale[i] = 1.0
                }
            }
        }
    }

    // MARK: - Trainer Card

    private func trainerCard(_ trainer: (id: String, photo: String, name: String, vibe: String, quote: String, preview: String)) -> some View {
        let isSelected = voicePreference == trainer.id
        let isPlaying = playingId == trainer.id

        return Button {
            Haptics.medium()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                voicePreference = trainer.id
            }
            playPreview(trainer.preview, id: trainer.id)
        } label: {
            HStack(spacing: 14) {
                Image(trainer.photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Palette.accent : Color.clear, lineWidth: 2.5)
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(trainer.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)

                        if isSelected {
                            Text("active")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.accent.opacity(0.1))
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(trainer.vibe)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)

                    Text(trainer.quote)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                        .italic()
                }

                Spacer()

                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .symbolEffect(.variableColor.iterative)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(isSelected ? Palette.accent.opacity(0.06) : Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Palette.accent.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
            .plankShadow()
        }
        .buttonStyle(TrainerButtonStyle())
    }

    private func playPreview(_ clip: String, id: String) {
        previewPlayer?.stop()
        guard let url = Bundle.main.url(forResource: clip, withExtension: "m4a") else { return }
        previewPlayer = try? AVAudioPlayer(contentsOf: url)
        previewPlayer?.play()
        playingId = id
        let duration = previewPlayer?.duration ?? 3
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if playingId == id { playingId = nil }
        }
    }
}

// MARK: - Press Scale Button Style

private struct TrainerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
