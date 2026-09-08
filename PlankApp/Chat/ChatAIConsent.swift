import SwiftUI

// MARK: - ChatAIConsent (p81)
//
// The chat envelope carries strictly more sensitive facts than a
// dinner photo — the medication compound, dose events, symptoms, the
// weight trend, and her own notes — and it rides to a third-party
// model (OpenAI, via the jeni-chat function). The food door has had
// an explicit consent sheet since v25 E5; chat had only the statutory
// identity line, which answers "is this a person?" and says nothing
// about where the words go. App Review 5.1.2(i) (as of 2025-11-13,
// "including with third-party AI") requires the disclosure AND the
// explicit permission BEFORE the data flows.
//
// Same stop-gap storage shape as FoodAIConsent (AppStorage, swept at
// sign-out with the food keys, restated per device) so the eventual
// server-side consent column migrates both with one rename.
enum ChatAIConsent {
    /// AppStorage key — `Bool`. `true` once the user has tapped accept.
    static let acceptedKey = "chatAIConsentAccepted"
    /// AppStorage key — ISO8601 timestamp string of when accept fired.
    static let acceptedAtKey = "chatAIConsentAt"

    static func hasAccepted() -> Bool {
        UserDefaults.standard.bool(forKey: acceptedKey)
    }

    static func markAccepted() {
        UserDefaults.standard.set(true, forKey: acceptedKey)
        UserDefaults.standard.set(
            ISO8601DateFormatter().string(from: Date()),
            forKey: acceptedAtKey
        )
    }

    /// The sheet's fact rows, exposed so the disclosure can be pinned
    /// against what the envelope actually sends (p82: the sheet must
    /// name every category a reasonable person would be surprised by).
    static let disclosureFacts: [String] = [
        "what you type goes to OpenAI's model to be answered",
        "your file rides along so the answer fits you. your plan, weight trend, meals, medication record, symptoms, cycle rhythm, your notes, and what jeni remembers",
        "they don't train on it",
        "your conversations stay on this phone, not in our cloud",
    ]
}

// MARK: - The sheet
//
// Mirrors the food primer's honesty bar: name the recipient, name
// what travels, the no-training assurance, where the transcript
// lives. The identity line rides here too, so "at first chat" is a
// real placement, not a desk footnote she may scroll past.
struct ChatAIConsentSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("BEFORE YOUR FIRST MESSAGE")
                        .font(Typo.captionTracked)
                        .kerning(0.18 * 11)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.top, Space.lg)

                    Text("how jeni answers.")
                        .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title2))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, Space.sm)

                    VStack(alignment: .leading, spacing: Space.md) {
                        ForEach(ChatAIConsent.disclosureFacts, id: \.self) {
                            factRow($0)
                        }
                    }
                    .padding(.top, Space.lg)

                    Text("jeni is a digital coach. not a person, not your clinician.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.top, Space.lg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.lg)
                // §5.2 AX escape — at accessibility sizes the decision
                // joins the scroll so nothing is pinned out of reach.
                if typeSize.isAccessibilitySize { decision }
            }
            .scrollBounceBehavior(.basedOnSize)
            if !typeSize.isAccessibilitySize { decision }
        }
        .background(Palette.bgPrimary)
    }

    private var decision: some View {
        JFContinueButton(
            label: "accept",
            action: onAccept,
            secondaryLabel: "not now",
            secondaryAction: onDecline
        )
        .padding(.top, Space.sm)
    }

    private func factRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm + 2) {
            Circle()
                .fill(Palette.cocoaTertiary)
                .frame(width: 4, height: 4)
                .offset(y: -3)
                .accessibilityHidden(true)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
