import SwiftUI

// MARK: - BodyVisionIntroView
//
// app v9 P2 — the one-time introduction (the migration-moment
// pattern): existing users and day-2+ new users meet Body Vision
// once, as a received moment — never a nag. Either choice stamps it
// done; the weekly invitation on the checklist remains the only
// recurring surface. Copy = D10 draft.

struct BodyVisionIntroView: View {
    /// "see it" → the scan module; "later" → just closes.
    let onSee: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("BODY VISION")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.bottom, Space.sm)
                Text("I can keep your record now.")
                    .font(Typo.title)
                    .foregroundStyle(Palette.cocoaPrimary)
                    .fixedSize(horizontal: false, vertical: true)   // XXXL wraps
                    .padding(.bottom, Space.lg)
                VStack(alignment: .leading, spacing: Space.md) {
                    introRow("a few seconds in front of the camera, once a week.")
                    introRow("an ink line of your waist, kept on your phone — the shape of change.")
                    introRow("no number is ever read from a photo. it's evidence, not a measurement.")
                }
                Spacer()
                VStack(spacing: Space.sm) {
                    Button {
                        Haptics.light()
                        onSee()
                    } label: {
                        Text("see it")
                            .font(Typo.heading)
                            .foregroundStyle(Palette.bgPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Palette.cocoaPrimary))
                    }
                    .buttonStyle(.plain)
                    Button("later") {
                        Haptics.soft()
                        onLater()
                    }
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
    }

    private func introRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 4, height: 4)
                .offset(y: -3)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
