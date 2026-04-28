import SwiftUI
import AVFoundation

struct ChangeTrainerView: View {
    @AppStorage("voicePreference") private var voicePreference = "keepItReal"
    @Environment(\.dismiss) private var dismiss
    @State private var previewPlayer: AVAudioPlayer?
    @State private var playingId: String?
    @State private var selectedId: String = ""

    // Animation
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = 12
    @State private var cardOpacity: [Double] = [0, 0, 0]
    @State private var cardOffset: [CGFloat] = [24, 24, 24]
    @State private var cardScale: [CGFloat] = [0.92, 0.92, 0.92]
    @State private var hasAnimated = false

    // Loading state
    @State private var isLoading = false
    @State private var loadingWord = ""
    @State private var loadingWordIndex = 0
    @State private var loadingDots = ""

    private let trainers: [(id: String, photo: String, name: String, vibe: String, quote: String, preview: String)] = [
        ("keepItReal", "coach-kira", "Kira", "Sassy & Real", "\"My mama planks better than this\"", "kira_preview"),
        ("encouraging", "coach-sarah", "Sarah", "Warm & Supportive", "\"You're doing amazing, keep breathing\"", "sarah_preview"),
        ("balanced", "coach-matson", "Matson", "Chill & Playful", "\"Come on, we're gonna have a good time\"", "matson_preview"),
    ]

    private let loadingWords = [
        "Warming up vocal cords",
        "Stretching personality",
        "Loading attitude",
        "Calibrating sass levels",
        "Flexing voice muscles",
        "Syncing vibes",
        "Tuning motivation frequency",
        "Brewing coaching energy",
        "Downloading tough love",
        "Activating gym mode",
    ]

    private var hasChanged: Bool {
        !selectedId.isEmpty && selectedId != voicePreference
    }

    var body: some View {
        ZStack {
            // Main content
            if !isLoading {
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

                        // Change button
                        if hasChanged {
                            let newTrainer = trainers.first { $0.id == selectedId }
                            Button {
                                Haptics.vibrate()
                                previewPlayer?.stop()
                                startLoading(newName: newTrainer?.name ?? "coach")
                            } label: {
                                Text("Switch to \(newTrainer?.name ?? "coach")")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Palette.textInverse)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Palette.bgInverse)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .transition(.opacity.combined(with: .offset(y: 8)))
                            .padding(.top, Space.sm)
                        }
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.top, Space.md)
                    .padding(.bottom, 40)
                }
                .background(Palette.bgPrimary)
            }

            // Loading screen
            if isLoading {
                loadingScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasChanged)
        .onAppear {
            selectedId = voicePreference
            animateIn()
        }
        .onDisappear { previewPlayer?.stop() }
    }

    // MARK: - Loading Screen

    private var loadingScreen: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                // Trainer photo
                if let trainer = trainers.first(where: { $0.id == selectedId }) {
                    Image(trainer.photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Palette.accent, lineWidth: 2.5))
                }

                VStack(spacing: Space.sm) {
                    Text("\(loadingWord)\(loadingDots)")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())

                    ProgressView()
                        .tint(Palette.accent)
                }
            }
        }
    }

    private func startLoading(newName: String) {
        isLoading = true
        loadingWordIndex = Int.random(in: 0..<loadingWords.count)
        loadingWord = loadingWords[loadingWordIndex]
        loadingDots = ""

        // Cycle through words + dots
        let totalDuration = 2.4
        let wordChanges = 3
        let interval = totalDuration / Double(wordChanges)

        for i in 0..<wordChanges {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    loadingWordIndex = (loadingWordIndex + 1) % loadingWords.count
                    loadingWord = loadingWords[loadingWordIndex]
                    loadingDots = ""
                }
                // Animate dots
                for d in 1...3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(d) * 0.2) {
                        loadingDots = String(repeating: ".", count: d)
                    }
                }
            }
        }

        // Apply change and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            voicePreference = selectedId
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
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
        let isSelected = selectedId == trainer.id
        let isCurrent = voicePreference == trainer.id
        let isPlaying = playingId == trainer.id

        return Button {
            Haptics.medium()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedId = trainer.id
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

                        if isCurrent {
                            Text("current")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.stateGood)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.stateGood.opacity(0.1))
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

                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .symbolEffect(.variableColor.iterative)
                        .transition(.scale.combined(with: .opacity))
                } else if isSelected && !isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.accent)
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

private struct TrainerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
