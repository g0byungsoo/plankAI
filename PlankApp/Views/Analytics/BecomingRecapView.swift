import SwiftUI
import UIKit

// MARK: - Becoming Sunday recap (P3b)
//
// The weekly takeover — the tab's heartbeat per the 5-expert
// consensus (MacroFactor's weekly ritual is the strongest retention
// mechanic in the category; weekly cadence is itself the anti-shame
// move). Three pages on the lesson player's JFPageTransition
// vocabulary:
//   1. the headline — line-cascade hero ("week three." / "she kept
//      showing up."), soft haptic per line
//   2. the receipts — numbered serif facts from her real week
//   3. the day card — pre-rendered, "keep it" → share sheet
// Quiet weeks still get a true sentence; an EMPTY week never
// presents at all (the gate lives in AnalyticsView — never recap
// an empty week at her).

struct BecomingRecapView: View {
    let weekNumber: Int?          // program week; nil = non-program user
    let facts: [String]           // share-safe receipts, ≥1 guaranteed by gate
    let quietWeek: Bool           // 1 engaged day only — soften page 2
    let dayCard: UIImage?
    let onDismiss: () -> Void

    private enum Stage { case headline, receipts, card }
    @State private var stage: Stage = .headline
    @State private var showShare = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var weekWord: String? {
        guard let weekNumber else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: weekNumber)) ?? "\(weekNumber)"
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        Haptics.light()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.5)))
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
                Spacer()
            }

            switch stage {
            case .headline: headlinePage.transition(JFPageTransition.standard)
            case .receipts: receiptsPage.transition(JFPageTransition.standard)
            case .card:     cardPage.transition(JFPageTransition.standard)
            }
        }
        .sheet(isPresented: $showShare) {
            if let dayCard {
                BecomingShareSheet(image: dayCard)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear { Analytics.captureScreen("BecomingRecap") }
    }

    // MARK: Page 1 — the headline

    private var headlinePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            LineCascadeText(
                lines: headlineLines,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                lineSpacing: Typo.heroHeadlineLineGap
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        // That-girl wink under the cascade — founder-supplied
        // real-photo cutout, floats in the dead space above the CTA.
        .overlay(alignment: .bottomTrailing) {
            Image("accent-sunglasses")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(-8))
                .padding(.trailing, Space.lg)
                .padding(.bottom, 16)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue") {
                withAnimation(Motion.pageEntrance) { stage = .receipts }
            }
        }
    }

    private var headlineLines: [LineCascadeText.Line] {
        if let weekWord {
            return [
                .composite(base: "week \(weekWord).", italic: [weekWord]),
                .composite(base: "she kept showing up.", italic: ["showing up"]),
            ]
        }
        return [
            .plain("this week."),
            .composite(base: "she kept showing up.", italic: ["showing up"]),
        ]
    }

    // MARK: Page 2 — the receipts

    private var receiptsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("the receipts")
                .font(.custom("DMSans-Medium", size: 11))
                .kerning(1.98)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, Space.lg)

            VStack(alignment: .leading, spacing: Space.lg) {
                ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                        Text("\(index + 1)")
                            .font(.custom("JeniHeroSerif-Italic", size: 26))
                            .foregroundStyle(Palette.accent)
                        Text(fact)
                            .font(.custom("DMSans-Regular", size: 17))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }

            if quietWeek {
                Text("quiet weeks count too. tomorrow resets \u{2665}\u{FE0E}")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue") {
                withAnimation(Motion.pageEntrance) { stage = .card }
            }
        }
    }

    // MARK: Page 3 — the day card

    private var cardPage: some View {
        VStack(spacing: 0) {
            Spacer()
            if let dayCard {
                Image(uiImage: dayCard)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Palette.accent.opacity(0.18), radius: 0, x: 4, y: 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.lg)
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "keep it",
                action: {
                    // Guard: presenting with a nil card draws an empty
                    // (black) sheet. No card → nothing to keep.
                    if dayCard != nil { showShare = true } else { onDismiss() }
                },
                secondaryLabel: "not now",
                secondaryAction: {
                    Haptics.light()
                    onDismiss()
                }
            )
        }
    }
}
