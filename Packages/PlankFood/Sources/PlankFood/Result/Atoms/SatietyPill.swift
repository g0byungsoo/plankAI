#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - SatietyPill
//
// 2026-06-15 Sprint A — the satiety check-in.
//
// Above the "log it" CTA on every result card. Asks the vocabulary
// question the post-Ozempic cohort already asks themselves silently:
// am I *hungry* right now, or is this *meh* (food noise / habit /
// boredom)? Single-tap, fully optional, fully deselectable.
//
// The choice fires `food_satiety_marked` analytics with the raw state
// so the Becoming "your food noise" weekly module can pull patterns
// once enough data lands.
//
// Voice locked: italic-Fraunces ONLY on the punch word inside the
// reflective line ("*body* knows ♥" / "totally *fair* ♥"). The pill
// labels themselves render in Fraunces italic — the words ARE the
// punch.
//
// Design discipline:
//   - Custom 10pt-radius rounded-rect shape (architectural, not
//     fully-capsule) so the pills read as deliberate luxury rather
//     than playful bubble.
//   - Selected state: textPrimary fill, cream label, soft bloom
//     spring (1.0 → 1.06 → 1.0). Unselected sibling dims to 0.45
//     opacity so the choice reads as commitment, not equivocation.
//   - Rigid haptic on tap (firmer than .light, lighter than .medium)
//     — the post-Ozempic cohort gets physical confirmation without
//     the gym-app pomp.
//   - Reflective affirmation slides in from x:+12 after select,
//     holds 1.8s, then fades out. Differentiated copy for each
//     choice so the vocabulary loop registers.
//   - NO scatter sticker (per [[feedback-scatter-milestone-rule]] —
//     stickers ship on welcome / plan-reveal / graduation only).

public enum SatietyChoice: String, Sendable {
    case hungry
    case meh
}

public struct SatietyPill: View {

    @Binding var choice: SatietyChoice?
    let onSelect: (SatietyChoice) -> Void

    @State private var affirmation: SatietyChoice? = nil
    @State private var affirmationVisible: Bool = false
    @State private var bloomingChoice: SatietyChoice? = nil

    public init(
        choice: Binding<SatietyChoice?>,
        onSelect: @escaping (SatietyChoice) -> Void
    ) {
        self._choice = choice
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 6) {
            pill(.hungry)
            pill(.meh)

            // Reflective affirmation — slides in from the right after
            // select, then quietly fades. Italic-Fraunces on the punch
            // word per locked voice; lowercase casual; ♥ terminal.
            ZStack(alignment: .leading) {
                if let v = affirmation {
                    affirmationLine(for: v)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing)
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                        .opacity(affirmationVisible ? 1 : 0)
                }
            }
            .frame(minHeight: 14, alignment: .leading)
            .animation(Self.affirmationSpring, value: affirmationVisible)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Pill

    @ViewBuilder
    private func pill(_ value: SatietyChoice) -> some View {
        let isSelected = choice == value
        let isOtherSelected = choice != nil && !isSelected

        Button {
            handleTap(value)
        } label: {
            Text(value.rawValue)
                .font(.custom(
                    isSelected ? "Fraunces72pt-SemiBoldItalic" : "Fraunces72pt-Italic",
                    size: 13
                ))
                .foregroundStyle(isSelected ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                .tracking(0.2)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    SatietyPillShape()
                        .fill(isSelected ? FoodTheme.textPrimary : Color.clear)
                )
                .overlay(
                    SatietyPillShape()
                        .strokeBorder(
                            isSelected ? FoodTheme.textPrimary
                                       : FoodTheme.textPrimary.opacity(0.22),
                            lineWidth: 0.75
                        )
                )
                .scaleEffect(bloomingChoice == value ? 1.06 : 1.0)
                .opacity(isOtherSelected ? 0.45 : 1.0)
        }
        .buttonStyle(SatietyPillPressStyle())
        .animation(Self.pillSpring, value: isSelected)
        .animation(Self.dimEase, value: isOtherSelected)
        .animation(Self.bloomSpring, value: bloomingChoice)
        .accessibilityLabel("mark this plate as \(value.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected
            ? "double tap to deselect"
            : "double tap to choose")
    }

    // MARK: - Affirmation

