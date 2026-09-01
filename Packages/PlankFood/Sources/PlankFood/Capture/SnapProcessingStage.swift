#if canImport(UIKit)
import SwiftUI

// MARK: - SnapProcessingStage (v23 pass 4 — founder reference)
//
// THE PROCESSING — the founder's reference interface, in Jeni's
// hand: on capture the photograph COMPRESSES into a glowing card
// over its own blurred self, the aim's brackets ride the card, a
// bright line sweeps the frame, and a staged checklist speaks the
// pipeline's real phases beneath.
//
// Honesty (E2 class): the steps describe the ONE real request's
// phases in plain words — the same class as the retired caption
// rotator. The intermediate steps advance on conservative timers;
// the FINAL step completes only when the understanding actually
// lands (`complete`), so the list can never claim a finished
// reading before there is one. The active row's indicator is the
// dose-dot pulse — never a spinner.
//
// Reduce Motion: no sweep, no pulse, no compress — the list alone
// carries the wait, whole-state fades only.

public struct SnapProcessingStage: View {

    public let photo: UIImage
    /// The understanding landed — every step checks.
    public let complete: Bool
    /// The honest slow line joins under the list.
    public let longScan: Bool
    public let mode: DialMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How many steps have finished (0…4). Timers advance 1…3;
    /// `complete` finishes 4.
    @State private var stepsDone = 0
    /// Sweep line position 0…1 inside the bracket area.
    @State private var sweepDown = false
    /// The compress-in beat.
    @State private var settled = false

    public init(photo: UIImage, complete: Bool, longScan: Bool, mode: DialMode) {
        self.photo = photo
        self.complete = complete
        self.longScan = longScan
        self.mode = mode
    }

    private var steps: [String] {
        switch mode {
        case .scan:
            return ["photo kept", "reading what's on it",
                    "counting the nutrition", "putting the page together"]
        case .label:
            return ["photo kept", "reading the label",
                    "copying the printed values", "putting the page together"]
        case .barcode:
            return ["code caught", "finding the product",
                    "reading its label", "putting the page together"]
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * 0.86
            let cardH = min(geo.size.height * 0.50, cardW * 1.22)

            ZStack {
                // The photograph's own blur is the room.
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 34)
                    .overlay(Color.black.opacity(0.42))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // THE CARD — the photograph, compressed and lit.
                    ZStack {
                        // The sweep runs INSIDE the card's own clip so
                        // the light reads edge-to-edge — no gaps, the
                        // frame owns it (founder catch: an inset line
                        // looked incomplete).
                        ZStack {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardW, height: cardH)
                                .clipped()

                            if !reduceMotion {
                                sweepLine(width: cardW)
                                    .offset(y: (sweepDown ? 1 : -1) * (cardH / 2 - 5))
                            }
                        }
                        .frame(width: cardW, height: cardH)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                        // The aim rides the card.
                        CornerBracketsShape(
                            frameWidth: cardW - 52,
                            frameHeight: cardH - 52,
                            cornerRadius: FoodTheme.Radius.card,
                            armLength: min(cardW, cardH) * 0.16
                        )
                        .stroke(
                            Color.white.opacity(0.92),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                    }
                    .frame(width: cardW, height: cardH)
                    // The warm halo — hugging the card, never a cloud
                    // (frame-caught: radius 46 bloomed behind the list).
                    .shadow(color: FoodTheme.bgPrimary.opacity(0.30), radius: 26, x: 0, y: 0)
                    .shadow(color: Color.white.opacity(0.10), radius: 10, x: 0, y: 0)
                    .scaleEffect(settled ? 1.0 : 1.16)
                    .padding(.top, geo.size.height * 0.10)

                    // THE STEPS — the pipeline, spoken plainly.
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            stepRow(step, state: stepState(i))
                        }
                        if longScan {
                            Text("taking a little longer than usual")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.leading, 34)
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 34)
                    .padding(.horizontal, 44)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            if reduceMotion {
                settled = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    settled = true
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    sweepDown = true
                }
            }
        }
        // The sweep's pulse — a soft tap as the light turns at each
        // edge (rate ~0.7/s, far under the haptic ceiling). Stops
        // with the reading.
        .task {
            guard !reduceMotion else { return }
            let sweeper = UIImpactFeedbackGenerator(style: .soft)
            sweeper.prepare()
            while !Task.isCancelled && !complete {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled && !complete else { return }
                sweeper.impactOccurred(intensity: 0.55)
                sweeper.prepare()
            }
        }
        // The timers speak the phases; the truth finishes the list.
        .task {
            let beats: [(UInt64, Int)] = [
                (350_000_000, 1), (2_650_000_000, 2), (3_500_000_000, 3),
            ]
            for (delay, count) in beats {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    stepsDone = max(stepsDone, count)
                }
            }
        }
        .onChange(of: complete) { _, done in
            if done {
                withAnimation(.easeOut(duration: 0.3)) { stepsDone = steps.count }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("reading your plate")
    }

    // MARK: - Pieces

    private enum StepState { case done, active, pending }

    private func stepState(_ i: Int) -> StepState {
        if i < stepsDone { return .done }
        if i == stepsDone { return .active }
        return .pending
    }

    @ViewBuilder
    private func stepRow(_ title: String, state: StepState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .transition(.opacity)
                case .active:
                    PulseDot(reduceMotion: reduceMotion)
                case .pending:
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
                        .frame(width: 15, height: 15)
                }
            }
            .frame(width: 22, height: 22)

            Text(title)
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundStyle(.white.opacity(
                    state == .pending ? 0.4 : (state == .done ? 0.65 : 1.0)
                ))
        }
        .animation(.easeOut(duration: 0.3), value: state == .done)
    }

    /// One bright reading line with soft tails — engineered light,
    /// vivid enough to own the frame (founder: brighter, slicker).
    @ViewBuilder
    private func sweepLine(width: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white.opacity(0), .white.opacity(0.38), .white.opacity(0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: 84)
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: 2.5)
                .shadow(color: .white.opacity(0.95), radius: 10, x: 0, y: 0)
                .shadow(color: .white.opacity(0.6), radius: 22, x: 0, y: 0)
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// The dose-dot pulse — the active step's life (never a spinner).
private struct PulseDot: View {
    let reduceMotion: Bool
    @State private var bright = false

    var body: some View {
        Circle()
            .fill(FoodTheme.roseBlush)
            .frame(width: 11, height: 11)
            .scaleEffect(bright ? 1.0 : 0.72)
            .opacity(bright ? 1.0 : 0.6)
            .onAppear {
                guard !reduceMotion else { bright = true; return }
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

#endif  // canImport(UIKit)
