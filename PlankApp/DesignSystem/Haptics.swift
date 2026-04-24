import UIKit
import AudioToolbox

/// Centralized haptic feedback. Use these instead of creating generators inline.
enum Haptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Light tap — option select, toggle, small button
    static func light() { lightImpact.impactOccurred() }

    /// Medium tap — card tap, navigation, confirm
    static func medium() { mediumImpact.impactOccurred() }

    /// Heavy tap — celebration, session start, milestone
    static func heavy() { heavyImpact.impactOccurred() }

    /// Soft — scroll snap, subtle feedback
    static func soft() { softImpact.impactOccurred() }

    /// Rigid — error, alert, warning
    static func rigid() { rigidImpact.impactOccurred() }

    /// Selection tick — picker change, segment switch
    static func tick() { selection.selectionChanged() }

    /// Success — session complete, good form confirmed
    static func success() { notification.notificationOccurred(.success) }

    /// Warning — form fault detected
    static func warning() { notification.notificationOccurred(.warning) }

    /// Error — session failed, camera blocked
    static func error() { notification.notificationOccurred(.error) }

    /// Strong vibration — like receiving a text message.
    /// Uses AudioServices, not the haptic engine. This is the real vibration motor.
    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    /// Double vibrate — two strong pulses like an urgent notification.
    static func doubleVibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}
