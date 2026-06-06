#if canImport(UIKit)
import SwiftUI

// MARK: - FoodAIConsentSheet
//
// One-time Apple 5.1.2(i) disclosure modal. Fires the first time a user
// taps the food camera, before any photo capture or model call happens.
// Apple's policy expects users to understand when third-party AI is
// processing their data and to have an explicit accept/decline at the
// boundary.
//
// Per sprint W5-T4 + plan §AI disclosure (locked copy):
//   "to read what's on your plate, JeniFit shares your photo with
//   vision models from OpenAI and Anthropic. they don't train on
//   your data."
//
// Plus a 3-line "what you're agreeing to" detail block — required for
// review credibility but kept short (long disclosure = read as fine
// print = accept-blindly = compliance theatre).
//
// Acceptance persists via AppStorage as a stop-gap. Schema work to
// sync `food_ai_consent_at` into Supabase profile lands in a follow-up
// ticket; the AppStorage value is the source of truth on-device.
// Re-prompt is required if any provider changes (future-proof in
// the policy clause — not enforced by code yet; would key the
// AppStorage flag by provider set hash when that happens).
//
// Decline → onDecline closure runs. CaptureFlowView interprets this
// as "user backed out" and dismisses the capture flow entirely so the
// user lands back on Home. They can re-tap the food card any time to
// see the sheet again.

@MainActor
public struct FoodAIConsentSheet: View {

    public let onAccept: () -> Void
    public let onDecline: () -> Void

    public init(onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.onAccept = onAccept
        self.onDecline = onDecline
    }

    public var body: some View {
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            VStack(spacing: FoodTheme.Space.lg) {
                Spacer(minLength: FoodTheme.Space.lg)

                // Headline — italic-Fraunces punch on "read"
                ItalicAccentText(
                    "before we read your plate ♥",
                    italic: ["read"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 26),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                    color: FoodTheme.textPrimary,
                    alignment: .leading
                )
                .padding(.horizontal, FoodTheme.Space.lg)

                // Body — locked disclosure copy per plan §AI disclosure
                Text("to read what's on your plate, JeniFit shares your photo with vision models from OpenAI and Anthropic. they don't train on your data.")
                    .font(.system(size: 15))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, FoodTheme.Space.lg)

                // Detail block — scrapbook chrome, 3 lines
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(icon: "checkmark.circle.fill",
                              text: "photos go to OpenAI + Anthropic")
                    detailRow(icon: "checkmark.circle.fill",
                              text: "they don't train on your data")
                    detailRow(icon: "checkmark.circle.fill",
                              text: "deleted after analysis, unless you opt to keep")
                }
                .padding(FoodTheme.Space.md)
                .background(FoodTheme.bgElevated, in: RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                        .stroke(FoodTheme.textPrimary, lineWidth: FoodTheme.Stroke.scrapbook)
                )
                .shadow(color: FoodTheme.textPrimary.opacity(0.25), radius: 0, x: 3, y: 3)
                .padding(.horizontal, FoodTheme.Space.lg)

                Spacer(minLength: FoodTheme.Space.lg)

                // CTAs — cocoa pill primary, text-only secondary
                VStack(spacing: 12) {
                    Button(action: onAccept) {
                        Text("accept ♥")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                            .foregroundStyle(FoodTheme.bgPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(FoodTheme.textPrimary)
                            .clipShape(Capsule())
                    }
                    Button(action: onDecline) {
                        Text("not now")
                            .font(.system(size: 14))
                            .foregroundStyle(FoodTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, FoodTheme.Space.lg)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            FoodAnalytics.track(.aiConsentShown)
        }
    }


    @ViewBuilder
    private func detailRow(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FoodTheme.accent)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Consent storage key
//
// AppStorage stop-gap until the food_ai_consent_at column ships in
// Supabase. Key chosen to match the spec field name so the migration
// is a 1:1 rename.

public enum FoodAIConsent {
    /// AppStorage key — `Bool`. `true` once the user has tapped accept.
    public static let acceptedKey = "foodAIConsentAccepted"
    /// AppStorage key — ISO8601 timestamp string of when accept fired.
    public static let acceptedAtKey = "foodAIConsentAt"

    /// Snapshot read — true if the user has accepted the disclosure at
    /// any point on this device.
    public static func hasAccepted() -> Bool {
        UserDefaults.standard.bool(forKey: acceptedKey)
    }

    /// Mark accepted now. Idempotent.
    public static func markAccepted() {
        UserDefaults.standard.set(true, forKey: acceptedKey)
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: Date()),
                                  forKey: acceptedAtKey)
    }
}

#endif  // canImport(UIKit)
