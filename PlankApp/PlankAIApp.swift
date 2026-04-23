import SwiftUI
import SwiftData

@main
struct PlankAIApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [
            // PlankSync models would be registered here
            // UserRecord.self,
            // SessionLogRecord.self,
            // DayProgressRecord.self,
            // ExerciseRecord.self,
            // ExerciseCalibrationRecord.self,
        ])
    }
}
