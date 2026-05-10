import SwiftUI
import AVFoundation
import PlankSync

/// Shown after the user taps Start on the Home card and before the live
/// session player. Surfaces the workout's name, calorie estimate, total
/// time, exercise count, a one-line "why this works" tip, and a list of
/// every exercise with its duration and category.
struct PreRoutineView: View {
    let workout: WorkoutPreset
    let onStart: () -> Void
    let onCancel: () -> Void

    /// Holds the welcome clip player so it doesn't get cut off if SwiftUI
    /// recreates the body. Single playback per presentation — guarded by
    /// `didPlayIntro`. Recorded coach voice (one of the `routine_start_*`
    /// clips for the selected trainer) — replaces the prior robotic
    /// AVSpeechSynthesizer intro.
    @State private var introPlayer: AVAudioPlayer?
    @State private var didPlayIntro = false

    /// Reference body weight for kcal estimation. Real per-user weight
    /// arrives in Phase 7 (weight-loss analytics) — until then this gives a
    /// stable, transparent baseline (~average adult woman).
    private static let referenceBodyKg: Double = 65

    private var totalKcal: Int {
        let total = workout.exercises.reduce(0.0) { sum, slot in
            guard let ex = slot.exercise else { return sum }
            return sum + ex.kcalPerMinute(bodyWeightKg: Self.referenceBodyKg)
                * Double(slot.duration) / 60.0
        }
        return max(1, Int(total.rounded()))
    }

    /// Distinct primary areas across main slots, in original order.
    private var primaryAreas: [TargetArea] {
        var seen: Set<TargetArea> = []
        var ordered: [TargetArea] = []
        for slot in workout.exercises where slot.category == .main {
            if let area = slot.exercise?.primaryArea, !seen.contains(area) {
                seen.insert(area); ordered.append(area)
            }
        }
        return ordered
    }

