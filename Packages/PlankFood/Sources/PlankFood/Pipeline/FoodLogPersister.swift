import Foundation
import SwiftData

// MARK: - FoodLogPersister
//
// Saves CapturedFood (the in-memory result from FoodCaptureDispatcher)
// as SwiftData FoodLogRecord + FoodLogItemRecord rows. Called from
// the result card's "log it" CTA after the user confirms.
//
// SwiftData inserts run synchronously on the ModelContext's actor;
// we wrap in MainActor since the call site is UI-driven. Persistence
// is local-first — Supabase upsert happens on the AppSync sweep
// (existing pattern via pendingUpsert flag).
//
// W3-T6 scope: local persistence only. Supabase upsertFoodLog
// method on PlankApp/Sync/AppSync.swift is a follow-on in this
// same ticket — see the bottom of the file.

@MainActor
public enum FoodLogPersister {

    /// Insert a CapturedFood into the given ModelContext. Returns
    /// the inserted FoodLogRecord (caller may use its id for
    /// telemetry or navigation). Throws on context errors.
    @discardableResult
    public static func persist(
        _ food: CapturedFood,
        userId: String,
        photoMode: PhotoMode? = nil,
        into context: ModelContext
    ) throws -> FoodLogRecord {

        // Aggregate plate-level totals via the load-bearing math
        // service (v3 D26: same path for any kcal display).
        let itemNutrition = food.items.map { item in
            CalorieMathService.ItemNutrition(
                kcal: item.kcal ?? 0,
                kcalLow: item.kcal ?? 0,
                kcalHigh: item.kcal ?? 0,
                proteinG: item.proteinG ?? 0,
                carbsG: item.carbsG ?? 0,
                fatG: item.fatG ?? 0,
                fiberG: item.fiberG ?? 0
            )
        }
        let plate = CalorieMathService.aggregate(itemNutrition)

        let record = FoodLogRecord(
            userId: userId,
            kcalTotal: food.kcalLow != nil ? (food.kcalLow! + food.kcalHigh!) / 2 : plate.totalKcal,
            kcalTotalLow: food.kcalLow,
            kcalTotalHigh: food.kcalHigh,
            proteinG: plate.totalProteinG.optionalNonZero,
            carbsG: plate.totalCarbsG.optionalNonZero,
            fatG: plate.totalFatG.optionalNonZero,
            fiberG: plate.totalFiberG.optionalNonZero,
            plateType: food.plateType.rawValue,
            source: food.source.rawValue,
            photoMode: photoMode?.rawValue,
            confidence: food.confidence
        )

        // Insert parent first, then items (FK reference satisfied).
        context.insert(record)

        for (index, item) in food.items.enumerated() {
            let itemRecord = FoodLogItemRecord(
                userId: userId,
                name: item.name,
                portionG: item.portionGrams,
                kcal: item.kcal ?? 0,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                usdaFdcId: item.nutritionSource == .usdaFDC ? Int(item.usdaSearchTerms.first ?? "") : nil,
                canonicalPantryId: item.nutritionSource == .canonicalPantry ? item.id : nil,
                openFoodFactsCode: item.nutritionSource == .openFoodFacts ? item.id : nil,
                llmName: item.name,
                llmPortionG: item.portionGrams,
                llmConfidence: item.confidence,
                position: index
            )
            itemRecord.foodLog = record
            context.insert(itemRecord)
        }

        try context.save()
        return record
    }
}

// MARK: - Helpers

private extension Double {
    var optionalNonZero: Double? {
        self > 0 ? self : nil
    }
}
