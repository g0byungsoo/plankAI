import SwiftUI
import AVFoundation

// MARK: - BreathworkSessionView
//
// The ~2.5 min guided breath session in the post-purchase flow. Per the
// breathwork-science research synthesis (2026-05-27): slow exhale-dominant
// breathing (JeniFit's existing 4-in / 6-out, in the coherent/parasympathetic
// band) for ~12 cycles. Jeni's voice opens and closes; the BreathCircle
// visual + haptics guide each cycle (no per-cycle audio — avoids sync
// complexity and the repetitive-cue problem).
//
// Reuses BreathCircle.swift verbatim. Three phases:
//   .intro     — Jeni intro audio plays, bloom holds
//   .breathing — BreathCircle cycles 4-in / 6-out × 12
//   .complete  — "ready to move?" choice (option C per product decision):
//                  "let's go"  → onReadyToMove() (workout)
//                  "later"     → onLater()        (home)
//                X (any phase) → onDismiss()       (home)
//
// Audio prefers breath_intro_<voice>.m4a / breath_close_<voice>.m4a
// (run Scripts/generate_breathwork_clips.sh). Falls back to text-only
// (on-screen cues + BreathCircle) if the clips aren't in the bundle —
// the session still works, just silent.

struct BreathworkSessionView: View {
    let onReadyToMove: () -> Void
    let onLater: () -> Void
    let onDismiss: () -> Void

    /// Which technique to run. Default is `.calming` so Day-1
    /// PostPurchaseFlowView's existing call site stays a one-line
    /// `BreathworkSessionView(onReadyToMove:..., onLater:..., onDismiss:...)`
    /// without changes. Home re-entry passes a value from BreathLibraryView.
    var techProtocol: BreathworkProtocol = .calming

    /// Session length multiplier — the protocol's base repeats cover
    /// ~1 minute; the Balban dose is 5 min/day, so the intro offers
    /// 1 / 2 / 5 and the session scales its cycle count.
    var sessionMinutes: Int = 1

    /// Where the session was launched from. Day-1's post-purchase
    /// flow keeps the "ready to move" chained choice; daily program
    /// entries end on the receipt (PostSessionView's quieter sibling
    /// — a breath session ends at ~30% of a workout's celebration).
    enum SessionContext { case day1, daily }
    var context: SessionContext = .day1

