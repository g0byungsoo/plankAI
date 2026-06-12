import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v4.6 round 4 — editorial single-hero per the design consult
// (founder reference: Urban Outfitters splash, subject-over-type).
// Cream ground from frame 0 (invisible handoff from the static
// launch screen), the blazer-girl cutout anchored to the bottom edge
// with her legs bleeding off-screen, and the affirmation set in the
// hero serif UNDER her layer so her shoulder overlaps the line tail.
// One motion moment: the cutout settles (y +10pt, scale 1.015 → rest).
// No breathe, no cascade, no scatter. 1 image + 1 text + 1 bow.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Palette.programEraBg
                    .ignoresSafeArea()

                // The affirmation — fixed, not rotating: a sub-second
                // screen can't land variety; one line seen on every
                // launch becomes the brand's doorbell. Sits UNDER the
                // girl so her blazer overlaps the tail (the editorial
                // subject-over-type move).
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.34)
                    (Text("your\n").font(Typo.heroHeadline)
                     + Text("that girl").font(Typo.heroHeadlineItalic)
                     + Text(" era.").font(Typo.heroHeadline))
                        .foregroundStyle(Palette.textPrimary)
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                // The girl — bottom-anchored, legs bleed off-screen,
                // shoulder rising INTO the line tail (subject-over-type).
                VStack {
                    Spacer(minLength: 0)
                    Image("onb-identity-powerful")
                        .resizable()
                        .scaledToFit()
                        .frame(height: geo.size.height * 0.68)
                        .offset(
                            x: geo.size.width * 0.10,
                            y: geo.size.height * 0.04 + (settled ? 0 : 10)
                        )
                        .scaleEffect(settled ? 1.0 : 1.015, anchor: .bottom)
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea(edges: .bottom)

                // Wordmark — handoff anchor, static from frame 0.
                VStack {
                    (Text("jeni").font(.custom("Fraunces72pt-SemiBold", size: 17))
                     + Text("\u{2009}•\u{2009}").font(.custom("Fraunces72pt-Light", size: 14))
                     + Text("fit").font(.custom("Fraunces72pt-SemiBold", size: 17)))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 6)
                    Spacer()
                }

                if case .failed = state {
                    VStack {
                        Spacer()
                        failureContent
                            .padding(.bottom, 60)
                    }
                }
            }
        }
        .onAppear {
            if reduceMotion {
                settled = true
            } else {
                withAnimation(Motion.entranceSoft) { settled = true }
            }
        }
    }

    @ViewBuilder
    private var failureContent: some View {
        VStack(spacing: Space.md) {
            (
                Text("couldn't ").font(.custom("Fraunces72pt-SemiBold", size: 18)) +
                Text("connect.").font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
            )
            .foregroundStyle(Palette.textPrimary)

            Text(failureMessage)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)

            Button(action: onRetry) {
                Text("try again")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.textInverse)
                    .frame(width: 160, height: 44)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
            }
            .padding(.top, Space.xs)
        }
        .padding(.horizontal, Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.bgPrimary.opacity(0.92))
                .padding(-12)
        )
    }

    private var failureMessage: String {
        if case .failed(let message) = state { return message }
        return ""
    }
}

#Preview("Running") {
    AffirmationLoaderScreen(state: .running, onRetry: {})
}

#Preview("Failed") {
    AffirmationLoaderScreen(
        state: .failed("Make sure you're connected to the internet, then try again."),
        onRetry: {}
    )
}
