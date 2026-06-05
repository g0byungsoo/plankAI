import Foundation
import SwiftData

// MARK: - FoodLogRecord
//
// SwiftData @Model for a logged food entry. Mirrors the
// public.food_logs table in scripts/schema.sql exactly — column
// names use snake_case to match what SyncService payloads send to
// Supabase.
//
// One FoodLogRecord per scan/log event. Items live in
// FoodLogItemRecord (1-to-many, cascading delete).
//
// Schema versioning: wrapped in FoodLogSchemaV1: VersionedSchema
// per v3 D26. Future column additions get lightweight migration
// for free; renames/splits go through MigrationPlan.

@Model
public final class FoodLogRecord {
    @Attribute(.unique) public var id: String
    public var userId: String
    public var loggedAt: Date

    /// One of: "breakfast" | "lunch" | "dinner" | "snack". Optional;
    /// derived from logged_at time of day if unset at save time.
    public var mealSlot: String?

    /// Point-estimate plate kcal. NaN-safe: 0 when items aren't yet
    /// USDA-joined (CalorieMathService.aggregate returns 0 for an
    /// empty plate, which is the honest reading).
    public var kcalTotal: Double

    /// Range fields for restaurant_estimate source. NULL/0 for
    /// single-value sources.
    public var kcalTotalLow: Double?
    public var kcalTotalHigh: Double?

    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?

    /// One of PlateType raw values (snake_case for restaurantRange).
    public var plateType: String

    /// One of CaptureSource raw values: photo | quick_add | im_out |
    /// restaurant_estimate | barcode | voice | text | menu.
    public var source: String

    /// D13 pre-eat tracking. NULL = non-photo source or pre-D13 entry.
    public var photoMode: String?

    public var confidence: Double?

    public var createdAt: Date
    public var updatedAt: Date

    /// AppSync sweep flag — true means the row hasn't yet been
    /// confirmed by the Supabase upsert response. Mirrors the
    /// WeightLogRecord pattern. Cleared on successful upsert.
    public var pendingUpsert: Bool

    /// Reverse relationship to items. Cascade-delete: dropping a
    /// FoodLogRecord drops its items too (matches the Supabase FK
    /// ON DELETE CASCADE).
    @Relationship(deleteRule: .cascade, inverse: \FoodLogItemRecord.foodLog)
    public var items: [FoodLogItemRecord] = []

    public init(
        id: String = UUID().uuidString,
        userId: String,
        loggedAt: Date = .now,
        mealSlot: String? = nil,
        kcalTotal: Double,
        kcalTotalLow: Double? = nil,
        kcalTotalHigh: Double? = nil,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        fiberG: Double? = nil,
        plateType: String,
        source: String,
        photoMode: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.userId = userId
        self.loggedAt = loggedAt
        self.mealSlot = mealSlot ?? Self.mealSlotForTime(loggedAt)
        self.kcalTotal = kcalTotal
        self.kcalTotalLow = kcalTotalLow
        self.kcalTotalHigh = kcalTotalHigh
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.plateType = plateType
        self.source = source
        self.photoMode = photoMode
        self.confidence = confidence
        self.createdAt = .now
        self.updatedAt = .now
        self.pendingUpsert = true
    }

    /// Default meal slot from local hour-of-day. User can override
    /// later via the food log editor.
    public static func mealSlotForTime(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<11:  return "breakfast"
        case 11..<15: return "lunch"
        case 15..<18: return "snack"
        default:      return "dinner"
        }
    }
}