    @ViewBuilder
    private func affirmationLine(for value: SatietyChoice) -> some View {
        let parts = affirmationParts(for: value)
        ItalicAccentText(
            parts.base,
            italic: parts.italic,
            baseFont: .custom("Fraunces72pt-Regular", size: 12),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 12),
            color: FoodTheme.textSecondary,
            alignment: .leading
        )
        .padding(.leading, 4)
        .accessibilityHidden(true)  // already announced via pill selection
    }

    private func affirmationParts(for value: SatietyChoice) -> (base: String, italic: [String]) {
        switch value {
        case .hungry: return ("body knows ♥", ["body"])
        case .meh:    return ("totally fair ♥", ["fair"])
        }
    }

    // MARK: - Interaction

    private func handleTap(_ value: SatietyChoice) {
        let alreadyChosen = (choice == value)

        // Haptic — .rigid is firmer than .light, lighter than .medium.
        // Calibrated for confirmation without the gym-app loudness.
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)

        if alreadyChosen {
            // Deselect. Animate the dim-undo + clear the affirmation.
            withAnimation(Self.pillSpring) {
                choice = nil
            }
            dismissAffirmation()
            return
        }

        // Select.
        withAnimation(Self.pillSpring) {
            choice = value
        }

        // Spring bloom: 1.0 → 1.06 → 1.0 over the bloom window.
        bloomingChoice = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(Self.bloomSpring) {
                if bloomingChoice == value { bloomingChoice = nil }
            }
        }

        presentAffirmation(value)

        // Fire analytics on the selecting transition only — re-taps to
        // deselect don't re-fire (matches the existing one-event-per-
        // material-choice convention in FoodAnalytics).
        onSelect(value)
    }

    private func presentAffirmation(_ value: SatietyChoice) {
        // Replace any in-flight affirmation immediately. The combined
        // insertion (move + opacity) reads cleanly when the prior
        // affirmation has already faded; if it hasn't, we cross-fade.
        withAnimation(Self.affirmationSpring) {
            affirmation = value
            affirmationVisible = true
        }
        // Dismiss after 1.8s. Re-tapping mid-flight extends the window
        // (new presentAffirmation cancels by overwriting).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            // Guard: only dismiss if THIS affirmation is still showing.
            // A subsequent tap will have replaced `affirmation`.
            if affirmation == value {
                dismissAffirmation()
            }
        }
    }

    private func dismissAffirmation() {
        withAnimation(.easeOut(duration: 0.32)) {
            affirmationVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            if !affirmationVisible { affirmation = nil }
        }
    }

    // MARK: - Motion tokens (local — mirrors PlankApp Motion)

    private static let pillSpring: Animation = .spring(response: 0.42, dampingFraction: 0.78)
    private static let bloomSpring: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    private static let affirmationSpring: Animation = .spring(response: 0.48, dampingFraction: 0.82)
    private static let dimEase: Animation = .easeOut(duration: 0.25)
}

// MARK: - SatietyPillPressStyle
//
// Subtle press-down scale (1.0 → 0.96) on touch-down, with an easeOut
// release. Sits cleanly under the selection-bloom + dim animations on
// the pill — the press is short and tactile (0.18s response), the
// bloom is gentler (0.42s) so the two read as press → release →
// bloom rather than competing motion.

private struct SatietyPillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.18, dampingFraction: 0.75)
                    : .spring(response: 0.32, dampingFraction: 0.82),
                value: configuration.isPressed
            )
    }
}

// MARK: - SatietyPillShape
//
// 10pt fixed radius rounded-rect. At our 28pt tall pill that's a 36%
// radius — architectural rounding rather than fully-capsule. Reads
// as a deliberate luxury shape, not a friendly chat bubble.

private struct SatietyPillShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> SatietyPillShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: insetAmount, dy: insetAmount)
        return Path(roundedRect: inset, cornerRadius: 10, style: .continuous)
    }
}

// MARK: - Preview

#Preview("SatietyPill states") {
    StatefulPreviewWrapper(SatietyChoice?.none) { binding in
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("idle").font(.system(size: 10)).foregroundStyle(.secondary)
                SatietyPill(choice: binding, onSelect: { _ in })
            }

            StatefulPreviewWrapper(SatietyChoice?.some(.hungry)) { b in
                VStack(alignment: .leading, spacing: 8) {
                    Text("hungry selected").font(.system(size: 10)).foregroundStyle(.secondary)
                    SatietyPill(choice: b, onSelect: { _ in })
                }
            }

            StatefulPreviewWrapper(SatietyChoice?.some(.meh)) { b in
                VStack(alignment: .leading, spacing: 8) {
                    Text("meh selected").font(.system(size: 10)).foregroundStyle(.secondary)
                    SatietyPill(choice: b, onSelect: { _ in })
                }
            }
        }
        .padding(24)
        .background(FoodTheme.bgPrimary)
    }
}

/// Tiny @State wrapper so the preview can drive the @Binding without
/// pulling in extra ceremony.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}

#endif  // canImport(UIKit)
