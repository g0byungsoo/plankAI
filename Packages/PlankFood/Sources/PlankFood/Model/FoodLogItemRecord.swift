import Foundation
import SwiftData

// MARK: - FoodLogItemRecord
//
// SwiftData @Model for one item inside a FoodLogRecord. Mirrors
// public.food_log_items table. user_id replicated locally to match
// the Supabase schema (where it's denormalized for RLS performance).
//
// LLM-original fields (llm*) preserved for the corrections-as-moat
// flywheel — even after a user correction, we keep what the LLM
// said so the v1.0.8 fine-tune dataset can compute the diff.

@Model
public final class FoodLogItemRecord {
    @Attribute(.unique) public var id: String

    /// Inverse of FoodLogRecord.items. SwiftData manages both
    /// sides of the @Relationship.
    public var foodLog: FoodLogRecord?

    public var userId: String
    public var name: String
    public var portionG: Double
    public var kcal: Double

    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?

    /// Lookup attribution — which DB resolved this item.
    public var usdaFdcId: Int?
    public var canonicalPantryId: String?
    public var openFoodFactsCode: String?

    // LLM-original fields. Preserved across corrections.
    public var llmName: String?
    public var llmPortionG: Double?
    public var llmConfidence: Double?

    public var position: Int

    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        portionG: Double,
        kcal: Double,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        usdaFdcId: Int? = nil,
        canonicalPantryId: String? = nil,
        openFoodFactsCode: String? = nil,
        llmName: String? = nil,
        llmPortionG: Double? = nil,
        llmConfidence: Double? = nil,
        position: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.portionG = portionG
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.usdaFdcId = usdaFdcId
        self.canonicalPantryId = canonicalPantryId
        self.openFoodFactsCode = openFoodFactsCode
        self.llmName = llmName
        self.llmPortionG = llmPortionG
        self.llmConfidence = llmConfidence
        self.position = position
        self.createdAt = .now
    }
}
