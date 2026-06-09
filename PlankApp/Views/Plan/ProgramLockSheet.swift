import SwiftUI

// MARK: - ProgramLockSheet
//
// v1.1 program pivot — PlanView redesign per UX spec §5.
// Bottom sheet that presents when the user taps a locked future
// day on the ProgramDayStrip. Wistful, never punitive.
//
// Founder rules for the lock surface (locked 2026-06-09):
//   - No paywall CTA. The user already paid (or trialed). The lock
//     is structural to the program, not a paywall.
//   - No counter of locked days ("63 more!"). Cluster does the math.
//   - Future-tense for the program ("waits for you"), not past-tense
//     for the user ("you missed it").
//   - Lowercase casual, italic-Fraunces on the pull quote, no em-dashes.
//
// Copy adapts based on tapped day vs current day distance:
//   - tomorrow (day = current + 1): warm/close — "unlocks tomorrow"
//   - 2-7 days out: "X days away. you're closer than you think."
//   - 7+ days out: "X days away. your future self is waiting."

struct ProgramLockSheet: View {

    let lockedDay: Int
    let currentDay: Int
    let totalDays: Int
    let onDismiss: () -> Void

    var body: some View {
        // Layout fills the entire .medium-detent sheet area so the
        // system container background (which can render as dim/grey
        // on iOS 17+) never bleeds through at the top or bottom edges.
        // Spacer between content and CTA pushes the button to the
        // bottom of the available sheet height.
        VStack(alignment: .leading, spacing: 0) {
            handle
            content
            Spacer(minLength: 24)
            cta
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.programCard)
    }

    private var handle: some View {
        Capsule()
            .fill(Palette.hairlineCocoa)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 28)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Lock icon row
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Palette.cocoaSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Day eyebrow — anchors the user in the program scale.
            Text("day \(lockedDay) of \(totalDays)")
                .font(Typo.editorialEyebrow)
                .foregroundStyle(Palette.cocoaTertiary)
                .textCase(.uppercase)
                .kerning(0.66)
                .frame(maxWidth: .infinity, alignment: .center)

            // Pull-quote. Italic Fraunces 22pt. Anti-shame, anti-em-dash.
            Text("a small lock, a longer story.")
                .font(Typo.pullQuote)
                .foregroundStyle(Palette.cocoaPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            // Adaptive body
            Text(bodyCopy)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, Space.lg + 4)
    }

    private var bodyCopy: String {
        let distance = lockedDay - currentDay
        if distance == 1 {
            return "your program is built day by day. day \(lockedDay) unlocks tomorrow. showing up beats jumping ahead."
        }
        if distance <= 7 {
            return "day \(lockedDay) is \(distance) days away. your program is built day by day. you're closer than you think."
        }
        return "day \(lockedDay) is \(distance) days away. your program is built day by day. your future self is waiting."
    }

    private var cta: some View {
        Button {
            Haptics.light()
            onDismiss()
        } label: {
            Text("got it.")
                .font(Typo.heading)
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Palette.cocoaPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.lg)
        .padding(.top, 28)
        .padding(.bottom, 24)
    }
}
