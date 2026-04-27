import SwiftUI
import AVFoundation

struct ChangeTrainerView: View {
    @AppStorage("voicePreference") private var voicePreference = "keepItReal"
    @State private var previewPlayer: AVAudioPlayer?
    @State private var playingId: String?

    private let trainers: [(id: String, photo: String, name: String, vibe: String, quote: String, preview: String)] = [
        ("keepItReal", "coach-kira", "Kira", "Sassy & Real", "\"My mama planks better than this\"", "kira_preview"),
        ("encouraging", "coach-sarah", "Sarah", "Warm & Supportive", "\"You're doing amazing, keep breathing\"", "sarah_preview"),
        ("balanced", "coach-matson", "Matson", "Charming & Motivating", "\"Come on darlin', you got this\"", "matson_preview"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Your Coach")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                Text("Tap to preview their voice. Your coach guides you through every workout.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)

                VStack(spacing: 12) {
                    ForEach(trainers, id: \.id) { trainer in
                        trainerCard(trainer)
                    }
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .onDisappear { previewPlayer?.stop() }
    }

    private func trainerCard(_ trainer: (id: String, photo: String, name: String, vibe: String, quote: String, preview: String)) -> some View {
        let isSelected = voicePreference == trainer.id
        let isPlaying = playingId == trainer.id

        return Button {
            Haptics.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                voicePreference = trainer.id
            }
            playPreview(trainer.preview, id: trainer.id)
        } label: {
            HStack(spacing: 14) {
                // Photo
                Image(trainer.photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Palette.accent : Color.clear, lineWidth: 2.5)
                    )

                // Info
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

                // Play indicator
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .symbolEffect(.variableColor.iterative)
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
