#if canImport(UIKit)
import SwiftUI

// MARK: - HomeFoodIntroTile
//
// Per v5 §Existing user journey + D38: dismissible soft banner shown
// above the HomeFoodCard on flag-flip day for users who installed
// pre-v1.0.7. No popup, no modal — just a tile they can tap (opens
// camera) or dismiss (hidden permanently). Auto-dismisses after 7
// days if untouched per v4 §2.
//
// Show condition (determined by caller):
//   - food_rail_enabled = true for this user
//   - hasShownIntro = false (UserDefaults flag)
//   - This is an EXISTING user (i.e. user installed before v1.0.7
//     — proxy: created_at on UserRecord predates v1.0.7 release)
//   - Less than 7 days since the flag flipped for them
//
// All four gate decisions live in HomeView (callers) since the
// FoodLogPersister + UserDefaults patterns there are app-level.

public struct HomeFoodIntroTile: View {

    public let onTap: () -> Void
    public let onDismiss: () -> Void

    public init(
        onTap: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onTap = onTap
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: FoodTheme.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("✿")
                        .font(.system(size: 14))
                        .foregroundStyle(FoodTheme.accent)
                    Text("jenifit now reads your plate")
                        .font(.custom("Fraunces72pt-SemiBold", size: 15))
                        .foregroundStyle(FoodTheme.textPrimary)
                }
                Text("tap to try — first scan takes 3 seconds")
                    .font(.system(size: 12))
                    .foregroundStyle(FoodTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("dismiss")
        }
        .padding(FoodTheme.Space.md)
        .background(FoodTheme.accentSubtle.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("jenifit now reads your plate. tap to try — first scan takes 3 seconds")
    }
}

// MARK: - Preview

#Preview("HomeFoodIntroTile") {
    VStack(spacing: 12) {
        HomeFoodIntroTile(
            onTap: { print("tap") },
            onDismiss: { print("dismiss") }
        )
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