    @AppStorage("voicePreference") private var storedVoice: String = "encouraging"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case intro, breathing, complete }
    @State private var phase: Phase = .intro
    @State private var breathState: BreathCircle.State = .holding(scale: 0.6)
    @State private var introLineVisible = false
    @State private var completeVisible = false
    @State private var showQuitConfirmation = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var didFinishCycles = false
    /// Ambient lo-fi under the whole session — reuses the JeniMethod
    /// ritual's player (lesson_zen_lofi, looped, fade in/out). Slightly
    /// lower target volume than the ritual so Jeni's bookend voice lines
    /// stay clear over it.
    @State private var music = RitualMusicPlayer(targetVolume: 0.28)

    /// Breathing config sourced from `techProtocol`. The old fixed-4/6/6
    /// constants are gone — protocol drives everything so changing the
    /// technique changes the session shape end-to-end.
    private var inhaleSec: Int { techProtocol.inhaleSec }
    private var exhaleSec: Int { techProtocol.exhaleSec }
    private var totalReps: Int { techProtocol.repeats * max(1, sessionMinutes) }

    var body: some View {
        // Background + sticker scatter lifted to PostPurchaseFlowView so
        // they stay stable across phase swaps (was the flicker cause).
        ZStack {
            // Close affordance — always available (asymmetric care: Jeni
            // offers, never traps). X → home, never auto-launches workout.
            VStack {
                HStack {
                    Spacer()
                    Button {
                        Haptics.light()
                        if phase == .complete {
                            // Already finished the breath — no need to
                            // confirm; X here is the same as "save for
                            // later" (lands on home).
                            Analytics.track(.breathworkSessionDismissed,
                                            properties: ["phase": phaseName])
                            stopAudio()
                            onDismiss()
                        } else {
                            // Mid-session — confirm before bailing so a
                            // stray tap doesn't drop the user out of the
                            // breath they just committed to.
                            showQuitConfirmation = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.5)))
                    }
                    .accessibilityLabel("Close")
                    .padding(.trailing, Space.lg)
                    .padding(.top, Space.md)
                }
                Spacer()
            }

            switch phase {
            case .intro, .breathing:
                breathingContent
            case .complete:
                completeContent
            }
        }
        .onAppear {
            Analytics.captureScreen("BreathworkSession")
            music.play()
            startIntro()
        }
        .onDisappear {
            music.stop()
            stopAudio()
        }
        .confirmationDialog(
            "leave the breath?",
            isPresented: $showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("leave", role: .destructive) {
                Analytics.track(.breathworkSessionDismissed,
                                properties: ["phase": phaseName])
                stopAudio()
                onDismiss()
            }
            Button("keep breathing", role: .cancel) {}
        } message: {
            Text("the hard part is starting. you already did that.")
        }
    }

    // MARK: - Breathing content (intro + cycling share the bloom)

    private var breathingContent: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            BreathCircle(
                state: breathState,
                onCycleComplete: {
                    guard !didFinishCycles else { return }
                    didFinishCycles = true
                    finishBreathing()
                },
                // Mindful cues instead of clinical inhale/exhale. The long
                // exhale is the parasympathetic lever (the cortisol-lowering
                // mechanism), so "let it go" both reads mindful AND points
                // at the active ingredient.
                inhaleWord: "breathe in",
                exhaleWord: "let it go"
            )

            // During intro, a single settling line under the bloom that
            // names the diaphragmatic (belly) breath — the technique the
            // research ties to cortisol reduction. During cycling,
            // BreathCircle renders its own phase words, so we hide this.
            if phase == .intro {
                Text("breathe into your belly. soften your jaw. drop your shoulders.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(introLineVisible ? 1 : 0)
                    .padding(.horizontal, Space.lg)
            }

            Spacer()
        }
    }

    // MARK: - Complete content

    @ViewBuilder private var completeContent: some View {
        switch context {
        case .day1: day1CompleteContent
        case .daily: receiptContent
        }
    }

    /// Day-1 option-C choice (unchanged — chains into the first workout).
    private var day1CompleteContent: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .opacity(completeVisible ? StickerName.heartGlossy.style.opacity : 0)
                .scaleEffect(completeVisible ? 1 : 0.6)

            VStack(spacing: Space.sm) {
                ItalicAccentText("good. feel that?",
                                 italic: ["feel that"],
                                 baseFont: titleFont,
                                 italicFont: titleItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .center)

                Text("that's your nervous system settling. less stress, fewer cravings that aren't really hunger.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
            }
            .opacity(completeVisible ? 1 : 0)
            .offset(y: completeVisible ? 0 : 8)

            Spacer()

            VStack(spacing: Space.sm) {
                Button {
                    Haptics.medium()
                    Analytics.track(.breathworkSessionCompleted,
                                    properties: ["next": "workout"])
                    stopAudio()
                    onReadyToMove()
                } label: {
                    Text("ready to move")
                }
                .buttonStyle(.ctaPrimary)

                Button {
                    Haptics.light()
                    Analytics.track(.breathworkSessionCompleted,
                                    properties: ["next": "later"])
                    stopAudio()
                    onLater()
                } label: {
                    Text("save it for later")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, Space.xs)
            }
            .opacity(completeVisible ? 1 : 0)
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.xl)
        }
    }

    /// The receipt — daily completion at ~30% of a workout's
    /// celebration weight. Serif headline, the protocol's honest
    /// mechanism line, her real breath week as 7 dots, one quiet CTA.
    /// No fireworks, no share, no numbers about her body.
    private var receiptContent: some View {
        VStack(spacing: 0) {
            Spacer()

            ItalicAccentText("that's your body settling.",
                             italic: ["settling"],
                             baseFont: titleFont,
                             italicFont: titleItalicFont,
                             color: Palette.textPrimary,
                             alignment: .center)
                .opacity(completeVisible ? 1 : 0)
                .offset(y: completeVisible ? 0 : 8)

            Text(techProtocol.receiptLine)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .opacity(completeVisible ? 1 : 0)

            // Her breath week — real BreathworkState data, gain-framed
            // (the same dot idiom as Becoming's week row).
            let flags = BreathworkState.shared.weekDayFlags
            let count = flags.filter { $0 }.count
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    ForEach(Array(flags.enumerated()), id: \.offset) { _, breathed in
                        if breathed {
                            Circle().fill(Palette.cocoaPrimary).frame(width: 7, height: 7)
                        } else {
                            Circle().stroke(Palette.divider, lineWidth: 1.2).frame(width: 7, height: 7)
                        }
                    }
                }
                Text(count == 1 ? "1 breath day this week" : "\(count) breath days this week")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, Space.lg)
            .opacity(completeVisible ? 1 : 0)

            Spacer()

            JFContinueButton(label: "done") {
                Analytics.track(.breathworkSessionCompleted,
                                properties: ["next": "done", "minutes": sessionMinutes])
                stopAudio()
                onLater()
            }
            .opacity(completeVisible ? 1 : 0)
        }
    }

    // MARK: - Phase drivers

    private func startIntro() {
        Analytics.track(.breathworkSessionStarted, properties: [
            "protocol_id": techProtocol.rawValue
        ])
        breathState = .holding(scale: 0.6)
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) { introLineVisible = true }

        // Play intro audio if available; start cycling when it ends.
        // Without audio, hold for a fixed beat then start cycling so the
        // user has a moment to settle before the breath begins.
        if let url = resolveAudioURL(base: "breath_intro"), !reduceMotion {
            playAudio(url: url) {
                startBreathing()
            }
        } else {
            let settleDelay: TimeInterval = reduceMotion ? 0.5 : 4.0
            DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
                startBreathing()
            }
        }
    }

    private func startBreathing() {
        guard phase == .intro else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            introLineVisible = false
            phase = .breathing
        }
        // Kick the BreathCircle into its cycling state. It drives the
        // visual, haptics, countdown, and fires onCycleComplete when all
        // reps finish.
        breathState = .cycling(
            inhale: inhaleSec,
            hold: techProtocol.holdSec,
            exhale: exhaleSec,
            repeats: totalReps
        )
    }

    private func finishBreathing() {
        // Play the close line, reveal the choice.
        if let url = resolveAudioURL(base: "breath_close"), !reduceMotion {
            playAudio(url: url, onComplete: nil)
        }
        breathState = .idle
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = .complete
        }
        withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
            completeVisible = true
        }
        Haptics.success()
        // Stamp the completion so the home BreathworkHomeCard + Becoming
        // BreathworkBentoTile reflect the new count immediately. Idempotent
        // (~60s coalesce) so any race with a fast user double-tap on
        // "ready to move" doesn't double-count.
        BreathworkState.shared.recordCompletion()
    }

    private var phaseName: String {
        switch phase {
        case .intro:     return "intro"
        case .breathing: return "breathing"
        case .complete:  return "complete"
        }
    }

    // MARK: - Audio

    private func resolveAudioURL(base: String) -> URL? {
        let name: String
        switch storedVoice {
        case "balanced":   name = "\(base)_matson"
        case "keepItReal": name = "\(base)_kira"
        default:           name = "\(base)_jeni"
        }
        return Bundle.main.url(forResource: name, withExtension: "m4a")
    }

    /// Play a clip; fire `onComplete` after its natural duration. Used to
    /// chain the intro line into the breath cycles.
    private func playAudio(url: URL, onComplete: (() -> Void)?) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayer = player
            player.play()
            if let onComplete {
                let duration = player.duration
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.3) {
                    onComplete()
                }
            }
        } catch {
            #if DEBUG
            print("[Breathwork] audio FAILED: \(error)")
            #endif
            // If playback fails, still advance so the user isn't stuck.
            if let onComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { onComplete() }
            }
        }
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Typography

    private var titleFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 28, relativeTo: .title2)
    }
    private var titleItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 28, relativeTo: .title2)
    }
}

#if DEBUG
#Preview {
    BreathworkSessionView(
        onReadyToMove: {},
        onLater: {},
        onDismiss: {}
    )
}
#endif
