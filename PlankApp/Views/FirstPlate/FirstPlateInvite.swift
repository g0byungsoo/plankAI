import SwiftUI

// MARK: - FirstPlateInvite (v25 E5 — THE FIRST PLATE)
//
// The beat that used to be a price.
//
// Design intent — this screen has one job and must not look like a
// gate. It is bottom-weighted (the ask sits in the thumb, the fact sits
// in the eye), it leads with HER OWN NUMBER rather than a promise, and
// it carries no card, no icon, no illustration. The only ornament is a
// hairline, and the hairline is doing work: it separates what jeni
// already knows from what she is asking for.
//
// Why the floor is the hero: it is the one number onboarding earned,
// it is the single most evidence-backed lever for this cohort (protein
// 1.2-2.0 g/kg — r3/r4), and rendering it here proves jeni was
// listening before she asks for anything. With no weight on file there
// is no floor and the screen says so by saying less (provenance law).

struct FirstPlateInvite: View {

    let floorG: Int?
    let onStart: () -> Void
    let onSkip: () -> Void

    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // All the air sits ABOVE. The page is one composed block
            // that meets the thumb, not a stack floating mid-screen —
            // the first pass centred it and read as two disconnected
            // halves (frame-caught).
            Spacer(minLength: Space.lg)

            Text("FIRST, ONE PLATE")
                .font(Typo.captionTracked)
                .tracking(1.4)
                .foregroundStyle(Palette.textSecondary)
                .jeniArrive(arrived, index: 0)

            headline
                .padding(.top, Space.md)
                .jeniArrive(arrived, index: 1)

            Text(subhead)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md)
                .jeniArrive(arrived, index: 2)

            rule
                .padding(.top, Space.lg)

            Text("show me one plate and i'll tell you what's in it.")
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.lg)
                .jeniArrive(arrived, index: 4)
                // The ink pill is heavy and casts a shadow; it needs
                // more air under the line than between the lines.
                .padding(.bottom, Space.xl - Space.sm)
        }
        .padding(.horizontal, Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(Palette.bgPrimary.ignoresSafeArea())
        // The CTA brings its OWN gutter (JFContinueButton pads by
        // Space.lg). Nesting it inside the copy column double-applied
        // the inset and broke the left edge against the text.
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "read my first plate",
                action: onStart,
                secondaryLabel: "not right now",
                secondaryAction: onSkip
            )
            .jeniArrive(arrived, index: 5)
        }
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
    }

    // MARK: - The headline
    //
    // Numeral-first when there is a number to lead with; a plain
    // editorial line when the record is silent. Never a fabricated one.

    @ViewBuilder
    private var headline: some View {
        if let floorG {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(floorG) g")
                    .font(Typo.numeralHero)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("of protein a day.")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Typo.programHeroLineGap + 16)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(floorG) grams of protein a day")
        } else {
            // No weight on file, so no floor and no invented one. The
            // face says less rather than guessing (provenance law).
            Text("one real plate.")
                .font(Typo.displayHero)
                .foregroundStyle(Palette.textPrimary)
                .lineSpacing(Typo.displayHeroLineGap)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subhead: String {
        floorG == nil
            ? "before anything else, let's log one real meal."
            : "that's your floor. it came from the weight you gave me."
    }

    // MARK: - The rule
    //
    // It draws rather than appears: the one piece of motion on the
    // screen, and it means something — the line between what jeni knows
    // and what she is asking for. Reduce Motion gets it whole.

    private var rule: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(
                    width: (reduceMotion || arrived) ? geo.size.width : 0,
                    height: 1
                )
                .animation(
                    reduceMotion ? nil : JeniMotion.draw.delay(JeniMotion.stagger * 3),
                    value: arrived
                )
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("with a floor") {
    FirstPlateInvite(floorG: 90, onStart: {}, onSkip: {})
}
#Preview("no weight on file") {
    FirstPlateInvite(floorG: nil, onStart: {}, onSkip: {})
}
#endif
