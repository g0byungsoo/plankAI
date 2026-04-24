import SwiftUI
import SwiftData
import PlankSync

@main
struct PlankAIApp: App {
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
                HomeView()
            } else {
                OnboardingView { data in
                    userName = data.name
                    userGoal = data.goal
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
        ])
    }
}
