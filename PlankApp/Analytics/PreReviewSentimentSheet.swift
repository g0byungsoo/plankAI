import SwiftUI
import UIKit

// MARK: - PreReviewSentimentSheet
//
// "Loving it?" pre-prompt sentiment gate (Headspace pattern — lifts star
// rating average by ~0.5 because dissatisfied users self-route to
// feedback instead of 1-starring on the App Store). Used by the
// sessionThreePR and dayStreakSeven triggers in PostSessionView and
// HomeView; the onboarding postPlanReveal trigger has its own inline
// sentiment UI at case 215 and does NOT use this sheet.
//
// Behavior:
//   - "yes, loving it" → calls onYes (which should fire the system
//     SKStoreReviewController.requestReview(in:) sheet)
//   - "not yet" → calls onNotYet (slots 2-3 route to FeedbackView mailto
//     so the dissatisfied user has somewhere to vent without burning a
//     real review slot)
//
// Voice signal stays JeniFit-locked: italic Fraunces on "loving",
// lowercase casual elsewhere, no scale/shame language.

struct PreReviewSentimentSheet: View {
    let title: String       // "loving the workout?" / "loving the streak?"
    /// Renamed from `body` to avoid collision with SwiftUI View's
    /// `var body: some View`.
    let message: String     // why we're asking
    let onYes: () -> Void   // present SKStoreReviewController
    let onNotYet: () -> Void // route to FeedbackView mailto
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle for sheet, since we're not in a NavigationView
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Palette.divider)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // 2026-05-30 visual upgrade: wrap the hero + headline +
            // message in the canonical scrapbook chrome (24pt corners,
            // 1.5pt accent border, hard offset shadow) so the sheet
            // matches the brand-promises + review-prompt screen styling.
            // Visual rhythm continuity across slots 1-3 of the rating
            // trigger set.
            VStack(spacing: Space.md) {
                // Hero sticker — heart-glossy matches the existing
                // onboarding case 215 sentiment gate so the brand
                // language stays consistent across all 3 slots.
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.12))
                        .frame(width: 84, height: 84)
                    Image(StickerName.heartGlossy.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .opacity(StickerName.heartGlossy.style.opacity)
                }
                .padding(.top, Space.md)

                // Italic Fraunces on the punch word per locked voice signals.
                (Text("loving ").font(.custom("Fraunces72pt-SemiBold", size: 24))
                 + Text(title).font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
                 + Text("?").font(.custom("Fraunces72pt-SemiBold", size: 24)))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity)
            .scrapbookCardBackground()
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, 4)

            Spacer().frame(height: Space.lg)

            VStack(spacing: 10) {
                Button {
                    Haptics.success()
                    onYes()
                    onDismiss()
                } label: {
                    Text("yes, loving it")
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundStyle(Palette.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Palette.textPrimary)
                        .clipShape(Capsule())
                }

                Button {
                    Haptics.light()
                    onNotYet()
                    onDismiss()
                } label: {
                    Text("not yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressFeedbackStyle())
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
        .background(Palette.bgPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
