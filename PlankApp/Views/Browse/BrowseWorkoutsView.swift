import SwiftUI

/// Browse alternative workouts: longer sessions, single-area focus, or a
/// dedicated stretch flow. Each card calls the engine to generate a session
/// on tap, then hands it back to the host (HomeView) so save/streak logic
/// stays in one place.
///
/// Visual language matches the Home cards (jenifitWorkoutCard /
/// benchmarkCard): full-width vertical cards on cream background, regular
/// Fraunces titles, eyebrow meta lines, accent-rose CTAs. Italic is held
/// back for the page hero only — using it on every card flattens the
/// brand signal.
struct BrowseWorkoutsView: View {
    let onSelect: (WorkoutPreset) -> Void
    let onCancel: () -> Void

    /// User signals needed to size each generated session. Passed in by
    /// HomeView so we don't re-read AppStorage from a child view.
    let bodyFocus: [BodyFocus]
    let defaultLengthMinutes: Int
    let startingTier: Int
    let recentSessionExerciseIds: [[String]]
    let recentRatings: [Int]

    /// Per-card stagger on appearance — gives the screen a subtle
    /// editorial cadence rather than slapping content in all at once.
    @State private var didAppear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Spacer().frame(height: 56) // room for floating close

                    header
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 12)

                    section(title: "by length",
                            staggerIndex: 1) {
                        VStack(spacing: Space.sm) {
                            lengthCard(15, label: "quick hit",
                                       blurb: "time-poor day, full payoff.")
                            lengthCard(30, label: "full sweat",
                                       blurb: "real session — warmup, work, wind-down.")
                            lengthCard(45, label: "deep work",
                                       blurb: "long-form, structured, balanced.")
                        }
                    }

                    section(title: "by focus area",
                            staggerIndex: 2) {
                        VStack(spacing: Space.sm) {
                            focusCard(.flatBelly,
                                      title: "abs",
                                      blurb: "core + obliques. posture-aware.")
                            focusCard(.roundButt,
                                      title: "glutes",
                                      blurb: "shape and lift through the posterior.")
                            focusCard(.slimLegs,
                                      title: "lower body",
                                      blurb: "quads, hamstrings, calves.")
                            focusCard(.tonedArms,
                                      title: "upper body",
                                      blurb: "shoulders, arms, posture.")
                            focusCard(.fullBody,
                                      title: "full body",
                                      blurb: "everything, balanced.")
                        }
                    }

                    section(title: "recovery",
                            staggerIndex: 3) {
                        recoveryCard
                    }

                    Spacer().frame(height: Space.xl)
                }
                .padding(.horizontal, Space.screenPadding)
            }

            closeButton
                .padding(.horizontal, Space.screenPadding)
                .padding(.top, Space.sm)
        }
        .onAppear {
            if reduceMotion {
                didAppear = true   // snap, skip the swell
            } else {
                withAnimation(Motion.entranceSoft) { didAppear = true }
            }
        }
    }

    // MARK: - Hero

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("more workouts")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text("pick your next.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
        }
        // Sticker accent — iridescent bow. Reads as "pick your favorite"
        // for the library (replaces disco ball, which leaned more
        // nightclub than browse-y).
        .overlay(alignment: .topTrailing) {
            Image(StickerName.bowIridescent.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-10))
                .offset(x: 4, y: -8)
                .opacity(StickerName.bowIridescent.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
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
        }
    }

    // MARK: - Section helper

    private func section<Content: View>(
        title: String,
        staggerIndex: Int,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)
            content()
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
        .animation(Motion.entrance.delay(0.08 + Double(staggerIndex) * Motion.stagger),
                   value: didAppear)
    }

    // MARK: - Length card

    private func lengthCard(_ minutes: Int, label: String, blurb: String) -> some View {
        cardButton {
            onSelect(generateForLength(minutes))
        } content: {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("\(label)\u{2009}·\u{2009}\(minutes) min")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)

                Text("\(minutes) minutes.")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)

                Text(blurb)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Focus card

    private func focusCard(_ focus: BodyFocus, title: String, blurb: String) -> some View {
        cardButton {
            onSelect(generateForFocus(focus))
        } content: {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("focus\u{2009}·\u{2009}\(defaultLengthMinutes) min")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)

                Text("\(title).")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)

                Text(blurb)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Recovery card (accent-tinted treatment)

    private var recoveryCard: some View {
        Button {
            Haptics.light()
            onSelect(WorkoutGenerator.generateStretchSession(lengthMinutes: 10))
        } label: {
            HStack(alignment: .top, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("recovery\u{2009}·\u{2009}10 min")
                        .font(Typo.eyebrow).tracking(2)
                        .foregroundStyle(Palette.stateGood)

                    Text("stretch & recover.")
                        .font(Typo.titleItalic)
                        .foregroundStyle(Palette.textPrimary)

                    Text("static holds. low impact. wind-down for tight days.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Palette.stateGood)
                    .padding(.top, 2)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Sage-tinted scrapbook chrome — 24pt corners, 1.5pt sage
            // border, sage hard offset shadow. Distinct from the rose
            // chrome on length/focus cards so the recovery beat reads
            // visually different from the work.
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.stateGood.opacity(0.25))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.stateGood.opacity(0.14))
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.stateGood, lineWidth: 1.5)
                }
            )
        }
        .buttonStyle(CardPressStyle())
        // Cherub sticker accent — dreamy, recovery-ish vibe. Hangs off
        // the top-right corner.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.cherub.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(14))
                .offset(x: 12, y: -20)
                .opacity(StickerName.cherub.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Card chrome

    @ViewBuilder
    private func cardButton<Content: View>(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(alignment: .top, spacing: Space.md) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .padding(.top, 4)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Scrapbook chrome — 24pt corners, 1.5pt accent border, hard
            // offset shadow. Drops `plankShadow()` per the trend research.
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.accent.opacity(0.15))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.bgElevated)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.accent, lineWidth: 1.5)
                }
            )
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: - Generation

    private func generateForLength(_ minutes: Int) -> WorkoutPreset {
        WorkoutGenerator.generate(from: WorkoutGenerator.Input(
            bodyFocus: bodyFocus.isEmpty ? [.fullBody] : bodyFocus,
            lengthMinutes: minutes,
            recentSessionExerciseIds: recentSessionExerciseIds,
            recentRatings: recentRatings,
            startingTier: startingTier
        ))
    }

    private func generateForFocus(_ focus: BodyFocus) -> WorkoutPreset {
        WorkoutGenerator.generate(from: WorkoutGenerator.Input(
            bodyFocus: [focus],
            lengthMinutes: defaultLengthMinutes,
            recentSessionExerciseIds: recentSessionExerciseIds,
            recentRatings: recentRatings,
            startingTier: startingTier
        ))
    }
}

// MARK: - Press feedback

/// Subtle scale-down on press, matching JeniFit's other tappable cards.
private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
