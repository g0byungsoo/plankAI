import SwiftData
@testable import plankAI
import PlankSync

// ONE in-memory ModelContainer for the whole test process. The
// project's cross-package @Model registration HANGS the main thread
// on a SECOND in-memory container in the same process (the failure
// that exiled the food models from the app container — see
// PlankAIApp.modelContainer notes), and a subset schema crashes, so
// every SwiftData-touching test class shares THIS container, uses
// distinct userIds, and never creates its own.

enum TestModelContainer {
    static let shared: ModelContainer = {
        try! ModelContainer(
            for: UserRecord.self, SessionLogRecord.self, DayProgressRecord.self,
                ExerciseRecord.self, ExerciseCalibrationRecord.self,
                SessionRatingRecord.self, WeightLogRecord.self,
                ProgramPlanRecord.self, ProgramDayCheckRecord.self, ChatMessageRecord.self,
                ObservationRecord.self, RegimenPlanRecord.self,
                ConsentGrantRecord.self, BodyScanRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()
}