    private var tip: String {
        let names = primaryAreas.map { $0.rawValue.camelCaseToWords.lowercased() }
        if names.isEmpty {
            return "A balanced routine to keep you moving today."
        }
        let joined: String = {
            switch names.count {
            case 1: return names[0]
            case 2: return "\(names[0]) and \(names[1])"
            default: return names.dropLast().joined(separator: ", ") + ", and \(names.last!)"
            }
        }()
        return "Targets your \(joined). Built around recovery so you can come back tomorrow."
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        header
                        statsRow
                        tipCard
                        exerciseList
                            .padding(.bottom, 100)   // breathe over the start button
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.top, Space.md)
                }

                startButton
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.bottom, Space.lg)
            }
        }
        .onAppear {
            playIntroIfNeeded()
        }
        .onDisappear {
            introPlayer?.stop()
            introPlayer = nil
        }
    }

    /// Play a recorded coach voice clip on first appearance. Picks a
    /// random `routine_start_<n>` from the trainer the user selected
    /// (Kira / Jeni / Sam), so the welcome is on-brand instead of
    /// robotic system TTS. Guarded by `didPlayIntro` so a SwiftUI
    /// re-render doesn't restart playback.
    private func playIntroIfNeeded() {
        guard !didPlayIntro else { return }
        didPlayIntro = true

        // Trainer prefix — empty for Kira, "jeni_" for Jeni, "matson_"
        // for Sam (kept internal; user-facing display is "Sam").
        // Mirrors RoutineAudioManager.prefix.
        let prefix: String
        switch UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging" {
        case "encouraging": prefix = "jeni_"
        case "balanced":    prefix = "matson_"
        default:            prefix = ""
        }

        // Try the trainer-prefixed variant first, fall back to the
        // un-prefixed Kira clip if the trainer's variant isn't bundled.
        let pick = Int.random(in: 1...3)
        let baseName = "routine_start_\(pick)"
        let trainerName = prefix.isEmpty ? baseName : "\(prefix)\(baseName)"
        let url = Bundle.main.url(forResource: trainerName, withExtension: "m4a")
            ?? Bundle.main.url(forResource: baseName, withExtension: "m4a")
        guard let url else { return }
        do {
            introPlayer = try AVAudioPlayer(contentsOf: url)
            introPlayer?.volume = 1.0
            introPlayer?.play()
        } catch {
            // Audio failure is non-fatal — silent intro is acceptable
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
                    .tappableArea()
            }
            .accessibilityLabel("Close")
            Spacer()
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            VStack(spacing: Space.xs) {
                Text("today's workout")
                    .font(Typo.eyebrow)
                    .tracking(2)
                    .foregroundStyle(Palette.accent)

                Text(workout.name.lowercased())
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                if let desc = workout.description {
                    Text(desc)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Space.xs)
                }
            }

            // Two small stickers framing the header — gives the screen
            // visual punctuation without competing with the title.
            HStack {
                Image(StickerName.candyIridescent.assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-15))
                    .opacity(StickerName.candyIridescent.style.opacity)
                Spacer()
                Image(StickerName.starLineart.assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(18))
                    .opacity(StickerName.starLineart.style.opacity)
            }
            .padding(.horizontal, Space.lg)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: Space.sm) {
            statCard(icon: "clock", value: "\(workout.estimatedDuration)", unit: "min")
            statCard(icon: "flame.fill", value: "\(totalKcal)", unit: "kcal")
            statCard(icon: "figure.run", value: "\(workout.exercises.count)", unit: "moves")
        }
    }

    private func statCard(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .padding(.bottom, 4)
            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Palette.textPrimary)
            Text(unit)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.accent.opacity(0.15))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }

    // MARK: - Tip card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .padding(.top, 3)
            Text(tip)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.accent.opacity(0.15))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.accentSubtle.opacity(0.45))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
            }
        )
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        // Insert "round N" dividers when slot.round changes — Pamela
        // Reif's "and now repeat" pattern (rules §4). Most sessions are
        // round 1 only, so no dividers render. For long sessions we get
        // one divider before the first slot of each round.
        let entries = Array(workout.exercises.enumerated())
        let totalRounds = workout.exercises.map { $0.round }.max() ?? 1

        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("the plan")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
                .padding(.bottom, Space.xs)

            ForEach(entries, id: \.offset) { idx, slot in
                if shouldShowRoundDivider(idx: idx, slot: slot, totalRounds: totalRounds) {
                    roundDivider(round: slot.round, of: totalRounds)
                }
                exerciseRow(idx: idx, slot: slot)
            }
        }
    }

    /// Show a divider when (a) the session has multiple rounds, AND (b)
    /// this is the first slot of its round (or main category transitions
    /// happen — warmup → round 1 main → round 2 main → cooldown).
    private func shouldShowRoundDivider(idx: Int, slot: ExerciseSlot, totalRounds: Int) -> Bool {
        guard totalRounds > 1 else { return false }
        guard slot.category == .main else { return false }
        if idx == 0 { return true }
        let prev = workout.exercises[idx - 1]
        // First main slot, or round changed within main.
        return prev.category != .main || prev.round != slot.round
    }

    private func roundDivider(round: Int, of total: Int) -> some View {
        HStack(spacing: Space.sm) {
            Text("round \(round) · of \(total)")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .tracking(2)
                .foregroundStyle(Palette.accent)
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)
        }
        .padding(.top, Space.xs)
    }

    private func exerciseRow(idx: Int, slot: ExerciseSlot) -> some View {
        HStack(spacing: Space.md) {
            Text("\(idx + 1)")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(Palette.accent)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(slot.exercise?.name.lowercased() ?? slot.exerciseId)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: 6) {
                    Text(categoryLabel(slot.category))
                        .font(Typo.caption)
                        .foregroundStyle(categoryColor(slot.category))
                    // Surface body position so the user sees the flow
                    // through the session (standing → quadruped → plank
                    // → supine, etc.) before they start.
                    if let pos = slot.exercise?.position {
                        Text("·")
                            .foregroundStyle(Palette.textSecondary)
                        Text(positionLabel(pos))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let side = slot.side {
                        Text("·")
                            .foregroundStyle(Palette.textSecondary)
                        Text(side.rawValue)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Spacer()

            Text("\(slot.duration)s")
                .font(.custom("Fraunces72pt-SemiBold", size: 16))
                .foregroundStyle(Palette.textPrimary)
        }
        // Compound exercise row — VoiceOver reads "1, squat, main,
        // standing, 30 seconds" as one phrase per row instead of
        // walking 5 separate elements.
        .accessibilityElement(children: .combine)
        .padding(.vertical, Space.sm + 2)
        .padding(.horizontal, Space.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        )
    }

    private func categoryLabel(_ c: ExerciseCategory) -> String {
        switch c {
        case .warmup:   return "warm up"
        case .main:     return "main"
        case .cooldown: return "cool down"
        }
    }

    private func categoryColor(_ c: ExerciseCategory) -> Color {
        switch c {
        case .warmup:   return Palette.accent
        case .main:     return Palette.textSecondary
        case .cooldown: return Palette.stateGood
        }
    }

    private func positionLabel(_ p: ExercisePosition) -> String {
        switch p {
        case .standing:   return "standing"
        case .quadruped:  return "quadruped"
        case .plank:      return "plank"
        case .prone:      return "prone"
        case .sideLying:  return "side-lying"
        case .supine:     return "supine"
        case .seated:     return "seated"
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Button {
            Haptics.vibrate()
            onStart()
        } label: {
            HStack {
                Text("start workout")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, 22)
            .frame(height: 60)
            .background(Palette.bgInverse)
            .clipShape(Capsule())
        }
    }
}
