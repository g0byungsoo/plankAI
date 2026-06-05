import Foundation
import SwiftData

// MARK: - FoodLogSchemaV1
//
// VersionedSchema wrapper per v3 D26 architecture lock. SwiftData
// requires this wrapping pattern for migration support. Even though
// v1.0.7 ships only one schema version, defining it now means
// future migrations (adding columns, renaming, splitting models)
// drop in via SchemaMigrationPlan without touching the @Model
// definitions.
//
// Apple's WWDC23 #10195 + the WWDC24 SwiftData migration session
// both recommend establishing VersionedSchema from the first ship —
// retrofitting it later requires recovering the original schema
// shape from production data.

public enum FoodLogSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            FoodLogRecord.self,
            FoodLogItemRecord.self,
        ]
    }
}
