import SwiftUI

/// A true-to-iOS notification banner mock used on the onboarding
/// nudge-permission screen ("want a nudge from jeni?"). It renders the
/// real app icon (the jenifit bow mark in a squircle tile), the app name
/// + relative time, a bold notification title and a body line inside real
/// iOS banner chrome - frosted material, ~22pt squircle, hairline glass
/// edge, soft drop shadow.
///
/// On appear it drops + settles in like a notification arriving and fires
/// a bespoke "notification buzz" haptic as it lands; tapping it replays the
/// buzz with a small press-settle. The point: pre-permission, the OS can't
/// show a real banner, so she SEES and FEELS exactly what jeni's nudge will
/// feel like before deciding. Reduce-motion drops the motion but keeps the
/// haptic so the "feel it" promise still lands.
struct NudgeNotificationBanner: View {
    let title: String
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var pressed = false

    var body: some View {
        VStack(spacing: 10) {
            banner
                .scaleEffect(pressed ? 0.97 : 1)
                .offset(y: arrived ? 0 : -60)
                .opacity(arrived ? 1 : 0)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture { replay() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("notification preview from jenifit. \(title). \(message). tap to feel it.")

            Text("tap to feel it \u{2665}\u{FE0E}")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .opacity(arrived ? 1 : 0)
        }
        .onAppear { arrive() }
    }

    // MARK: - Banner chrome

    private var banner: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("jenifit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 8)
                    Text("now")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Palette.textSecondary.opacity(0.7))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    /// The app icon: the jenifit bow mark inset on a soft-rose squircle
    /// tile so it reads instantly as "an icon from this app." iOS app
    /// icons are ~22.5% corner-radius squircles; 9 / 38 matches that.
    private var icon: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Palette.accentSubtle)
            .frame(width: 38, height: 38)
            .overlay(
                Image("logo_jenifit_bow")
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.5)
            )
    }

    // MARK: - Motion + haptics

    private func arrive() {
        guard !arrived else { return }
        guard !reduceMotion else {
            arrived = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                ActivationHaptics.shared.notificationBuzz()
            }
            return
        }
        // Drop in from the top + settle, then buzz as it lands - the
        // cadence of a real notification arriving.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.74)) {
                arrived = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                ActivationHaptics.shared.notificationBuzz()
            }
        }
    }

    private func replay() {
        ActivationHaptics.shared.notificationBuzz()
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) { pressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) { pressed = false }
        }
    }
}
