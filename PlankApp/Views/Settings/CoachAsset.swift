import Foundation

/// voicePreference → coach identity. Single source for the avatar asset +
/// lowercase display name (the mapping was previously duplicated inline in
/// JenisNoteCard / CoachIntroView / OnboardingView / ChangeTrainerView).
enum CoachAsset {
    static func imageName(for voicePreference: String) -> String {
        switch voicePreference {
        case "balanced":   return "coach-matson"
        case "keepItReal": return "coach-kira"
        default:           return "coach-jeni"
        }
    }

    static func displayName(for voicePreference: String) -> String {
        switch voicePreference {
        case "balanced":   return "sam"
        case "keepItReal": return "kira"
        default:           return "jeni"
        }
    }
}
