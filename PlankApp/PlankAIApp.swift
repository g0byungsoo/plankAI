import SwiftUI
import SwiftData
import PlankSync

// MARK: - Orientation Control

/// Controls which orientations are allowed. Session sets this to .all,
/// everything else keeps .portrait.
class OrientationManager {
    static let shared = OrientationManager()
    var allowedOrientations: UIInterfaceOrientationMask = .portrait
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.shared.allowedOrientations
    }
}

@main
struct PlankAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Ensure Application Support directory exists before SwiftData tries to create the store
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("userExperience") private var userExperience = ""
    @AppStorage("voicePreference") private var voicePreference = "keepItReal"

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView { data in
                    userName = data.name
                    // Map focusArea to WorkoutGoal for v2 routine selection
                    switch data.focusArea {
                    case "abs": userGoal = "definition"
                    case "obliques": userGoal = "sculpting"
                    case "lowerBack": userGoal = "strength"
                    default: userGoal = "fullCore"
                    }
                    userExperience = data.experience
                    voicePreference = data.voicePreference
                    UserDefaults.standard.set(data.ageRange, forKey: "ageRange")
                    UserDefaults.standard.set(data.activityLevel, forKey: "activityLevel")
                    UserDefaults.standard.set(data.focusArea, forKey: "focusArea")
                    UserDefaults.standard.set(data.plankTime, forKey: "plankTime")
                    UserDefaults.standard.set(data.commitmentDaysPerWeek, forKey: "commitmentDays")
                    UserDefaults.standard.set(data.notificationsEnabled, forKey: "notificationsEnabled")
                    hasCompletedOnboarding = true
                }
            }
        }
        .modelContainer(for: [
            UserRecord.self,
            SessionLogRecord.self,
            DayProgressRecord.self,
            ExerciseRecord.self,
            ExerciseCalibrationRecord.self,
            SessionRatingRecord.self,
        ])
    }
}
