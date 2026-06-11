import SwiftUI
import SwiftData
import AVFoundation
import PlankSync
import Auth

struct ChangeTrainerView: View {
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var userRecords: [UserRecord]
    @State private var auth = AuthService.shared
    @State private var previewPlayer: AVAudioPlayer?
    @State private var playingId: String?
    @State private var selectedId: String = ""

    /// Cross-device-synced UserRecord row for the current auth user.
    /// Returns nil for legacy users whose record predates Phase 4 columns
    /// or for fresh installs that haven't hydrated yet.
    private var currentUserRecord: UserRecord? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        if let hit = userRecords.first(where: { $0.id == userId }) { return hit }
        let descriptor = FetchDescriptor<UserRecord>(predicate: #Predicate { $0.id == userId })
        return try? modelContext.fetch(descriptor).first
    }

    // Animation
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = 12
    @State private var cardOpacity: [Double] = [0, 0, 0]
    @State private var cardOffset: [CGFloat] = [24, 24, 24]
    @State private var cardScale: [CGFloat] = [0.92, 0.92, 0.92]
    @State private var hasAnimated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Loading state
    @State private var isLoading = false
    @State private var loadingWord = ""
    @State private var loadingWordIndex = 0
    @State private var loadingDots = ""

    private let trainers: [(id: String, photo: String, name: String, vibe: String, quote: String, preview: String)] = [
        ("encouraging", "coach-jeni", "Jeni", "Mindful & Kind", "\"You're doing beautifully. keep breathing.\"", "jeni_preview"),
        ("keepItReal", "coach-kira", "Kira", "Sassy & Real", "\"My mama planks better than this.\"", "kira_preview"),
        ("balanced", "coach-matson", "Sam", "Chill & Playful", "\"Come on, we're gonna have a good time.\"", "matson_preview"),
    ]

    private let loadingWords = [
        "Warming up vocal cords",
        "Stretching personality",
        "Loading attitude",
        "Calibrating sass levels",
        "Tuning motivation frequency",
        "Brewing coaching energy",
        "Activating coach mode",
    ]

    private var hasChanged: Bool {
        !selectedId.isEmpty && selectedId != voicePreference
    }

    var body: some View {
        ZStack {
            if !isLoading {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        header
                            .opacity(headerOpacity)
                            .offset(y: headerOffset)

                        VStack(spacing: Space.sm) {
                            ForEach(Array(trainers.enumerated()), id: \.element.id) { i, trainer in
                                trainerCard(trainer)
                                    .opacity(cardOpacity[i])
                                    .offset(y: cardOffset[i])
                                    .scaleEffect(cardScale[i], anchor: .center)
                            }
                        }

                        if hasChanged {
                            let newTrainer = trainers.first { $0.id == selectedId }
                            switchPill(newTrainer?.name ?? "coach")
                                .transition(.opacity.combined(with: .offset(y: 8)))
                                .padding(.top, Space.sm)
                        }

                        Spacer().frame(height: Space.xl)
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.top, Space.md)
                }
                .background(Palette.programEraBg)
            }

            if isLoading {
                loadingScreen
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossFade, value: hasChanged)
        .onAppear {
            selectedId = voicePreference
            animateIn()
        }
        .onDisappear { previewPlayer?.stop() }
    }

    // MARK: - Header

    private var header: some View {
        // her75 Phase 6 — JFPageHero (audit §7). Eyebrow dropped;
        // "tap to preview" affordance KEPT (genuinely non-obvious
        // interaction per the editorial-register exception).
        VStack(alignment: .leading, spacing: Space.xs) {
            JFPageHero(title: "your coach.", italic: ["your"], alignment: .leading)
                .padding(.horizontal, -Space.screenPadding)  // parent already pads
            Text("tap to preview their voice.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Switch pill

    private func switchPill(_ name: String) -> some View {
        Button {
            Haptics.vibrate()
            previewPlayer?.stop()
            startLoading(newName: name)
        } label: {
            HStack {
                Text("switch to \(name.lowercased())")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.bgInverse)
                }
            )
        }
        .buttonStyle(TrainerButtonStyle())
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
                withAnimation(Motion.crossFade) {
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
            let previousCoach = voicePreference
            voicePreference = selectedId
            Analytics.track(.coachChanged, properties: [
                "from": previousCoach, "to": selectedId
            ])
            if let record = currentUserRecord {
                record.onboardingVoicePreference = selectedId
                record.pendingUpsert = true
                try? modelContext.save()
                Task { await AppSync.shared.upsertUser(record) }
            }
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

        if reduceMotion {
            headerOpacity = 1
            headerOffset = 0
            for i in 0..<3 {
                cardOpacity[i] = 1
                cardOffset[i] = 0
                cardScale[i] = 1.0
            }
            return
        }

        withAnimation(Motion.gentleSpring.delay(0.1)) {
            headerOpacity = 1
            headerOffset = 0
        }

        for i in 0..<3 {
            let delay = 0.2 + Double(i) * Motion.stagger
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Haptics.soft()
                withAnimation(Motion.gentleSpring) {
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
            withAnimation(Motion.gentleSpring) {
                selectedId = trainer.id
            }
            playPreview(trainer.preview, id: trainer.id)
        } label: {
            HStack(spacing: Space.md) {
                Image(trainer.photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Palette.accent, lineWidth: 2)
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(trainer.name.lowercased() + ".")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                            .foregroundStyle(Palette.textPrimary)

                        if isCurrent {
                            Text("current")
                                .font(Typo.eyebrow).tracking(1)
                                .foregroundStyle(Palette.stateGood)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.stateGood.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(trainer.vibe.lowercased())
                        .font(Typo.eyebrow).tracking(2)
                        .foregroundStyle(Palette.accent)

                    Text(trainer.quote)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .italic()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.accent)
                        .symbolEffect(.variableColor.iterative)
                        .transition(.scale.combined(with: .opacity))
                } else if isSelected && !isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Scrapbook chrome — accent border, hard offset shadow.
            // Selected card gets a stronger accent fill.
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.accent.opacity(0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isSelected ? Palette.accent.opacity(0.10) : Palette.bgElevated)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.accent, lineWidth: isSelected ? 2 : 1.5)
                }
            )
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
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
